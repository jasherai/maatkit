#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-parallel-restore/mk-parallel-restore";

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
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $output;

# #############################################################################
# Issue 729: mk-parallel-restore --fast-index does not restore secondary indexes
# #############################################################################
$output = `$cmd --create-databases $trunk/mk-parallel-restore/t/samples/issue_729 --fast-index 2>&1`;
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
