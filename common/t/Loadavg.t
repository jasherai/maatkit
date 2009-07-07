#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

require "../Loadavg.pm";
require "../DSNParser.pm";
require "../Sandbox.pm";

my $dp  = new DSNParser();
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
