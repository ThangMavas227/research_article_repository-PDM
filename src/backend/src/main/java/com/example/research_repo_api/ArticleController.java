package com.example.research_repo_api;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import java.util.HashSet;
import java.util.Set;
import java.util.regex.Pattern;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.servlet.http.HttpServletRequest;

/**
 * GET    /api/articles?keyword=&year=&yearFrom=&yearTo=&venueType=&page=1&size=10   public (no login)
 * POST   /api/articles                                admin only: add an article
 * PUT    /api/articles/{id}                           admin only: edit an article
 * DELETE /api/articles/{id}                           admin only: delete an article
 * Every article has the same shape everywhere (list, POST and PUT responses):
 * {id,title,year,doi,abstract,venueId,venueName,editionNumber,startPage,authors:[{id,name}],
 *  references:[{id,title}],citedBy:[{id,title}]}
 */
@RestController
@RequestMapping("/api/articles")
public class ArticleController {

    private static final int MAX_SIZE = 100;

    private static final String ARTICLE_COLUMNS =
            "SELECT a.ArticleID, a.Title, a.DOI, a.Abstract, a.StartPage, a.VenueID, v.Name AS VenueName,"
                    + " a.EditionNumber, e.PubYear";
    private static final String ARTICLE_FROM =
            " FROM Article a JOIN Edition e ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber"
                    + " JOIN Venue v ON v.VenueID = a.VenueID";

    private static final Pattern DOI = Pattern.compile("^10\\.[0-9]{4,9}/.+");

    private final JdbcTemplate jdbc;
    private final AuthService auth;

    public ArticleController(JdbcTemplate jdbc, AuthService auth) {
        this.jdbc = jdbc;
        this.auth = auth;
    }

    public record AuthorItem(String id, String name) {}

    public record RefItem(String id, String title) {}

    public record ArticleItem(String id, String title, int year, String doi, String abstractText,
            String venueId, String venueName, int editionNumber, int startPage,
            List<AuthorItem> authors, List<RefItem> references, List<RefItem> citedBy) {

        /** JSON field is "abstract" (a Java keyword, so the record component has another name). */
        @JsonProperty("abstract")
        public String abstractText() { return abstractText; }
    }

    /** One author of an article: give {id} for an existing author, or {name} to create a new author. */
    public record AuthorInput(String id, String name) {}

    /** Body of POST / PUT. authors are in writing order (first = Position 1). */
    public record ArticleRequest(String title, String doi,
            @JsonProperty("abstract") String abstractText,
            Integer startPage, String venueId, Integer editionNumber, List<AuthorInput> authors) {}

    public record ArticlePage(List<ArticleItem> items, int page, int size, long totalItems, int totalPages) {}

    @GetMapping
    public ArticlePage list(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer yearFrom,
            @RequestParam(required = false) Integer yearTo,
            @RequestParam(required = false) String venueType,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {

        if (page < 1) throw new BadRequestException("page must be >= 1");
        if (size < 1 || size > MAX_SIZE) throw new BadRequestException("size must be between 1 and " + MAX_SIZE);

        // Keep ?year= for existing browse.js clients. SavedSearch uses the range filters.
        if (year != null && (yearFrom != null || yearTo != null)) {
            throw new BadRequestException("year cannot be combined with yearFrom or yearTo");
        }
        SearchCriteria.validateYear("year", year);
        SearchCriteria filters = SearchCriteria.normalized(keyword, yearFrom, yearTo, venueType);

        // Build WHERE only from fixed SQL; bind all user input with placeholders.
        StringBuilder where = new StringBuilder(" WHERE 1=1");
        List<Object> args = new ArrayList<>();
        if (filters.keyword() != null) {
            // Match the title OR the name of any author of the article.
            // The database collation (utf8mb4_0900_ai_ci) already ignores case and accents.
            where.append(" AND (a.Title LIKE ? ESCAPE '\\\\' OR EXISTS ("
                    + "SELECT 1 FROM Writes w2 JOIN Author au2 ON au2.AuthorID = w2.AuthorID"
                    + " WHERE w2.ArticleID = a.ArticleID AND au2.FullName LIKE ? ESCAPE '\\\\'))");
            String pattern = "%" + escapeLike(filters.keyword()) + "%";
            args.add(pattern);
            args.add(pattern);
        }
        if (year != null) {
            where.append(" AND e.PubYear = ?");
            args.add(year);
        }
        if (filters.yearFrom() != null) {
            where.append(" AND e.PubYear >= ?");
            args.add(filters.yearFrom());
        }
        if (filters.yearTo() != null) {
            where.append(" AND e.PubYear <= ?");
            args.add(filters.yearTo());
        }
        if (filters.venueType() != null) {
            where.append(" AND v.VenueType = ?");
            args.add(filters.venueType());
        }

        Long total = jdbc.queryForObject("SELECT COUNT(*)" + ARTICLE_FROM + where, Long.class, args.toArray());
        long totalItems = total == null ? 0 : total;
        int totalPages = (int) ((totalItems + size - 1) / size);

        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(size);
        pageArgs.add((long) (page - 1) * size);
        List<Map<String, Object>> rows = jdbc.queryForList(
                ARTICLE_COLUMNS + ARTICLE_FROM + where
                        + " ORDER BY e.PubYear DESC, a.Title, a.ArticleID LIMIT ? OFFSET ?",
                pageArgs.toArray());

        return new ArticlePage(toItems(rows), page, size, totalItems, totalPages);
    }

    /** Builds full article objects (authors, references, citedBy) for rows from ARTICLE_COLUMNS. */
    private List<ArticleItem> toItems(List<Map<String, Object>> rows) {
        Map<String, List<AuthorItem>> authorsByArticle = loadAuthors(rows);
        // references: articles this one cites; citedBy: articles that cite this one.
        Map<String, List<RefItem>> refs = loadCitations(rows, "CitingArticleID", "CitedArticleID");
        Map<String, List<RefItem>> citedBy = loadCitations(rows, "CitedArticleID", "CitingArticleID");

        List<ArticleItem> items = new ArrayList<>();
        for (Map<String, Object> r : rows) {
            String id = (String) r.get("ArticleID");
            items.add(new ArticleItem(id, (String) r.get("Title"),
                    ((Number) r.get("PubYear")).intValue(),
                    (String) r.get("DOI"), (String) r.get("Abstract"),
                    (String) r.get("VenueID"), (String) r.get("VenueName"),
                    ((Number) r.get("EditionNumber")).intValue(), ((Number) r.get("StartPage")).intValue(),
                    authorsByArticle.getOrDefault(id, List.of()),
                    refs.getOrDefault(id, List.of()),
                    citedBy.getOrDefault(id, List.of())));
        }
        return items;
    }

    private ArticleItem loadOne(String id) {
        List<Map<String, Object>> rows = jdbc.queryForList(ARTICLE_COLUMNS + ARTICLE_FROM + " WHERE a.ArticleID = ?", id);
        if (rows.isEmpty()) throw new ApiException(HttpStatus.NOT_FOUND, "article not found");
        return toItems(rows).get(0);
    }

    // ---------------------------------------------------------------- write endpoints (admin only)

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public ArticleItem create(HttpServletRequest request, @RequestBody(required = false) ArticleRequest body) {
        auth.requireAdmin(request);
        validate(body, true);
        String id = nextId("Article", "ArticleID", "AR");
        jdbc.update("INSERT INTO Article (ArticleID, Title, DOI, Abstract, StartPage, VenueID, EditionNumber)"
                + " VALUES (?, ?, ?, ?, ?, ?, ?)",
                id, body.title().trim(), body.doi().trim(), blankToNull(body.abstractText()),
                body.startPage(), body.venueId().trim(), body.editionNumber());
        writeAuthors(id, body.authors());
        return loadOne(id);
    }

    /** Full edit: title, doi, abstract, startPage, venueId, editionNumber are required. authors is optional
     *  (omit = keep the current authors; send a list = replace them). */
    @PutMapping("/{id}")
    @Transactional
    public ArticleItem update(HttpServletRequest request, @PathVariable String id,
            @RequestBody(required = false) ArticleRequest body) {
        auth.requireAdmin(request);
        requireExists(id);
        validate(body, false);
        jdbc.update("UPDATE Article SET Title = ?, DOI = ?, Abstract = ?, StartPage = ?, VenueID = ?, EditionNumber = ?"
                + " WHERE ArticleID = ?",
                body.title().trim(), body.doi().trim(), blankToNull(body.abstractText()),
                body.startPage(), body.venueId().trim(), body.editionNumber(), id);
        if (body.authors() != null) {
            jdbc.update("DELETE FROM Writes WHERE ArticleID = ?", id);
            writeAuthors(id, body.authors());
        }
        return loadOne(id);
    }

    /** Deletes the article together with its author links, citations (both directions), subjects and keywords. */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void delete(HttpServletRequest request, @PathVariable String id) {
        auth.requireAdmin(request);
        if (jdbc.update("DELETE FROM Article WHERE ArticleID = ?", id) == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "article not found");
        }
    }

    private void requireExists(String id) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM Article WHERE ArticleID = ?", Integer.class, id);
        if (n == null || n == 0) throw new ApiException(HttpStatus.NOT_FOUND, "article not found");
    }

    private void validate(ArticleRequest b, boolean authorsRequired) {
        if (b == null) throw new BadRequestException("request body is required");
        if (b.title() == null || b.title().isBlank()) throw new BadRequestException("title is required");
        if (b.title().trim().length() > 255) throw new BadRequestException("title must be at most 255 characters");
        if (b.doi() == null || b.doi().isBlank()) throw new BadRequestException("doi is required");
        if (!DOI.matcher(b.doi().trim()).matches() || b.doi().trim().length() > 100) {
            throw new BadRequestException("doi must look like 10.1234/abc (at most 100 characters)");
        }
        if (b.startPage() == null || b.startPage() < 1) throw new BadRequestException("startPage is required and must be >= 1");
        if (b.venueId() == null || b.venueId().isBlank()) throw new BadRequestException("venueId is required");
        if (b.editionNumber() == null || b.editionNumber() < 1) {
            throw new BadRequestException("editionNumber is required and must be >= 1");
        }
        Integer ed = jdbc.queryForObject("SELECT COUNT(*) FROM Edition WHERE VenueID = ? AND EditionNumber = ?",
                Integer.class, b.venueId().trim(), b.editionNumber());
        if (ed == null || ed == 0) throw new BadRequestException("this venue/edition does not exist");

        if (b.authors() == null) {
            if (authorsRequired) throw new BadRequestException("authors must contain at least one author");
            return;
        }
        if (b.authors().isEmpty()) throw new BadRequestException("authors must contain at least one author");
        Set<String> seen = new HashSet<>();
        for (AuthorInput a : b.authors()) {
            boolean hasId = a != null && a.id() != null && !a.id().isBlank();
            boolean hasName = a != null && a.name() != null && !a.name().isBlank();
            if (hasId == hasName) throw new BadRequestException("each author needs either id (existing) or name (new), not both");
            if (hasName && a.name().trim().length() > 150) throw new BadRequestException("author name must be at most 150 characters");
            if (hasId) {
                if (!seen.add(a.id().trim())) throw new BadRequestException("the same author is listed twice");
                Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM Author WHERE AuthorID = ?", Integer.class, a.id().trim());
                if (n == null || n == 0) throw new BadRequestException("author not found: " + a.id().trim());
            }
        }
    }

    /** Inserts the Writes rows (Position 1, 2, 3 ... in list order); new authors are created first. */
    private void writeAuthors(String articleId, List<AuthorInput> authors) {
        int position = 1;
        for (AuthorInput a : authors) {
            String authorId;
            if (a.id() != null && !a.id().isBlank()) {
                authorId = a.id().trim();
            } else {
                authorId = nextId("Author", "AuthorID", "AU");
                jdbc.update("INSERT INTO Author (AuthorID, FullName) VALUES (?, ?)", authorId, a.name().trim());
            }
            jdbc.update("INSERT INTO Writes (ArticleID, AuthorID, Position) VALUES (?, ?, ?)", articleId, authorId, position++);
        }
    }

    /** Next id such as AR041: the largest number already used with this prefix, plus one. */
    private String nextId(String table, String column, String prefix) {
        Long max = jdbc.queryForObject("SELECT COALESCE(MAX(CAST(SUBSTRING(" + column + ", 3) AS UNSIGNED)), 0) FROM "
                + table + " WHERE " + column + " REGEXP '^" + prefix + "[0-9]+$'", Long.class);
        return String.format("%s%03d", prefix, (max == null ? 0 : max) + 1);
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    /** Authors of the given articles, ordered by Writes.Position. One query for the whole page. */
    private Map<String, List<AuthorItem>> loadAuthors(List<Map<String, Object>> rows) {
        Map<String, List<AuthorItem>> out = new HashMap<>();
        if (rows.isEmpty()) return out;
        String marks = String.join(",", Collections.nCopies(rows.size(), "?"));
        Object[] ids = rows.stream().map(r -> r.get("ArticleID")).toArray();
        jdbc.query("SELECT w.ArticleID, au.AuthorID, au.FullName FROM Writes w"
                + " JOIN Author au ON au.AuthorID = w.AuthorID"
                + " WHERE w.ArticleID IN (" + marks + ") ORDER BY w.ArticleID, w.Position",
                rs -> {
                    out.computeIfAbsent(rs.getString(1), k -> new ArrayList<>())
                            .add(new AuthorItem(rs.getString(2), rs.getString(3)));
                }, ids);
        return out;
    }

    /**
     * Citation neighbours of the given articles, one query for the whole page.
     * keyCol = the column that equals the page's article, otherCol = the neighbour article.
     * Both arguments are fixed literals from this class, never user input.
     */
    private Map<String, List<RefItem>> loadCitations(List<Map<String, Object>> rows, String keyCol, String otherCol) {
        Map<String, List<RefItem>> out = new HashMap<>();
        if (rows.isEmpty()) return out;
        String marks = String.join(",", Collections.nCopies(rows.size(), "?"));
        Object[] ids = rows.stream().map(r -> r.get("ArticleID")).toArray();
        jdbc.query("SELECT c." + keyCol + ", o.ArticleID, o.Title FROM Citation c"
                + " JOIN Article o ON o.ArticleID = c." + otherCol
                + " WHERE c." + keyCol + " IN (" + marks + ") ORDER BY c." + keyCol + ", o.ArticleID",
                rs -> {
                    out.computeIfAbsent(rs.getString(1), k -> new ArrayList<>())
                            .add(new RefItem(rs.getString(2), rs.getString(3)));
                }, ids);
        return out;
    }

    private static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
