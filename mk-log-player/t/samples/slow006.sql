-- This is meant to be used with ../common/t/samples/slow006.txt
-- and the log splits which result from it.

CREATE DATABASE foo;
USE foo;
CREATE TABLE foo_tbl (
   col INT
);
INSERT INTO foo_tbl VALUES (1),(3),(5),(7),(9);

CREATE DATABASE bar;
USE bar;
CREATE TABLE bar_tbl (
   col INT
);
INSERT INTO bar_tbl VALUES (2),(4),(6),(8),(10);
