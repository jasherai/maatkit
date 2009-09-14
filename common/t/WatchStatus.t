#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 10;

require "../WatchStatus.pm";
require "../DSNParser.pm";
require "../Sandbox.pm";
require "../MaatkitTest.pm";
require "../InnoDBStatusParser.pm";

MaatkitTest->import(qw(load_file));

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $is  = new InnoDBStatusParser();
my $dp  = new DSNParser();
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
   $w->ok(),
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
   $w->ok(),
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

$status = load_file('samples/is001.txt');

is(
   $w->ok(),
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
   $w->ok(),
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
   $w->ok(),
   1,
   'Slave status ok'
);

$status = {
  Seconds_Behind_Master => '61',
};

is(
   $w->ok(),
   0,
   'Slave status not ok'
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
      $w->ok(),
      1,
      'Status ok (online)'
   );

   $w = new WatchStatus(
      params => 'InnoDB:Innodb_buffer_pool_pages_total:>:1',
      dbh    => $dbh,
      InnoDBStatusParser => $is,
   );
   is(
      $w->ok(),
      1,
      'InnoDB status ok (online)'
   );

   $w = new WatchStatus(
      params => 'slave:Last_Errno:=:0',
      dbh    => $dbh,
   );
   is(
      $w->ok(),
      1,
      'Slave status ok (online)'
   );
};

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
