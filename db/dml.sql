-- =====================================================================
-- IT079IU - Group 8 - Topic 18: Research Article Repository
-- dml.sql : statements the application needs + constraint tests
-- Run after schema.sql. Every block is wrapped in a transaction that is
-- ROLLED BACK so the sample data stays unchanged (change to COMMIT to keep).
-- ? marks are the JDBC PreparedStatement parameters used by the Java app.
-- =====================================================================
USE research_repo;

-- ---------------------------------------------------------------------
-- A. INSERT / UPDATE / DELETE for each main table
-- ---------------------------------------------------------------------
START TRANSACTION;

-- Author
INSERT INTO Author (AuthorID, FullName, Orcid) VALUES ('AU031', 'Test Author', '0000-0002-1825-0097');
UPDATE Author SET FullName = 'Test Author Jr.' WHERE AuthorID = 'AU031';
-- app form: INSERT INTO Author (AuthorID, FullName, Orcid) VALUES (?, ?, ?);
--           UPDATE Author SET FullName = ?, Orcid = ? WHERE AuthorID = ?;
--           DELETE FROM Author WHERE AuthorID = ?;

-- Institution + Affiliation
INSERT INTO Institution (InstitutionID, Name, Country) VALUES ('I017', 'Test Institute', 'Vietnam');
INSERT INTO Affiliation (AuthorID, InstitutionID, StartDate, EndDate) VALUES ('AU031', 'I017', '2024-09-01', NULL);
UPDATE Affiliation SET EndDate = '2025-06-30' WHERE AuthorID = 'AU031' AND InstitutionID = 'I017' AND StartDate = '2024-09-01';
DELETE FROM Affiliation WHERE AuthorID = 'AU031' AND InstitutionID = 'I017' AND StartDate = '2024-09-01';
UPDATE Institution SET Country = 'Singapore' WHERE InstitutionID = 'I017';
DELETE FROM Institution WHERE InstitutionID = 'I017';

-- SubjectArea / Keyword
INSERT INTO SubjectArea (AreaID, Name, ParentAreaID) VALUES ('SA017', 'Graph Neural Networks', 'SA010');
UPDATE SubjectArea SET Name = 'GNN' WHERE AreaID = 'SA017';
DELETE FROM SubjectArea WHERE AreaID = 'SA017';
INSERT INTO Keyword (KeywordID, Term) VALUES ('K021', 'federated learning');
UPDATE Keyword SET Term = 'federated-learning' WHERE KeywordID = 'K021';
DELETE FROM Keyword WHERE KeywordID = 'K021';

-- Venue (ISA): supertype first, then subtype; Edition (weak) then its subtype
INSERT INTO Venue (VenueID, Name, Publisher, VenueType) VALUES ('V031', 'Test Journal of Databases', 'Test Press', 'J');
INSERT INTO Journal (VenueID, VenueType, Issn) VALUES ('V031', 'J', '1234-5679');
INSERT INTO Edition (VenueID, EditionNumber, PubYear) VALUES ('V031', 1, 2025);
INSERT INTO JournalEdition (VenueID, EditionNumber, Volume) VALUES ('V031', 1, 1);
UPDATE Venue SET Publisher = 'Another Press' WHERE VenueID = 'V031';
UPDATE Edition SET PubYear = 2026 WHERE VenueID = 'V031' AND EditionNumber = 1;
DELETE FROM Edition WHERE VenueID = 'V031' AND EditionNumber = 1;   -- cascades to JournalEdition
DELETE FROM Journal WHERE VenueID = 'V031';
DELETE FROM Venue   WHERE VenueID = 'V031';

-- Article, Writes, Citation, Classified, HasKeyword
INSERT INTO Article (ArticleID, Title, DOI, Abstract, StartPage, VenueID, EditionNumber)
VALUES ('AR041', 'A Test Article', '10.5555/rr.test.041', 'Short abstract.', 1, 'V001', 1);
INSERT INTO Writes (ArticleID, AuthorID, Position) VALUES ('AR041', 'AU001', 1), ('AR041', 'AU002', 2);
INSERT INTO Citation (CitingArticleID, CitedArticleID) VALUES ('AR041', 'AR001');
INSERT INTO Classified (ArticleID, AreaID) VALUES ('AR041', 'SA002');
INSERT INTO HasKeyword (ArticleID, KeywordID) VALUES ('AR041', 'K001');
UPDATE Article SET Title = 'A Test Article (revised)' WHERE ArticleID = 'AR041';
UPDATE Writes SET Position = 3 WHERE ArticleID = 'AR041' AND AuthorID = 'AU002';
DELETE FROM Article WHERE ArticleID = 'AR041';          -- cascades to Writes, Citation, Classified, HasKeyword

-- Login: the Java app fetches the row by username and verifies the password against PasswordHash
-- with bcrypt (the SQL never compares plain passwords).  ? = PreparedStatement parameter.
SELECT ReaderID, UserName, Role, PasswordHash FROM Reader WHERE UserName = 'admin';   -- app: WHERE UserName = ?

-- Reader, ReadingList, Contains, SavedSearch
INSERT INTO Reader (ReaderID, UserName, Email, PasswordHash, Role) VALUES ('R017', 'test_user', 'test_user@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader');
INSERT INTO ReadingList (ReaderID, ListName, CreatedDate) VALUES ('R017', 'My list', CURRENT_TIMESTAMP);
INSERT INTO `Contains` (ReaderID, ListName, ArticleID) VALUES ('R017', 'My list', 'AR001');
INSERT INTO SavedSearch (ReaderID, SearchName, Criteria) VALUES ('R017', 'My search', JSON_OBJECT('keyword', 'indexing', 'yearFrom', 2018));
UPDATE Reader SET Email = 'new_mail@example.edu' WHERE ReaderID = 'R017';
UPDATE ReadingList SET ListName = 'Renamed list' WHERE ReaderID = 'R017' AND ListName = 'My list';  -- cascades to Contains
DELETE FROM Reader WHERE ReaderID = 'R017';             -- cascades to lists, items, searches

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
       VALUES ('AR901', 'Duplicate DOI', '10.5555/rr.2000.001', 1, 'V001', 1);                 -- 1062 UNIQUE DOI
INSERT INTO Article (ArticleID, Title, DOI, StartPage, VenueID, EditionNumber)
       VALUES ('AR902', 'No such edition', '10.5555/rr.x.902', 1, 'V001', 99);                 -- 1452 FK edition
INSERT INTO Citation (CitingArticleID, CitedArticleID) VALUES ('AR001', 'AR001');           -- trigger: self-citation
INSERT INTO Citation (CitingArticleID, CitedArticleID) VALUES ('AR001', 'AR010');           -- trigger: AR010 (2023) is later than AR001 (2016)
INSERT INTO Affiliation (AuthorID, InstitutionID, StartDate, EndDate)
       VALUES ('AU001', 'I001', '2020-01-01', '2019-01-01');                                -- 3819 CHECK EndDate >= StartDate
INSERT INTO Journal (VenueID, VenueType, Issn) VALUES ('V016', 'J', '9999-9999');           -- 1452 composite FK: V016 is a conference
INSERT INTO ConferenceEdition (VenueID, EditionNumber, Location) VALUES ('V001', 1, 'X');   -- 1452 FK: V001 is not a conference
INSERT INTO Reader (ReaderID, UserName, Email, PasswordHash) VALUES ('R900', 'bad_mail', 'not-an-email', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu'); -- 3819 CHECK email
INSERT INTO Reader (ReaderID, UserName, Email, PasswordHash, Role) VALUES ('R901', 'bad_role', 'bad_role@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'superuser'); -- 3819 CHECK role
INSERT INTO SavedSearch (ReaderID, SearchName, Criteria) VALUES ('R001', 'bad json', 'abc'); -- 3140 invalid JSON
DELETE FROM Institution WHERE InstitutionID = 'I001';                                       -- 1451 FK RESTRICT: still has affiliations
DELETE FROM Edition WHERE VenueID = 'V001' AND EditionNumber = 1;                           -- 1451 FK RESTRICT: still has articles
