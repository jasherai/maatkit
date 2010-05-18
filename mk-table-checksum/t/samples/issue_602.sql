-- Issue 602: mk-table-checksum issue with invalid dates
drop database if exists issue_602;
create database issue_602;
use issue_602;
create table t (
   a int,
   b datetime not null,
   key (b)
);
insert into t VALUES (RAND(), NOW()-INTERVAL RAND() SECOND);
insert into t VALUES (RAND(), NOW()-INTERVAL RAND() SECOND);
insert into t VALUES (RAND(), NOW()-INTERVAL RAND() SECOND);
insert into t VALUES (RAND(), NOW()-INTERVAL RAND() SECOND);
insert into t VALUES (RAND(), NOW()-INTERVAL RAND() SECOND);
insert into t VALUES (RAND(), NOW()-INTERVAL RAND() SECOND);
insert into t VALUES (RAND(), NOW()-INTERVAL RAND() SECOND);
insert into t VALUES (RAND(), NOW()-INTERVAL RAND() SECOND);
insert into t VALUES (RAND(), NOW()-INTERVAL RAND() SECOND);
insert into t VALUES (RAND(), NOW()-INTERVAL RAND() SECOND);

-- invalid datetime
insert into t VALUES (RAND(), '2010-00-09 00:00:00' );
