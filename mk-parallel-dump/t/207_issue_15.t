#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

require '../mk-parallel-dump';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-parallel-dump -F $cnf ";
my $mysql = $sb->_use_for('master');

$sb->create_dbs($dbh, ['test']);

my $output;
my $basedir = '/tmp/dump/';
diag(`rm -rf $basedir`);

my @tbls;

# #############################################################################
# Issue 15: mk-parallel-dump should continue if a table fails to dump
# #############################################################################
diag(`rm -rf $basedir`);
SKIP: {
   skip 'Sandbox master does not have the sakila database', 3
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   diag(`mv /tmp/12345/data/sakila/film_text.MYD /tmp/12345/data/sakila/.film_text-OK.MYD`);
   diag(`cp samples/film_text-crashed.MYD /tmp/12345/data/sakila/film_text.MYD`);
   $dbh->do('FLUSH TABLES');

   $output = `$cmd --base-dir $basedir -v -v -d sakila -t film_text,actor --progress 2>&1`;
   like(
      $output,
      qr/all\s+\S+\s+3\s+0\s+-\s+done.+?1 databases, 2 tables, 2 chunks/,
      'Dumped other tables after crashed table (issue 15)'
   );

   # This test will fail if you're using an old version of mysqldump that
   # doesn't add "Dump completed" at the end.  And the next test will pass
   # when it shouldn't.
   SKIP: {
      # New dump files no longer have any mysqldump fluff, so we'll need
      # to conjure a new way to test this.
      skip 'No longer valid with new dump files', 1 if 1;
      $output = `grep 'Dump completed' $basedir/sakila/actor.000000.sql`;
      like(
         $output,
         qr/Dump completed/,
         'Dump completed for good table (issue 15)'
      );
   };

   $output = `grep 'Dump completed' $basedir/sakila/film_text.000000.sql`;
   is(
      $output,
      "",
      'Dump did not complete for crashed table (issue 15)'
   );

   diag(`rm -rf /tmp/12345/data/sakila/film_text.MYD`);
   diag(`mv /tmp/12345/data/sakila/.film_text-OK.MYD /tmp/12345/data/sakila/film_text.MYD`);
   $dbh->do('FLUSH TABLES');
};

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
