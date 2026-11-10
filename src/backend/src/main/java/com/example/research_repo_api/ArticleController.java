package com.example.research_repo_api;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * GET /api/articles?keyword=&year=&page=1&size=8
 * Public endpoint (no login). Response shape follows the frontend contract (browse.js):
 * { items:[{id,title,year,authors:[{id,name}]}], page, size, totalItems, totalPages }
 */
@RestController
@RequestMapping("/api/articles")
public class ArticleController {

    private static final int MAX_SIZE = 100;

    private final JdbcTemplate jdbc;

    public ArticleController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record AuthorItem(String id, String name) {}

    public record ArticleItem(String id, String title, int year, List<AuthorItem> authors) {}

    public record ArticlePage(List<ArticleItem> items, int page, int size, long totalItems, int totalPages) {}

    @GetMapping
    public ArticlePage list(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Integer year,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {

        if (page < 1) throw new BadRequestException("page must be >= 1");
        if (size < 1 || size > MAX_SIZE) throw new BadRequestException("size must be between 1 and " + MAX_SIZE);

        // Build the WHERE clause only from the filters that were supplied.
        StringBuilder where = new StringBuilder(" WHERE 1=1");
        List<Object> args = new ArrayList<>();
        if (keyword != null && !keyword.isBlank()) {
            // Match the title OR the name of any author of the article.
            // The database collation (utf8mb4_0900_ai_ci) already ignores case and accents.
            where.append(" AND (a.Title LIKE ? ESCAPE '\\\\' OR EXISTS ("
                    + "SELECT 1 FROM Writes w2 JOIN Author au2 ON au2.AuthorID = w2.AuthorID"
                    + " WHERE w2.ArticleID = a.ArticleID AND au2.FullName LIKE ? ESCAPE '\\\\'))");
            String pattern = "%" + escapeLike(keyword.trim()) + "%";
            args.add(pattern);
            args.add(pattern);
        }
        if (year != null) {
            where.append(" AND e.PubYear = ?");
            args.add(year);
        }

        String from = " FROM Article a JOIN Edition e ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber";

        Long total = jdbc.queryForObject("SELECT COUNT(*)" + from + where, Long.class, args.toArray());
        long totalItems = total == null ? 0 : total;
        int totalPages = (int) ((totalItems + size - 1) / size);

        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(size);
        pageArgs.add((long) (page - 1) * size);
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT a.ArticleID, a.Title, e.PubYear" + from + where
                        + " ORDER BY e.PubYear DESC, a.Title, a.ArticleID LIMIT ? OFFSET ?",
                pageArgs.toArray());

        Map<String, List<AuthorItem>> authorsByArticle = loadAuthors(rows);

        List<ArticleItem> items = new ArrayList<>();
        for (Map<String, Object> r : rows) {
            String id = (String) r.get("ArticleID");
            items.add(new ArticleItem(id, (String) r.get("Title"),
                    ((Number) r.get("PubYear")).intValue(),
                    authorsByArticle.getOrDefault(id, List.of())));
        }
        return new ArticlePage(items, page, size, totalItems, totalPages);
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

    private static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
