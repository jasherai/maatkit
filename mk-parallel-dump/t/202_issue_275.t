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
require "$trunk/mk-parallel-dump/mk-parallel-dump";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf ";
my $mysql = $sb->_use_for('master');

$sb->create_dbs($dbh, ['test']);

my $output;
my $basedir = '/tmp/dump/';
diag(`rm -rf $basedir`);

my @tbls;

# #############################################################################
# Issue 275: mk-parallel-dump --chunksize does not work properly with --csv
# #############################################################################

$sb->load_file('master', 'mk-parallel-dump/t/samples/issue_223.sql');
diag(`rm -rf $basedir`);

# This test relies on issue_223.sql loaded above which creates test.t1.
# There are 55 rows and we add 1 more (999) for 56 total.  So --chunk-size 28
# should make 2 chunks.  And since the range of vals is 1..999, those chunks
# will be < 500 and >= 500.  Furthermore, the top 2 vals are 100 and 999,
# so the 2nd chunk should contain only 999.
diag(`rm -rf $basedir`);
$dbh->do('insert into test.t1 values (999)');
diag(`$cmd --base-dir $basedir --csv --chunk-size 28 -d test -t t1 > /dev/null`);

$output = `wc -l $basedir/test/t1.000000.txt`;
like($output, qr/^55/, 'First chunk of csv dump (issue 275)');

$output = `cat $basedir/test/t1.000001.txt`;
is($output, "999\n", 'Second chunk of csv dump (issue 275)');

$output = `cat $basedir/test/t1.chunks`;
is($output, "`a` < 500\n`a` >= 500\n", 'Chunks of csv dump (issue 275)');

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
