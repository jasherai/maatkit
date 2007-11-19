use test;

drop table if exists table_1;
drop table if exists table_2;
drop table if exists table_3;
drop table if exists table_4;

create table table_1(
   a int not null primary key,
   b int,
   c int not null,
   d varchar(50),
   key(b)
) type=innodb;

create table table_2(
   a int not null primary key auto_increment,
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

create table table_4(
   a int
) type=innodb;

insert into table_1 values
   (1, 2, 3, 4),
   (2, null, 3, 4),
   (3, 2, 3, "\t"),
   (4, 2, 3, "\n");

insert into table_3 select * from table_1;

DROP TABLE IF EXISTS `table_5`;
CREATE TABLE `table_5` (
  a date not null,
  b int not null,
  c varchar(10) not null,
  d varchar(50) not null,
  e int not null,
  f int not null,
  g float not null,
  h decimal(9,5) not null,
  i datetime not null,
  PRIMARY KEY  (a,b,c,d)
) type=InnoDB;

INSERT INTO `table_5` VALUES (current_date - interval 2 day,581,'m','ga',1,16,0,'0.00402','2007-03-10 18:00:33')
,(current_date - interval 2 day,584,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,584,'m','ga',1,9,0,'0.00226','2007-03-10 18:00:33')
,(current_date - interval 2 day,586,'b','yu',58,76,0,'0.01900','2007-03-10 18:00:33')
,(current_date - interval 2 day,587,'b','uc',261,381,0,'0.95259','2007-03-10 18:00:33')
,(current_date - interval 2 day,587,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,587,'m','ga',1,15,0,'0.00377','2007-03-10 18:00:33')
,(current_date - interval 2 day,588,'b','mb',54,171,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,593,'b','yu',271,422,0,'0.10550','2007-03-10 18:00:33')
,(current_date - interval 2 day,594,'b','uc',328,493,0,'1.23261','2007-03-10 18:00:33')
,(current_date - interval 2 day,594,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,594,'m','ga',1,26,0,'0.00653','2007-03-10 18:00:33')
,(current_date - interval 2 day,595,'b','yu',248,337,0,'0.08425','2007-03-10 18:00:33')
,(current_date - interval 2 day,596,'b','uc',286,367,0,'0.91759','2007-03-10 18:00:33')
,(current_date - interval 2 day,596,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,596,'m','ga',1,32,0,'0.00804','2007-03-10 18:00:33')
,(current_date - interval 2 day,600,'b','mb',64,85,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,603,'b','mb',149,304,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,604,'b','mb',86,112,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,605,'b','mb',60,74,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,619,'b','mb',50,78,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,623,'b','yu',235,300,0,'0.07500','2007-03-10 18:00:33')
,(current_date - interval 2 day,624,'b','mb',57,60,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,625,'b','uc',624,852,0,'2.13020','2007-03-10 18:00:33')
,(current_date - interval 2 day,625,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,625,'m','ga',1,30,0,'0.00753','2007-03-10 18:00:33')
,(current_date - interval 2 day,626,'b','yu',4,4,0,'0.00100','2007-03-10 18:00:33')
,(current_date - interval 2 day,628,'b','uc',28,44,0,'0.11001','2007-03-10 18:00:33')
,(current_date - interval 2 day,628,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,628,'m','ga',1,2,0,'0.00050','2007-03-10 18:00:33')
,(current_date - interval 2 day,629,'b','yu',161,384,0,'0.09600','2007-03-10 18:00:33')
,(current_date - interval 2 day,631,'b','uc',317,788,0,'1.97018','2007-03-10 18:00:33')
,(current_date - interval 2 day,631,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,631,'m','ga',1,136,0,'0.03416','2007-03-10 18:00:33')
,(current_date - interval 2 day,634,'b','yu',173,562,0,'0.14050','2007-03-10 18:00:33')
,(current_date - interval 2 day,635,'b','mb',131,295,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,636,'b','uc',867,2334,0,'5.83554','2007-03-10 18:00:33')
,(current_date - interval 2 day,636,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,636,'m','ga',1,34,0,'0.00854','2007-03-10 18:00:33')
,(current_date - interval 2 day,641,'b','yu',86,119,0,'0.02975','2007-03-10 18:00:33')
,(current_date - interval 2 day,643,'b','uc',103,121,0,'0.30253','2007-03-10 18:00:33')
,(current_date - interval 2 day,643,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,643,'m','ga',1,12,0,'0.00301','2007-03-10 18:00:33')
,(current_date - interval 2 day,647,'b','uc',16,17,0,'0.04250','2007-03-10 18:00:33')
,(current_date - interval 2 day,647,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,647,'m','ga',1,24,0,'0.00603','2007-03-10 18:00:33')
,(current_date - interval 2 day,650,'b','mb',318,490,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,652,'b','mb',36,39,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,653,'b','yu',32,52,0,'0.01300','2007-03-10 18:00:33')
,(current_date - interval 2 day,654,'b','mb',13,21,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,655,'b','uc',62,70,0,'0.17502','2007-03-10 18:00:33')
,(current_date - interval 2 day,655,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,655,'m','ga',1,18,0,'0.00452','2007-03-10 18:00:33')
,(current_date - interval 2 day,657,'b','mb',11,26,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,658,'b','yu',353,397,0,'0.09925','2007-03-10 18:00:33')
,(current_date - interval 2 day,660,'b','mb',319,378,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,661,'b','uc',1043,1655,0,'4.13788','2007-03-10 18:00:33')
,(current_date - interval 2 day,661,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,661,'m','ga',1,49,0,'0.01231','2007-03-10 18:00:33')
,(current_date - interval 2 day,663,'b','mb',18,18,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,676,'b','uc',233,404,0,'1.01009','2007-03-10 18:00:33')
,(current_date - interval 2 day,676,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,676,'m','ga',1,24,0,'0.00603','2007-03-10 18:00:33')
,(current_date - interval 2 day,678,'b','yu',117,178,0,'0.04450','2007-03-10 18:00:33')
,(current_date - interval 2 day,679,'b','mb',29,54,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,683,'b','uc',230,303,0,'0.75757','2007-03-10 18:00:33')
,(current_date - interval 2 day,683,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,683,'m','ga',1,40,0,'0.01005','2007-03-10 18:00:33')
,(current_date - interval 2 day,685,'b','yu',96,134,0,'0.03350','2007-03-10 18:00:33')
,(current_date - interval 2 day,687,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,687,'m','ga',1,27,0,'0.00678','2007-03-10 18:00:33')
,(current_date - interval 2 day,692,'b','mb',7,7,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,697,'b','uc',55,80,0,'0.20002','2007-03-10 18:00:33')
,(current_date - interval 2 day,697,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,697,'m','ga',1,9,0,'0.00226','2007-03-10 18:00:33')
,(current_date - interval 2 day,698,'b','yu',36,43,0,'0.01075','2007-03-10 18:00:33')
,(current_date - interval 2 day,699,'b','mb',17,19,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,702,'b','yu',10,19,0,'0.00475','2007-03-10 18:00:33')
,(current_date - interval 2 day,710,'b','yu',48,238,0,'0.05950','2007-03-10 18:00:33')
,(current_date - interval 2 day,711,'b','uc',33,54,0,'0.13501','2007-03-10 18:00:33')
,(current_date - interval 2 day,711,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,711,'m','ga',1,4,0,'0.00100','2007-03-10 18:00:33')
,(current_date - interval 2 day,712,'b','yu',1509,2930,0,'0.73250','2007-03-10 18:00:33')
,(current_date - interval 2 day,716,'b','uc',153,296,0,'0.74007','2007-03-10 18:00:33')
,(current_date - interval 2 day,716,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,716,'m','ga',1,10,0,'0.00251','2007-03-10 18:00:33')
,(current_date - interval 2 day,717,'b','yu',26,49,0,'0.01225','2007-03-10 18:00:33')
,(current_date - interval 2 day,722,'b','uc',52,70,0,'0.17502','2007-03-10 18:00:33')
,(current_date - interval 2 day,722,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,722,'m','ga',1,9,0,'0.00226','2007-03-10 18:00:33')
,(current_date - interval 2 day,723,'b','yu',76,107,0,'0.02675','2007-03-10 18:00:33')
,(current_date - interval 2 day,724,'b','mb',39,56,0,'0.00000','2007-03-10 18:00:33')
,(current_date - interval 2 day,727,'b','uc',44,65,0,'0.16252','2007-03-10 18:00:33')
,(current_date - interval 2 day,727,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,727,'m','ga',1,30,0,'0.00753','2007-03-10 18:00:33')
,(current_date - interval 2 day,728,'b','yu',3,3,0,'0.00075','2007-03-10 18:00:33')
,(current_date - interval 2 day,730,'b','yu',180,212,0,'0.05300','2007-03-10 18:00:33')
,(current_date - interval 2 day,733,'b','uc',111,191,0,'0.47754','2007-03-10 18:00:33')
,(current_date - interval 2 day,733,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,733,'m','ga',1,3,0,'0.00075','2007-03-10 18:00:33')
,(current_date - interval 2 day,740,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,740,'m','ga',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,741,'c','dr',1,1,0,'0.00025','2007-03-10 18:00:33')
,(current_date - interval 2 day,741,'m','ga',1,3,0,'0.00075','2007-03-10 18:00:33')
,(current_date - interval 2 day,743,'b','yu',137,163,0,'0.04075','2007-03-10 18:00:33');

drop table if exists table_6;
create table table_6(
   a int not null,
   b int not null,
   c int,
   primary key(a, b)
);

-- This test data specifically designed to be ambiguous unless the
-- ascending-index WHERE clause is carefully wrapped in parens.  If the archiver
-- goes to 2 rows and doesn't wrap right, it will archive the 3rd row which it
-- should not because it archives c=1.
insert into table_6(a, b, c)
   values(1, 1, 1), (1, 2, 1), (1, 3, 0);

-- This table and table_8/9 designed to check that ON DUPLICATE KEY UPDATE can
-- work okay with the before_insert functionality.

drop table if exists table_7;
create table table_7(
   a int not null,
   b int not null,
   c int not null,
   primary key(a, b)
) type=innodb;

drop table if exists table_8;
create table table_8 like table_7;

drop table if exists table_9;
create table table_9(
   a int not null primary key,
   b int not null,
   c int not null
) type=innodb;

insert into table_7(a, b, c) values
   (1, 2, 1),
   (1, 3, 5);

drop table if exists table_10;
create table table_10(a int not null primary key);

-- This table is designed not to work right with ascending slices unless
-- mysql-archiver gets the ascending slice right.  The important thing is that
-- the PK columns aren't in the same order as the columns.  If mysql-archiver
-- ascends by the first two columns 2 rows at a time, confusing column ordinals
-- with PK ordinals, some rows won't get archived.
drop table if exists table_11;
CREATE TABLE table_11 (
   pk_2 int not null,
   col_1 int not null,
   pk_1 int not null,
   primary key(pk_1, pk_2)
);
-- Notice how the values are being inserted in PK order, but out of
-- first-two-columns-scan order:
insert into table_11(pk_2, col_1, pk_1)
   values
   (1, 1, 1),
   (2, 3, 1),
   (1, 0, 2),
   (1, 0, 3);

-- This test uses an auto_increment colum to test --safeautoinc.
drop table if exists table_12;
create table table_12( a int not null auto_increment primary key, b int);
insert into table_12(b) values(1),(1),(1);

-- This test moves rows to different tables depending on the value of a
-- column.
drop table if exists table_13, table_odd, table_even;
create table table_13(a int not null primary key);
insert into table_13(a) values(1),(2),(3);
