#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 12;

use WatchStatus;
use DSNParser;
use Sandbox;
use InnoDBStatusParser;
use MaatkitTest;

my $is  = new InnoDBStatusParser();
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('slave1');

my $status;

sub show_status {
   my ( $dbh, $var, %args ) = @_;
   return $status->{$var}->{Value};
}
sub show_innodb_status {
   my ( $dbh, $var, %args ) = @_;
   return $status;
}
sub show_slave_status {
   my ( $dbh, $var, %args ) = @_;
   return $status->{$var};
}

# ###########################################################################
# Test watching SHOW STATUS.
# ###########################################################################
my $w = new WatchStatus(
   params => 'status:Uptime:>:10',
   dbh    => 1,
);
$w->set_callbacks( show_status => \&show_status );

$status = {
  Uptime => {
    Value => '9693',
    Variable_name => 'Uptime'
  },
};

is(
   $w->check(),
   1,
   'Uptime ok'
);

$status = {
  Uptime => {
    Value => '5',
    Variable_name => 'Uptime'
  },
};

is(
   $w->check(),
   0,
   'Uptime not ok'
);

# ###########################################################################
# Test watching SHOW INNODB STATUS.
# ###########################################################################
$w = new WatchStatus(
   params => 'innodb:Innodb_buffer_pool_pages_free:>:10',
   dbh    => 1,
   InnoDBStatusParser => $is,
);
$w->set_callbacks( show_innodb_status => \&show_innodb_status );

$status = load_file('common/t/samples/is001.txt');

is(
   $w->check(),
   1,
   'InnoDB status ok'
);

$w = new WatchStatus(
   params => 'innodb:Innodb_buffer_pool_pages_free:>:500',
   dbh    => 1,
   InnoDBStatusParser => $is,
);
$w->set_callbacks( show_innodb_status => \&show_innodb_status );

is(
   $w->check(),
   0,
   'InnoDB status not ok'
);

# ###########################################################################
# Test watching SHOW INNODB STATUS.
# ###########################################################################
$w = new WatchStatus(
   params => 'slave:Seconds_Behind_Master:<:60',
   dbh    => 1,
);
$w->set_callbacks( show_slave_status => \&show_slave_status );

$status = {
  Seconds_Behind_Master => '50',
};

is(
   $w->check(),
   1,
   'Slave status ok'
);

$status = {
  Seconds_Behind_Master => '61',
};

is(
   $w->check(),
   0,
   'Slave status not ok'
);

is_deeply(
   [ $w->get_last_check() ],
   [ '61', '<', '60' ],
   'get_last_check()'
);

# ###########################################################################
# Online tests.
# ###########################################################################
SKIP: {
   skip 'Cannot connect to sandbox slave', 3 unless $dbh;

   $w = new WatchStatus(
      params => 'status:Uptime:>:5',
      dbh    => $dbh,
   );
   is(
      $w->check(),
      1,
      'Status ok (online)'
   );

   $w = new WatchStatus(
      params => 'InnoDB:Innodb_buffer_pool_pages_total:>:1',
      dbh    => $dbh,
      InnoDBStatusParser => $is,
   );
   is(
      $w->check(),
      1,
      'InnoDB status ok (online)'
   );

   $w = new WatchStatus(
      params => 'slave:Last_Errno:=:0',
      dbh    => $dbh,
   );
   is(
      $w->check(),
      1,
      'Slave status ok (online)'
   );
};

# ###########################################################################
# Test parsing params.
# ###########################################################################
my $param = 'status:Threads_connected:>:16';
eval{
   WatchStatus::parse_params($param);
};
is(
   $EVAL_ERROR,
   '',
   "Parses param: $param"
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $w->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
$sb->wipe_clean($dbh) if $dbh;
exit;
