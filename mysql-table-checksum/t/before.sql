use test;

drop table if exists checksum_test;
drop table if exists checksum_test_2;

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

drop table if exists checksums;
CREATE TABLE checksums (
 db         char(64)     NOT NULL,
 tbl        char(64)     NOT NULL,
 this_crc   char(40)     NOT NULL,
 this_cnt   int unsigned NOT NULL,
 master_crc char(40)         NULL,
 master_cnt int unsigned     NULL,
 ts         timestamp    NOT NULL,
 PRIMARY KEY (db,tbl)
);
