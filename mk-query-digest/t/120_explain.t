#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

require '../../common/DSNParser.pm';
require '../../common/VersionParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $vp = new VersionParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 1;
}

my $run_with = '../mk-query-digest --report-format=query_report --limit 10 ../../common/t/samples/';

# Test --explain.  Because the file says 'use sakila' only the first one will
# succeed.
SKIP: {
   # TODO: change slow001.sql or do something else to make this work
   # with or without the sakila db loaded.
   skip 'Sakila database is loaded which breaks this test', 1
      if @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};
   ok(
      no_diff($run_with.'slow001.txt --explain h=127.1,P=12345,u=msandbox,p=msandbox',
         'samples/slow001_explainreport.txt'),
      'Analysis for slow001 with --explain',
   );
};

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
