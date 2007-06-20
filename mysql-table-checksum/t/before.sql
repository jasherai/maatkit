use test;

drop table if exists checksum_test;
drop table if exists checksum_test_2;
drop table if exists checksum_test_3;
drop table if exists checksum_test_4;
drop table if exists checksum_test_5;

create table checksum_test(
   a int not null primary key,
   b int,
   c int not null
) type=innodb;

insert into checksum_test(a, b, c) values
   (1, 2, 3), (2, NULL, 3);

create table checksum_test_2(
   a int not null primary key,
   b int,
   c int not null
) type=innodb;

insert into checksum_test_2 select * from checksum_test;

create table checksum_test_3(
   a int not null primary key,
   b int,
   c int not null
) type=innodb;

insert into checksum_test_3 values
   (1,3,8),
   (3,238,1),
   (2,38,147);

create table checksum_test_4(
   a int,
   b int,
   c int not null,
   unique key(a)
) type=innodb;

insert into checksum_test_4 values
   (NULL,3,8),
   (3,3,8);

create table checksum_test_5(
   a date not null primary key,
   b int
) type=innodb;

insert into checksum_test_5 values
   ('2000-01-01', 5),
   ('2001-01-01', 5);

drop table if exists checksum_test_6;
create table checksum_test_6(
   a datetime not null primary key,
   b int
) type=innodb;
insert into checksum_test_6 values
   ('1922-01-14 05:18:23', 5),
   ('1950-03-21 09:03:15', 88),
   ('2005-11:26 00:59:19', 234);

drop table if exists checksum_test_7;
create table checksum_test_7(
   a time not null primary key,
   b int
) type=innodb;
insert into checksum_test_7 values
   ('05:18:23', 5),
   ('09:03:15', 88),
   ('00:59:19', 234);

drop table if exists checksum;

  CREATE TABLE checksum (
     db         char(64)     NOT NULL,
     tbl        char(64)     NOT NULL,
     chunk      int          NOT NULL,
     boundaries char(64)     NOT NULL,
     this_crc   char(40)     NOT NULL,
     this_cnt   int          NOT NULL,
     master_crc char(40)         NULL,
     master_cnt int              NULL,
     ts         timestamp    NOT NULL,
     PRIMARY KEY (db, tbl, chunk)
  );

