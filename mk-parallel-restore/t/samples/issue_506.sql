DROP DATABASE IF EXISTS issue_506;
CREATE DATABASE issue_506;
USE issue_506;
CREATE TABLE t (
  i int,
  UNIQUE INDEX (i)
);
INSERT INTO issue_506.t VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10);
