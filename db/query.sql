-- =====================================================================
-- IT079IU - Group 8 - Topic 18: Research Article Repository
-- query.sql : 12 required queries + 2 extra nested queries
-- Run after db/script.sql (it creates and fills the database research_repo).
-- Values such as 'AR003', 'AR014', 'SA001', 'V002', 'V007', 'AU001' and the
-- keyword 'query optimization' are SAMPLE PARAMETERS: replace them to test
-- other cases.
-- Query types used (marker next to each label):
--   [JOIN] [OUTER JOIN] [GROUP BY / HAVING] [NOT EXISTS - division]
--   [UNION] [EXISTS] [IN] [VIEW] [SUBQUERY IN FROM] [SELECT BY KEY]
-- Relational algebra for Q1, Q4, Q9 and Q13: see db/relational_algebra.md
-- =====================================================================
USE research_repo;

-- Q1 [JOIN]: Retrieve the reference list of a given article.
SELECT
    RefArticle.ArticleID,
    RefArticle.Title,
    RefArticle.DOI,
    E.PubYear,
    V.Name AS VenueName
FROM Citation C
JOIN Article RefArticle
    ON C.CitedArticleID = RefArticle.ArticleID
JOIN Edition E
    ON RefArticle.VenueID = E.VenueID
    AND RefArticle.EditionNumber = E.EditionNumber
JOIN Venue V
    ON E.VenueID = V.VenueID
WHERE C.CitingArticleID = 'AR003'
ORDER BY E.PubYear, RefArticle.Title;

-- Q2 [JOIN]: Retrieve all articles that cite a given article.
SELECT
    CitingArticle.ArticleID,
    CitingArticle.Title,
    CitingArticle.DOI,
    E.PubYear,
    V.Name AS VenueName
FROM Citation C
JOIN Article CitingArticle
    ON C.CitingArticleID = CitingArticle.ArticleID
JOIN Edition E
    ON CitingArticle.VenueID = E.VenueID
    AND CitingArticle.EditionNumber = E.EditionNumber
JOIN Venue V
    ON E.VenueID = V.VenueID
WHERE C.CitedArticleID = 'AR014'
ORDER BY E.PubYear, CitingArticle.Title;

-- Q3 [JOIN + GROUP BY]: Retrieve the ten most cited articles in a given subject area.
-- A.Title is the tie-breaker so that articles with equal counts have a fixed order.
SELECT
A.ArticleID,
A.Title,
SA.Name AS SubjectArea,
COUNT(DISTINCT C.CitingArticleID) AS CitationCount
FROM Article A
JOIN Classified CL
ON A.ArticleID = CL.ArticleID
JOIN SubjectArea SA
ON CL.AreaID = SA.AreaID
LEFT JOIN Citation C
ON A.ArticleID = C.CitedArticleID
WHERE SA.AreaID = 'SA001'
GROUP BY
A.ArticleID, A.Title, SA.AreaID, SA.Name
ORDER BY CitationCount DESC, A.Title
LIMIT 10;

-- Q4 [NOT EXISTS - relational division]: Find authors who have published in every venue in a given list.
SELECT au.AuthorID, au.FullName
FROM Author au
WHERE NOT EXISTS (
    SELECT 1 FROM Venue v
    WHERE v.VenueID IN ('V002', 'V007')
      AND NOT EXISTS (
          SELECT 1
          FROM Writes w JOIN Article a ON a.ArticleID = w.ArticleID
          WHERE w.AuthorID = au.AuthorID AND a.VenueID = v.VenueID));

-- Q5 [JOIN + SUBQUERY IN FROM + GROUP BY]: Calculate the average number of authors per article for each publication year.
SELECT e.PubYear,
       COUNT(*)                       AS Articles,
       SUM(t.NumAuthors)              AS TotalAuthors,
       ROUND(AVG(t.NumAuthors), 2)    AS AvgAuthorsPerArticle
FROM Article a
JOIN Edition e ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber
JOIN (SELECT ArticleID, COUNT(*) AS NumAuthors
      FROM Writes
      GROUP BY ArticleID) t ON t.ArticleID = a.ArticleID
GROUP BY e.PubYear
ORDER BY e.PubYear;

-- Q6 [SELECT BY KEY]: Find an Article by its Article ID.
SELECT ArticleID, Title, DOI, Abstract, StartPage, VenueID, EditionNumber
FROM Article
WHERE ArticleID = 'AR001';

-- Q7 [JOIN + GROUP BY / HAVING]: Find authors who have published at least a specified number of articles.
SELECT
    au.AuthorID,
    au.FullName,
    COUNT(*) AS ArticleCount
FROM Author AS au
INNER JOIN Writes AS w
        ON w.AuthorID = au.AuthorID
GROUP BY au.AuthorID, au.FullName
HAVING COUNT(*) >= 2
ORDER BY ArticleCount DESC, au.FullName;

-- Q8 [JOIN]: Retrieve articles associated with a given keyword.
SELECT DISTINCT a.ArticleID, a.Title, a.DOI, a.Abstract, a.StartPage, a.VenueID, a.EditionNumber
FROM Article a
JOIN HasKeyword hk ON hk.ArticleID = a.ArticleID
JOIN Keyword k     ON k.KeywordID  = hk.KeywordID
WHERE k.Term = 'query optimization';

-- Q9 [UNION - set operation]: Retrieve authors who have published articles in either Venue A or Venue B.
-- Venue A = 'ACM Transactions on Database Systems', Venue B = 'The VLDB Journal'.
-- UNION removes duplicates, so an author who published in both venues appears once.
SELECT au.AuthorID, au.FullName
FROM Author au
JOIN Writes w  ON w.AuthorID  = au.AuthorID
JOIN Article a ON a.ArticleID = w.ArticleID
JOIN Venue v   ON v.VenueID   = a.VenueID
WHERE v.Name = 'ACM Transactions on Database Systems'
UNION
SELECT au.AuthorID, au.FullName
FROM Author au
JOIN Writes w  ON w.AuthorID  = au.AuthorID
JOIN Article a ON a.ArticleID = w.ArticleID
JOIN Venue v   ON v.VenueID   = a.VenueID
WHERE v.Name = 'The VLDB Journal';

-- Q10 [VIEW]: Create and use a view containing article information.
CREATE OR REPLACE VIEW ArticleInfo AS
SELECT
    a.ArticleID,
    a.Title,
    a.DOI,
    a.StartPage,
    a.VenueID,
    v.Name      AS VenueName,
    v.VenueType,
    a.EditionNumber,
    e.PubYear
FROM Article AS a
INNER JOIN Venue AS v
        ON v.VenueID = a.VenueID
INNER JOIN Edition AS e
        ON e.VenueID = a.VenueID
       AND e.EditionNumber = a.EditionNumber;

-- use the view
SELECT ArticleID, Title, VenueName, PubYear
FROM ArticleInfo
WHERE VenueType = 'J'
  AND PubYear >= 2020
ORDER BY PubYear DESC, Title;

-- Q11 [OUTER JOIN + GROUP BY]: Retrieve all articles and their citation counts, including uncited ones.
SELECT
    a.ArticleID,
    a.Title,
    COUNT(c.CitingArticleID) AS CitationCount
FROM Article AS a
LEFT JOIN Citation AS c
       ON c.CitedArticleID = a.ArticleID
GROUP BY a.ArticleID, a.Title
ORDER BY CitationCount DESC, a.ArticleID;

-- Q12 [SELECT BY KEY]: Find an Author by their Author ID.
SELECT AuthorID, FullName
FROM Author
WHERE AuthorID = 'AU001';

-- =====================================================================
-- Extra queries: nested queries with EXISTS and IN
-- =====================================================================

-- Q13 [EXISTS + NOT EXISTS, nested]: Find authors who have at least one article that nobody has cited.
SELECT au.AuthorID, au.FullName
FROM Author au
WHERE EXISTS (
    SELECT 1
    FROM Writes w
    WHERE w.AuthorID = au.AuthorID
      AND NOT EXISTS (
          SELECT 1
          FROM Citation c
          WHERE c.CitedArticleID = w.ArticleID))
ORDER BY au.FullName;

-- Q14 [IN, nested]: Find articles written by at least one author who is currently
-- (end date empty) affiliated with a given institution.
SELECT a.ArticleID, a.Title, a.DOI
FROM Article a
WHERE a.ArticleID IN (
    SELECT w.ArticleID
    FROM Writes w
    WHERE w.AuthorID IN (
        SELECT af.AuthorID
        FROM Affiliation af
        JOIN Institution i ON i.InstitutionID = af.InstitutionID
        WHERE i.Name = 'Tsinghua University'
          AND af.EndDate IS NULL))
ORDER BY a.Title;
