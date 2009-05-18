#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-find -F $cnf ";

my $output = `$cmd mysql --tblregex column`;
like($output, qr/`mysql`.`columns_priv`/, 'Found mysql.columns_priv');

# These tests are going to be senstive to your sakila db.  Hopefully,
# it matches mine which I tend to load fresh and not modify.  For example,
# the next insert id for sakila.film is expected to be 1001.  If this
# becomes an issue, I may commit my copy of the sakila db to Google Code.

SKIP: {
   skip 'Sandbox master does not have the sakila database', 2
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   # ########################################################################
   # First, test actions: --exec*, print*, etc.
   # ########################################################################

   # POD says: "[--print] is the default action if no other action is
   # specified."
   $output = `$cmd --autoinc 1001`;
   is(
      $output,
      "`sakila`.`film`\n",
      '--print is default action'
   );


   # Test that explicit --print doesn't blow up. 
   $output = `$cmd --autoinc 1001 --print`;
   is(
      $output,
      "`sakila`.`film`\n",
      'Explicit --print',
   );

   # TODO: finish
};

$sb->wipe_clean($dbh);
exit;
