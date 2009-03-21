#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Test::More tests => 2;

my $output = `perl ../mk-slave-find --help`;
like($output, qr/Prompt for a password/, 'It compiles');

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $slave_dbh  = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

# We have to create the 2nd slave ourselves because it is
# usually not running.
my $slave2_was_already_running = 1;
if ( !$sb->get_dbh_for('slave2') ) {
   $slave2_was_already_running = 0;
   diag(`../../sandbox/make_sandbox 12347`);
   diag(`/tmp/12347/use -e "change master to master_host='127.0.0.1', master_log_file='mysql-bin.000001', master_log_pos=0, master_user='msandbox', master_password='msandbox', master_port=12346"`);
   diag(`/tmp/12347/use -e "start slave"`);
}

$output = `perl ../mk-slave-find -h 127.0.0.1 -P 12345 -u msandbox -p msandbox`;
my $expected = <<EOF;
127.0.0.1:12345
+- 127.0.0.1:12346
   +- 127.0.0.1:12347
EOF
is($output, $expected, 'Found the desired slaves');

if ( !$slave2_was_already_running ) {
   # Stop and remove slave2 if we started it.
   diag(`/tmp/12347/stop`);
   diag(`rm -rf /tmp/12347`);
}
exit;
