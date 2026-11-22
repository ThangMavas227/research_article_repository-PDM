-- =====================================================================
-- PDM - Index verification (MySQL 8.0)
-- Database: research_repo. Run AFTER script.sql.
-- The three indexes are already CREATED by script.sql:
--   CREATE INDEX idx_citation_cited ON Citation (CitedArticleID);
--   CREATE INDEX idx_article_title  ON Article  (Title);
--   CREATE INDEX idx_edition_year   ON Edition  (PubYear);
-- Do not CREATE them again here: MySQL would report duplicate index names.
-- This script only INSPECTS the indexes and EXPLAINs query plans; it changes no data
-- and is safe to rerun.
-- =====================================================================
USE research_repo;

-- A. Verify the three indexes exist on the intended columns.
SELECT TABLE_NAME AS TableName,
       INDEX_NAME AS IndexName,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS IndexedColumns
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND (
       (TABLE_NAME = 'Citation' AND INDEX_NAME = 'idx_citation_cited')
    OR (TABLE_NAME = 'Article'  AND INDEX_NAME = 'idx_article_title')
    OR (TABLE_NAME = 'Edition'  AND INDEX_NAME = 'idx_edition_year')
  )
GROUP BY TABLE_NAME, INDEX_NAME
ORDER BY TABLE_NAME;

-- B. Inspect other indexes, including PRIMARY, UNIQUE, and FK indexes.
SHOW INDEX FROM Citation;
SHOW INDEX FROM Article;
SHOW INDEX FROM Edition;

-- ---------------------------------------------------------------------
-- WITH the index: the plan should show type = ref / range and key = the index.
-- ---------------------------------------------------------------------
-- C. EXPLAIN: Citation lookup by the cited article (query Q2).
EXPLAIN
SELECT CitingArticleID
FROM Citation
WHERE CitedArticleID = 'AR018';

-- D. EXPLAIN: prefix search on article title.
EXPLAIN
SELECT ArticleID, Title
FROM Article
WHERE Title LIKE 'Learned%';

-- E. EXPLAIN: publication year filter (search form).
EXPLAIN
SELECT VenueID, EditionNumber, PubYear
FROM Edition
WHERE PubYear = 2023;

-- F. EXPLAIN: project query - articles that cite a given article.
EXPLAIN
SELECT a.ArticleID, a.Title
FROM Citation c
JOIN Article a ON a.ArticleID = c.CitingArticleID
WHERE c.CitedArticleID = 'AR018';

-- G. EXPLAIN: project query - articles published in 2023.
EXPLAIN
SELECT a.ArticleID, a.Title, e.PubYear
FROM Edition e
JOIN Article a
  ON a.VenueID = e.VenueID AND a.EditionNumber = e.EditionNumber
WHERE e.PubYear = 2023;

-- ---------------------------------------------------------------------
-- WITHOUT the index (IGNORE INDEX only changes the plan, the index is not dropped):
-- compare type and rows with C, D and E above.
-- ---------------------------------------------------------------------
-- H. Citation lookup without idx_citation_cited: the whole primary key is scanned.
EXPLAIN
SELECT CitingArticleID
FROM Citation IGNORE INDEX (idx_citation_cited)
WHERE CitedArticleID = 'AR018';

-- I. Title prefix search without idx_article_title: the whole table is scanned.
EXPLAIN
SELECT ArticleID, Title
FROM Article IGNORE INDEX (idx_article_title)
WHERE Title LIKE 'Learned%';

-- J. Year filter without idx_edition_year: the whole table is scanned.
EXPLAIN
SELECT VenueID, EditionNumber, PubYear
FROM Edition IGNORE INDEX (idx_edition_year)
WHERE PubYear = 2023;

-- K. Limit of idx_article_title: a search for a word INSIDE a title cannot seek in the index
--    (type = index, not range), so this index helps prefix and exact-title searches only.
EXPLAIN
SELECT ArticleID, Title
FROM Article
WHERE Title LIKE '%Learned%';

-- EXPLAIN shows the optimizer's plan, not a guaranteed speedup.
-- For a fair performance benchmark, compare plans and timing on larger data.
