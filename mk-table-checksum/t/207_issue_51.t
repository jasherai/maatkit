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
      plan tests => 1;
}

my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $res;
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf -d test -t checksum_test 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/checksum_tbl.sql');
$sb->load_file('master', 'mk-table-checksum/t/samples/issue_94.sql');

# #############################################################################
# Issue 51: --wait option prevents data from being inserted
# #############################################################################

# This test relies on table issue_94 created somewhere above, which has
# something like:
# mysql> select * from issue_94;
# +----+----+---------+
# | a  | b  | c       |
# +----+----+---------+
# |  1 |  2 | apple   | 
# |  3 |  4 | banana  | 
# |  5 |  6 | kiwi    | 
# |  7 |  8 | orange  | 
# |  9 | 10 | grape   | 
# | 11 | 12 | coconut | 
# +----+----+---------+

$master_dbh->do('DELETE FROM test.checksum');
# Give it something to think about. 
$slave_dbh->do('DELETE FROM test.issue_94 WHERE a > 5');
`perl ../mk-table-checksum --replicate=test.checksum --algorithm=BIT_XOR h=127.1,P=12345,u=msandbox,p=msandbox --databases test --tables issue_94 --chunk-size 500000 --wait 900`;
$res = $master_dbh->selectall_arrayref("SELECT * FROM test.checksum");
is($res->[0]->[1], 'issue_94', '--wait does not prevent update to --replicate tbl (issue 51)');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
