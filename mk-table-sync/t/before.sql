use test;

drop table if exists test1;
drop table if exists test2;

create table test1(
   a int not null,
   b char(2) not null,
   primary key(a, b)
) ENGINE=INNODB DEFAULT CHARSET=latin1;

create table test2 like test1;

insert into test1 values(1, 'en'), (2, 'ca');

-- The funny eacute character will cause mk-table-sync to make a call to
-- MySQL to strcmp(), and that should not cause any problems.
insert into test2 values(1, 'en'), (2, 'ée');
