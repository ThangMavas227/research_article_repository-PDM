-- =====================================================================
-- PDM - Transaction demonstration (MySQL 8.0.16+ / InnoDB)
-- Database: research_repo (run AFTER script.sql).
-- The demo is SAFE for the real database: the test rows are removed at the end and the
-- two demo procedures are dropped, so the sample data is left exactly as it was.
-- Safe to run again. Unexpected errors are NEVER reported as PASS.
--
-- Scenario: "submit a new article together with a new author". Three tables change
-- (Author, Article, Writes), so the work must be all-or-nothing:
--   A. COMMIT   : every statement succeeds -> all three rows are kept
--   B. ROLLBACK : CHECK (Position >= 1) fails on the last insert -> nothing is kept
--   C. ROLLBACK : duplicate DOI fails on the second insert -> the new author is removed too
-- =====================================================================
USE research_repo;

DROP PROCEDURE IF EXISTS pdm_test_commit;
DROP PROCEDURE IF EXISTS pdm_test_rollback;
DROP PROCEDURE IF EXISTS pdm_test_rollback_dup_doi;

DELIMITER $$

-- A. Successful transaction: insert Author + Article + Writes atomically.
CREATE PROCEDURE pdm_test_commit()
BEGIN
    DECLARE v_condition_count INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_message TEXT DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET STACKED DIAGNOSTICS v_condition_count = NUMBER;
        GET STACKED DIAGNOSTICS CONDITION v_condition_count
            v_errno = MYSQL_ERRNO, v_message = MESSAGE_TEXT;
        ROLLBACK;
        SET @pdm_commit_result = 'FAIL';
        SELECT 'FAIL: COMMIT test aborted; transaction rolled back' AS Result,
               v_errno AS MySQL_Error, v_message AS Error_Message;
    END;

    START TRANSACTION;

    -- Do not overwrite or remove any pre-existing data.
    IF EXISTS (SELECT 1 FROM Author WHERE AuthorID = 'AU100')
       OR EXISTS (SELECT 1 FROM Article WHERE ArticleID = 'AR026')
       OR EXISTS (SELECT 1 FROM Writes WHERE ArticleID = 'AR026' AND AuthorID = 'AU100')
    THEN
        -- A second run is safe only if ALL three committed rows match.
        IF EXISTS (SELECT 1 FROM Author
                   WHERE AuthorID = 'AU100' AND FullName = 'Transaction Test Author')
           AND EXISTS (SELECT 1 FROM Article
                       WHERE ArticleID = 'AR026'
                         AND Title = 'Transaction Test Article'
                         AND DOI = '10.9999/pdm-transaction-test'
                         AND Abstract = 'Sample article for transaction testing.'
                         AND StartPage = 1 AND VenueID = 'V001' AND EditionNumber = 1)
           AND EXISTS (SELECT 1 FROM Writes
                       WHERE ArticleID = 'AR026' AND AuthorID = 'AU100' AND Position = 1)
        THEN
            COMMIT;
            SET @pdm_commit_result = 'SKIP', @pdm_commit_created = 0;  -- rows pre-existed: keep them
            SELECT 'SKIP: COMMIT test rows already exist and match' AS Result,
                   NULL AS MySQL_Error, NULL AS Error_Message;
        ELSE
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Test IDs already exist with different or incomplete data';
        END IF;
    ELSE
        INSERT INTO Author (AuthorID, FullName)
        VALUES ('AU100', 'Transaction Test Author');

        INSERT INTO Article
            (ArticleID, Title, DOI, Abstract, StartPage, VenueID, EditionNumber)
        VALUES
            ('AR026', 'Transaction Test Article', '10.9999/pdm-transaction-test',
             'Sample article for transaction testing.', 1, 'V001', 1);

        INSERT INTO Writes (ArticleID, AuthorID, Position)
        VALUES ('AR026', 'AU100', 1);

        COMMIT;
        SET @pdm_commit_result = 'PASS', @pdm_commit_created = 1;  -- this run created the rows
        SELECT 'PASS: COMMIT saved Author, Article and Writes' AS Result,
               NULL AS MySQL_Error, NULL AS Error_Message;
    END IF;
END$$

-- B. Failed transaction: CHECK (Position >= 1) MUST cause a rollback.
CREATE PROCEDURE pdm_test_rollback()
BEGIN
    DECLARE v_condition_count INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_message TEXT DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET STACKED DIAGNOSTICS v_condition_count = NUMBER;
        GET STACKED DIAGNOSTICS CONDITION v_condition_count
            v_errno = MYSQL_ERRNO, v_message = MESSAGE_TEXT;
        ROLLBACK;

        -- MySQL error 3819 = violated CHECK constraint.
        -- Do not confuse duplicate-key/FK errors with the intended failure.
        IF v_errno = 3819
           AND v_message LIKE '%ck_writes_position%'
           AND NOT EXISTS (SELECT 1 FROM Author WHERE AuthorID = 'AU101')
           AND NOT EXISTS (SELECT 1 FROM Article WHERE ArticleID = 'AR027')
           AND NOT EXISTS (SELECT 1 FROM Writes WHERE ArticleID = 'AR027')
        THEN
            SET @pdm_check_result = 'PASS';
            SELECT 'PASS: expected CHECK error; ROLLBACK verified' AS Result,
                   v_errno AS MySQL_Error, v_message AS Error_Message;
        ELSE
            SET @pdm_check_result = 'FAIL';
            SELECT 'FAIL: unexpected error or rollback could not be verified' AS Result,
                   v_errno AS MySQL_Error, v_message AS Error_Message;
        END IF;
    END;

    START TRANSACTION;

    -- Test IDs must be unused; otherwise the test would be misleading.
    IF EXISTS (SELECT 1 FROM Author WHERE AuthorID = 'AU101')
       OR EXISTS (SELECT 1 FROM Article WHERE ArticleID = 'AR027')
       OR EXISTS (SELECT 1 FROM Writes WHERE ArticleID = 'AR027')
    THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Rollback test IDs already exist; no data changed';
    END IF;

    INSERT INTO Author (AuthorID, FullName)
    VALUES ('AU101', 'Rollback Test Author');

    INSERT INTO Article
        (ArticleID, Title, DOI, Abstract, StartPage, VenueID, EditionNumber)
    VALUES
        ('AR027', 'Rollback Test Article', '10.9999/pdm-rollback-test',
         'Sample article for rollback testing.', 1, 'V001', 1);

    -- Deliberate violation of ck_writes_position.
    INSERT INTO Writes (ArticleID, AuthorID, Position)
    VALUES ('AR027', 'AU101', 0);

    -- If no CHECK error occurs, ROLLBACK anyway to protect the database.
    ROLLBACK;
    SELECT 'FAIL: expected CHECK error did not occur; rolled back for safety' AS Result,
           NULL AS MySQL_Error, NULL AS Error_Message;
END$$

-- C. Failed transaction: a DUPLICATE DOI makes the Article insert fail, and the NEW AUTHOR
--    inserted just before it must disappear as well (no half-finished data).
CREATE PROCEDURE pdm_test_rollback_dup_doi()
BEGIN
    DECLARE v_condition_count INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_message TEXT DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET STACKED DIAGNOSTICS v_condition_count = NUMBER;
        GET STACKED DIAGNOSTICS CONDITION v_condition_count
            v_errno = MYSQL_ERRNO, v_message = MESSAGE_TEXT;
        ROLLBACK;

        -- MySQL error 1062 = duplicate entry, here on the UNIQUE constraint of the DOI.
        IF v_errno = 1062
           AND v_message LIKE '%uq_article_doi%'
           AND NOT EXISTS (SELECT 1 FROM Author WHERE AuthorID = 'AU102')
           AND NOT EXISTS (SELECT 1 FROM Article WHERE ArticleID = 'AR028')
        THEN
            SET @pdm_doi_result = 'PASS';
            SELECT 'PASS: expected duplicate-DOI error; new author rolled back too' AS Result,
                   v_errno AS MySQL_Error, v_message AS Error_Message;
        ELSE
            SET @pdm_doi_result = 'FAIL';
            SELECT 'FAIL: unexpected error or rollback could not be verified' AS Result,
                   v_errno AS MySQL_Error, v_message AS Error_Message;
        END IF;
    END;

    START TRANSACTION;

    IF EXISTS (SELECT 1 FROM Author WHERE AuthorID = 'AU102')
       OR EXISTS (SELECT 1 FROM Article WHERE ArticleID = 'AR028')
    THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Duplicate-DOI test IDs already exist; no data changed';
    END IF;

    INSERT INTO Author (AuthorID, FullName)
    VALUES ('AU102', 'Duplicate DOI Test Author');

    -- The DOI of article AR001 already exists -> error 1062 on uq_article_doi.
    INSERT INTO Article
        (ArticleID, Title, DOI, Abstract, StartPage, VenueID, EditionNumber)
    VALUES
        ('AR028', 'Duplicate DOI Test Article', '10.1145/2699501',
         'Sample article for the duplicate DOI test.', 1, 'V001', 1);

    INSERT INTO Writes (ArticleID, AuthorID, Position)
    VALUES ('AR028', 'AU102', 1);

    ROLLBACK;
    SELECT 'FAIL: expected duplicate-DOI error did not occur; rolled back for safety' AS Result,
           NULL AS MySQL_Error, NULL AS Error_Message;
END$$

DELIMITER ;

-- D. Run the three demos. Each procedure records its own outcome in a session variable
--    (NOT RUN = the procedure never reached its verdict), so section E checks BOTH the
--    procedure result and the data.
SET @pdm_commit_result = 'NOT RUN', @pdm_check_result = 'NOT RUN', @pdm_doi_result = 'NOT RUN',
    @pdm_commit_created = 0;
CALL pdm_test_commit();
CALL pdm_test_rollback();
CALL pdm_test_rollback_dup_doi();

-- E. Final verification: PASS in all three rows is the expected result.
SELECT 'COMMIT' AS TestCase,
       IF(
           EXISTS (SELECT 1 FROM Author WHERE AuthorID = 'AU100'
                   AND FullName = 'Transaction Test Author')
           AND EXISTS (SELECT 1 FROM Article WHERE ArticleID = 'AR026'
                       AND DOI = '10.9999/pdm-transaction-test')
           AND EXISTS (SELECT 1 FROM Writes WHERE ArticleID = 'AR026'
                       AND AuthorID = 'AU100' AND Position = 1)
           AND @pdm_commit_result IN ('PASS', 'SKIP'),
           'PASS', 'FAIL'
       ) AS Verification
UNION ALL
SELECT 'ROLLBACK (CHECK)' AS TestCase,
       IF(
           NOT EXISTS (SELECT 1 FROM Author WHERE AuthorID = 'AU101')
           AND NOT EXISTS (SELECT 1 FROM Article WHERE ArticleID = 'AR027')
           AND NOT EXISTS (SELECT 1 FROM Writes WHERE ArticleID = 'AR027')
           AND @pdm_check_result = 'PASS',
           'PASS', 'FAIL'
       )
UNION ALL
SELECT 'ROLLBACK (duplicate DOI)' AS TestCase,
       IF(
           NOT EXISTS (SELECT 1 FROM Author WHERE AuthorID = 'AU102')
           AND NOT EXISTS (SELECT 1 FROM Article WHERE ArticleID = 'AR028')
           AND NOT EXISTS (SELECT 1 FROM Writes WHERE ArticleID = 'AR028')
           AND @pdm_doi_result = 'PASS',
           'PASS', 'FAIL'
       );

-- F. Clean-up: remove ONLY the rows created by THIS run (@pdm_commit_created = 1), so rows that
--    already existed before the test are never deleted. The demo procedures are dropped too
--    (deleting the article cascades to its Writes row).
DELETE FROM Article WHERE ArticleID = 'AR026' AND @pdm_commit_created = 1;
DELETE FROM Author  WHERE AuthorID  = 'AU100' AND @pdm_commit_created = 1;
DROP PROCEDURE IF EXISTS pdm_test_commit;
DROP PROCEDURE IF EXISTS pdm_test_rollback;
DROP PROCEDURE IF EXISTS pdm_test_rollback_dup_doi;

SELECT IF(NOT EXISTS (SELECT 1 FROM Author WHERE AuthorID IN ('AU101', 'AU102'))
          AND NOT EXISTS (SELECT 1 FROM Article WHERE ArticleID IN ('AR027', 'AR028'))
          AND (@pdm_commit_created = 0
               OR (NOT EXISTS (SELECT 1 FROM Author WHERE AuthorID = 'AU100')
                   AND NOT EXISTS (SELECT 1 FROM Article WHERE ArticleID = 'AR026'))),
          'PASS: test data removed, sample data unchanged',
          'FAIL: test rows are still in the database') AS Cleanup;
