DROP DATABASE IF EXISTS test2;
CREATE DATABASE test2;
USE test2;
CREATE TABLE t (
  a int primary key,
  b int,
  c int,
  INDEX (c),
  INDEX (b,c)
) ENGINE=InnoDB;
INSERT INTO test2.t VALUES (1,2,3),(2,2,2),(3,4,5),(4,0,0),(5,1,2),(6,6,NULL),(7,NULL,7),(8,NULL,NULL);

DROP DATABASE IF EXISTS other_db;  -- test using default db
CREATE DATABASE other_db;
USE other_db;
CREATE TABLE t (
  a int primary key,
  b int,
  c int,
  INDEX (c),
  INDEX (b,c)
  ) ENGINE=InnoDB;
INSERT INTO t VALUES (1,2,3);
