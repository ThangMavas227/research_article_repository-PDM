package com.example.research_repo_api;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;

import jakarta.servlet.http.HttpServletRequest;

/** Every query is scoped by UserID from an authenticated Bearer token, never a client-supplied id. */
@RestController
@RequestMapping("/api/saved-searches")
public class SavedSearchController {

    public record CreateSavedSearchRequest(String searchName, SearchCriteria criteria) {}
    public record SavedSearchItem(String searchName, SearchCriteria criteria, LocalDateTime createdDate) {}
    public record SavedSearchList(List<SavedSearchItem> items) {}

    private static final String SELECT_COLUMNS = "SELECT SearchName, Criteria, CreatedDate FROM SavedSearch";

    private final JdbcTemplate jdbc;
    private final AuthService auth;
    private final JsonMapper json;

    public SavedSearchController(JdbcTemplate jdbc, AuthService auth, JsonMapper json) {
        this.jdbc = jdbc;
        this.auth = auth;
        this.json = json;
    }

    /** POST: 201 with the newly saved search, or 409 for a duplicate name within this account. */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public SavedSearchItem create(HttpServletRequest request,
            @RequestBody(required = false) CreateSavedSearchRequest body) {
        String userId = auth.requireUser(request).id();
        if (body == null) throw new BadRequestException("request body is required");
        String name = normalizedName(body.searchName());
        if (body.criteria() == null) throw new BadRequestException("criteria is required");
        SearchCriteria criteria = body.criteria().normalized();

        try {
            // Insert relies on PK (UserID, SearchName): safe even for concurrent duplicate requests.
            jdbc.update("INSERT INTO SavedSearch (UserID, SearchName, Criteria) VALUES (?, ?, ?)",
                    userId, name, encode(criteria));
        } catch (DuplicateKeyException e) {
            throw new ApiException(HttpStatus.CONFLICT, "a saved search with this searchName already exists");
        }
        return jdbc.queryForObject(SELECT_COLUMNS + " WHERE UserID = ? AND SearchName = ?",
                (rs, row) -> mapItem(rs.getString("SearchName"), rs.getString("Criteria"),
                        rs.getTimestamp("CreatedDate").toLocalDateTime()),
                userId, name);
    }

    /** GET: only the searches belonging to the logged-in user. */
    @GetMapping
    public SavedSearchList list(HttpServletRequest request) {
        String userId = auth.requireUser(request).id();
        List<SavedSearchItem> items = jdbc.query(SELECT_COLUMNS
                        + " WHERE UserID = ? ORDER BY CreatedDate DESC, SearchName ASC",
                (rs, row) -> mapItem(rs.getString("SearchName"), rs.getString("Criteria"),
                        rs.getTimestamp("CreatedDate").toLocalDateTime()),
                userId);
        return new SavedSearchList(items);
    }

    /** DELETE: 204 only when that user's named search was deleted; otherwise 404. */
    @DeleteMapping("/{searchName}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void delete(HttpServletRequest request, @PathVariable String searchName) {
        String userId = auth.requireUser(request).id();
        String name = normalizedName(searchName);
        int deleted = jdbc.update("DELETE FROM SavedSearch WHERE UserID = ? AND SearchName = ?", userId, name);
        if (deleted == 0) throw new ApiException(HttpStatus.NOT_FOUND, "saved search not found");
    }

    private static String normalizedName(String name) {
        if (name == null || name.isBlank()) throw new BadRequestException("searchName is required");
        String trimmed = name.trim();
        if (trimmed.length() > 100) throw new BadRequestException("searchName must be at most 100 characters");
        // A slash cannot be reliably round-tripped through a path segment on all HTTP servers.
        if (trimmed.indexOf('/') >= 0 || trimmed.indexOf('\\') >= 0) {
            throw new BadRequestException("searchName must not contain / or backslash");
        }
        return trimmed;
    }

    private String encode(SearchCriteria criteria) {
        try {
            return json.writeValueAsString(criteria);
        } catch (JacksonException e) {
            throw new IllegalStateException("cannot serialize saved search criteria", e);
        }
    }

    private SavedSearchItem mapItem(String name, String rawCriteria, LocalDateTime createdDate) {
        try {
            SearchCriteria criteria = json.readValue(rawCriteria, SearchCriteria.class);
            return new SavedSearchItem(name, criteria.normalized(), createdDate);
        } catch (JacksonException e) {
            throw new IllegalStateException("invalid saved-search JSON in database", e);
        }
    }
}
