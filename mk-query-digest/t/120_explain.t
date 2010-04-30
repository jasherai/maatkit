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

use Sandbox;
use MaatkitTest;
use VersionParser;
# See 101_slowlog_analyses.t for why we shift.
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift
shift @INC;  # Sandbox

require "$trunk/mk-query-digest/mk-query-digest";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $vp  = new VersionParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my $sample = "mk-query-digest/t/samples/";

$dbh->do('drop database if exists food');
$dbh->do('create database food');
$dbh->do('use food');
$dbh->do('create table trees (fruit varchar(24), unique index (fruit))');

my $output = '';
my @args   = ('--explain', 'h=127.1,P=12345,u=msandbox,p=msandbox', qw(--report-format=query_report --limit 10));

# The table has no rows so EXPLAIN will return NULL for most values.
ok(
   no_diff(
      sub { mk_query_digest::main(@args,
         "$trunk/common/t/samples/slow007.txt") },
      ($sandbox_version ge '5.1' ? "$sample/slow007_explain_1-51.txt"
                                 : "$sample/slow007_explain_1.txt")
   ),
   'Analysis for slow007 with --explain, no rows',
);

# Normalish output from EXPLAIN.
$dbh->do('insert into trees values ("apple"),("orange"),("banana")');

ok(
   no_diff(
      sub { mk_query_digest::main(@args,
         "$trunk/common/t/samples/slow007.txt") },
      ($sandbox_version ge '5.1' ? "$sample/slow007_explain_2-51.txt"
                                 : "$sample/slow007_explain_2.txt")
   ),
   'Analysis for slow007 with --explain',
);

# Failed EXPLAIN.
$dbh->do('drop table trees');

ok(
   no_diff(
      sub { mk_query_digest::main(@args,
         "$trunk/common/t/samples/slow007.txt") },
      "mk-query-digest/t/samples/slow007_explain_3.txt",
      trf => "sed 's/line [0-9]\\+/line 0/'",
   ),
   'Analysis for slow007 with --explain, failed',
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
