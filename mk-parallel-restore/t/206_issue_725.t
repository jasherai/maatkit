#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Issue 729: mk-parallel-restore --fast-index does not restore secondary indexes
# #############################################################################
$output = `$cmd --create-databases samples/issue_729 --fast-index 2>&1`;
unlike(
   $output,
   qr/failed/,
   'Issue 729, --fast-index: nothing failed'
);
like(
   $output,
   qr/0\s+failures/,
   'Issue 729, --fast-index: no failures reported'
);
$output = $dbh->selectrow_arrayref('show create table issue_729.posts')->[1];
is(
   $output,
"CREATE TABLE `posts` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `template_id` smallint(5) unsigned NOT NULL default '0',
  `other_id` bigint(20) unsigned NOT NULL default '0',
  `date` int(10) unsigned NOT NULL default '0',
  `private` tinyint(3) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `other_id` (`other_id`)
) ENGINE=InnoDB AUTO_INCREMENT=15418 DEFAULT CHARSET=latin1",
   'Issue 720, --fast-index: secondary index was created'
);


# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
