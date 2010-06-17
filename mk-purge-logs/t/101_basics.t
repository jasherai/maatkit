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
require "$trunk/mk-purge-logs/mk-purge-logs";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => "Cannot connect to sandbox master";
}
elsif ( !$slave_dbh ) {
   plan skip_all => "Cannot connect to sandbox slave";
}

# A reset and flush should result in the master having 2 binlogs and
# its slave using the 2nd.
diag(`$trunk/sandbox/mk-test-env reset`);
$master_dbh->do('flush logs');
sleep 1;

my $mbinlogs = $master_dbh->selectall_arrayref('show binary logs');
plan skip_all => "Failed to reset and flush master binary logs"
   unless @$mbinlogs == 2;

my $ss = $slave_dbh->selectrow_hashref('show slave status');
plan skip_all => "Slave did not reset to second master binary log "
   unless $ss->{Master_Log_File} eq $mbinlogs->[1]->[0];

plan tests => 6;

my @args   = ('h=127.1,P=12345,u=msandbox,p=msandbox');
my $output = '';


# #############################################################################
# Test --dry-run.
# #############################################################################
$output = output(
   sub { mk_purge_logs::main(@args, qw(--purge --dry-run)) },
);
like(
   $output,
   qr/dry-run.+?PURGE BINARY LOGS TO \? mysql-bin\.000002/ms,
   "--dry-run prints PURGE statement"
);

my $mbinlogs2 = $master_dbh->selectall_arrayref('show binary logs');
is_deeply(
   $mbinlogs2,
   $mbinlogs,
   "No purge with --dry-run"
);


# #############################################################################
# Test a real --purge.
# #############################################################################
$output = output(
   sub { mk_purge_logs::main(@args, qw(--purge)) },
);
is(
   $output,
   "",
   "No output by default"
);

$mbinlogs2 = $master_dbh->selectall_arrayref('show binary logs');
is_deeply(
   $mbinlogs2,
   [
      [ $mbinlogs->[1]->[0], $mbinlogs->[1]->[1], ],
   ],
   "Purged unused binary log"
);

# #############################################################################
# Test that used binlogs are *not* purged.
# #############################################################################
$output = output(
   sub { mk_purge_logs::main(@args, qw(--purge -v)) },
);
$mbinlogs = $master_dbh->selectall_arrayref('show binary logs');
is_deeply(
   $mbinlogs,
   $mbinlogs2,
   "Didn't purge used binlog"
);

like(
   $output,
   qr/Found slave.+12346/,
   "--verbose output reports slave found"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$master_dbh->disconnect();
$slave_dbh->disconnect();
exit;
