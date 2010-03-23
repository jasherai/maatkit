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

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
if ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 3;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Test that --create-databases won't replicate with --no-bin-log.
# #############################################################################
$slave_dbh->do('DROP DATABASE IF EXISTS issue_625');

is_deeply(
   $slave_dbh->selectall_arrayref("show databases like 'issue_625'"),
   [],
   "Database doesn't exist on slave"
);

my $master_pos = $master_dbh->selectall_arrayref('SHOW MASTER STATUS')->[0]->[1];

`$cmd $trunk/mk-parallel-restore/t/samples/issue_625 --create-databases --no-bin-log`;

is_deeply(
   $slave_dbh->selectall_arrayref("show databases like 'issue_625'"),
   [],
   "Database still doesn't exist on slave"
);
is(
   $master_dbh->selectall_arrayref('SHOW MASTER STATUS')->[0]->[1],
   $master_pos,
   "Bin log pos unchanged ($master_pos)"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);

# Every now and then I like to reset the master/slave binlogs so
# new slaves created by other test scripts don't have to replay
# a bunch of old, unrelated repl data.
diag(`$trunk/sandbox/mk-test-env reset`);

exit;
