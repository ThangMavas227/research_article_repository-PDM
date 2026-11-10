-- IT079IU - Group 8 - Topic 18: Research Article Repository
DROP DATABASE IF EXISTS research_repo;
CREATE DATABASE research_repo CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE research_repo;

-- 1. Tables (created in an order that satisfies the foreign keys)
CREATE TABLE Institution (
    InstitutionID VARCHAR(15)  NOT NULL,
    Name          VARCHAR(255) NOT NULL,
    Country       VARCHAR(60)  NULL,
    CONSTRAINT pk_institution PRIMARY KEY (InstitutionID),
    CONSTRAINT uq_institution_name UNIQUE (Name)
);

CREATE TABLE Author (
    AuthorID VARCHAR(15)  NOT NULL,
    FullName VARCHAR(150) NOT NULL,
    Orcid    CHAR(19)     NULL,
    CONSTRAINT pk_author PRIMARY KEY (AuthorID),
    CONSTRAINT uq_author_orcid UNIQUE (Orcid),
    CONSTRAINT ck_author_orcid CHECK (Orcid IS NULL OR Orcid REGEXP '^[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{4}$')
);

-- An affiliation holds for an author during a period (EndDate NULL = still current)
CREATE TABLE Affiliation (
    AuthorID      VARCHAR(15) NOT NULL,
    InstitutionID VARCHAR(15) NOT NULL,
    StartDate     DATE        NOT NULL,
    EndDate       DATE        NULL,
    CONSTRAINT pk_affiliation PRIMARY KEY (AuthorID, InstitutionID, StartDate),
    CONSTRAINT fk_aff_author FOREIGN KEY (AuthorID) REFERENCES Author (AuthorID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_aff_inst FOREIGN KEY (InstitutionID) REFERENCES Institution (InstitutionID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_aff_dates CHECK (EndDate IS NULL OR EndDate >= StartDate)
);

-- Self-referencing hierarchy: ParentAreaID / child roles (SubAreaOf)
CREATE TABLE SubjectArea (
    AreaID       VARCHAR(15)  NOT NULL,
    Name         VARCHAR(150) NOT NULL,
    ParentAreaID VARCHAR(15)  NULL,
    CONSTRAINT pk_subjectarea PRIMARY KEY (AreaID),
    CONSTRAINT uq_subjectarea_name UNIQUE (Name),
    CONSTRAINT fk_area_parent FOREIGN KEY (ParentAreaID) REFERENCES SubjectArea (AreaID)
        ON DELETE SET NULL ON UPDATE CASCADE
    -- "area is not its own parent" cannot be a CHECK (MySQL forbids CHECK on a column that has
    -- a SET NULL / CASCADE foreign key action) -> enforced by triggers trg_area_bi / trg_area_bu
);

CREATE TABLE Keyword (
    KeywordID VARCHAR(15) NOT NULL,
    Term      VARCHAR(100) NOT NULL,
    CONSTRAINT pk_keyword PRIMARY KEY (KeywordID),
    CONSTRAINT uq_keyword_term UNIQUE (Term)
);

-- ISA hierarchy Venue -> Journal | Conference (disjoint, discriminator VenueType)
CREATE TABLE Venue (
    VenueID   VARCHAR(15)  NOT NULL,
    Name      VARCHAR(255) NOT NULL,
    Publisher VARCHAR(255) NULL,
    VenueType CHAR(1)      NOT NULL,
    CONSTRAINT pk_venue PRIMARY KEY (VenueID),
    CONSTRAINT uq_venue_name UNIQUE (Name),
    CONSTRAINT uq_venue_id_type UNIQUE (VenueID, VenueType),      -- target of the subtype FKs
    CONSTRAINT ck_venue_type CHECK (VenueType IN ('J', 'C'))
);

-- Subtype FKs use (VenueID, VenueType): a Journal row can only point to a venue of type 'J'.
-- Because VenueType is also used in a CHECK, MySQL only allows RESTRICT actions on that FK.
CREATE TABLE Journal (
    VenueID   VARCHAR(15) NOT NULL,
    VenueType CHAR(1)     NOT NULL DEFAULT 'J',
    Issn      CHAR(9)     NOT NULL,
    CONSTRAINT pk_journal PRIMARY KEY (VenueID),
    CONSTRAINT uq_journal_issn UNIQUE (Issn),
    CONSTRAINT fk_journal_venue FOREIGN KEY (VenueID, VenueType) REFERENCES Venue (VenueID, VenueType)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_journal_type CHECK (VenueType = 'J'),
    CONSTRAINT ck_journal_issn CHECK (Issn REGEXP '^[0-9]{4}-[0-9]{3}[0-9X]$')
);

CREATE TABLE Conference (
    VenueID   VARCHAR(15) NOT NULL,
    VenueType CHAR(1)     NOT NULL DEFAULT 'C',
    Acronym   VARCHAR(20) NOT NULL,
    CONSTRAINT pk_conference PRIMARY KEY (VenueID),
    CONSTRAINT uq_conference_acronym UNIQUE (Acronym),
    CONSTRAINT fk_conference_venue FOREIGN KEY (VenueID, VenueType) REFERENCES Venue (VenueID, VenueType)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_conference_type CHECK (VenueType = 'C')
);

-- Weak entity of Venue: partial key EditionNumber, identifying relationship HasEdition
CREATE TABLE Edition (
    VenueID       VARCHAR(15) NOT NULL,
    EditionNumber INT         NOT NULL,
    PubYear       SMALLINT    NOT NULL,   -- diagram says YEAR; SMALLINT+CHECK avoids Connector/J returning java.sql.Date
    CONSTRAINT pk_edition PRIMARY KEY (VenueID, EditionNumber),
    CONSTRAINT fk_edition_venue FOREIGN KEY (VenueID) REFERENCES Venue (VenueID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_edition_number CHECK (EditionNumber > 0),
    CONSTRAINT ck_edition_year CHECK (PubYear BETWEEN 1900 AND 2100)
);

-- Edition ISA: subtype must match the venue type via the 2nd FK; disjoint follows from it.
-- 'Total' (every Edition has a subtype row) cannot be declared: insert both rows in one transaction.
CREATE TABLE JournalEdition (
    VenueID       VARCHAR(15) NOT NULL,
    EditionNumber INT         NOT NULL,
    Volume        INT         NOT NULL,
    CONSTRAINT pk_journaledition PRIMARY KEY (VenueID, EditionNumber),
    CONSTRAINT fk_je_edition FOREIGN KEY (VenueID, EditionNumber) REFERENCES Edition (VenueID, EditionNumber)
        ON DELETE CASCADE ON UPDATE CASCADE,
    -- the venue must be a Journal; since a venue is either J or C, an edition can never be both
    CONSTRAINT fk_je_journal FOREIGN KEY (VenueID) REFERENCES Journal (VenueID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_je_volume CHECK (Volume > 0)
);

CREATE TABLE ConferenceEdition (
    VenueID       VARCHAR(15)  NOT NULL,
    EditionNumber INT          NOT NULL,
    Location      VARCHAR(150) NOT NULL,
    CONSTRAINT pk_conferenceedition PRIMARY KEY (VenueID, EditionNumber),
    CONSTRAINT fk_ce_edition FOREIGN KEY (VenueID, EditionNumber) REFERENCES Edition (VenueID, EditionNumber)
        ON DELETE CASCADE ON UPDATE CASCADE,
    -- the venue must be a Conference (see JournalEdition)
    CONSTRAINT fk_ce_conference FOREIGN KEY (VenueID) REFERENCES Conference (VenueID)
        ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE TABLE Article (
    ArticleID     VARCHAR(15)  NOT NULL,
    Title         VARCHAR(255) NOT NULL,
    DOI           VARCHAR(100) NOT NULL,
    Abstract      TEXT         NULL,
    StartPage     INT          NOT NULL,
    VenueID       VARCHAR(15)  NOT NULL,
    EditionNumber INT          NOT NULL,
    CONSTRAINT pk_article PRIMARY KEY (ArticleID),
    CONSTRAINT uq_article_doi UNIQUE (DOI),
    CONSTRAINT fk_article_edition FOREIGN KEY (VenueID, EditionNumber) REFERENCES Edition (VenueID, EditionNumber)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_article_doi CHECK (DOI REGEXP '^10\\.[0-9]{4,9}/.+'),
    CONSTRAINT ck_article_startpage CHECK (StartPage > 0)
);

-- M:N Article-Author carrying its own attribute Position
CREATE TABLE Writes (
    ArticleID VARCHAR(15) NOT NULL,
    AuthorID  VARCHAR(15) NOT NULL,
    Position  INT         NOT NULL,
    CONSTRAINT pk_writes PRIMARY KEY (ArticleID, AuthorID),
    CONSTRAINT uq_writes_position UNIQUE (ArticleID, Position),   -- one author per slot
    CONSTRAINT fk_writes_article FOREIGN KEY (ArticleID) REFERENCES Article (ArticleID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_writes_author FOREIGN KEY (AuthorID) REFERENCES Author (AuthorID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_writes_position CHECK (Position >= 1)
);

-- Recursive relationship on Article, roles: citing / cited
CREATE TABLE Citation (
    CitingArticleID VARCHAR(15) NOT NULL,
    CitedArticleID  VARCHAR(15) NOT NULL,
    CONSTRAINT pk_citation PRIMARY KEY (CitingArticleID, CitedArticleID),
    CONSTRAINT fk_cit_citing FOREIGN KEY (CitingArticleID) REFERENCES Article (ArticleID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cit_cited FOREIGN KEY (CitedArticleID) REFERENCES Article (ArticleID)
        ON DELETE CASCADE ON UPDATE CASCADE
    -- "no self-citation" cannot be a CHECK here (FK referential actions on the same columns):
    -- it is enforced in trigger trg_citation_bi
);

CREATE TABLE Classified (
    ArticleID VARCHAR(15) NOT NULL,
    AreaID    VARCHAR(15) NOT NULL,
    CONSTRAINT pk_classified PRIMARY KEY (ArticleID, AreaID),
    CONSTRAINT fk_cl_article FOREIGN KEY (ArticleID) REFERENCES Article (ArticleID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cl_area FOREIGN KEY (AreaID) REFERENCES SubjectArea (AreaID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE HasKeyword (
    ArticleID VARCHAR(15) NOT NULL,
    KeywordID VARCHAR(15) NOT NULL,
    CONSTRAINT pk_haskeyword PRIMARY KEY (ArticleID, KeywordID),
    CONSTRAINT fk_hk_article FOREIGN KEY (ArticleID) REFERENCES Article (ArticleID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_hk_keyword FOREIGN KEY (KeywordID) REFERENCES Keyword (KeywordID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Reader (
    ReaderID VARCHAR(15)  NOT NULL,
    UserName VARCHAR(50)  NOT NULL,
    Email    VARCHAR(255) NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,                      -- bcrypt hash, never the plain password
    Role     VARCHAR(10)  NOT NULL DEFAULT 'reader',
    CONSTRAINT pk_reader PRIMARY KEY (ReaderID),
    CONSTRAINT uq_reader_username UNIQUE (UserName),
    CONSTRAINT uq_reader_email UNIQUE (Email),
    CONSTRAINT ck_reader_email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT ck_reader_role CHECK (Role IN ('reader', 'author', 'admin'))
);

-- Weak entity of Reader (partial key ListName)
CREATE TABLE ReadingList (
    ReaderID    VARCHAR(15)  NOT NULL,
    ListName    VARCHAR(100) NOT NULL,
    CreatedDate DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_readinglist PRIMARY KEY (ReaderID, ListName),
    CONSTRAINT fk_rl_reader FOREIGN KEY (ReaderID) REFERENCES Reader (ReaderID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE `Contains` (
    ReaderID  VARCHAR(15)  NOT NULL,
    ListName  VARCHAR(100) NOT NULL,
    ArticleID VARCHAR(15)  NOT NULL,
    AddedDate DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_contains PRIMARY KEY (ReaderID, ListName, ArticleID),
    CONSTRAINT fk_ct_list FOREIGN KEY (ReaderID, ListName) REFERENCES ReadingList (ReaderID, ListName)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ct_article FOREIGN KEY (ArticleID) REFERENCES Article (ArticleID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Weak entity of Reader (partial key SearchName); search criteria stored as JSON
CREATE TABLE SavedSearch (
    ReaderID    VARCHAR(15)  NOT NULL,
    SearchName  VARCHAR(100) NOT NULL,
    Criteria    JSON         NOT NULL,
    CreatedDate DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_savedsearch PRIMARY KEY (ReaderID, SearchName),
    CONSTRAINT fk_ss_reader FOREIGN KEY (ReaderID) REFERENCES Reader (ReaderID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_ss_json CHECK (JSON_VALID(Criteria))
);

-- 2. Indexes (FK columns are indexed automatically by InnoDB)
-- Helps "articles that cite a given article" (query Q2) and the citation counts
-- of Q3/Q11: the PK (Citing, Cited) cannot serve lookups by CitedArticleID.
CREATE INDEX idx_citation_cited ON Citation (CitedArticleID);
-- Helps searching articles by title in the search form.
CREATE INDEX idx_article_title ON Article (Title);
-- Helps per-year aggregation (Q5) and year-range search.
CREATE INDEX idx_edition_year ON Edition (PubYear);

-- 3. Triggers: rules that declarative constraints cannot express
DELIMITER $$

-- R1: an article cannot cite itself, nor an article published in a later year
CREATE TRIGGER trg_citation_bi BEFORE INSERT ON Citation FOR EACH ROW
BEGIN
    DECLARE y_citing SMALLINT;
    DECLARE y_cited  SMALLINT;
    IF NEW.CitingArticleID = NEW.CitedArticleID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An article cannot cite itself';
    END IF;
    SELECT e.PubYear INTO y_citing FROM Article a JOIN Edition e
        ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber WHERE a.ArticleID = NEW.CitingArticleID;
    SELECT e.PubYear INTO y_cited FROM Article a JOIN Edition e
        ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber WHERE a.ArticleID = NEW.CitedArticleID;
    IF y_cited > y_citing THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An article cannot cite a later publication';
    END IF;
END$$

CREATE TRIGGER trg_citation_bu BEFORE UPDATE ON Citation FOR EACH ROW
BEGIN
    DECLARE y_citing SMALLINT;
    DECLARE y_cited  SMALLINT;
    IF NEW.CitingArticleID = NEW.CitedArticleID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An article cannot cite itself';
    END IF;
    SELECT e.PubYear INTO y_citing FROM Article a JOIN Edition e
        ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber WHERE a.ArticleID = NEW.CitingArticleID;
    SELECT e.PubYear INTO y_cited FROM Article a JOIN Edition e
        ON e.VenueID = a.VenueID AND e.EditionNumber = a.EditionNumber WHERE a.ArticleID = NEW.CitedArticleID;
    IF y_cited > y_citing THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An article cannot cite a later publication';
    END IF;
END$$

-- R2: the periods of one author at the same institution must not overlap
CREATE TRIGGER trg_affiliation_bi BEFORE INSERT ON Affiliation FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM Affiliation
               WHERE AuthorID = NEW.AuthorID AND InstitutionID = NEW.InstitutionID
                 AND StartDate <= COALESCE(NEW.EndDate, '9999-12-31')
                 AND COALESCE(EndDate, '9999-12-31') >= NEW.StartDate) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Overlapping affiliation period at the same institution';
    END IF;
END$$

CREATE TRIGGER trg_affiliation_bu BEFORE UPDATE ON Affiliation FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM Affiliation
               WHERE AuthorID = NEW.AuthorID AND InstitutionID = NEW.InstitutionID
                 AND NOT (StartDate = OLD.StartDate AND InstitutionID = OLD.InstitutionID AND AuthorID = OLD.AuthorID)
                 AND StartDate <= COALESCE(NEW.EndDate, '9999-12-31')
                 AND COALESCE(EndDate, '9999-12-31') >= NEW.StartDate) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Overlapping affiliation period at the same institution';
    END IF;
END$$

-- R3: a subject area cannot be its own parent
CREATE TRIGGER trg_area_bi BEFORE INSERT ON SubjectArea FOR EACH ROW
BEGIN
    IF NEW.ParentAreaID IS NOT NULL AND NEW.ParentAreaID = NEW.AreaID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A subject area cannot be its own parent';
    END IF;
END$$

CREATE TRIGGER trg_area_bu BEFORE UPDATE ON SubjectArea FOR EACH ROW
BEGIN
    IF NEW.ParentAreaID IS NOT NULL AND NEW.ParentAreaID = NEW.AreaID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A subject area cannot be its own parent';
    END IF;
END$$

DELIMITER ;

-- 4. Sample data (inserted parents first)
INSERT INTO Institution (InstitutionID, Name, Country) VALUES
  ('I001', 'Vietnam National University HCMC', 'Vietnam'),
  ('I002', 'International University - VNU HCMC', 'Vietnam'),
  ('I003', 'Hanoi University of Science and Technology', 'Vietnam'),
  ('I004', 'Massachusetts Institute of Technology', 'USA'), ('I005', 'Stanford University', 'USA'),
  ('I006', 'Carnegie Mellon University', 'USA'), ('I007', 'University of Oxford', 'United Kingdom'),
  ('I008', 'University of Cambridge', 'United Kingdom'), ('I009', 'ETH Zurich', 'Switzerland'),
  ('I010', 'National University of Singapore', 'Singapore'), ('I011', 'Tsinghua University', 'China'),
  ('I012', 'University of Tokyo', 'Japan'), ('I013', 'Seoul National University', 'South Korea'),
  ('I014', 'Technical University of Munich', 'Germany'), ('I015', 'University of Toronto', 'Canada'),
  ('I016', 'University of Melbourne', 'Australia');

INSERT INTO Author (AuthorID, FullName, Orcid) VALUES
  ('AU001', 'Nguyen Van An', '0000-0001-1000-2000'), ('AU002', 'Tran Thi Binh', '0000-0002-1037-2091'),
  ('AU003', 'Le Hoang Cuong', '0000-0003-1074-2182'), ('AU004', 'Pham Minh Duc', '0000-0004-1111-2273'),
  ('AU005', 'Vo Thi Hoa', '0000-0005-1148-2364'), ('AU006', 'Huynh Quoc Khanh', '0000-0006-1185-2455'),
  ('AU007', 'Alice Johnson', '0000-0007-1222-2546'), ('AU008', 'Bob Martinez', '0000-0008-1259-2637'),
  ('AU009', 'Chen Wei', '0000-0009-1296-2728'), ('AU010', 'Daniela Rossi', '0000-0001-1333-2819'),
  ('AU011', 'Elena Petrova', '0000-0002-1370-2910'), ('AU012', 'Farid Haddad', '0000-0003-1407-3001'),
  ('AU013', 'Grace Kim', '0000-0004-1444-3092'), ('AU014', 'Hiroshi Tanaka', '0000-0005-1481-3183'),
  ('AU015', 'Ingrid Larsen', '0000-0006-1518-3274'), ('AU016', 'Jamal Williams', '0000-0007-1555-3365'),
  ('AU017', 'Kavita Rao', '0000-0008-1592-3456');

INSERT INTO Affiliation (AuthorID, InstitutionID, StartDate, EndDate) VALUES
  ('AU001', 'I004', '2010-09-01', '2016-06-30'), ('AU001', 'I010', '2016-08-31', NULL),
  ('AU002', 'I001', '2012-09-01', NULL), ('AU003', 'I002', '2013-09-01', NULL),
  ('AU004', 'I014', '2013-09-01', '2019-06-30'), ('AU004', 'I011', '2019-08-31', NULL),
  ('AU005', 'I003', '2015-09-01', NULL), ('AU006', 'I015', '2016-09-01', NULL),
  ('AU007', 'I008', '2011-09-01', '2018-06-30'), ('AU007', 'I009', '2018-08-31', NULL),
  ('AU008', 'I003', '2018-09-01', NULL), ('AU009', 'I004', '2011-09-01', NULL),
  ('AU010', 'I010', '2014-09-01', '2017-06-30'), ('AU010', 'I008', '2017-08-31', NULL),
  ('AU011', 'I004', '2013-09-01', NULL), ('AU012', 'I015', '2014-09-01', NULL),
  ('AU013', 'I001', '2012-09-01', '2016-06-30'), ('AU013', 'I015', '2016-08-31', NULL),
  ('AU014', 'I016', '2016-09-01', NULL), ('AU015', 'I011', '2017-09-01', NULL),
  ('AU016', 'I007', '2010-09-01', '2019-06-30'), ('AU016', 'I014', '2019-08-31', NULL),
  ('AU017', 'I009', '2011-09-01', NULL);

INSERT INTO SubjectArea (AreaID, Name, ParentAreaID) VALUES
  ('SA001', 'Computer Science', NULL), ('SA002', 'Databases', 'SA001'), ('SA003', 'Machine Learning', 'SA001'),
  ('SA004', 'Information Retrieval', 'SA001'), ('SA005', 'Natural Language Processing', 'SA001'),
  ('SA006', 'Computer Vision', 'SA001'), ('SA007', 'Data Mining', 'SA001'), ('SA008', 'Query Processing', 'SA002'),
  ('SA009', 'Transaction Management', 'SA002'), ('SA010', 'Deep Learning', 'SA003'),
  ('SA011', 'Reinforcement Learning', 'SA003'), ('SA012', 'Recommender Systems', 'SA004'),
  ('SA013', 'Bioinformatics', NULL), ('SA014', 'Genomics', 'SA013'), ('SA015', 'Scientometrics', NULL),
  ('SA016', 'Knowledge Graphs', 'SA002');

INSERT INTO Keyword (KeywordID, Term) VALUES
  ('K001', 'indexing'), ('K002', 'query optimization'), ('K003', 'concurrency control'),
  ('K004', 'neural networks'), ('K005', 'transformers'), ('K006', 'graph databases'), ('K007', 'recommendation'),
  ('K008', 'citation analysis'), ('K009', 'text mining'), ('K010', 'clustering'), ('K011', 'sentiment analysis'),
  ('K012', 'image classification'), ('K013', 'reinforcement learning'), ('K014', 'genome sequencing'),
  ('K015', 'ontology'), ('K016', 'data integration');

INSERT INTO Venue (VenueID, Name, Publisher, VenueType) VALUES
  ('V001', 'ACM Transactions on Database Systems', 'ACM', 'J'), ('V002', 'The VLDB Journal', 'Springer', 'J'),
  ('V003', 'Journal of Machine Learning Research', 'JMLR Inc.', 'J'),
  ('V004', 'IEEE Transactions on Knowledge and Data Engineering', 'IEEE', 'J'),
  ('V005', 'Information Systems', 'Elsevier', 'J'), ('V006', 'Artificial Intelligence', 'Elsevier', 'J'),
  ('V007', 'ACM Computing Surveys', 'ACM', 'J'), ('V008', 'Journal of Information Science', 'SAGE', 'J'),
  ('V009', 'Data Mining and Knowledge Discovery', 'Springer', 'J'),
  ('V010', 'Bioinformatics Letters', 'Oxford Academic', 'J'), ('V011', 'Scientometrics Review', 'Springer', 'J'),
  ('V012', 'Journal of Web Semantics', 'Elsevier', 'J'), ('V013', 'Neural Computation Letters', 'MIT Press', 'J'),
  ('V014', 'Knowledge-Based Systems', 'Elsevier', 'J'), ('V015', 'Pattern Recognition Journal', 'Elsevier', 'J'),
  ('V016', 'ACM SIGMOD Conference', 'ACM', 'C'),
  ('V017', 'International Conference on Very Large Data Bases', 'VLDB Endowment', 'C'),
  ('V018', 'IEEE International Conference on Data Engineering', 'IEEE', 'C'),
  ('V019', 'ACM SIGKDD Conference', 'ACM', 'C'),
  ('V020', 'Conference on Neural Information Processing Systems', 'NeurIPS Foundation', 'C'),
  ('V021', 'International Conference on Machine Learning', 'PMLR', 'C'),
  ('V022', 'Annual Meeting of the Association for Computational Linguistics', 'ACL', 'C'),
  ('V023', 'The Web Conference', 'ACM', 'C'), ('V024', 'ACM SIGIR Conference', 'ACM', 'C'),
  ('V025', 'ACM Conference on Information and Knowledge Management', 'ACM', 'C'),
  ('V026', 'Conference on Computer Vision and Pattern Recognition', 'IEEE', 'C'),
  ('V027', 'AAAI Conference on Artificial Intelligence', 'AAAI Press', 'C'),
  ('V028', 'International Joint Conference on Artificial Intelligence', 'IJCAI Org.', 'C'),
  ('V029', 'Empirical Methods in Natural Language Processing', 'ACL', 'C'),
  ('V030', 'International Conference on Learning Representations', 'OpenReview', 'C');

INSERT INTO Journal (VenueID, VenueType, Issn) VALUES
  ('V001', 'J', '2000-1000'), ('V002', 'J', '2007-1053'), ('V003', 'J', '2014-1106'), ('V004', 'J', '2021-1159'),
  ('V005', 'J', '2028-1212'), ('V006', 'J', '2035-1265'), ('V007', 'J', '2042-1318'), ('V008', 'J', '2049-1371'),
  ('V009', 'J', '2056-1424'), ('V010', 'J', '2063-1477'), ('V011', 'J', '2070-1530'), ('V012', 'J', '2077-1583'),
  ('V013', 'J', '2084-1636'), ('V014', 'J', '2091-1689'), ('V015', 'J', '2098-1742');

INSERT INTO Conference (VenueID, VenueType, Acronym) VALUES
  ('V016', 'C', 'SIGMOD'), ('V017', 'C', 'VLDB'), ('V018', 'C', 'ICDE'), ('V019', 'C', 'KDD'),
  ('V020', 'C', 'NeurIPS'), ('V021', 'C', 'ICML'), ('V022', 'C', 'ACL'), ('V023', 'C', 'WWW'),
  ('V024', 'C', 'SIGIR'), ('V025', 'C', 'CIKM'), ('V026', 'C', 'CVPR'), ('V027', 'C', 'AAAI'),
  ('V028', 'C', 'IJCAI'), ('V029', 'C', 'EMNLP'), ('V030', 'C', 'ICLR');

INSERT INTO Edition (VenueID, EditionNumber, PubYear) VALUES
  ('V001', 1, 2016), ('V002', 1, 2017), ('V003', 1, 2018), ('V004', 1, 2019), ('V005', 1, 2020),
  ('V006', 1, 2016), ('V007', 1, 2017), ('V008', 1, 2018), ('V009', 1, 2019), ('V010', 1, 2020),
  ('V011', 1, 2016), ('V012', 1, 2017), ('V013', 1, 2018), ('V014', 1, 2019), ('V015', 1, 2020),
  ('V016', 1, 2016), ('V017', 1, 2017), ('V018', 1, 2018), ('V019', 1, 2019), ('V020', 1, 2020),
  ('V021', 1, 2016), ('V022', 1, 2017), ('V023', 1, 2018), ('V024', 1, 2019), ('V025', 1, 2020),
  ('V026', 1, 2016), ('V027', 1, 2017), ('V028', 1, 2018), ('V029', 1, 2019), ('V030', 1, 2020);

INSERT INTO JournalEdition (VenueID, EditionNumber, Volume) VALUES
  ('V001', 1, 26), ('V002', 1, 28), ('V003', 1, 30), ('V004', 1, 29), ('V005', 1, 31),
  ('V006', 1, 28), ('V007', 1, 27), ('V008', 1, 29), ('V009', 1, 31), ('V010', 1, 30),
  ('V011', 1, 27), ('V012', 1, 29), ('V013', 1, 28), ('V014', 1, 30), ('V015', 1, 32);

INSERT INTO ConferenceEdition (VenueID, EditionNumber, Location) VALUES
  ('V016', 1, 'Vancouver'), ('V017', 1, 'Vienna'), ('V018', 1, 'Seoul'), ('V019', 1, 'Sydney'),
  ('V020', 1, 'Berlin'), ('V021', 1, 'Toronto'), ('V022', 1, 'Kyoto'), ('V023', 1, 'Paris'),
  ('V024', 1, 'Honolulu'), ('V025', 1, 'Lisbon'), ('V026', 1, 'Hanoi'), ('V027', 1, 'Barcelona'),
  ('V028', 1, 'Montreal'), ('V029', 1, 'Dubai'), ('V030', 1, 'Singapore');

INSERT INTO Article (ArticleID, Title, DOI, Abstract, StartPage, VenueID, EditionNumber) VALUES
  ('AR001', 'Adaptive Indexing for Large-Scale Relational Workloads', '10.5555/rr.2000.001', 'This paper studies adaptive indexing for large-scale relational workloads and reports results on realistic benchmark datasets.', 1, 'V001', 1),
  ('AR002', 'Cost-Based Query Optimization Under Uncertainty', '10.5555/rr.2013.002', 'This paper studies cost-based query optimization under uncertainty and reports results on realistic benchmark datasets.', 18, 'V002', 1),
  ('AR003', 'Snapshot Isolation Revisited for Distributed Transactions', '10.5555/rr.2026.003', 'This paper studies snapshot isolation revisited for distributed transactions and reports results on realistic benchmark datasets.', 35, 'V003', 1),
  ('AR004', 'A Survey of Graph Database Engines', '10.5555/rr.2039.004', 'This paper studies a survey of graph database engines and reports results on realistic benchmark datasets.', 52, 'V004', 1),
  ('AR005', 'Deep Residual Models for Medical Image Classification', '10.5555/rr.2052.005', 'This paper studies deep residual models for medical image classification and reports results on realistic benchmark datasets.', 69, 'V005', 1),
  ('AR006', 'Attention Mechanisms in Document Retrieval', '10.5555/rr.2065.006', 'This paper studies attention mechanisms in document retrieval and reports results on realistic benchmark datasets.', 86, 'V006', 1),
  ('AR007', 'Learning to Rank with Click Feedback', '10.5555/rr.2078.007', 'This paper studies learning to rank with click feedback and reports results on realistic benchmark datasets.', 103, 'V007', 1),
  ('AR008', 'Scalable Collaborative Filtering with Implicit Signals', '10.5555/rr.2091.008', 'This paper studies scalable collaborative filtering with implicit signals and reports results on realistic benchmark datasets.', 120, 'V008', 1),
  ('AR009', 'Knowledge Graph Embeddings for Entity Linking', '10.5555/rr.2104.009', 'This paper studies knowledge graph embeddings for entity linking and reports results on realistic benchmark datasets.', 137, 'V001', 1),
  ('AR010', 'Benchmarking NoSQL Stores on Mixed Workloads', '10.5555/rr.2117.010', 'This paper studies benchmarking nosql stores on mixed workloads and reports results on realistic benchmark datasets.', 154, 'V002', 1),
  ('AR011', 'Differential Privacy in Query Processing', '10.5555/rr.2130.011', 'This paper studies differential privacy in query processing and reports results on realistic benchmark datasets.', 171, 'V003', 1),
  ('AR012', 'Policy Gradient Methods for Index Selection', '10.5555/rr.2143.012', 'This paper studies policy gradient methods for index selection and reports results on realistic benchmark datasets.', 188, 'V004', 1),
  ('AR013', 'Transformer Language Models for Sentiment Analysis', '10.5555/rr.2156.013', 'This paper studies transformer language models for sentiment analysis and reports results on realistic benchmark datasets.', 205, 'V005', 1),
  ('AR014', 'Clustering Citation Networks at Scale', '10.5555/rr.2169.014', 'This paper studies clustering citation networks at scale and reports results on realistic benchmark datasets.', 222, 'V006', 1),
  ('AR015', 'Open Access and Citation Advantage: An Empirical Study', '10.5555/rr.2182.015', 'This paper studies open access and citation advantage: an empirical study and reports results on realistic benchmark datasets.', 239, 'V007', 1),
  ('AR016', 'Genome Sequence Alignment on Columnar Stores', '10.5555/rr.2195.016', 'This paper studies genome sequence alignment on columnar stores and reports results on realistic benchmark datasets.', 256, 'V008', 1),
  ('AR017', 'Entity Resolution for Bibliographic Databases', '10.5555/rr.2208.017', 'This paper studies entity resolution for bibliographic databases and reports results on realistic benchmark datasets.', 273, 'V016', 1),
  ('AR018', 'Learned Cardinality Estimation', '10.5555/rr.2221.018', 'This paper studies learned cardinality estimation and reports results on realistic benchmark datasets.', 290, 'V017', 1),
  ('AR019', 'Federated Learning for Recommender Systems', '10.5555/rr.2234.019', 'This paper studies federated learning for recommender systems and reports results on realistic benchmark datasets.', 307, 'V018', 1),
  ('AR020', 'Ontology-Based Data Integration of Scholarly Metadata', '10.5555/rr.2247.020', 'This paper studies ontology-based data integration of scholarly metadata and reports results on realistic benchmark datasets.', 324, 'V019', 1),
  ('AR021', 'Temporal Query Languages for Evolving Affiliations', '10.5555/rr.2260.021', 'This paper studies temporal query languages for evolving affiliations and reports results on realistic benchmark datasets.', 341, 'V020', 1),
  ('AR022', 'Contrastive Pretraining for Scientific Text', '10.5555/rr.2273.022', 'This paper studies contrastive pretraining for scientific text and reports results on realistic benchmark datasets.', 358, 'V021', 1),
  ('AR023', 'Frequent Pattern Mining in Co-authorship Graphs', '10.5555/rr.2286.023', 'This paper studies frequent pattern mining in co-authorship graphs and reports results on realistic benchmark datasets.', 375, 'V022', 1),
  ('AR024', 'Convolutional Architectures for Figure Retrieval', '10.5555/rr.2299.024', 'This paper studies convolutional architectures for figure retrieval and reports results on realistic benchmark datasets.', 392, 'V023', 1);

INSERT INTO Writes (ArticleID, AuthorID, Position) VALUES
  ('AR001', 'AU001', 1), ('AR001', 'AU002', 2), ('AR001', 'AU014', 3), ('AR001', 'AU009', 4), ('AR002', 'AU001', 1), ('AR002', 'AU002', 2),
  ('AR002', 'AU008', 3), ('AR002', 'AU009', 4), ('AR003', 'AU001', 1), ('AR003', 'AU002', 2), ('AR003', 'AU003', 3), ('AR004', 'AU011', 1),
  ('AR004', 'AU010', 2), ('AR004', 'AU013', 3), ('AR005', 'AU003', 1), ('AR005', 'AU004', 2), ('AR005', 'AU002', 3), ('AR006', 'AU005', 1),
  ('AR006', 'AU003', 2), ('AR006', 'AU002', 3), ('AR007', 'AU010', 1), ('AR008', 'AU008', 1), ('AR008', 'AU011', 2), ('AR008', 'AU012', 3),
  ('AR009', 'AU010', 1), ('AR009', 'AU001', 2), ('AR010', 'AU001', 1), ('AR011', 'AU004', 1), ('AR012', 'AU010', 1), ('AR012', 'AU001', 2),
  ('AR013', 'AU003', 1), ('AR013', 'AU004', 2), ('AR013', 'AU006', 3), ('AR013', 'AU008', 4), ('AR014', 'AU009', 1), ('AR014', 'AU004', 2),
  ('AR015', 'AU008', 1), ('AR015', 'AU001', 2), ('AR016', 'AU008', 1), ('AR017', 'AU007', 1), ('AR017', 'AU009', 2), ('AR018', 'AU012', 1),
  ('AR019', 'AU006', 1), ('AR019', 'AU013', 2), ('AR020', 'AU009', 1), ('AR020', 'AU005', 2), ('AR021', 'AU002', 1), ('AR022', 'AU007', 1),
  ('AR023', 'AU014', 1), ('AR024', 'AU007', 1), ('AR024', 'AU002', 2);

INSERT INTO Citation (CitingArticleID, CitedArticleID) VALUES
  ('AR002', 'AR001'), ('AR002', 'AR017'), ('AR003', 'AR001'), ('AR003', 'AR022'), ('AR004', 'AR001'), ('AR004', 'AR006'),
  ('AR004', 'AR024'), ('AR005', 'AR003'), ('AR005', 'AR017'), ('AR006', 'AR001'), ('AR007', 'AR014'), ('AR007', 'AR022'),
  ('AR008', 'AR001'), ('AR008', 'AR010'), ('AR009', 'AR001'), ('AR009', 'AR006'), ('AR010', 'AR001'), ('AR010', 'AR002'),
  ('AR010', 'AR014'), ('AR010', 'AR017'), ('AR011', 'AR001'), ('AR011', 'AR002'), ('AR011', 'AR014'), ('AR011', 'AR023'),
  ('AR012', 'AR001'), ('AR012', 'AR004'), ('AR012', 'AR018'), ('AR013', 'AR003'), ('AR013', 'AR010'), ('AR014', 'AR001'),
  ('AR014', 'AR006'), ('AR014', 'AR009'), ('AR015', 'AR001'), ('AR015', 'AR002'), ('AR015', 'AR009'), ('AR016', 'AR001'),
  ('AR016', 'AR007'), ('AR017', 'AR001'), ('AR017', 'AR006'), ('AR017', 'AR009'), ('AR017', 'AR014'), ('AR018', 'AR001'),
  ('AR018', 'AR002'), ('AR018', 'AR006'), ('AR019', 'AR014'), ('AR019', 'AR018'), ('AR020', 'AR003'), ('AR020', 'AR017'),
  ('AR020', 'AR022'), ('AR021', 'AR006'), ('AR021', 'AR017'), ('AR021', 'AR020'), ('AR022', 'AR001'), ('AR022', 'AR006'),
  ('AR022', 'AR009'), ('AR023', 'AR002'), ('AR023', 'AR014'), ('AR023', 'AR017'), ('AR024', 'AR001'), ('AR024', 'AR003'),
  ('AR024', 'AR007'), ('AR024', 'AR008');

INSERT INTO Classified (ArticleID, AreaID) VALUES
  ('AR001', 'SA002'), ('AR001', 'SA008'), ('AR002', 'SA008'), ('AR003', 'SA009'), ('AR004', 'SA002'), ('AR004', 'SA016'),
  ('AR005', 'SA010'), ('AR005', 'SA006'), ('AR006', 'SA004'), ('AR006', 'SA010'), ('AR007', 'SA004'), ('AR008', 'SA012'),
  ('AR009', 'SA016'), ('AR009', 'SA005'), ('AR010', 'SA002'), ('AR011', 'SA008'), ('AR011', 'SA002'), ('AR012', 'SA011'),
  ('AR012', 'SA002'), ('AR013', 'SA005'), ('AR013', 'SA010'), ('AR014', 'SA007'), ('AR014', 'SA015'), ('AR015', 'SA015'),
  ('AR016', 'SA014'), ('AR016', 'SA013'), ('AR017', 'SA002'), ('AR017', 'SA007'), ('AR018', 'SA008'), ('AR018', 'SA003'),
  ('AR019', 'SA012'), ('AR019', 'SA003'), ('AR020', 'SA016'), ('AR020', 'SA002'), ('AR021', 'SA002'), ('AR022', 'SA005'),
  ('AR022', 'SA010'), ('AR023', 'SA007'), ('AR024', 'SA006'), ('AR024', 'SA004');

INSERT INTO HasKeyword (ArticleID, KeywordID) VALUES
  ('AR001', 'K001'), ('AR002', 'K002'), ('AR003', 'K003'), ('AR004', 'K006'), ('AR005', 'K004'), ('AR005', 'K012'),
  ('AR006', 'K005'), ('AR006', 'K009'), ('AR007', 'K007'), ('AR008', 'K007'), ('AR009', 'K014'), ('AR009', 'K015'),
  ('AR012', 'K013'), ('AR012', 'K001'), ('AR013', 'K005'), ('AR013', 'K011'), ('AR014', 'K010'), ('AR014', 'K008'),
  ('AR015', 'K008'), ('AR016', 'K016'), ('AR016', 'K002'), ('AR017', 'K016'), ('AR017', 'K015'), ('AR018', 'K004'),
  ('AR018', 'K002'), ('AR019', 'K007'), ('AR020', 'K015'), ('AR020', 'K016'), ('AR021', 'K001'), ('AR021', 'K015'),
  ('AR022', 'K005'), ('AR022', 'K009'), ('AR023', 'K010'), ('AR023', 'K006'), ('AR024', 'K012'), ('AR024', 'K004');

INSERT INTO Reader (ReaderID, UserName, Email, PasswordHash, Role) VALUES
  ('R001', 'admin', 'admin@example.edu', '$2a$10$LR713.pP6dm5BdukuB7uMu8AozU7rWH6UbOSuAyX.Hgdi.P7QX2jG', 'admin'),
  ('R002', 'author1', 'author1@example.edu', '$2a$10$9JiwpkjBEmIeLZjVRP38m.nALr/BgvC01TVBNBy9nYle7IAl3herS', 'author'),
  ('R003', 'phuong_an', 'phuong_an@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R004', 'nguyen_bao', 'nguyen_bao@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R005', 'khanh_pl', 'khanh_pl@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R006', 'han_pg', 'han_pg@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R007', 'nhat_nv', 'nhat_nv@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R008', 'vo_bao', 'vo_bao@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R009', 'thang_hm', 'thang_hm@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R010', 'tai_nk', 'tai_nk@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R011', 'dr_smith', 'dr_smith@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R012', 'prof_lee', 'prof_lee@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R013', 'grad_student1', 'grad_student1@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R014', 'lib_admin', 'lib_admin@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R015', 'reviewer42', 'reviewer42@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('R016', 'data_nerd', 'data_nerd@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader');

INSERT INTO ReadingList (ReaderID, ListName, CreatedDate) VALUES
  ('R001', 'Thesis references', '2026-01-01 09:00:00'), ('R002', 'To read', '2026-02-02 09:00:00'),
  ('R003', 'Database internals', '2026-03-03 09:00:00'), ('R004', 'Favourite surveys', '2026-04-04 09:00:00'),
  ('R005', 'Citation analysis', '2026-05-05 09:00:00'), ('R006', 'ML basics', '2026-06-06 09:00:00'),
  ('R007', 'Thesis references', '2026-07-07 09:00:00'), ('R008', 'To read', '2026-08-08 09:00:00'),
  ('R009', 'Database internals', '2026-09-09 09:00:00'), ('R010', 'Favourite surveys', '2026-01-10 09:00:00'),
  ('R011', 'Citation analysis', '2026-02-11 09:00:00'), ('R012', 'ML basics', '2026-03-12 09:00:00'),
  ('R013', 'Thesis references', '2026-04-13 09:00:00'), ('R014', 'To read', '2026-05-14 09:00:00'),
  ('R015', 'Database internals', '2026-06-15 09:00:00');

INSERT INTO `Contains` (ReaderID, ListName, ArticleID, AddedDate) VALUES
  ('R001', 'Thesis references', 'AR008', '2026-01-01 9:00:00'), ('R003', 'Database internals', 'AR022', '2026-02-04 10:07:00'),
  ('R004', 'Favourite surveys', 'AR005', '2026-03-07 11:14:00'), ('R004', 'Favourite surveys', 'AR021', '2026-04-10 12:21:00'),
  ('R005', 'Citation analysis', 'AR001', '2026-05-13 13:28:00'), ('R006', 'ML basics', 'AR010', '2026-06-16 14:35:00'), 
  ('R006', 'ML basics', 'AR013', '2026-07-19 15:42:00'), ('R007', 'Thesis references', 'AR007', '2026-08-22 16:49:00'),
  ('R007', 'Thesis references', 'AR008', '2026-09-25 17:56:00'), ('R008', 'To read', 'AR008', '2026-01-01 18:03:00'), 
  ('R008', 'To read', 'AR020', '2026-02-04 9:10:00'), ('R009', 'Database internals', 'AR006', '2026-03-07 10:17:00'),
  ('R010', 'Favourite surveys', 'AR007', '2026-04-10 11:24:00'), ('R010', 'Favourite surveys', 'AR011', '2026-05-13 12:31:00'),
  ('R011', 'Citation analysis', 'AR009', '2026-06-16 13:38:00'), ('R011', 'Citation analysis', 'AR015', '2026-07-19 14:45:00'),
  ('R011', 'Citation analysis', 'AR016', '2026-08-22 15:52:00'), ('R012', 'ML basics', 'AR004', '2026-09-25 16:59:00'),
  ('R013', 'Thesis references', 'AR011', '2026-01-01 17:06:00'), ('R015', 'Database internals', 'AR007', '2026-02-04 18:13:00');

INSERT INTO SavedSearch (ReaderID, SearchName, Criteria, CreatedDate) VALUES
  ('R001', 'Search 1: query optimization', '{"keyword": "query optimization", "yearFrom": 2016, "yearTo": 2025, "venueType": "C"}', '2026-01-02 10:00:00'),
  ('R002', 'Search 2: knowledge graph', '{"keyword": "knowledge graph", "yearFrom": 2017, "yearTo": 2025, "venueType": "J"}', '2026-02-03 10:03:00'),
  ('R003', 'Search 3: citation', '{"keyword": "citation", "yearFrom": 2018, "yearTo": 2025, "venueType": "C"}', '2026-03-04 10:06:00'),
  ('R004', 'Search 4: transformer', '{"keyword": "transformer", "yearFrom": 2019, "yearTo": 2025, "venueType": "J"}', '2026-04-05 10:09:00'),
  ('R005', 'Search 5: privacy', '{"keyword": "privacy", "yearFrom": 2020, "yearTo": 2025, "venueType": "C"}', '2026-05-06 10:12:00'),
  ('R006', 'Search 6: recommendation', '{"keyword": "recommendation", "yearFrom": 2021, "yearTo": 2025, "venueType": "J"}', '2026-06-07 10:15:00'),
  ('R007', 'Search 7: genome', '{"keyword": "genome", "yearFrom": 2016, "yearTo": 2025, "venueType": "C"}', '2026-07-08 10:18:00'),
  ('R008', 'Search 8: benchmark', '{"keyword": "benchmark", "yearFrom": 2017, "yearTo": 2025, "venueType": "J"}', '2026-08-09 10:21:00'),
  ('R009', 'Search 9: query optimization', '{"keyword": "query optimization", "yearFrom": 2018, "yearTo": 2025, "venueType": "C"}', '2026-09-10 10:24:00'),
  ('R010', 'Search 10: knowledge graph', '{"keyword": "knowledge graph", "yearFrom": 2019, "yearTo": 2025, "venueType": "J"}', '2026-01-11 10:27:00'),
  ('R011', 'Search 11: citation', '{"keyword": "citation", "yearFrom": 2020, "yearTo": 2025, "venueType": "C"}', '2026-02-12 10:30:00'),
  ('R012', 'Search 12: transformer', '{"keyword": "transformer", "yearFrom": 2021, "yearTo": 2025, "venueType": "J"}', '2026-03-13 10:33:00'),
  ('R013', 'Search 13: privacy', '{"keyword": "privacy", "yearFrom": 2016, "yearTo": 2025, "venueType": "C"}', '2026-04-14 10:36:00'),
  ('R014', 'Search 14: recommendation', '{"keyword": "recommendation", "yearFrom": 2017, "yearTo": 2025, "venueType": "J"}', '2026-05-15 10:39:00'),
  ('R015', 'Search 15: genome', '{"keyword": "genome", "yearFrom": 2018, "yearTo": 2025, "venueType": "C"}', '2026-06-16 10:42:00');
