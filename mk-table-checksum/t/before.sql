use test;

drop table if exists checksum_test, checksum, fl_test;

create table checksum_test(
   a int not null primary key
);

insert into checksum_test(a) values (1);

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

create table fl_test(a float not null primary key, b double);
