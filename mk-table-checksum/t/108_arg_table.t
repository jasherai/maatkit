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
require "$trunk/mk-table-checksum/mk-table-checksum";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 4;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf -d test -t checksum_test 127.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');

# Check --since with --arg-table. The value in the --arg-table table
# ought to override the --since passed on the command-line.
$output = `$cmd --arg-table test.argtest --since 20 --explain 2>&1`;
unlike($output, qr/`a`>=20/, 'Argtest overridden');
like($output, qr/`a`>=1/, 'Argtest set to something else');

# Make sure that --arg-table table has only legally allowed columns in it
$output = `$cmd --arg-table test.argtest2 2>&1`;
like($output, qr/Column foobar .from test.argtest2/, 'Argtest with bad column');

# #############################################################################
# Issue 467: overridable arguments with --arg-table
# #############################################################################

# This block of actions is historical, before mk-table-checksum.t
# was modularized.  In some forgotten way, it sets up the conditions
# for the actual test below.
$sb->load_file('master', 'mk-table-checksum/t/samples/issue_122.sql');
$sb->load_file('master', 'mk-table-checksum/t/samples/issue_94.sql');
`$cmd --arg-table test.argtable --save-since -d test -t issue_122 --chunk-size 2`;
$master_dbh->do("INSERT INTO test.issue_122 VALUES (null,'a'),(null,'b')");
`$cmd --arg-table test.argtable --save-since -d test -t issue_122 --chunk-size 2`;
$master_dbh->do('ALTER TABLE test.argtable ADD COLUMN (modulo INT, offset INT, `chunk-size` INT)');
$master_dbh->do("TRUNCATE TABLE test.argtable");

# Two different args for two different tables.  Because issue_122 uses
# --chunk-size, it will use the BIT_XOR algo.  And issue_94 uses no opts
# so it will use the CHECKSUM algo.
$master_dbh->do("INSERT INTO test.argtable (db, tbl, since, modulo, offset, `chunk-size`) VALUES ('test', 'issue_122', NULL, 2, 1, 2)");
$master_dbh->do("INSERT INTO test.argtable (db, tbl, since, modulo, offset, `chunk-size`) VALUES ('test', 'issue_94', NULL, NULL, NULL, NULL)");
$master_dbh->do("INSERT INTO test.issue_122 VALUES (3,'c'),(4,'d'),(5,'e'),(6,'f'),(7,'g'),(8,'h'),(9,'i'),(10,'j')");

$output = `$cmd -d test -t issue_122,issue_94 --arg-table test.argtable | diff $trunk/mk-table-checksum/t/samples/issue_467.txt -`;
is(
   $output,
   '',
   'chunk-size, modulo and offset in argtable (issue 467)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
