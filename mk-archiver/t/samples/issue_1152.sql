DROP DATABASE IF EXISTS issue_1152;
DROP DATABASE IF EXISTS issue_1152_archive;
CREATE DATABASE issue_1152;
CREATE DATABASE issue_1152_archive;

USE issue_1152;
CREATE TABLE t (
   id  INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
   a   INT,
   b   INT,
   c   INT
);
INSERT INTO issue_1152.t VALUES
   (null, 1, 2, 3),
   (null, 2, 2, 3),
   (null, 3, 2, 7),
   (null, 4, 2, 3),
   (null, 5, 2, 3),
   (null, 6, 2, 3),
   (null, 7, 2, 3),
   (null, 8, 2, 3),
   (null, 9, 2, 3),
   (null, 10, 2, 3);

USE issue_1152_archive;
CREATE TABLE t (
   id  INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
   a   INT,
   b   INT,
   c   INT
);
