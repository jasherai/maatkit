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
require "$trunk/util/mysql-rmf/mysql-replication-monitor";

my $o  = new OptionParser(description=>'foo');
my $q  = new Quoter();
my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave1';
}
else {
   plan tests => 7;
}

my $output;
my $rows;

$sb->create_dbs($master_dbh, [qw(test)]);
$master_dbh->do('DROP TABLE IF EXISTS test.servers');
$master_dbh->do('USE test');

# #############################################################################
# get_monitored_server() gets the servers from the --monitor table and
# returns them an array of hashref.
# #############################################################################

my $monitor_dsn = {
   h => '127.1',
   P => 12345,
   u => 'msandbox',
   p => 'msandbox',
   D => 'test',
   t => 'servers',
};

my %args = (
   dsn          => $monitor_dsn,
   OptionParser => $o,
   Quoter       => $q,
   DSNParser    => $dp,
);

my @servers;

# Test how it handles not having the monitor table.
output(
   sub { @servers = mysql_replication_monitor::get_monitored_servers(%args) }
);
is_deeply(
   \@servers,
   [],
   "Doesn't crash if monitor table doesn't exist"
);

my $sql = "CREATE TABLE `servers` (
  `server`            VARCHAR(64) NOT NULL,
  `dsn`               VARCHAR(128) NOT NULL,
  `mk_heartbeat_file` VARCHAR(128),
  `comment`           VARCHAR(255),
  PRIMARY KEY (`server`)
)";

$master_dbh->do($sql);
sleep 1;

$output = output(
   sub { @servers = mysql_replication_monitor::get_monitored_servers(%args) }
);
is_deeply(
   \@servers,
   [],
   "Empty table, no servers"
);

like(
   $output,
   qr/Got 0 servers/,
   "Got 0 servers"
);

$master_dbh->do("insert into test.servers values ('master', 'h=127.1,P=12345,u=msandbox', 'hb', 'this is my comment')");

output(
   sub { @servers = mysql_replication_monitor::get_monitored_servers(%args) }
);
is_deeply(
   \@servers,
   [
      {
         name              => 'master',
         dsn               => {
            h => '127.1',
            P => 12345,
            u => 'msandbox',
            p => undef,
            D => undef,
            t => undef,
            S => undef,
            F => undef,
            A => undef,
         },
         mk_heartbeat_file => 'hb',
      },
   ],
   "Got a server"
);

# This 2nd server has a bad DSN part: z.  It should be skipped.
$master_dbh->do("insert into test.servers values ('bad', 'h=127.1,z=foo', null, null)");

$output = output(
   sub { @servers = mysql_replication_monitor::get_monitored_servers(%args) }
);
is_deeply(
   \@servers,
   [
      {
         name              => 'master',
         dsn               => {
            h => '127.1',
            P => 12345,
            u => 'msandbox',
            p => undef,
            D => undef,
            t => undef,
            S => undef,
            F => undef,
            A => undef,
         },
         mk_heartbeat_file => 'hb',
      },
   ],
   "Skipped server with bad DSN part"
);

like(
   $output,
   qr/Failed to parse server bad DSN/,
   "Failed to parse bad server DSN"
);

# Test where optional arg to select only specific servers.
$master_dbh->do("insert into test.servers values ('slave', 'h=127.1,P=12347', null, null)");

$output = output(
   sub {
      @servers
         = mysql_replication_monitor::get_monitored_servers(
            %args, where=>'server="slave"')
   }
);
is_deeply(
   \@servers,
   [
      {
         name              => 'slave',
         dsn               => {
            h => '127.1',
            P => 12347,
            u => undef,
            p => undef,
            D => undef,
            t => undef,
            S => undef,
            F => undef,
            A => undef,
         },
         mk_heartbeat_file => undef,
      },
   ],
   "where"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
