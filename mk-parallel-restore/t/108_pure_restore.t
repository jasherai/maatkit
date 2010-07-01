#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use MaatkitTest;
require "$trunk/mk-parallel-restore/mk-parallel-restore";

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $output;

# #############################################################################
# Test "pure" restore and attendant options.
# #############################################################################

$output = `$cmd $trunk/mk-parallel-restore/t/samples/fast_index --dry-run --quiet -t store`;
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
  UNIQUE KEY `idx_unique_manager` (`manager_staff_id`),
  KEY `idx_fk_address_id` (`address_id`),
  CONSTRAINT `fk_store_staff` FOREIGN KEY (`manager_staff_id`) REFERENCES `staff` (`staff_id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_store_address` FOREIGN KEY (`address_id`) REFERENCES `address` (`address_id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8
USE `sakila`
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `store` VALUES (1,1,1,'2006-02-15 11:57:12'),(2,2,2,'2006-02-15 11:57:12');
",
   'Pure restore'
);

$output = `$cmd $trunk/mk-parallel-restore/t/samples/fast_index --dry-run --quiet -t store --no-drop-tables`;
is(
   $output,
"USE `sakila`
CREATE TABLE `store` (
  `store_id` tinyint(3) unsigned NOT NULL auto_increment,
  `manager_staff_id` tinyint(3) unsigned NOT NULL,
  `address_id` smallint(5) unsigned NOT NULL,
  `last_update` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`store_id`),
  UNIQUE KEY `idx_unique_manager` (`manager_staff_id`),
  KEY `idx_fk_address_id` (`address_id`),
  CONSTRAINT `fk_store_staff` FOREIGN KEY (`manager_staff_id`) REFERENCES `staff` (`staff_id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_store_address` FOREIGN KEY (`address_id`) REFERENCES `address` (`address_id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8
USE `sakila`
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `store` VALUES (1,1,1,'2006-02-15 11:57:12'),(2,2,2,'2006-02-15 11:57:12');
",
   '--no-drop-tables'
);

$output = `$cmd $trunk/mk-parallel-restore/t/samples/fast_index --dry-run --quiet -t store --no-create-tables`;
is(
   $output,
"USE `sakila`
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `store` VALUES (1,1,1,'2006-02-15 11:57:12'),(2,2,2,'2006-02-15 11:57:12');
",
   '--no-create-tables'
);

# #############################################################################
# Done.
# #############################################################################
exit;
