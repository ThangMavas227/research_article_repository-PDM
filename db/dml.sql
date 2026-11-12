-- =====================================================================
-- IT079IU - Group 8 - Topic 18: Research Article Repository
-- dml.sql : statements the application needs + constraint tests
-- Run after script.sql. Every block is wrapped in a transaction that is
-- ROLLED BACK so the sample data stays unchanged (change to COMMIT to keep).
-- ? marks are the JDBC PreparedStatement parameters used by the Java app.
-- =====================================================================
USE research_repo;

-- ---------------------------------------------------------------------
-- A. INSERT / UPDATE / DELETE for each main table
-- ---------------------------------------------------------------------
START TRANSACTION;

-- Author
INSERT INTO Author (AuthorID, FullName) VALUES ('AU901', 'Test Author');
UPDATE Author SET FullName = 'Test Author Jr.' WHERE AuthorID = 'AU901';
-- app form: INSERT INTO Author (AuthorID, FullName) VALUES (?, ?);
--           UPDATE Author SET FullName = ? WHERE AuthorID = ?;
--           DELETE FROM Author WHERE AuthorID = ?;

-- Institution + Affiliation
INSERT INTO Institution (InstitutionID, Name) VALUES ('I901', 'Test Institute');
INSERT INTO Affiliation (AuthorID, InstitutionID, StartDate, EndDate) VALUES ('AU901', 'I901', '2024-09-01', NULL);
UPDATE Affiliation SET EndDate = '2025-06-30' WHERE AuthorID = 'AU901' AND StartDate = '2024-09-01';
DELETE FROM Affiliation WHERE AuthorID = 'AU901' AND StartDate = '2024-09-01';
UPDATE Institution SET Name = 'Test Institute (renamed)' WHERE InstitutionID = 'I901';
DELETE FROM Institution WHERE InstitutionID = 'I901';
DELETE FROM Author WHERE AuthorID = 'AU901';             -- allowed: AU901 has no articles (an author with articles is RESTRICTed)

-- SubjectArea / Keyword
INSERT INTO SubjectArea (AreaID, Name) VALUES ('SA901', 'Graph Neural Networks');
UPDATE SubjectArea SET Name = 'GNN' WHERE AreaID = 'SA901';
DELETE FROM SubjectArea WHERE AreaID = 'SA901';
INSERT INTO Keyword (KeywordID, Term) VALUES ('K901', 'federated learning');
UPDATE Keyword SET Term = 'federated-learning' WHERE KeywordID = 'K901';
DELETE FROM Keyword WHERE KeywordID = 'K901';

-- Venue (ISA): supertype first, then subtype; Edition (weak) carries Volume for a journal, Location for a conference
INSERT INTO Venue (VenueID, Name, VenueType) VALUES ('V031', 'Test Journal of Databases', 'J');
INSERT INTO Journal (VenueID, VenueType, ISSN) VALUES ('V031', 'J', '1234-5679');
INSERT INTO Edition (VenueID, EditionNumber, PubYear, Volume) VALUES ('V031', 1, 2025, 1);
UPDATE Venue SET Name = 'Test Journal of Data Systems' WHERE VenueID = 'V031';
UPDATE Edition SET PubYear = 2026, Volume = 2 WHERE VenueID = 'V031' AND EditionNumber = 1;
DELETE FROM Edition WHERE VenueID = 'V031' AND EditionNumber = 1;
DELETE FROM Journal WHERE VenueID = 'V031';
DELETE FROM Venue   WHERE VenueID = 'V031';

-- Conference: same pattern as the journal above
INSERT INTO Venue (VenueID, Name, VenueType) VALUES ('V032', 'Test Conference on Databases', 'C');
INSERT INTO Conference (VenueID, VenueType, Acronym) VALUES ('V032', 'C', 'TESTC');
INSERT INTO Edition (VenueID, EditionNumber, PubYear, Location) VALUES ('V032', 1, 2025, 'Hanoi');
UPDATE Conference SET Acronym = 'TESTC2' WHERE VenueID = 'V032';
UPDATE Edition SET Location = 'Da Nang' WHERE VenueID = 'V032' AND EditionNumber = 1;
DELETE FROM Edition WHERE VenueID = 'V032' AND EditionNumber = 1;
DELETE FROM Conference WHERE VenueID = 'V032';
DELETE FROM Venue   WHERE VenueID = 'V032';

-- Article, Writes, Citation, Classified, HasKeyword
INSERT INTO Article (ArticleID, Title, DOI, Abstract, StartPage, VenueID, EditionNumber)
VALUES ('AR041', 'A Test Article', '10.5555/rr.test.041', 'Short abstract.', 1, 'V018', 2);   -- ICDE 2023, the latest edition
INSERT INTO Writes (ArticleID, AuthorID, Position) VALUES ('AR041', 'AU001', 1), ('AR041', 'AU002', 2);
INSERT INTO Citation (CitingArticleID, CitedArticleID) VALUES ('AR041', 'AR001');
INSERT INTO Classified (ArticleID, AreaID) VALUES ('AR041', 'SA002');
INSERT INTO HasKeyword (ArticleID, KeywordID) VALUES ('AR041', 'K001');
UPDATE Article SET Title = 'A Test Article (revised)' WHERE ArticleID = 'AR041';
UPDATE Writes SET Position = 3 WHERE ArticleID = 'AR041' AND AuthorID = 'AU002';
-- link rows can also be removed one at a time (a citation of a same-year article is allowed)
INSERT INTO Citation (CitingArticleID, CitedArticleID) VALUES ('AR041', 'AR017');
DELETE FROM Citation WHERE CitingArticleID = 'AR041' AND CitedArticleID = 'AR017';
INSERT INTO Classified (ArticleID, AreaID) VALUES ('AR041', 'SA003');
DELETE FROM Classified WHERE ArticleID = 'AR041' AND AreaID = 'SA003';
INSERT INTO HasKeyword (ArticleID, KeywordID) VALUES ('AR041', 'K002');
DELETE FROM HasKeyword WHERE ArticleID = 'AR041' AND KeywordID = 'K002';
DELETE FROM Writes WHERE ArticleID = 'AR041' AND AuthorID = 'AU002';
DELETE FROM Article WHERE ArticleID = 'AR041';          -- cascades to the remaining Writes, Citation, Classified, HasKeyword rows

-- Login: the Java app fetches the row by username and verifies the password against PasswordHash
-- with bcrypt (the SQL never compares plain passwords).  ? = PreparedStatement parameter.
SELECT UserID, Username, Role, PasswordHash FROM User WHERE Username = 'admin';   -- app: WHERE Username = ?

-- User, ReadingList, Contains, SavedSearch
INSERT INTO User (UserID, Username, Email, PasswordHash, Role) VALUES ('U017', 'test_user', 'test_user@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader');
INSERT INTO ReadingList (UserID, ListName, CreatedDate) VALUES ('U017', 'My list', CURRENT_TIMESTAMP);
INSERT INTO `Contains` (UserID, ListName, ArticleID) VALUES ('U017', 'My list', 'AR001');
INSERT INTO SavedSearch (UserID, SearchName, Criteria) VALUES ('U017', 'My search', JSON_OBJECT('keyword', 'indexing', 'yearFrom', 2018));
UPDATE User SET Email = 'new_mail@example.edu' WHERE UserID = 'U017';
UPDATE ReadingList SET ListName = 'Renamed list' WHERE UserID = 'U017' AND ListName = 'My list';  -- cascades to Contains
UPDATE `Contains` SET AddedDate = '2026-01-15 10:00:00' WHERE UserID = 'U017' AND ListName = 'Renamed list' AND ArticleID = 'AR001';
UPDATE SavedSearch SET Criteria = JSON_OBJECT('keyword', 'indexing', 'yearFrom', 2020) WHERE UserID = 'U017' AND SearchName = 'My search';
DELETE FROM `Contains` WHERE UserID = 'U017' AND ListName = 'Renamed list' AND ArticleID = 'AR001';
DELETE FROM ReadingList WHERE UserID = 'U017' AND ListName = 'Renamed list';
DELETE FROM SavedSearch WHERE UserID = 'U017' AND SearchName = 'My search';
DELETE FROM User WHERE UserID = 'U017';                 -- would also cascade to any remaining lists, items and searches

ROLLBACK;

-- ---------------------------------------------------------------------
-- B. Operation that changes several tables together (transaction with COMMIT / ROLLBACK)
--    "Submit a new article": Article + Writes (authors) + Classified + HasKeyword
-- ---------------------------------------------------------------------
START TRANSACTION;
INSERT INTO Article (ArticleID, Title, DOI, Abstract, StartPage, VenueID, EditionNumber)
VALUES ('AR042', 'Transactional Submission Demo', '10.5555/rr.demo.042', 'Demo.', 10, 'V016', 1);
INSERT INTO Writes (ArticleID, AuthorID, Position) VALUES ('AR042', 'AU003', 1), ('AR042', 'AU004', 2);
INSERT INTO Classified (ArticleID, AreaID) VALUES ('AR042', 'SA002');
INSERT INTO HasKeyword (ArticleID, KeywordID) VALUES ('AR042', 'K001');
-- If every statement succeeded the app issues:  COMMIT;
-- If any statement fails (duplicate DOI, unknown author, ...) the app issues: ROLLBACK;
ROLLBACK;   -- demo: nothing is kept

-- Stored procedure version, used by the app via CALL (all-or-nothing)
DROP PROCEDURE IF EXISTS sp_add_article_with_author;
DELIMITER $$
CREATE PROCEDURE sp_add_article_with_author(
    IN p_article VARCHAR(15), IN p_title VARCHAR(255), IN p_doi VARCHAR(100),
    IN p_venue VARCHAR(15), IN p_edition INT, IN p_startpage INT, IN p_author VARCHAR(15))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    INSERT INTO Article (ArticleID, Title, DOI, StartPage, VenueID, EditionNumber)
        VALUES (p_article, p_title, p_doi, p_startpage, p_venue, p_edition);
    INSERT INTO Writes (ArticleID, AuthorID, Position) VALUES (p_article, p_author, 1);
    COMMIT;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- C. Constraint tests: EVERY statement below must FAIL (expected error in comment)
-- ---------------------------------------------------------------------
INSERT INTO Author (AuthorID, FullName) VALUES ('AU001', 'Duplicate Key');                  -- 1062 duplicate PK
INSERT INTO Writes (ArticleID, AuthorID, Position) VALUES ('AR001', 'AU999', 9);            -- 1452 FK: author missing
INSERT INTO Writes (ArticleID, AuthorID, Position) VALUES ('AR001', 'AU017', 0);            -- 3819 CHECK Position >= 1
INSERT INTO Article (ArticleID, Title, DOI, StartPage, VenueID, EditionNumber)
       VALUES ('AR900', 'Bad DOI', 'not-a-doi', 1, 'V001', 1);                                 -- 3819 CHECK DOI format
INSERT INTO Article (ArticleID, Title, DOI, StartPage, VenueID, EditionNumber)
       VALUES ('AR901', 'Duplicate DOI', '10.1145/2699501', 1, 'V001', 1);                 -- 1062 UNIQUE DOI
INSERT INTO Article (ArticleID, Title, DOI, StartPage, VenueID, EditionNumber)
       VALUES ('AR902', 'No such edition', '10.5555/rr.x.902', 1, 'V001', 99);                 -- 1452 FK edition
INSERT INTO Citation (CitingArticleID, CitedArticleID) VALUES ('AR001', 'AR001');           -- 1644 trigger: self-citation
INSERT INTO Citation (CitingArticleID, CitedArticleID) VALUES ('AR001', 'AR025');           -- 1644 trigger: AR025 (2023) is later than AR001 (2015)
INSERT INTO Affiliation (AuthorID, InstitutionID, StartDate, EndDate)
       VALUES ('AU001', 'I001', '2005-01-01', '2004-01-01');                                -- 3819 CHECK EndDate >= StartDate
INSERT INTO Affiliation (AuthorID, InstitutionID, StartDate, EndDate)
       VALUES ('AU001', 'I001', '2018-01-01', NULL);                                        -- 1644 trigger: overlaps AU001's current affiliation
INSERT INTO Journal (VenueID, VenueType, ISSN) VALUES ('V016', 'J', '9999-9999');           -- 1452 composite FK: V016 is a conference
INSERT INTO Edition (VenueID, EditionNumber, PubYear, Location) VALUES ('V001', 99, 2020, 'X');   -- 1644 trigger: a journal edition needs a volume
INSERT INTO Edition (VenueID, EditionNumber, PubYear, Volume) VALUES ('V016', 99, 2020, 5);       -- 1644 trigger: a conference edition has no volume
INSERT INTO Edition (VenueID, EditionNumber, PubYear, Volume) VALUES ('V001', 98, 2020, 0);       -- 3819 CHECK Volume > 0
INSERT INTO User (UserID, Username, Email, PasswordHash) VALUES ('U900', 'bad_mail', 'not-an-email', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu'); -- 3819 CHECK email
INSERT INTO User (UserID, Username, Email, PasswordHash, Role) VALUES ('U901', 'bad_role', 'bad_role@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'superuser'); -- 3819 CHECK role
INSERT INTO SavedSearch (UserID, SearchName, Criteria) VALUES ('U001', 'bad json', 'abc'); -- 3140 invalid JSON
DELETE FROM Institution WHERE InstitutionID = 'I001';                                       -- 1451 FK RESTRICT: still has affiliations
DELETE FROM Edition WHERE VenueID = 'V001' AND EditionNumber = 1;                           -- 1451 FK RESTRICT: still has articles
