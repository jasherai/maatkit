#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-parallel-restore/mk-parallel-restore";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $output;

# #############################################################################
# Test --fast-index.
# #############################################################################
$output = `$cmd $trunk/mk-parallel-restore/t/samples/fast_index --dry-run --quiet -t store --fast-index`;
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
$output = `$cmd $trunk/mk-parallel-restore/t/samples/fast_index --dry-run --quiet -t store --fast-index -t film_text`;
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

SKIP: {
   skip 'Cannot connect to sandbox master', 4 unless $dbh;
   $dbh->{InactiveDestroy}  = 1;  # Don't die on fork().

   # ##########################################################################
   # Issue 729: mk-parallel-restore --fast-index does not restore secondary
   # indexes
   # ##########################################################################
   $output = `$cmd --create-databases $trunk/mk-parallel-restore/t/samples/issue_729 --fast-index 2>&1`;
   unlike(
      $output,
      qr/failed/,
      '--fast-index: nothing failed'
   );
   like(
      $output,
      qr/0\s+failures/,
      '--fast-index: no failures reported'
   );
   $output = lc($dbh->selectrow_arrayref('show create table issue_729.posts')->[1]);
   $output =~ s/primary key  /primary key /;  # 5.0/5.1 difference *sigh*
   is(
      $output,
"create table `posts` (
  `id` int(10) unsigned not null auto_increment,
  `template_id` smallint(5) unsigned not null default '0',
  `other_id` bigint(20) unsigned not null default '0',
  `date` int(10) unsigned not null default '0',
  `private` tinyint(3) unsigned not null default '0',
  primary key (`id`),
  key `other_id` (`other_id`)
) engine=innodb auto_increment=15418 default charset=latin1",
      '--fast-index: secondary index was created'
   );

   # ##########################################################################
   # Issue 833: parallel-restore create index problem.
   # ##########################################################################
   my $retval = mk_parallel_restore::main('-F', $cnf,
      qw(--fast-index --tab --create-databases --quiet),
      "$trunk/mk-parallel-restore/t/samples/issue_833");
   is(
      $retval,
      0,
      'All key defs comma terminated (issue 833)'
   );

   $sb->wipe_clean($dbh);
}

# #############################################################################
# Done.
# #############################################################################
exit;
