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
require "$trunk/util/mysql-rmf/mysql-failover";

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 16;
}

my $output = '';
my $cnf    = "/tmp/12345/my.sandbox.cnf";
my $cmd    = "$trunk/util/mysql-rmf/mysql-replication-monitor";

$dbh->do('drop database if exists repl');
$dbh->do('create database repl');

`$cmd --create-servers-table --create-state-table --servers F=$cnf,t=repl.servers --state F=$cnf,t=repl.state --run-once --quiet --check-logs none`;

$dbh->do("insert into repl.state set
   observer='daniel',
   server='m1',
   position=90,
   file='mysql-bin.2900',
   master_log_file='mysql-bin.2901',
   read_master_log_pos=190,
   relay_master_log_file='mysql-bin.2901',
   exec_master_log_pos=140,
   connection_ok=1,
   slave_io_running=1,
   slave_sql_running=1,
   master_host='m2',
   master_port=2091,
   ts=NOW()");

my @s1_slave;
my @s1_master;
my @m2_slave;
my @m2_master;

my %s1_slave = (
   _name                 => 's1 slave',
   master_host           => '127.0.0.1',
   master_port           => 2900,
   master_log_file       => 'mysql-bin.2900',
   read_master_log_pos   => 100,
   relay_master_log_file => 'mysql-bin.2900',
   slave_io_running      => 'Yes',
   slave_sql_running     => 'Yes',
   exec_master_log_pos   => 100,
);
my %s1_master = (
   _name                 => 's1 master',
   position => 550,
   file     => 'mysql-bin.2902',
);
my %m2_slave = (
   _name                 => 'm2 slave',
   master_host           => '127.0.0.1',
   master_port           => 2900,
   master_log_file       => 'mysql-bin.2900',
   read_master_log_pos   => 120,
   relay_master_log_file => 'mysql-bin.2900',
   slave_io_running      => 'Yes',
   slave_sql_running     => 'Yes',
   exec_master_log_pos   => 120,
);
my %m2_master = (
   _name                 => 'm2 master',
   position => 380,
   file     => 'mysql-bin.2901',
);

my $dead_master = { name => 'm1' };
my $new_master  = { name => 's1', dsn => {h=>'127.1', P=>2902} };
my $live_master = { name => 'm2' };
my $servers     = { dbh => $dbh, tbl => 'repl.servers' };
my $state       = { dbh => $dbh, tbl => 'repl.state'   };

sub my_get_status {
   my ( $what, $server ) = @_;
   my $sql = "SHOW " . uc($what) . " STATUS /* $server->{name} */";
   mysql_failover::_log($sql);
   my $status;
   if ( $what eq 'master' ) {
      if ( $server->{name} eq 's1' ) {
         $status = shift @s1_master;
      }
      else {
         $status = shift @m2_master;
      }
   }
   else {  # SLAVE status
      if ( $server->{name} eq 's1' ) {
         $status = shift @s1_slave;
      }
      else {
         $status = shift @m2_slave;
      }
   }
   return $status;
};

undef *mysql_failover::get_status;
*mysql_failover::get_status = \&my_get_status;

# First get_status() to see if new pos > live pos.
push @s1_slave,  { %s1_slave  };
push @m2_slave,  { %m2_slave  };

# 2nd get_status() after new master_pos_wait.
push @s1_slave,  { %s1_slave  };

# First get_status() caught up new Position.
push @s1_master, { %s1_master };

# get_status() after live master_pos_wait.
push @m2_slave,  { %m2_slave  };

$output = output(
   sub {
      mysql_failover::failover(
         dead_master => $dead_master,
         new_master  => $new_master,
         live_master => $live_master,
         servers     => $servers,
         state       => $state,
         dry_run     => 1,
      )
   },
);

like(
   $output,
   qr/SELECT MASTER_POS_WAIT\('mysql-bin.2900', 100, 60\) \/\* s1 \*\//,
   "s1 < m2, wait s1"
);

like(
   $output,
   qr/SELECT MASTER_POS_WAIT\('mysql-bin.2900', 120, 60\) \/\* m2 \*\//,
   "s1 < m2, wait m2"
);

like(
   $output,
   qr/CHANGE MASTER TO MASTER_HOST='m2', MASTER_PORT=2091, MASTER_LOG_FILE='mysql-bin.2901', MASTER_LOG_POS=140 \/\* s1 \*\//,
   "s1 < m2, change s1 master"
);

like(
   $output,
   qr/CHANGE MASTER TO MASTER_HOST='127.1', MASTER_PORT=2902, MASTER_LOG_FILE='mysql-bin.2902', MASTER_LOG_POS=550 \/\* m2 \*\//,
   "s1 < m2, change m2 master"
);


# #############################################################################
# s1 = m2
# #############################################################################

# First get_status() to see if new pos > live pos.
push @s1_slave, {
   %s1_slave,
   read_master_log_pos => 120,
   exec_master_log_pos => 100,
};
push @m2_slave,  { %m2_slave  };

# 2nd get_status() after new master_pos_wait.
push @s1_slave,  {
   %s1_slave,
   read_master_log_pos => 120,
   exec_master_log_pos => 120,
};

# First get_status() caught up new Position.
push @s1_master, { %s1_master };

# get_status() after live master_pos_wait.
push @m2_slave,  { %m2_slave  };

$output = output(
   sub {
      mysql_failover::failover(
         dead_master => $dead_master,
         new_master  => $new_master,
         live_master => $live_master,
         servers     => $servers,
         state       => $state,
         dry_run     => 1,
      )
   },
);

like(
   $output,
   qr/SELECT MASTER_POS_WAIT\('mysql-bin.2900', 120, 60\) \/\* s1 \*\//,
   "s1 = m2, wait s1"
);

like(
   $output,
   qr/SELECT MASTER_POS_WAIT\('mysql-bin.2900', 120, 60\) \/\* m2 \*\//,
   "s1 = m2, wait m2"
);

like(
   $output,
   qr/CHANGE MASTER TO MASTER_HOST='m2', MASTER_PORT=2091, MASTER_LOG_FILE='mysql-bin.2901', MASTER_LOG_POS=140 \/\* s1 \*\//,
   "s1 = m2, change s1 master"
);

like(
   $output,
   qr/CHANGE MASTER TO MASTER_HOST='127.1', MASTER_PORT=2902, MASTER_LOG_FILE='mysql-bin.2902', MASTER_LOG_POS=550 \/\* m2 \*\//,
   "s1 = m2, change m2 master"
);


# #############################################################################
# m1 > live
# #############################################################################

# First get_status() to see if new pos > live pos.
push @s1_slave, {
   %s1_slave,
   read_master_log_pos => 100,
   exec_master_log_pos => 69,
};
push @m2_slave, {
   %m2_slave,
   read_master_log_pos => 70,
   exec_master_log_pos => 60,
};

# First get_status() caught up new, common Position.
push @s1_master, {
   %s1_master,
   position => 442,  # m2 should start at this pos
};

# 2nd get_status() after new master_pos_wait.
push @s1_slave,  {
   %s1_slave,
   read_master_log_pos => 100,
   exec_master_log_pos => 100,
};

# get_status() after live master_pos_wait.
push @m2_slave, {
   %m2_slave,
   read_master_log_pos => 70,
   exec_master_log_pos => 70,
};

$output = output(
   sub {
      mysql_failover::failover(
         dead_master => $dead_master,
         new_master  => $new_master,
         live_master => $live_master,
         servers     => $servers,
         state       => $state,
         dry_run     => 1,
      )
   },
);

unlike(
   $output,
   qr/ WARNING /,
   "s1 > m2, no warning"
);

like(
   $output,
   qr/STOP SLAVE SQL_THREAD \/\* s1 \*\//,
   "s1 > m2, stop s1 sql thread"
);

like(
   $output,
   qr/START SLAVE SQL_THREAD UNTIL MASTER_LOG_FILE='mysql-bin.2900', MASTER_LOG_POS=70/,
   "s1 > m2, start sql thread until m2 pos"
);

like(
   $output,
   qr/SELECT MASTER_POS_WAIT\('mysql-bin.2900', 100, 60\) \/\* s1 \*\//,
   "s1 > m2, wait s1"
);

like(
   $output,
   qr/SELECT MASTER_POS_WAIT\('mysql-bin.2900', 70, 60\) \/\* m2 \*\//,
   "s1 > m2, wait m2"
);

like(
   $output,
   qr/CHANGE MASTER TO MASTER_HOST='m2', MASTER_PORT=2091, MASTER_LOG_FILE='mysql-bin.2901', MASTER_LOG_POS=140 \/\* s1 \*\//,
   "s1 > m2, change s1 master"
);

like(
   $output,
   qr/CHANGE MASTER TO MASTER_HOST='127.1', MASTER_PORT=2902, MASTER_LOG_FILE='mysql-bin.2902', MASTER_LOG_POS=442 \/\* m2 \*\//,
   "s1 > m2, change m2 master"
);

# #############################################################################
# s1 exec > m2 read == bad, m2 will writes
# #############################################################################

# First get_status() to see if new pos > live pos.
push @s1_slave, {
   %s1_slave,
   read_master_log_pos => 100,
   exec_master_log_pos => 71,
};
push @m2_slave, {
   %m2_slave,
   read_master_log_pos => 70,
   exec_master_log_pos => 60,
};

# First get_status() caught up new, common Position.
push @s1_master, {
   %s1_master,
   position => 442,  # m2 should start at this pos
};

# 2nd get_status() after new master_pos_wait.
push @s1_slave,  {
   %s1_slave,
   read_master_log_pos => 100,
   exec_master_log_pos => 100,
};

# get_status() after live master_pos_wait.
push @m2_slave, {
   %m2_slave,
   read_master_log_pos => 70,
   exec_master_log_pos => 70,
};

$output = output(
   sub {
      mysql_failover::failover(
         dead_master => $dead_master,
         new_master  => $new_master,
         live_master => $live_master,
         servers     => $servers,
         state       => $state,
         dry_run     => 1,
      )
   },
);

like(
   $output,
   qr/ WARNING /,
   "s1 exec > m2 read, warning"
);

# #############################################################################
# Done.
# #############################################################################
exit;
