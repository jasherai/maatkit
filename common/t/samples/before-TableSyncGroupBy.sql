use test;

drop table if exists test1,test2;

create table test1(
   a int not null,
   b int not null,
   c int not null
) ENGINE=INNODB DEFAULT CHARSET=latin1;

create table test2 like test1;

insert into test1 values
   (1, 2, 3),
   (1, 2, 3),
   (1, 2, 3),
   (1, 2, 3),
   (2, 2, 3),
   (2, 2, 3),
   (2, 2, 3),
   (2, 2, 3),
   (3, 2, 3),
   (3, 2, 3);

insert into test2 values
   (1, 2, 3),
   (1, 2, 3),
   (1, 2, 3),
   (2, 2, 3),
   (2, 2, 3),
   (2, 2, 3),
   (2, 2, 3),
   (2, 2, 3),
   (2, 2, 3),
   (4, 2, 3);
