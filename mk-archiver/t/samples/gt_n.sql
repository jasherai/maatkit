DROP DATABASE IF EXISTS gt_n;
CREATE DATABASE gt_n;
USE gt_n;
CREATE TABLE t1 (
   id int not null auto_increment primary key,
   status varchar(32) not null,
   index (status)
);

CREATE TABLE t2 LIKE t1;

-- 12 ok, 6 bad
INSERT INTO t1 VALUES
   (null, 'ok'),
   (null, 'bad'),
   (null, 'ok'),
   (null, 'bad'),
   (null, 'ok'),
   (null, 'bad'),
   (null, 'bad'),
   (null, 'ok'),
   (null, 'ok'),
   (null, 'bad'),
   (null, 'bad'),
   (null, 'ok'),
   (null, 'ok'),
   (null, 'ok'),
   (null, 'ok'),
   (null, 'ok'),
   (null, 'ok'),
   (null, 'ok');

-- 4 ok, 14 bad
INSERT INTO t2 VALUES
   (null, 'bad'),
   (null, 'bad'),
   (null, 'ok'),
   (null, 'bad'),
   (null, 'ok'),
   (null, 'bad'),
   (null, 'bad'),
   (null, 'ok'),
   (null, 'ok'),
   (null, 'bad'),
   (null, 'bad'),
   (null, 'bad'),
   (null, 'bad'),
   (null, 'bad'),
   (null, 'bad'),
   (null, 'bad'),
   (null, 'bad'),
   (null, 'bad');
