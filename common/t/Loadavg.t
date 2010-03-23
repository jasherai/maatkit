#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 7;

use Loadavg;
use DSNParser;
use Sandbox;
use InnoDBStatusParser;
use MaatkitTest;

my $is  = new InnoDBStatusParser();
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $slave_dbh = $sb->get_dbh_for('slave1');

my $la = new Loadavg();

isa_ok($la, 'Loadavg');

like(
   $la->loadavg(),
   qr/[\d\.]+/,
   'system loadavg'
);

like(
   $la->status($dbh, metric=>'Uptime'),
   qr/\d+/,
   'status Uptime'
);

like(
   $la->innodb(
      $dbh,
      InnoDBStatusParser => $is,
      section            => 'status',
      var                => 'Innodb_data_fsyncs',
   ),
   qr/\d+/,
   'InnoDB stats'
);

is(
   $la->innodb(
      $dbh,
      InnoDBStatusParser => $is,
      section            => 'this section does not exist',
      var                => 'foo',
   ),
   0,
   'InnoDB stats for nonexistent section'
);

SKIP: {
   skip 'Cannot connect to sandbox slave1', 1 unless $slave_dbh;

   like(
      $la->slave_lag($slave_dbh),
      qr/\d+/,
      'slave lag'
   );
};

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $la->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
$sb->wipe_clean($dbh);
exit;
