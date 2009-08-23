DROP DATABASE IF EXISTS diff_results;
CREATE DATABASE diff_results;
USE diff_results;

DROP TABLE IF EXISTS `identical`;
CREATE TABLE `identical` (
  `i` int(11) default NULL,
  `c` char(1) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
INSERT INTO `identical` VALUES (1,'a'),(2,'b');

DROP TABLE IF EXISTS `not_in_left`;
CREATE TABLE `not_in_left` (
  `i` int(11) default NULL,
  `c` char(1) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
INSERT INTO `not_in_left` VALUES (1,'a'),(2,'b'),(3,'c');

DROP TABLE IF EXISTS `not_in_right`;
CREATE TABLE `not_in_right` (
  `i` int(11) default NULL,
  `c` char(1) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
INSERT INTO `not_in_right` VALUES (1,'a'),(2,'b');

DROP TABLE IF EXISTS `diff_1`;
CREATE TABLE `diff_1` (
  `i` int(11) default NULL,
  `c` char(1) default NULL,
  UNIQUE INDEX (i),
  INDEX (c, i)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
INSERT INTO `diff_1` VALUES (1,'a'),(2,'b'),(4,'d');

DROP TABLE IF EXISTS `diff_2`;
CREATE TABLE `diff_2` (
  `i` int(11) default NULL,
  `c` char(1) default NULL,
  UNIQUE INDEX (i),
  INDEX (c, i)
  ) ENGINE=MyISAM DEFAULT CHARSET=latin1;
INSERT INTO `diff_2` VALUES (1,'a'),(2,'b'),(4,'r'),(3,'c');

DROP TABLE IF EXISTS `diff_3`;
CREATE TABLE `diff_3` (
  `i` int(11) NOT NULL,  -- makes replacable index; avoid groupby algo
  `c` char(1) default NULL,
  UNIQUE INDEX (i),
  INDEX (c, i)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
INSERT INTO `diff_3` VALUES (1,'a'),(2,'b'),(4,'r'),(3,'c');

