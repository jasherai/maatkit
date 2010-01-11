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

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 10;
}

my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf -d test -t checksum_test 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');

# #############################################################################
# Issue 36: Add --resume option to mk-table-checksum (1/2)
# #############################################################################

# The following tests rely on a clean test db, that's why we dropped
# test.issue_21 above.

# First re-checksum and replicate using chunks so we can more easily break,
# resume and test it.
`../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox --ignore-databases sakila --replicate test.checksum --empty-replicate-table --chunk-size 100`;

# Make sure the results propagate
sleep 1;

# Now break the results as if that run didn't finish
`/tmp/12345/use -e "DELETE FROM test.checksum WHERE tbl = 'help_relation' AND chunk > 4"`;
`/tmp/12345/use -e "DELETE FROM test.checksum WHERE tbl = 'help_topic' OR tbl = 'host'"`;
`/tmp/12345/use -e "DELETE FROM test.checksum WHERE tbl LIKE 'proc%' OR tbl LIKE 't%' OR tbl = 'user'"`;

# And now test --resume with --replicate
`../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox --ignore-databases sakila --resume-replicate --replicate test.checksum --chunk-size 100 > /tmp/mktc_issue36.txt`;

# We have to chop the output because a simple diff on the whole thing won't
# work well because the TIME column can sometimes change from 0 to 1.
# So, instead, we check that the top part lists the chunks already done,
# and then we simplify the latter lines which should be the
# resumed/not-yet-done chunks.
$output = `head -n 14 /tmp/mktc_issue36.txt | diff samples/resume02_already_done.txt -`;
ok(!$output, 'Resumes with --replicate (1/2)');
$output = `tail -n 19 /tmp/mktc_issue36.txt | awk '{print \$1,\$2,\$3,\$4}' | diff samples/resume02_resumed.txt -`;
ok(!$output, 'Resumes with --replicate (2/2)');

`rm /tmp/mktc_issue36.txt`;

# #############################################################################
# Issue 36: Add --resume option to mk-table-checksum (2/2)
# #############################################################################

# This tests just one database...
$output = `../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox h=127.1,P=12346 -d test --chunk-size 3 --resume samples/resume01_partial.txt | diff samples/resume01_whole.txt -`;
ok(!$output, 'Resumes checksum of chunked data (1 db)');

# but this tests two.
$output = `../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox h=127.1,P=12346 --ignore-databases sakila --resume samples/resume03_partial.txt | diff samples/resume03_whole.txt -`;
ok(!$output, 'Resumes checksum of non-chunked data (2 dbs)');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
