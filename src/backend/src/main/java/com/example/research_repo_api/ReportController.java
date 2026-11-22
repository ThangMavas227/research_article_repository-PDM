package com.example.research_repo_api;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Report endpoints for the Topic 18 queries Q3, Q4 and Q5 (public, read-only).
 * The SQL is the one in db/query.sql; user values are always bound as ? parameters.
 *
 * GET /api/reports/top-cited?areaId=SA001                    ten most cited articles of one subject area (Q3)
 * GET /api/reports/authors-all-venues?venueIds=V002,V007     authors who published in EVERY listed venue (Q4)
 * GET /api/reports/average-authors-by-year                   average number of authors per article per year (Q5)
 */
@RestController
@RequestMapping("/api/reports")
public class ReportController {

    private static final int MAX_VENUES = 20;

    private final JdbcTemplate jdbc;

    public ReportController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record TopCitedItem(String id, String title, String subjectArea, long citationCount) {}

    public record AuthorItem(String id, String name) {}

    public record YearAverage(int year, long articles, long totalAuthors, double averageAuthorsPerArticle) {}

    /** Q3, same SQL as db/query.sql. LEFT JOIN: articles that were never cited are listed too, with citationCount 0. */
    @GetMapping("/top-cited")
    public List<TopCitedItem> topCited(@RequestParam(required = false) String areaId) {
        if (areaId == null || areaId.isBlank()) throw new BadRequestException("areaId is required");
        String id = areaId.trim();
        Integer exists = jdbc.queryForObject("SELECT COUNT(*) FROM SubjectArea WHERE AreaID = ?", Integer.class, id);
        if (exists == null || exists == 0) throw new BadRequestException("unknown subject area: " + id);

        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT A.ArticleID, A.Title, SA.Name AS SubjectArea,"
                        + " COUNT(DISTINCT C.CitingArticleID) AS CitationCount"
                        + " FROM Article A"
                        + " JOIN Classified CL ON A.ArticleID = CL.ArticleID"
                        + " JOIN SubjectArea SA ON CL.AreaID = SA.AreaID"
                        + " LEFT JOIN Citation C ON A.ArticleID = C.CitedArticleID"
                        + " WHERE SA.AreaID = ?"
                        + " GROUP BY A.ArticleID, A.Title, SA.AreaID, SA.Name"
                        + " ORDER BY CitationCount DESC, A.Title LIMIT 10", id);
        List<TopCitedItem> items = new ArrayList<>();
        for (Map<String, Object> r : rows) {
            items.add(new TopCitedItem((String) r.get("ArticleID"), (String) r.get("Title"),
                    (String) r.get("SubjectArea"), ((Number) r.get("CitationCount")).longValue()));
        }
        return items;
    }

    /** Q4, relational division written with two NOT EXISTS. venueIds is a comma-separated list. */
    @GetMapping("/authors-all-venues")
    public List<AuthorItem> authorsInAllVenues(@RequestParam(required = false) List<String> venueIds) {
        Set<String> ids = new LinkedHashSet<>();
        if (venueIds != null) {
            for (String part : venueIds) {
                if (part == null) continue;
                for (String s : part.split(",")) {
                    if (!s.isBlank()) ids.add(s.trim());
                }
            }
        }
        if (ids.isEmpty()) throw new BadRequestException("venueIds is required (e.g. venueIds=V002,V007)");
        if (ids.size() > MAX_VENUES) throw new BadRequestException("at most " + MAX_VENUES + " venues");

        String marks = String.join(",", java.util.Collections.nCopies(ids.size(), "?"));
        Integer known = jdbc.queryForObject("SELECT COUNT(*) FROM Venue WHERE VenueID IN (" + marks + ")",
                Integer.class, ids.toArray());
        if (known == null || known != ids.size()) throw new BadRequestException("unknown venue in venueIds");

        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT au.AuthorID, au.FullName FROM Author au WHERE NOT EXISTS ("
                        + " SELECT 1 FROM Venue v WHERE v.VenueID IN (" + marks + ")"
                        + " AND NOT EXISTS (SELECT 1 FROM Writes w JOIN Article a ON a.ArticleID = w.ArticleID"
                        + " WHERE w.AuthorID = au.AuthorID AND a.VenueID = v.VenueID))"
                        + " ORDER BY au.FullName, au.AuthorID", ids.toArray());
        List<AuthorItem> items = new ArrayList<>();
        for (Map<String, Object> r : rows) {
            items.add(new AuthorItem((String) r.get("AuthorID"), (String) r.get("FullName")));
        }
        return items;
    }

    /** Q5. */
    @GetMapping("/average-authors-by-year")
    public List<YearAverage> averageAuthorsByYear() {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT e.PubYear, COUNT(*) AS Articles, SUM(t.NumAuthors) AS TotalAuthors,"
                        + " ROUND(AVG(t.NumAuthors), 2) AS AvgAuthorsPerArticle"
                        + " FROM Article a"
                        + " JOIN Edition e ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber"
                        + " JOIN (SELECT ArticleID, COUNT(*) AS NumAuthors FROM Writes GROUP BY ArticleID) t"
                        + " ON t.ArticleID = a.ArticleID"
                        + " GROUP BY e.PubYear ORDER BY e.PubYear");
        List<YearAverage> items = new ArrayList<>();
        for (Map<String, Object> r : rows) {
            items.add(new YearAverage(((Number) r.get("PubYear")).intValue(), ((Number) r.get("Articles")).longValue(),
                    ((Number) r.get("TotalAuthors")).longValue(),
                    ((Number) r.get("AvgAuthorsPerArticle")).doubleValue()));
        }
        return items;
    }
}
