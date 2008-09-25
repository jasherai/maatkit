-- This is meant to be used with ../common/t/samples/slow006.txt
-- and the log splits which result from it.

DROP DATABASE IF EXISTS mklp_foo;
CREATE DATABASE mklp_foo;
USE mklp_foo;
CREATE TABLE foo_tbl (
   col INT
);
INSERT INTO foo_tbl VALUES (1),(3),(5),(7),(9),(11),(13),(15),(17),(19),(21);

DROP DATABASE IF EXISTS mklp_bar;
CREATE DATABASE mklp_bar;
USE mklp_bar;
CREATE TABLE bar_tbl (
   col INT
);
INSERT INTO bar_tbl VALUES (2),(4),(6),(8),(10),(12),(14),(16),(18),(20);
