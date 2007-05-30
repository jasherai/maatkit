use test;

drop table if exists table_1;
drop table if exists table_2;
drop table if exists table_3;

create table table_1(
   a int not null primary key,
   b int,
   c int not null,
   d varchar(50)
) type=innodb;

create table table_2(
   a int not null primary key,
   b int,
   c int not null,
   d varchar(50)
) type=innodb;

create table table_3(
   a int not null,
   b int,
   c int not null,
   d varchar(50),
   primary key(a, c)
) type=innodb;

insert into table_1 values
   (1, 2, 3, 4),
   (2, null, 3, 4),
   (3, 2, 3, "\t"),
   (4, 2, 3, "\n");

insert into table_3 select * from table_1;
