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
use DSNParser;
use VersionParser;
use Sandbox;

my $dp = new DSNParser();
my $vp = new VersionParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'Sakila database is loaded which breaks this test';
}
else {
   plan tests => 1;
}

my $run_with = "$trunk/mk-query-digest/mk-query-digest --report-format=query_report --limit 10 ../../common/t/samples/";

# Test --explain.  Because the file says 'use sakila' only the first one will
# succeed.

# TODO: change slow001.sql or do something else to make this work
# with or without the sakila db loaded.
ok(
   no_diff($run_with.'slow001.txt --explain h=127.1,P=12345,u=msandbox,p=msandbox',
      "mk-query-digest/t/samples/slow001_explainreport.txt"),
   'Analysis for slow001 with --explain',
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
