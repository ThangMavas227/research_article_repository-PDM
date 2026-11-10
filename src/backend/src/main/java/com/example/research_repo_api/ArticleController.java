package com.example.research_repo_api;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * GET /api/articles?q=&year=&page=1&size=10
 * Public endpoint (no login). Returns one page of articles plus pagination info.
 */
@RestController
@RequestMapping("/api/articles")
public class ArticleController {

    private static final int MAX_SIZE = 100;

    private final JdbcTemplate jdbc;

    public ArticleController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record ArticleItem(String articleId, String title, List<String> authors, int publicationYear) {}

    public record Pagination(int page, int size, long totalItems, int totalPages) {}

    public record ArticlePage(List<ArticleItem> data, Pagination pagination) {}

    @GetMapping
    public ArticlePage list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Integer year,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {

        if (page < 1) throw new BadRequestException("page must be >= 1");
        if (size < 1 || size > MAX_SIZE) throw new BadRequestException("size must be between 1 and " + MAX_SIZE);

        // Build the WHERE clause only from the filters that were supplied.
        StringBuilder where = new StringBuilder(" WHERE 1=1");
        List<Object> args = new ArrayList<>();
        if (q != null && !q.isBlank()) {
            where.append(" AND a.Title LIKE ? ESCAPE '\\\\'");
            args.add("%" + escapeLike(q.trim()) + "%");
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

        Map<String, List<String>> authorsByArticle = loadAuthors(rows);

        List<ArticleItem> items = new ArrayList<>();
        for (Map<String, Object> r : rows) {
            String id = (String) r.get("ArticleID");
            items.add(new ArticleItem(id, (String) r.get("Title"),
                    authorsByArticle.getOrDefault(id, List.of()),
                    ((Number) r.get("PubYear")).intValue()));
        }
        return new ArticlePage(items, new Pagination(page, size, totalItems, totalPages));
    }

    /** Authors of the given articles, ordered by Writes.Position. One query for the whole page. */
    private Map<String, List<String>> loadAuthors(List<Map<String, Object>> rows) {
        Map<String, List<String>> out = new HashMap<>();
        if (rows.isEmpty()) return out;
        String marks = String.join(",", java.util.Collections.nCopies(rows.size(), "?"));
        Object[] ids = rows.stream().map(r -> r.get("ArticleID")).toArray();
        jdbc.query("SELECT w.ArticleID, au.FullName FROM Writes w JOIN Author au ON au.AuthorID = w.AuthorID"
                + " WHERE w.ArticleID IN (" + marks + ") ORDER BY w.ArticleID, w.Position",
                rs -> {
                    out.computeIfAbsent(rs.getString(1), k -> new ArrayList<>()).add(rs.getString(2));
                }, ids);
        return out;
    }

    private static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
