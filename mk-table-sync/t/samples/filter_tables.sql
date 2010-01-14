drop database if exists issue_806_1;
drop database if exists issue_806_2;
create database issue_806_1;
create database issue_806_2;

use issue_806_1;
create table t1 (i int);
create table t2 (i int);

use issue_806_2;
create table t1 (i int);
create table t2 (i int);
create table t3 (i int);
