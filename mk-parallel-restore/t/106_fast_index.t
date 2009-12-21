#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Test --fast-index.
# #############################################################################
$output = `$cmd samples/fast_index --dry-run --quiet -t store --fast-index`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`store`
CREATE TABLE `store` (
  `store_id` tinyint(3) unsigned NOT NULL auto_increment,
  `manager_staff_id` tinyint(3) unsigned NOT NULL,
  `address_id` smallint(5) unsigned NOT NULL,
  `last_update` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`store_id`),
  CONSTRAINT `fk_store_staff` FOREIGN KEY (`manager_staff_id`) REFERENCES `staff` (`staff_id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_store_address` FOREIGN KEY (`address_id`) REFERENCES `address` (`address_id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8
USE `sakila`
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `store` VALUES (1,1,1,'2006-02-15 11:57:12'),(2,2,2,'2006-02-15 11:57:12');
ALTER TABLE `sakila`.`store` ADD KEY `idx_fk_address_id` (`address_id`), ADD UNIQUE KEY `idx_unique_manager` (`manager_staff_id`)
",
   '--fast-index'
);

# This table should not be affected by --fast-index because it's not InnoDB.
$output = `$cmd samples/fast_index --dry-run --quiet -t store --fast-index -t film_text`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40000 ALTER TABLE `sakila`.`film_text` DISABLE KEYS */
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
/*!40000 ALTER TABLE `sakila`.`film_text` ENABLE KEYS */
",
   '--fast-index on non-InnoDB table'
);


# #############################################################################
# Done.
# #############################################################################
exit;
