-- =====================================================================
-- IT079IU - Group 8 - Topic 18: Research Article Repository
-- script.sql : DROP / CREATE / constraints / indexes / triggers / sample data
-- DBMS       : MySQL 8.0 (tested on 8.0.46). Version >= 8.0.16 is required so that
--              CHECK constraints are enforced (older versions parse but ignore them).
-- Run        : mysql -u root -p < script.sql   (runs on an empty server, top to bottom,
--              and can be run twice in a row without manual repair)
-- MySQL-specific features used: CHECK with REGEXP, JSON type + JSON_VALID, triggers with
--              SIGNAL, the DELIMITER command, utf8mb4_0900_ai_ci collation.
-- Note       : the relationship "Write" of the ER diagram is the table `Writes`
--              because WRITE is a reserved word in MySQL.
-- Sample data: bibliographic records (articles, authors, venues, citations, keywords, topics) are real,
--              taken from OpenAlex (CC0); affiliation periods, users, reading lists and saved searches
--              are synthetic; abstracts are the first sentence of the real abstract or a short own summary.
-- =====================================================================
DROP DATABASE IF EXISTS research_repo;
CREATE DATABASE research_repo CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE research_repo;

-- 1. Tables (created in an order that satisfies the foreign keys)
CREATE TABLE Institution (
    InstitutionID VARCHAR(15)  NOT NULL,
    Name          VARCHAR(255) NOT NULL,
    CONSTRAINT pk_institution PRIMARY KEY (InstitutionID),
    CONSTRAINT uq_institution_name UNIQUE (Name)
);

CREATE TABLE Author (
    AuthorID VARCHAR(15)  NOT NULL,
    FullName VARCHAR(150) NOT NULL,
    CONSTRAINT pk_author PRIMARY KEY (AuthorID)
);

-- Weak entity of Author: partial key StartDate (identifying relationship HasAffiliation);
-- the institution is an ordinary foreign key (relationship At). EndDate NULL = still current.
CREATE TABLE Affiliation (
    AuthorID      VARCHAR(15) NOT NULL,
    InstitutionID VARCHAR(15) NOT NULL,
    StartDate     DATE        NOT NULL,
    EndDate       DATE        NULL,
    CONSTRAINT pk_affiliation PRIMARY KEY (AuthorID, StartDate),
    CONSTRAINT fk_aff_author FOREIGN KEY (AuthorID) REFERENCES Author (AuthorID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_aff_inst FOREIGN KEY (InstitutionID) REFERENCES Institution (InstitutionID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_aff_dates CHECK (EndDate IS NULL OR EndDate >= StartDate)
);

CREATE TABLE SubjectArea (
    AreaID VARCHAR(15)  NOT NULL,
    Name   VARCHAR(150) NOT NULL,
    CONSTRAINT pk_subjectarea PRIMARY KEY (AreaID),
    CONSTRAINT uq_subjectarea_name UNIQUE (Name)
);

CREATE TABLE Keyword (
    KeywordID VARCHAR(15) NOT NULL,
    Term      VARCHAR(100) NOT NULL,
    CONSTRAINT pk_keyword PRIMARY KEY (KeywordID),
    CONSTRAINT uq_keyword_term UNIQUE (Term)
);

-- ISA hierarchy Venue -> Journal | Conference (disjoint, total; discriminator VenueType)
CREATE TABLE Venue (
    VenueID   VARCHAR(15)  NOT NULL,
    Name      VARCHAR(255) NOT NULL,
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
    ISSN      CHAR(9)     NOT NULL,
    CONSTRAINT pk_journal PRIMARY KEY (VenueID),
    CONSTRAINT uq_journal_issn UNIQUE (ISSN),
    CONSTRAINT fk_journal_venue FOREIGN KEY (VenueID, VenueType) REFERENCES Venue (VenueID, VenueType)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_journal_type CHECK (VenueType = 'J'),
    CONSTRAINT ck_journal_issn CHECK (ISSN REGEXP '^[0-9]{4}-[0-9]{3}[0-9X]$')
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

-- Weak entity of Venue: partial key EditionNumber, identifying relationship HasEdition.
-- Volume belongs to journal editions only and Location to conference editions only; this depends
-- on the venue type, so it is enforced by triggers trg_edition_bi / trg_edition_bu.
CREATE TABLE Edition (
    VenueID       VARCHAR(15)  NOT NULL,
    EditionNumber INT          NOT NULL,
    PubYear       SMALLINT     NOT NULL,   -- SMALLINT+CHECK instead of YEAR: Connector/J returns YEAR as java.sql.Date
    Volume        INT          NULL,
    Location      VARCHAR(150) NULL,
    CONSTRAINT pk_edition PRIMARY KEY (VenueID, EditionNumber),
    CONSTRAINT fk_edition_venue FOREIGN KEY (VenueID) REFERENCES Venue (VenueID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_edition_number CHECK (EditionNumber > 0),
    CONSTRAINT ck_edition_year CHECK (PubYear BETWEEN 1900 AND 2100),
    CONSTRAINT ck_edition_volume CHECK (Volume IS NULL OR Volume > 0)
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

CREATE TABLE User (
    UserID       VARCHAR(15)  NOT NULL,
    Username     VARCHAR(50)  NOT NULL,
    Email        VARCHAR(255) NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,                      -- bcrypt hash, never the plain password
    Role         VARCHAR(10)  NOT NULL DEFAULT 'reader',
    CONSTRAINT pk_user PRIMARY KEY (UserID),
    CONSTRAINT uq_user_username UNIQUE (Username),
    CONSTRAINT uq_user_email UNIQUE (Email),
    CONSTRAINT ck_user_email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT ck_user_role CHECK (Role IN ('reader', 'author', 'admin'))
);

-- Weak entity of User (partial key ListName), identifying relationship Owns
CREATE TABLE ReadingList (
    UserID      VARCHAR(15)  NOT NULL,
    ListName    VARCHAR(100) NOT NULL,
    CreatedDate DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_readinglist PRIMARY KEY (UserID, ListName),
    CONSTRAINT fk_rl_user FOREIGN KEY (UserID) REFERENCES User (UserID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- M:N between ReadingList and Article with its own attribute AddedDate
CREATE TABLE `Contains` (
    UserID    VARCHAR(15)  NOT NULL,
    ListName  VARCHAR(100) NOT NULL,
    ArticleID VARCHAR(15)  NOT NULL,
    AddedDate DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_contains PRIMARY KEY (UserID, ListName, ArticleID),
    CONSTRAINT fk_ct_list FOREIGN KEY (UserID, ListName) REFERENCES ReadingList (UserID, ListName)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ct_article FOREIGN KEY (ArticleID) REFERENCES Article (ArticleID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Weak entity of User (partial key SearchName), identifying relationship Saves;
-- search criteria are stored as JSON
CREATE TABLE SavedSearch (
    UserID      VARCHAR(15)  NOT NULL,
    SearchName  VARCHAR(100) NOT NULL,
    Criteria    JSON         NOT NULL,
    CreatedDate DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_savedsearch PRIMARY KEY (UserID, SearchName),
    CONSTRAINT fk_ss_user FOREIGN KEY (UserID) REFERENCES User (UserID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_ss_json CHECK (JSON_VALID(Criteria))
);

-- 2. Indexes (FK columns are indexed automatically by InnoDB)
-- Helps "articles that cite a given article" (Q2) and the citation counts of Q3, Q7 and
-- Q11: the PK (Citing, Cited) starts with CitingArticleID, so it cannot serve lookups by
-- CitedArticleID (EXPLAIN: ref access on 7 entries instead of scanning all 39 PK entries).
CREATE INDEX idx_citation_cited ON Citation (CitedArticleID);
-- Helps searching articles by the BEGINNING of a title (LIKE 'abc%') or an exact title.
-- A search for a word inside a title (LIKE '%abc%') cannot seek and does not benefit.
CREATE INDEX idx_article_title ON Article (Title);
-- Helps filtering by publication year (search form, year-range search): EXPLAIN shows a
-- ref access on 3 rows instead of a full scan of 41. Q5 reaches Edition through its PK.
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

-- R2: the affiliation periods of one author must not overlap, at any institution
CREATE TRIGGER trg_affiliation_bi BEFORE INSERT ON Affiliation FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM Affiliation
               WHERE AuthorID = NEW.AuthorID
                 AND StartDate <= COALESCE(NEW.EndDate, '9999-12-31')
                 AND COALESCE(EndDate, '9999-12-31') >= NEW.StartDate) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Overlapping affiliation period for the same author';
    END IF;
END$$

CREATE TRIGGER trg_affiliation_bu BEFORE UPDATE ON Affiliation FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM Affiliation
               WHERE AuthorID = NEW.AuthorID
                 AND NOT (AuthorID = OLD.AuthorID AND StartDate = OLD.StartDate)
                 AND StartDate <= COALESCE(NEW.EndDate, '9999-12-31')
                 AND COALESCE(EndDate, '9999-12-31') >= NEW.StartDate) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Overlapping affiliation period for the same author';
    END IF;
END$$

-- R3: a journal edition has a volume and no location; a conference edition has a location and no volume
CREATE TRIGGER trg_edition_bi BEFORE INSERT ON Edition FOR EACH ROW
BEGIN
    DECLARE vtype CHAR(1);
    SELECT VenueType INTO vtype FROM Venue WHERE VenueID = NEW.VenueID;
    IF vtype = 'J' AND (NEW.Volume IS NULL OR NEW.Location IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A journal edition needs a volume and has no location';
    END IF;
    IF vtype = 'C' AND (NEW.Location IS NULL OR NEW.Volume IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A conference edition needs a location and has no volume';
    END IF;
END$$

CREATE TRIGGER trg_edition_bu BEFORE UPDATE ON Edition FOR EACH ROW
BEGIN
    DECLARE vtype CHAR(1);
    SELECT VenueType INTO vtype FROM Venue WHERE VenueID = NEW.VenueID;
    IF vtype = 'J' AND (NEW.Volume IS NULL OR NEW.Location IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A journal edition needs a volume and has no location';
    END IF;
    IF vtype = 'C' AND (NEW.Location IS NULL OR NEW.Volume IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A conference edition needs a location and has no volume';
    END IF;
END$$

DELIMITER ;

-- 4. Sample data (inserted parents first)
INSERT INTO Institution (InstitutionID, Name) VALUES
  ('I001', 'Tsinghua University'), ('I002', 'Massachusetts Institute of Technology'),
  ('I003', 'Chinese Academy of Sciences'), ('I004', 'Technical University of Munich'),
  ('I005', 'Google (United States)'), ('I006', 'Hefei University of Technology'),
  ('I007', 'Hong Kong University of Science and Technology'), ('I008', 'Masaryk University'),
  ('I009', 'Simon Fraser University'), ('I010', 'Carnegie Mellon University'),
  ('I011', 'Chinese University of Hong Kong'), ('I012', 'Harbin Institute of Technology'),
  ('I013', 'South China Normal University'), ('I014', 'Zhejiang University'),
  ('I015', 'Beijing Institute of Technology'), ('I016', 'Hamad bin Khalifa University'),
  ('I017', 'Nanyang Technological University'), ('I018', 'Northeastern University'), ('I019', 'Tencent (China)'),
  ('I020', 'The University of Texas at Arlington'), ('I021', 'University of Pisa'),
  ('I022', 'Advanced Digital Sciences Center'),
  ('I023', 'Athena Research and Innovation Center In Information Communication & Knowledge Technologies'),
  ('I024', 'Australian National University'), ('I025', 'Centrum Wiskunde & Informatica'),
  ('I026', 'Foundation for Research and Technology Hellas'), ('I027', 'Guangdong University of Technology'),
  ('I028', 'Guangzhou University'), ('I029', 'Huawei Technologies (China)'), ('I030', 'IBM (United States)'),
  ('I031', 'KU Leuven'), ('I032', 'National and Kapodistrian University of Athens'), ('I033', 'Peking University'),
  ('I034', 'Roskilde University'), ('I035', 'South China University of Technology'),
  ('I036', 'State Key Laboratory of Information Security'),
  ('I037', 'University at Buffalo, State University of New York'),
  ('I038', 'University of California, Los Angeles'), ('I039', 'University of Illinois Urbana-Champaign'),
  ('I040', 'University of Toronto'), ('I041', 'Université Paris Descartes');

INSERT INTO Author (AuthorID, FullName) VALUES
  ('AU001', 'Ganzhao Yuan'), ('AU002', 'Zhenjie Zhang'), ('AU003', 'Marianne Winslett'), ('AU004', 'Xiaokui Xiao'),
  ('AU005', 'Yin Yang'), ('AU006', 'Zhifeng Hao'), ('AU007', 'Niccolò Meneghetti'), ('AU008', 'Oliver A. Kennedy'),
  ('AU009', 'Wolfgang Gatterbauer'), ('AU010', 'George Papadakis'), ('AU011', 'Vasilis Efthymiou'),
  ('AU012', 'Emmanouil Thanos'), ('AU013', 'Oktie Hassanzadeh'), ('AU014', 'Peter Christen'),
  ('AU015', 'Kangfei Zhao'), ('AU016', 'Jeffrey Xu Yu'), ('AU017', 'Qiyan Li'), ('AU018', 'Hao Zhang'),
  ('AU019', 'Yu Rong'), ('AU020', 'Quan Wang'), ('AU021', 'Zhendong Mao'), ('AU022', 'Bin Wang'),
  ('AU023', 'Li Guo'), ('AU024', 'Yao Tian'), ('AU025', 'Tingyun Yan'), ('AU026', 'Xi Zhao'),
  ('AU027', 'Kai Huang'), ('AU028', 'Xiaofang Zhou'), ('AU029', 'Xinyang Zhao'), ('AU030', 'Xuanhe Zhou'),
  ('AU031', 'Guoliang Li'), ('AU032', 'Matej Antol'), ('AU033', 'Jaroslav Oľha'), ('AU034', 'Terézia Slanináková'),
  ('AU035', 'Vlastislav Dohnal'), ('AU036', 'Run-An Wang'), ('AU037', 'Zhaonian Zou'), ('AU038', 'Ziqi Jing'),
  ('AU039', 'Dimitrios Skoutas'), ('AU040', 'Themis Palpanas'), ('AU041', 'Jia Zhu'), ('AU042', 'Zetao Zheng'),
  ('AU043', 'Min Yang'), ('AU044', 'Gabriel Pui Cheong Fung'), ('AU045', 'Yong Zhong Tang'),
  ('AU046', 'Qianjin Zhang'), ('AU047', 'Ronggui Wang'), ('AU048', 'Juan Yang'), ('AU049', 'Lixia Xue'),
  ('AU050', 'Dana Van Aken'), ('AU051', 'Andrew Pavlo'), ('AU052', 'Geoffrey J. Gordon'), ('AU053', 'Bohan Zhang'),
  ('AU054', 'Tim Kraska'), ('AU055', 'Alex Beutel'), ('AU056', 'Ed H.'), ('AU057', 'Jeffrey Dean'),
  ('AU058', 'Neoklis Polyzotis'), ('AU059', 'Vikram Nathan'), ('AU060', 'Jialin Ding'),
  ('AU061', 'Mohammad Alizadeh'), ('AU062', 'Pengfei Li'), ('AU063', 'Hua Cai Lu'), ('AU064', 'Qian Sheng Zheng'),
  ('AU065', 'Long Yang'), ('AU066', 'Gang Pan'), ('AU067', 'Ryan Marcus'), ('AU068', 'Parimarjan Negi'),
  ('AU069', 'Hongzi Mao'), ('AU070', 'Nesime Tatbul'), ('AU071', 'Viktor Leis'), ('AU072', 'Andrey Gubichev'),
  ('AU073', 'Atanas Mirchev'), ('AU074', 'Peter A. Boncz'), ('AU075', 'Alfons Kemper'),
  ('AU076', 'Thomas Neumann'), ('AU077', 'Ji Sun'), ('AU078', 'Paolo Ferragina'), ('AU079', 'Giorgio Vinciguerra'),
  ('AU080', 'Xiaoying Wang'), ('AU081', 'Changbo Qu'), ('AU082', 'Weiyuan Wu'), ('AU083', 'Jiannan Wang'),
  ('AU084', 'Qingqing Zhou'), ('AU085', 'Jiacheng Wu'), ('AU086', 'Yong Zhang'), ('AU087', 'Shimin Chen'),
  ('AU088', 'Jin Wang'), ('AU089', 'Yu Chen'), ('AU090', 'Chunxiao Xing'),
  ('AU091', 'Saravanan Thirumuruganathan'), ('AU092', 'Shohedul Hasan'), ('AU093', 'Nick Koudas'),
  ('AU094', 'Gautam Das'), ('AU095', 'Xiang Yu'), ('AU096', 'Chengliang Chai'), ('AU097', 'Nan Tang'),
  ('AU098', 'Jintao Zhang'), ('AU099', 'Chao Zhang');

INSERT INTO Affiliation (AuthorID, InstitutionID, StartDate, EndDate) VALUES
  ('AU001', 'I035', '2013-09-01', NULL), ('AU002', 'I022', '2012-09-01', NULL),
  ('AU003', 'I039', '2012-09-01', NULL), ('AU004', 'I017', '2013-09-01', NULL),
  ('AU005', 'I016', '2013-09-01', NULL), ('AU006', 'I027', '2011-09-01', NULL),
  ('AU007', 'I018', '2016-09-01', NULL), ('AU008', 'I037', '2016-09-01', NULL),
  ('AU009', 'I018', '2016-09-01', NULL), ('AU010', 'I032', '2018-09-01', NULL),
  ('AU011', 'I026', '2019-09-01', NULL), ('AU012', 'I031', '2018-09-01', NULL),
  ('AU013', 'I030', '2020-09-01', NULL), ('AU014', 'I024', '2019-09-01', NULL),
  ('AU015', 'I015', '2021-09-01', NULL), ('AU016', 'I011', '2020-09-01', NULL),
  ('AU017', 'I011', '2020-09-01', NULL), ('AU018', 'I029', '2020-09-01', NULL),
  ('AU019', 'I019', '2020-09-01', NULL), ('AU020', 'I036', '2014-09-01', NULL),
  ('AU021', 'I003', '2013-09-01', NULL), ('AU022', 'I003', '2015-09-01', NULL),
  ('AU023', 'I003', '2014-09-01', NULL), ('AU024', 'I007', '2020-09-01', NULL),
  ('AU025', 'I028', '2019-09-01', NULL), ('AU026', 'I007', '2020-09-01', NULL),
  ('AU027', 'I007', '2020-09-01', NULL), ('AU028', 'I007', '2018-09-01', NULL),
  ('AU029', 'I001', '2020-09-01', NULL), ('AU030', 'I001', '2019-09-01', NULL),
  ('AU031', 'I001', '2016-09-01', NULL), ('AU032', 'I008', '2018-09-01', NULL),
  ('AU033', 'I008', '2018-09-01', NULL), ('AU034', 'I008', '2017-09-01', NULL),
  ('AU035', 'I008', '2019-09-01', NULL), ('AU036', 'I012', '2019-09-01', NULL),
  ('AU037', 'I012', '2020-09-01', NULL), ('AU038', 'I012', '2021-09-01', NULL),
  ('AU039', 'I023', '2018-09-01', NULL), ('AU040', 'I041', '2017-09-01', NULL),
  ('AU041', 'I013', '2015-09-01', NULL), ('AU042', 'I013', '2016-09-01', NULL),
  ('AU043', 'I003', '2017-09-01', NULL), ('AU044', 'I011', '2015-09-01', NULL),
  ('AU045', 'I013', '2017-09-01', NULL), ('AU046', 'I006', '2017-09-01', NULL),
  ('AU047', 'I006', '2018-09-01', NULL), ('AU048', 'I006', '2016-09-01', NULL),
  ('AU049', 'I006', '2018-09-01', NULL), ('AU050', 'I010', '2014-09-01', NULL),
  ('AU051', 'I010', '2013-09-01', NULL), ('AU052', 'I010', '2013-09-01', NULL),
  ('AU053', 'I033', '2015-09-01', NULL), ('AU054', 'I002', '2014-09-01', NULL),
  ('AU055', 'I005', '2016-09-01', NULL), ('AU056', 'I005', '2014-09-01', NULL),
  ('AU057', 'I005', '2016-09-01', NULL), ('AU058', 'I005', '2014-09-01', NULL),
  ('AU059', 'I002', '2018-09-01', NULL), ('AU060', 'I002', '2017-09-01', NULL),
  ('AU061', 'I002', '2016-09-01', NULL), ('AU062', 'I014', '2018-09-01', NULL),
  ('AU063', 'I034', '2018-09-01', NULL), ('AU064', 'I017', '2016-09-01', NULL),
  ('AU065', 'I014', '2017-09-01', NULL), ('AU066', 'I014', '2016-09-01', NULL),
  ('AU067', 'I002', '2017-09-01', NULL), ('AU068', 'I002', '2018-09-01', NULL),
  ('AU069', 'I002', '2018-09-01', NULL), ('AU070', 'I002', '2017-09-01', NULL),
  ('AU071', 'I004', '2012-09-01', NULL), ('AU072', 'I004', '2012-09-01', NULL),
  ('AU073', 'I004', '2013-09-01', NULL), ('AU074', 'I025', '2013-09-01', NULL),
  ('AU075', 'I004', '2011-09-01', NULL), ('AU076', 'I004', '2013-09-01', NULL),
  ('AU077', 'I001', '2015-09-01', NULL), ('AU078', 'I021', '2016-09-01', NULL),
  ('AU079', 'I021', '2017-09-01', NULL), ('AU080', 'I009', '2017-09-01', NULL),
  ('AU081', 'I009', '2018-09-01', NULL), ('AU082', 'I009', '2017-09-01', NULL),
  ('AU083', 'I009', '2018-09-01', NULL), ('AU084', 'I019', '2017-09-01', NULL),
  ('AU085', 'I001', '2017-09-01', NULL), ('AU086', 'I001', '2019-09-01', NULL),
  ('AU087', 'I003', '2018-09-01', NULL), ('AU088', 'I038', '2019-09-01', NULL),
  ('AU089', 'I001', '2018-09-01', NULL), ('AU090', 'I001', '2017-09-01', NULL),
  ('AU091', 'I016', '2017-09-01', NULL), ('AU092', 'I020', '2016-09-01', NULL),
  ('AU093', 'I040', '2016-09-01', NULL), ('AU094', 'I020', '2018-09-01', NULL),
  ('AU095', 'I001', '2016-09-01', NULL), ('AU096', 'I001', '2016-09-01', '2023-08-31'),
  ('AU096', 'I015', '2023-09-01', NULL), ('AU098', 'I001', '2019-09-01', NULL),
  ('AU099', 'I001', '2021-09-01', NULL);

INSERT INTO SubjectArea (AreaID, Name) VALUES
  ('SA001', 'Advanced Database Systems and Queries'), ('SA002', 'Data Management and Algorithms'),
  ('SA003', 'Data Mining Algorithms and Applications'), ('SA004', 'Topic Modeling'),
  ('SA005', 'Algorithms and Data Compression'), ('SA006', 'Advanced Graph Neural Networks'),
  ('SA007', 'Cloud Computing and Resource Management'), ('SA008', 'Recommender Systems and Techniques'),
  ('SA009', 'Advanced Image and Video Retrieval Techniques'), ('SA010', 'Data Quality and Management'),
  ('SA011', 'Privacy-Preserving Technologies in Data'), ('SA012', 'Software System Performance and Reliability'),
  ('SA013', 'Bayesian Modeling and Causal Inference'), ('SA014', 'Cloud Data Security Solutions'),
  ('SA015', 'Graph Theory and Algorithms'), ('SA016', 'Image Retrieval and Classification Techniques'),
  ('SA017', 'Machine Learning and Data Classification');

INSERT INTO Keyword (KeywordID, Term) VALUES
  ('K001', 'cardinality estimation'), ('K002', 'learned indexes'), ('K003', 'query optimization'),
  ('K004', 'knowledge graph embedding'), ('K005', 'entity resolution'), ('K006', 'metric spaces'),
  ('K007', 'range queries'), ('K008', 'similarity search'), ('K009', 'active learning'),
  ('K010', 'aggregate queries'), ('K011', 'analytical databases'), ('K012', 'approximate differential privacy'),
  ('K013', 'approximate query processing'), ('K014', 'b-trees'), ('K015', 'bayesian belief updating'),
  ('K016', 'bayesian optimization'), ('K017', 'bipartite matching'), ('K018', 'blocking'),
  ('K019', 'data uncertainty'), ('K020', 'database query optimization'), ('K021', 'deep generative models'),
  ('K022', 'deep metric learning'), ('K023', 'deep reinforcement learning'), ('K024', 'differential privacy'),
  ('K025', 'dynamic data structures'), ('K026', 'entity embeddings'), ('K027', 'feature selection'),
  ('K028', 'filtering'), ('K029', 'graph convolutional networks'), ('K030', 'in-memory index'),
  ('K031', 'index structures'), ('K032', 'join order'), ('K033', 'join queries'),
  ('K034', 'large-scale machine learning'), ('K035', 'link prediction'), ('K036', 'lipps'),
  ('K037', 'model selection'), ('K038', 'one-to-one matching'), ('K039', 'probabilistic databases'),
  ('K040', 'production deployment'), ('K041', 'query processing'), ('K042', 'range scans'),
  ('K043', 'relation embeddings'), ('K044', 'semi-supervised learning'), ('K045', 'spatial indexing'),
  ('K046', 'spatial query processing'), ('K047', 'subgraph counting'), ('K048', 'tail latency'),
  ('K049', 'thompson sampling'), ('K050', 'time'), ('K051', 'transfer learning'), ('K052', 'tree-based models'),
  ('K053', 'tree-lstm'), ('K054', 'unstructured data');

INSERT INTO Venue (VenueID, Name, VenueType) VALUES
  ('V001', 'ACM Transactions on Database Systems', 'J'), ('V002', 'The VLDB Journal', 'J'),
  ('V003', 'Journal of Machine Learning Research', 'J'),
  ('V004', 'IEEE Transactions on Knowledge and Data Engineering', 'J'), ('V005', 'Information Systems', 'J'),
  ('V006', 'Artificial Intelligence', 'J'), ('V007', 'ACM Computing Surveys', 'J'),
  ('V008', 'Journal of Information Science', 'J'), ('V009', 'Data Mining and Knowledge Discovery', 'J'),
  ('V010', 'Bioinformatics', 'J'), ('V011', 'Scientometrics', 'J'), ('V012', 'Journal of Web Semantics', 'J'),
  ('V013', 'Neural Computation', 'J'), ('V014', 'Knowledge-Based Systems', 'J'),
  ('V015', 'Pattern Recognition', 'J'), ('V016', 'ACM SIGMOD International Conference on Management of Data', 'C'),
  ('V017', 'International Conference on Very Large Data Bases', 'C'),
  ('V018', 'IEEE International Conference on Data Engineering', 'C'),
  ('V019', 'ACM SIGKDD Conference on Knowledge Discovery and Data Mining', 'C'),
  ('V020', 'Conference on Neural Information Processing Systems', 'C'),
  ('V021', 'International Conference on Machine Learning', 'C'),
  ('V022', 'Annual Meeting of the Association for Computational Linguistics', 'C'),
  ('V023', 'The Web Conference', 'C'),
  ('V024', 'ACM SIGIR Conference on Research and Development in Information Retrieval', 'C'),
  ('V025', 'ACM Conference on Information and Knowledge Management', 'C'),
  ('V026', 'Conference on Computer Vision and Pattern Recognition', 'C'),
  ('V027', 'AAAI Conference on Artificial Intelligence', 'C'),
  ('V028', 'International Joint Conference on Artificial Intelligence', 'C'),
  ('V029', 'Empirical Methods in Natural Language Processing', 'C'),
  ('V030', 'International Conference on Learning Representations', 'C');

INSERT INTO Journal (VenueID, VenueType, ISSN) VALUES
  ('V001', 'J', '0362-5915'), ('V002', 'J', '0949-877X'), ('V003', 'J', '1532-4435'), ('V004', 'J', '1041-4347'),
  ('V005', 'J', '0306-4379'), ('V006', 'J', '0004-3702'), ('V007', 'J', '0360-0300'), ('V008', 'J', '0165-5515'),
  ('V009', 'J', '1384-5810'), ('V010', 'J', '1367-4803'), ('V011', 'J', '0138-9130'), ('V012', 'J', '1570-8268'),
  ('V013', 'J', '0899-7667'), ('V014', 'J', '0950-7051'), ('V015', 'J', '0031-3203');

INSERT INTO Conference (VenueID, VenueType, Acronym) VALUES
  ('V016', 'C', 'SIGMOD'), ('V017', 'C', 'VLDB'), ('V018', 'C', 'ICDE'), ('V019', 'C', 'KDD'),
  ('V020', 'C', 'NeurIPS'), ('V021', 'C', 'ICML'), ('V022', 'C', 'ACL'), ('V023', 'C', 'WWW'),
  ('V024', 'C', 'SIGIR'), ('V025', 'C', 'CIKM'), ('V026', 'C', 'CVPR'), ('V027', 'C', 'AAAI'),
  ('V028', 'C', 'IJCAI'), ('V029', 'C', 'EMNLP'), ('V030', 'C', 'ICLR');

INSERT INTO Edition (VenueID, EditionNumber, PubYear, Volume, Location) VALUES
  ('V001', 1, 2015, 40, NULL), ('V001', 2, 2018, 43, NULL), ('V002', 1, 2023, 32, NULL),
  ('V003', 1, 2019, 20, NULL), ('V004', 1, 2017, 29, NULL), ('V004', 2, 2022, 35, NULL),
  ('V004', 3, 2023, 35, NULL), ('V005', 1, 2021, 100, NULL), ('V005', 2, 2023, 117, NULL),
  ('V006', 1, 2019, 280, NULL), ('V007', 1, 2020, 53, NULL), ('V008', 1, 2019, 46, NULL),
  ('V009', 1, 2019, 34, NULL), ('V010', 1, 2019, 36, NULL), ('V011', 1, 2019, 121, NULL),
  ('V012', 1, 2019, 59, NULL), ('V013', 1, 2019, 31, NULL), ('V014', 1, 2020, 212, NULL),
  ('V015', 1, 2019, 90, NULL), ('V016', 1, 2017, NULL, 'Chicago'), ('V016', 2, 2018, NULL, 'Houston'),
  ('V016', 3, 2020, NULL, 'Portland'), ('V016', 4, 2021, NULL, 'Xi''an'), ('V017', 1, 2015, NULL, 'Kohala Coast'),
  ('V017', 2, 2019, NULL, 'Los Angeles'), ('V017', 3, 2020, NULL, 'Tokyo'), ('V017', 4, 2021, NULL, 'Copenhagen'),
  ('V018', 1, 2020, NULL, 'Dallas'), ('V018', 2, 2023, NULL, 'Anaheim'), ('V019', 1, 2019, NULL, 'Anchorage'),
  ('V020', 1, 2019, NULL, 'Vancouver'), ('V021', 1, 2019, NULL, 'Long Beach'), ('V022', 1, 2019, NULL, 'Florence'),
  ('V023', 1, 2019, NULL, 'San Francisco'), ('V024', 1, 2019, NULL, 'Paris'), ('V025', 1, 2019, NULL, 'Beijing'),
  ('V026', 1, 2019, NULL, 'Long Beach'), ('V027', 1, 2019, NULL, 'Honolulu'), ('V028', 1, 2019, NULL, 'Macao'),
  ('V029', 1, 2019, NULL, 'Hong Kong'), ('V030', 1, 2019, NULL, 'New Orleans');

INSERT INTO Article (ArticleID, Title, DOI, Abstract, StartPage, VenueID, EditionNumber) VALUES
  ('AR001', 'Optimizing Batch Linear Queries under Exact and Approximate Differential Privacy', '10.1145/2699501', 'Differential privacy is a promising privacy-preserving paradigm for statistical query processing over sensitive data. It works by injecting random noise into each query result such that it is provably hard for the adversary to infer the presence or absence of any individual record from the published noisy results.', 1, 'V001', 1),
  ('AR002', 'Learning From Query-Answers', '10.1145/3277503', 'Tuple-independent and disjoint-independent probabilistic databases (TI- and DI-PDBs) represent uncertain data in a factorized form as a product of independent random variables that represent either tuples (TI-PDBs) or sets of tuples (DI-PDBs).', 1, 'V001', 2),
  ('AR003', 'An analysis of one-to-one matching algorithms for entity resolution', '10.1007/s00778-023-00791-3', 'Abstract Entity resolution (ER) is the task of finding records that refer to the same real-world entities. A common scenario, which we refer to as Clean-Clean ER, is to resolve records across two clean sources (i.e., they are duplicate-free and contain one record per entity).', 1369, 'V002', 1),
  ('AR004', 'Learned sketch for subgraph counting: a holistic approach', '10.1007/s00778-023-00781-5', 'Proposes a learned sketch for subgraph counting that is designed holistically for the whole counting task.', 937, 'V002', 1),
  ('AR005', 'Knowledge Graph Embedding: A Survey of Approaches and Applications', '10.1109/tkde.2017.2754499', 'Knowledge graph (KG) embedding is to embed components of a KG including entities and relations into continuous vector spaces, so as to simplify the manipulation while preserving the inherent structure of the KG.', 2724, 'V004', 1),
  ('AR006', 'A Learned Index for Exact Similarity Search in Metric Spaces', '10.1109/tkde.2022.3206441', 'Indexing is an effective way to support efficient query processing in large databases. Recently the concept oflearned index, which replaces or complements traditional index structures with machine learning models, has been actively explored to reduce storage and search costs.', 7624, 'V004', 2),
  ('AR007', 'Automatic Database Knob Tuning: A Survey', '10.1109/tkde.2023.3266893', 'Knob tuning plays an important role in database optimization, which tunes knob settings to optimize the database performance or improve resource utilization. However, there are several common challenges in knob tuning.', 12470, 'V004', 3),
  ('AR008', 'Learned Metric Index — Proposition of learned indexing for unstructured data', '10.1016/j.is.2021.101774', 'Proposes learned indexing for unstructured data in metric spaces, replacing pivot-based structures with machine-learned models.', 101774, 'V005', 1),
  ('AR009', 'Cardinality estimation via learned dynamic sample selection', '10.1016/j.is.2023.102252', 'Estimates query cardinalities by learning which samples to select dynamically for each query.', 102252, 'V005', 2),
  ('AR010', 'Blocking and Filtering Techniques for Entity Resolution', '10.1145/3377455', 'Entity Resolution (ER), a core task of Data Integration, detects different entity profiles that correspond to the same real-world object. Due to its inherently quadratic complexity, a series of techniques accelerate it so that it scales to voluminous data.', 1, 'V007', 1),
  ('AR011', 'A semi-supervised model for knowledge graph embedding', '10.1007/s10618-019-00653-z', 'Describes a semi-supervised model that learns knowledge graph embeddings from both labelled triples and unlabelled data.', 1, 'V009', 1),
  ('AR012', 'Knowledge graph embedding by translating in time domain space for link prediction', '10.1016/j.knosys.2020.106564', 'Proposes a knowledge graph embedding that translates entities in a time domain space to improve link prediction.', 106564, 'V014', 1),
  ('AR013', 'Automatic Database Management System Tuning Through Large-scale Machine Learning', '10.1145/3035918.3064029', 'Database management system (DBMS) configuration tuning is an essential aspect of any data-intensive application effort.', 1009, 'V016', 1),
  ('AR014', 'The Case for Learned Index Structures', '10.1145/3183713.3196909', 'Indexes are models: a \\btree-Index can be seen as a model to map a key to the position of a record within a sorted array, a Hash-Index as a model to map a key to a position of a record within an unsorted array, and a BitMap-Index as a model to indicate if a data record exists or not.', 489, 'V016', 2),
  ('AR015', 'Learning Multi-Dimensional Indexes', '10.1145/3318464.3380579', 'Scanning and filtering over multi-dimensional tables are key operations in modern analytical database engines. To optimize the performance of these operations, databases often create clustered indexes over a single dimension or multi-dimensional indexes such as R-Trees, or use complex sort orders (e.g., Z-ordering).', 985, 'V016', 3),
  ('AR016', 'LISA: A Learned Index Structure for Spatial Data', '10.1145/3318464.3389703', 'In spatial query processing, the popular index R-tree may incur large storage consumption and high IO cost. Inspired by the recent learned index [17] that replaces B-tree with machine learning models, we study an analogy problem for spatial data.', 2119, 'V016', 3),
  ('AR017', 'Bao: Making Learned Query Optimization Practical', '10.1145/3448016.3452838', 'Recent efforts applying machine learning techniques to query optimization have shown few practical gains due to substantive training overhead, inability to adapt to changes, and poor tail performance.', 1275, 'V016', 4),
  ('AR018', 'How good are query optimizers, really?', '10.14778/2850583.2850594', 'Finding a good join order is crucial for query performance. In this paper, we introduce the Join Order Benchmark (JOB) and experimentally revisit the main components in the classic query optimizer architecture using a complex, real-world data set and realistic multi-join queries.', 204, 'V017', 1),
  ('AR019', 'An end-to-end learning-based cost estimator', '10.14778/3368289.3368296', 'Cost and cardinality estimation is vital to query optimizer, which can guide the query plan selection. However traditional empirical cost and cardinality estimation techniques cannot provide high-quality estimation, because they may not effectively capture the correlation between multiple tables.', 307, 'V017', 2),
  ('AR020', 'The PGM-index', '10.14778/3389133.3389135', 'We present the first learned index that supports predecessor, range queries and updates within provably efficient time and space bounds in the worst case. In the (static) context of just predecessor and range queries these bounds turn out to be optimal.', 1162, 'V017', 3),
  ('AR021', 'Are we ready for learned cardinality estimation?', '10.14778/3461535.3461552', 'Cardinality estimation is a fundamental but long unresolved problem in query optimization. Recently, multiple papers from different research groups consistently report that learned models have the potential to replace existing cardinality estimators.', 1640, 'V017', 4),
  ('AR022', 'Updatable learned index with precise positions', '10.14778/3457390.3457393', 'Index plays an essential role in modern database engines to accelerate the query processing. The new paradigm of "learned index" has significantly changed the way of designing index structures in DBMS.', 1276, 'V017', 4),
  ('AR023', 'Approximate Query Processing for Data Exploration using Deep Generative Models', '10.1109/icde48307.2020.00117', 'Data is generated at an unprecedented rate surpassing our ability to analyze them. The database community has pioneered many novel techniques for Approximate Query Processing (AQP) that could give approximate results in a fraction of time needed for computing exact results.', 1309, 'V018', 1),
  ('AR024', 'Reinforcement Learning with Tree-LSTM for Join Order Selection', '10.1109/icde48307.2020.00116', 'Join order selection (JOS) - the problem of finding the optimal join order for an SQL query - is a primary focus of database query optimizers. The problem is hard due to its large solution space.', 1297, 'V018', 1),
  ('AR025', 'AutoCE: An Accurate and Efficient Model Advisor for Learned Cardinality Estimation', '10.1109/icde55515.2023.00201', 'Cardinality estimation (CE) plays a crucial role in many database-related tasks such as query generation, cost estimation, and join ordering. Lately, we have witnessed the emergence of numerous learned CE models.', 2621, 'V018', 2);

INSERT INTO Writes (ArticleID, AuthorID, Position) VALUES
  ('AR001', 'AU001', 1), ('AR001', 'AU002', 2), ('AR001', 'AU003', 3), ('AR001', 'AU004', 4),
  ('AR001', 'AU005', 5), ('AR001', 'AU006', 6), ('AR002', 'AU007', 1), ('AR002', 'AU008', 2),
  ('AR002', 'AU009', 3), ('AR003', 'AU010', 1), ('AR003', 'AU011', 2), ('AR003', 'AU012', 3),
  ('AR003', 'AU013', 4), ('AR003', 'AU014', 5), ('AR004', 'AU015', 1), ('AR004', 'AU016', 2),
  ('AR004', 'AU017', 3), ('AR004', 'AU018', 4), ('AR004', 'AU019', 5), ('AR005', 'AU020', 1),
  ('AR005', 'AU021', 2), ('AR005', 'AU022', 3), ('AR005', 'AU023', 4), ('AR006', 'AU024', 1),
  ('AR006', 'AU025', 2), ('AR006', 'AU026', 3), ('AR006', 'AU027', 4), ('AR006', 'AU028', 5),
  ('AR007', 'AU029', 1), ('AR007', 'AU030', 2), ('AR007', 'AU031', 3), ('AR008', 'AU032', 1),
  ('AR008', 'AU033', 2), ('AR008', 'AU034', 3), ('AR008', 'AU035', 4), ('AR009', 'AU036', 1),
  ('AR009', 'AU037', 2), ('AR009', 'AU038', 3), ('AR010', 'AU010', 1), ('AR010', 'AU039', 2),
  ('AR010', 'AU012', 3), ('AR010', 'AU040', 4), ('AR011', 'AU041', 1), ('AR011', 'AU042', 2),
  ('AR011', 'AU043', 3), ('AR011', 'AU044', 4), ('AR011', 'AU045', 5), ('AR012', 'AU046', 1),
  ('AR012', 'AU047', 2), ('AR012', 'AU048', 3), ('AR012', 'AU049', 4), ('AR013', 'AU050', 1),
  ('AR013', 'AU051', 2), ('AR013', 'AU052', 3), ('AR013', 'AU053', 4), ('AR014', 'AU054', 1),
  ('AR014', 'AU055', 2), ('AR014', 'AU056', 3), ('AR014', 'AU057', 4), ('AR014', 'AU058', 5),
  ('AR015', 'AU059', 1), ('AR015', 'AU060', 2), ('AR015', 'AU061', 3), ('AR015', 'AU054', 4),
  ('AR016', 'AU062', 1), ('AR016', 'AU063', 2), ('AR016', 'AU064', 3), ('AR016', 'AU065', 4),
  ('AR016', 'AU066', 5), ('AR017', 'AU067', 1), ('AR017', 'AU068', 2), ('AR017', 'AU069', 3),
  ('AR017', 'AU070', 4), ('AR017', 'AU061', 5), ('AR017', 'AU054', 6), ('AR018', 'AU071', 1),
  ('AR018', 'AU072', 2), ('AR018', 'AU073', 3), ('AR018', 'AU074', 4), ('AR018', 'AU075', 5),
  ('AR018', 'AU076', 6), ('AR019', 'AU077', 1), ('AR019', 'AU031', 2), ('AR020', 'AU078', 1),
  ('AR020', 'AU079', 2), ('AR021', 'AU080', 1), ('AR021', 'AU081', 2), ('AR021', 'AU082', 3),
  ('AR021', 'AU083', 4), ('AR021', 'AU084', 5), ('AR022', 'AU085', 1), ('AR022', 'AU086', 2),
  ('AR022', 'AU087', 3), ('AR022', 'AU088', 4), ('AR022', 'AU089', 5), ('AR022', 'AU090', 6),
  ('AR023', 'AU091', 1), ('AR023', 'AU092', 2), ('AR023', 'AU093', 3), ('AR023', 'AU094', 4),
  ('AR024', 'AU095', 1), ('AR024', 'AU031', 2), ('AR024', 'AU096', 3), ('AR024', 'AU097', 4),
  ('AR025', 'AU098', 1), ('AR025', 'AU099', 2), ('AR025', 'AU031', 3), ('AR025', 'AU096', 4);

INSERT INTO Citation (CitingArticleID, CitedArticleID) VALUES
  ('AR003', 'AR010'), ('AR004', 'AR018'), ('AR004', 'AR019'), ('AR004', 'AR023'), ('AR006', 'AR014'),
  ('AR006', 'AR015'), ('AR006', 'AR016'), ('AR007', 'AR013'), ('AR007', 'AR017'), ('AR007', 'AR018'),
  ('AR007', 'AR019'), ('AR007', 'AR024'), ('AR008', 'AR014'), ('AR008', 'AR015'), ('AR008', 'AR020'),
  ('AR009', 'AR018'), ('AR009', 'AR021'), ('AR011', 'AR005'), ('AR012', 'AR005'), ('AR017', 'AR014'),
  ('AR017', 'AR018'), ('AR017', 'AR019'), ('AR019', 'AR018'), ('AR020', 'AR014'), ('AR021', 'AR014'),
  ('AR021', 'AR018'), ('AR021', 'AR019'), ('AR021', 'AR023'), ('AR021', 'AR024'), ('AR022', 'AR013'),
  ('AR022', 'AR014'), ('AR022', 'AR015'), ('AR022', 'AR020'), ('AR023', 'AR014'), ('AR024', 'AR018'),
  ('AR024', 'AR019'), ('AR025', 'AR019'), ('AR025', 'AR021'), ('AR025', 'AR024');

INSERT INTO Classified (ArticleID, AreaID) VALUES
  ('AR001', 'SA011'), ('AR001', 'SA014'), ('AR001', 'SA001'), ('AR002', 'SA001'), ('AR002', 'SA002'),
  ('AR002', 'SA013'), ('AR003', 'SA010'), ('AR003', 'SA001'), ('AR003', 'SA004'), ('AR004', 'SA015'),
  ('AR004', 'SA001'), ('AR004', 'SA003'), ('AR005', 'SA006'), ('AR005', 'SA004'), ('AR005', 'SA008'),
  ('AR006', 'SA002'), ('AR006', 'SA001'), ('AR006', 'SA009'), ('AR007', 'SA001'), ('AR007', 'SA007'),
  ('AR007', 'SA012'), ('AR008', 'SA009'), ('AR008', 'SA002'), ('AR008', 'SA016'), ('AR009', 'SA001'),
  ('AR009', 'SA002'), ('AR009', 'SA003'), ('AR010', 'SA010'), ('AR010', 'SA001'), ('AR010', 'SA004'),
  ('AR011', 'SA006'), ('AR011', 'SA004'), ('AR011', 'SA008'), ('AR012', 'SA006'), ('AR012', 'SA004'),
  ('AR012', 'SA008'), ('AR013', 'SA001'), ('AR013', 'SA007'), ('AR013', 'SA012'), ('AR014', 'SA001'),
  ('AR014', 'SA005'), ('AR014', 'SA002'), ('AR015', 'SA001'), ('AR015', 'SA002'), ('AR015', 'SA005'),
  ('AR016', 'SA002'), ('AR016', 'SA001'), ('AR016', 'SA003'), ('AR017', 'SA001'), ('AR017', 'SA002'),
  ('AR017', 'SA007'), ('AR018', 'SA001'), ('AR018', 'SA002'), ('AR018', 'SA003'), ('AR019', 'SA001'),
  ('AR019', 'SA002'), ('AR019', 'SA003'), ('AR020', 'SA005'), ('AR020', 'SA001'), ('AR020', 'SA002'),
  ('AR021', 'SA001'), ('AR021', 'SA002'), ('AR021', 'SA003'), ('AR022', 'SA001'), ('AR022', 'SA005'),
  ('AR022', 'SA002'), ('AR023', 'SA001'), ('AR023', 'SA002'), ('AR023', 'SA011'), ('AR024', 'SA001'),
  ('AR024', 'SA002'), ('AR024', 'SA003'), ('AR025', 'SA001'), ('AR025', 'SA002'), ('AR025', 'SA017');

INSERT INTO HasKeyword (ArticleID, KeywordID) VALUES
  ('AR001', 'K024'), ('AR001', 'K012'), ('AR001', 'K041'), ('AR002', 'K039'), ('AR002', 'K019'), ('AR002', 'K015'),
  ('AR003', 'K005'), ('AR003', 'K038'), ('AR003', 'K017'), ('AR004', 'K047'), ('AR004', 'K009'), ('AR004', 'K001'),
  ('AR005', 'K004'), ('AR005', 'K026'), ('AR005', 'K043'), ('AR006', 'K002'), ('AR006', 'K008'), ('AR006', 'K006'),
  ('AR007', 'K027'), ('AR007', 'K016'), ('AR007', 'K051'), ('AR008', 'K008'), ('AR008', 'K006'), ('AR008', 'K054'),
  ('AR009', 'K001'), ('AR009', 'K003'), ('AR009', 'K033'), ('AR010', 'K005'), ('AR010', 'K018'), ('AR010', 'K028'),
  ('AR011', 'K004'), ('AR011', 'K044'), ('AR011', 'K029'), ('AR012', 'K004'), ('AR012', 'K035'), ('AR012', 'K050'),
  ('AR013', 'K034'), ('AR014', 'K002'), ('AR014', 'K031'), ('AR014', 'K014'), ('AR015', 'K030'), ('AR015', 'K042'),
  ('AR015', 'K011'), ('AR016', 'K002'), ('AR016', 'K045'), ('AR016', 'K046'), ('AR017', 'K003'), ('AR017', 'K049'),
  ('AR017', 'K048'), ('AR018', 'K003'), ('AR018', 'K032'), ('AR018', 'K001'), ('AR019', 'K001'), ('AR019', 'K003'),
  ('AR019', 'K052'), ('AR020', 'K002'), ('AR020', 'K007'), ('AR020', 'K025'), ('AR021', 'K001'), ('AR021', 'K003'),
  ('AR021', 'K040'), ('AR022', 'K002'), ('AR022', 'K036'), ('AR022', 'K007'), ('AR023', 'K013'), ('AR023', 'K021'),
  ('AR023', 'K010'), ('AR024', 'K020'), ('AR024', 'K023'), ('AR024', 'K053'), ('AR025', 'K001'), ('AR025', 'K037'),
  ('AR025', 'K022');

INSERT INTO User (UserID, Username, Email, PasswordHash, Role) VALUES
  ('U001', 'admin', 'admin@example.edu', '$2a$10$LR713.pP6dm5BdukuB7uMu8AozU7rWH6UbOSuAyX.Hgdi.P7QX2jG', 'admin'),
  ('U002', 'author1', 'author1@example.edu', '$2a$10$9JiwpkjBEmIeLZjVRP38m.nALr/BgvC01TVBNBy9nYle7IAl3herS', 'author'),
  ('U003', 'phuong_an', 'phuong_an@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U004', 'nguyen_bao', 'nguyen_bao@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U005', 'khanh_pl', 'khanh_pl@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U006', 'han_pg', 'han_pg@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U007', 'nhat_nv', 'nhat_nv@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U008', 'vo_bao', 'vo_bao@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U009', 'thang_hm', 'thang_hm@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U010', 'tai_nk', 'tai_nk@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U011', 'dr_smith', 'dr_smith@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U012', 'prof_lee', 'prof_lee@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U013', 'grad_student1', 'grad_student1@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U014', 'lib_admin', 'lib_admin@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U015', 'reviewer42', 'reviewer42@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader'),
  ('U016', 'data_nerd', 'data_nerd@example.edu', '$2a$10$Y.L69oCVWu.Q49rTWTs1reqJ3fsE2ItPFJFZ824LB68vDCuiOJQsu', 'reader');

INSERT INTO ReadingList (UserID, ListName, CreatedDate) VALUES
  ('U001', 'Learned index papers', '2026-01-01 09:00:00'),
  ('U002', 'Cardinality estimation', '2026-02-02 09:00:00'), ('U003', 'Thesis references', '2026-03-03 09:00:00'),
  ('U004', 'To read', '2026-04-04 09:00:00'), ('U005', 'Query optimizer reading', '2026-05-05 09:00:00'),
  ('U006', 'Entity resolution', '2026-06-06 09:00:00'), ('U007', 'Benchmarks', '2026-07-07 09:00:00'),
  ('U008', 'Related work', '2026-08-08 09:00:00'), ('U009', 'Knowledge graphs', '2026-09-09 09:00:00'),
  ('U010', 'Tuning and advisors', '2026-01-10 09:00:00'), ('U011', 'Surveys', '2026-02-11 09:00:00'),
  ('U012', 'Database internals', '2026-03-12 09:00:00'), ('U013', 'Bloom filters', '2026-04-13 09:00:00'),
  ('U014', 'Reproduce results', '2026-05-14 09:00:00'), ('U015', 'Course project', '2026-06-15 09:00:00');

INSERT INTO `Contains` (UserID, ListName, ArticleID, AddedDate) VALUES
  ('U001', 'Learned index papers', 'AR014', '2026-01-01 12:00:00'),
  ('U001', 'Learned index papers', 'AR008', '2026-01-01 19:13:00'),
  ('U002', 'Cardinality estimation', 'AR009', '2026-02-03 02:26:00'),
  ('U002', 'Cardinality estimation', 'AR021', '2026-02-03 09:39:00'),
  ('U003', 'Thesis references', 'AR011', '2026-03-04 16:52:00'),
  ('U003', 'Thesis references', 'AR008', '2026-03-04 23:05:00'),
  ('U004', 'To read', 'AR009', '2026-04-06 06:18:00'), ('U004', 'To read', 'AR002', '2026-04-06 13:31:00'),
  ('U005', 'Query optimizer reading', 'AR018', '2026-05-07 20:44:00'),
  ('U005', 'Query optimizer reading', 'AR017', '2026-05-08 03:57:00'),
  ('U006', 'Entity resolution', 'AR010', '2026-06-09 10:10:00'),
  ('U006', 'Entity resolution', 'AR003', '2026-06-09 17:23:00'),
  ('U007', 'Benchmarks', 'AR023', '2026-07-11 00:36:00'), ('U007', 'Benchmarks', 'AR014', '2026-07-11 07:49:00'),
  ('U008', 'Related work', 'AR006', '2026-08-12 14:02:00'),
  ('U008', 'Related work', 'AR022', '2026-08-12 21:15:00'),
  ('U009', 'Knowledge graphs', 'AR011', '2026-09-14 04:28:00'),
  ('U009', 'Knowledge graphs', 'AR005', '2026-09-14 11:41:00'),
  ('U010', 'Tuning and advisors', 'AR007', '2026-01-15 18:54:00'),
  ('U010', 'Tuning and advisors', 'AR013', '2026-01-16 01:07:00');

INSERT INTO SavedSearch (UserID, SearchName, Criteria, CreatedDate) VALUES
  ('U001', 'learned index', '{"keyword": "learned index", "yearFrom": 2018, "yearTo": 2023, "venueType": "C"}', '2026-01-02 10:00:00'),
  ('U002', 'cardinality estimation', '{"keyword": "cardinality", "yearFrom": 2019, "yearTo": 2023}', '2026-02-03 10:03:00'),
  ('U003', 'query optimization', '{"keyword": "query optimization", "yearFrom": 2017, "yearTo": 2023, "venueType": "C"}', '2026-03-04 10:06:00'),
  ('U004', 'entity resolution', '{"keyword": "entity resolution", "yearFrom": 2019, "yearTo": 2023, "venueType": "J"}', '2026-04-05 10:09:00'),
  ('U005', 'knowledge graph embedding', '{"keyword": "knowledge graph", "yearFrom": 2017, "yearTo": 2023, "venueType": "J"}', '2026-05-06 10:12:00'),
  ('U006', 'benchmark', '{"keyword": "benchmark", "yearFrom": 2020, "yearTo": 2023}', '2026-06-07 10:15:00'),
  ('U007', 'bloom filter', '{"keyword": "bloom filter", "yearFrom": 2021, "yearTo": 2023, "venueType": "J"}', '2026-07-08 10:18:00'),
  ('U008', 'index tuning', '{"keyword": "index tuning", "yearFrom": 2022, "yearTo": 2023}', '2026-08-09 10:21:00'),
  ('U009', 'reinforcement learning', '{"keyword": "reinforcement learning", "yearFrom": 2020, "yearTo": 2023, "venueType": "C"}', '2026-09-10 10:24:00'),
  ('U010', 'survey', '{"keyword": "survey", "yearFrom": 2017, "yearTo": 2023, "venueType": "J"}', '2026-01-11 10:27:00'),
  ('U011', 'differential privacy', '{"keyword": "differential privacy", "yearFrom": 2015, "yearTo": 2023}', '2026-02-12 10:30:00'),
  ('U012', 'join order', '{"keyword": "join order", "yearFrom": 2019, "yearTo": 2023, "venueType": "C"}', '2026-03-13 10:33:00'),
  ('U013', 'approximate query', '{"keyword": "approximate query", "yearFrom": 2020, "yearTo": 2023, "venueType": "C"}', '2026-04-14 10:36:00'),
  ('U014', 'deep learning', '{"keyword": "deep learning", "yearFrom": 2019, "yearTo": 2023}', '2026-05-15 10:39:00'),
  ('U015', 'metric index', '{"keyword": "metric", "yearFrom": 2021, "yearTo": 2023, "venueType": "J"}', '2026-06-16 10:42:00');
