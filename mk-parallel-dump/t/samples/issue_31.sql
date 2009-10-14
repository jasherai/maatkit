DROP DATABASE IF EXISTS issue_31;
CREATE DATABASE issue_31;
USE issue_31;
CREATE TABLE t1 (
   t text
);
CREATE TABLE t2 LIKE t1;
CREATE TABLE t3 LIKE t1;
CREATE TABLE t4 LIKE t1;

INSERT INTO t4 VALUES
   ('foofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoo'),
   ('foofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoo'),
   ('foofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoo'),
   ('foofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoo');

INSERT INTO t1 VALUES
   ('foofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoo'),
   ('foofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoofoo');

INSERT INTO t3 VALUES
   ('foo');
