-- =====================================================================
-- IT079IU - Group 8 - Topic 18: Research Article Repository
-- queries.sql : 12 queries (+ 1 view) - run after schema.sql, MySQL 8.0
-- Each query is preceded by the question it answers.
-- =====================================================================
USE research_repo;

-- ---------------------------------------------------------------------
-- Q1 [multi-table join] (topic query 1)
-- Question: What is the reference list of article AR020 (the articles it cites),
--           with the venue and year of each cited article?
-- ---------------------------------------------------------------------
SELECT c.CitedArticleID, a.Title, v.Name AS Venue, e.PubYear
FROM Citation c
JOIN Article a ON a.ArticleID = c.CitedArticleID
JOIN Edition e ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber
JOIN Venue   v ON v.VenueID = e.VenueID
WHERE c.CitingArticleID = 'AR020'
ORDER BY e.PubYear, a.Title;

-- ---------------------------------------------------------------------
-- Q2 [multi-table join] (topic query 2)
-- Question: Which articles cite article AR001, and when were they published?
-- (uses idx_citation_cited)
-- ---------------------------------------------------------------------
SELECT c.CitingArticleID, a.Title, e.PubYear
FROM Citation c
JOIN Article a ON a.ArticleID = c.CitingArticleID
JOIN Edition e ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber
WHERE c.CitedArticleID = 'AR001'
ORDER BY e.PubYear, a.Title;

-- ---------------------------------------------------------------------
-- Q3 [nested query with IN + recursive CTE + aggregation] (topic query 3)
-- Question: What are the ten most cited articles in the subject area "Databases"
--           (including all of its sub-areas)?
-- ---------------------------------------------------------------------
WITH RECURSIVE area_tree (AreaID) AS (
    SELECT AreaID FROM SubjectArea WHERE Name = 'Databases'
    UNION ALL
    SELECT s.AreaID FROM SubjectArea s JOIN area_tree t ON s.ParentAreaID = t.AreaID
)
SELECT a.ArticleID, a.Title, COUNT(c.CitingArticleID) AS TimesCited
FROM Article a
LEFT JOIN Citation c ON c.CitedArticleID = a.ArticleID
WHERE a.ArticleID IN (SELECT cl.ArticleID FROM Classified cl
                      WHERE cl.AreaID IN (SELECT AreaID FROM area_tree))
GROUP BY a.ArticleID, a.Title
ORDER BY TimesCited DESC, a.ArticleID
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q4 [NOT EXISTS - "for all" / relational division] (topic query 4)
-- Question: Which authors have published in EVERY venue of the list
--           {V001, V002, V003}?
-- ---------------------------------------------------------------------
SELECT au.AuthorID, au.FullName
FROM Author au
WHERE NOT EXISTS (
    SELECT 1 FROM Venue v
    WHERE v.VenueID IN ('V001', 'V002', 'V003')
      AND NOT EXISTS (
          SELECT 1
          FROM Writes w
          JOIN Article a ON a.ArticleID = w.ArticleID
          WHERE w.AuthorID = au.AuthorID AND a.VenueID = v.VenueID));

-- ---------------------------------------------------------------------
-- Q5 [aggregation GROUP BY] (topic query 5)
-- Question: For each year, what is the average number of authors per article?
-- ---------------------------------------------------------------------
SELECT t.PubYear, COUNT(*) AS Articles, ROUND(AVG(t.NumAuthors), 2) AS AvgAuthors
FROM (SELECT a.ArticleID, e.PubYear, COUNT(w.AuthorID) AS NumAuthors
      FROM Article a
      JOIN Edition e ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber
      JOIN Writes  w ON w.ArticleID = a.ArticleID
      GROUP BY a.ArticleID, e.PubYear) t
GROUP BY t.PubYear
ORDER BY t.PubYear;

-- ---------------------------------------------------------------------
-- Q6 [outer join]
-- Question: List every author with the number of articles they wrote,
--           including authors who have not written any article yet.
-- ---------------------------------------------------------------------
SELECT au.AuthorID, au.FullName, COUNT(w.ArticleID) AS Articles
FROM Author au
LEFT JOIN Writes w ON w.AuthorID = au.AuthorID
GROUP BY au.AuthorID, au.FullName
ORDER BY Articles DESC, au.FullName;

-- ---------------------------------------------------------------------
-- Q7 [GROUP BY + HAVING]
-- Question: Which venues have published at least two articles, and how many
--           citations did those articles receive in total?
-- ---------------------------------------------------------------------
SELECT v.VenueID, v.Name, v.VenueType,
       COUNT(DISTINCT a.ArticleID)   AS Articles,
       COUNT(c.CitingArticleID)      AS TotalCitations
FROM Venue v
JOIN Article a ON a.VenueID = v.VenueID
LEFT JOIN Citation c ON c.CitedArticleID = a.ArticleID
GROUP BY v.VenueID, v.Name, v.VenueType
HAVING COUNT(DISTINCT a.ArticleID) >= 2
ORDER BY TotalCitations DESC, v.Name;

-- ---------------------------------------------------------------------
-- Q8 [nested query with IN]
-- Question: Which articles were written by authors currently affiliated
--           (EndDate IS NULL) with an institution in Vietnam?
-- ---------------------------------------------------------------------
SELECT DISTINCT a.ArticleID, a.Title
FROM Article a
JOIN Writes w ON w.ArticleID = a.ArticleID
WHERE w.AuthorID IN (SELECT af.AuthorID
                     FROM Affiliation af
                     JOIN Institution i ON i.InstitutionID = af.InstitutionID
                     WHERE af.EndDate IS NULL AND i.Country = 'Vietnam')
ORDER BY a.ArticleID;

-- ---------------------------------------------------------------------
-- Q9 [nested query with EXISTS]
-- Question: Which authors have at least one article that has never been cited?
-- ---------------------------------------------------------------------
SELECT au.AuthorID, au.FullName
FROM Author au
WHERE EXISTS (SELECT 1
              FROM Writes w
              WHERE w.AuthorID = au.AuthorID
                AND NOT EXISTS (SELECT 1 FROM Citation c WHERE c.CitedArticleID = w.ArticleID))
ORDER BY au.FullName;

-- ---------------------------------------------------------------------
-- Q10 [set operation: UNION]
-- Question: Which articles are either tagged with the keyword "transformers"
--           or classified in the subject area "Recommender Systems"?
-- ---------------------------------------------------------------------
SELECT a.ArticleID, a.Title, 'keyword: transformers' AS Reason
FROM Article a
JOIN HasKeyword hk ON hk.ArticleID = a.ArticleID
JOIN Keyword k ON k.KeywordID = hk.KeywordID
WHERE k.Term = 'transformers'
UNION
SELECT a.ArticleID, a.Title, 'area: Recommender Systems'
FROM Article a
JOIN Classified cl ON cl.ArticleID = a.ArticleID
JOIN SubjectArea s ON s.AreaID = cl.AreaID
WHERE s.Name = 'Recommender Systems'
ORDER BY ArticleID;

-- ---------------------------------------------------------------------
-- Q11 [view]
-- Question: How many times has each article been cited? (reusable view),
--           then: which are the five most cited articles overall?
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_article_citations AS
SELECT a.ArticleID, a.Title, e.PubYear, ve.Name AS Venue,
       COUNT(c.CitingArticleID) AS TimesCited
FROM Article a
JOIN Edition e  ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber
JOIN Venue   ve ON ve.VenueID = a.VenueID
LEFT JOIN Citation c ON c.CitedArticleID = a.ArticleID
GROUP BY a.ArticleID, a.Title, e.PubYear, ve.Name;

SELECT * FROM v_article_citations ORDER BY TimesCited DESC, ArticleID LIMIT 5;

-- ---------------------------------------------------------------------
-- Q12 [self-join on Writes + aggregation]
-- Question: Which pairs of authors have co-authored at least two articles together?
-- ---------------------------------------------------------------------
SELECT a1.FullName AS Author1, a2.FullName AS Author2, COUNT(*) AS JointArticles
FROM Writes w1
JOIN Writes w2 ON w2.ArticleID = w1.ArticleID AND w1.AuthorID < w2.AuthorID
JOIN Author a1 ON a1.AuthorID = w1.AuthorID
JOIN Author a2 ON a2.AuthorID = w2.AuthorID
GROUP BY a1.AuthorID, a1.FullName, a2.AuthorID, a2.FullName
HAVING COUNT(*) >= 2
ORDER BY JointArticles DESC, Author1;

-- ---------------------------------------------------------------------
-- Q13 [bonus - temporal affiliation]
-- Question: What was the affiliation history of each author who has changed institution?
-- ---------------------------------------------------------------------
SELECT au.FullName, i.Name AS Institution, af.StartDate, COALESCE(af.EndDate, 'present') AS EndDate
FROM Affiliation af
JOIN Author au ON au.AuthorID = af.AuthorID
JOIN Institution i ON i.InstitutionID = af.InstitutionID
WHERE af.AuthorID IN (SELECT AuthorID FROM Affiliation GROUP BY AuthorID HAVING COUNT(*) > 1)
ORDER BY au.FullName, af.StartDate;
