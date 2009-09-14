#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

require "../WatchProcesslist.pm";
require "../DSNParser.pm";
require "../Sandbox.pm";
require "../ProcesslistAggregator.pm";
require '../TextResultSetParser.pm';
require '../MaatkitTest.pm';

MaatkitTest->import(qw(load_file));

my $pla = new ProcesslistAggregator();
my $r   = new TextResultSetParser();
my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

my $proc;
sub show_processlist { return $proc };

$proc = $r->parse( load_file('samples/recset004.txt') );

my $w = new WatchProcesslist(
   params => 'state:Locked:count:<:1000',
   dbh    => 1,
   ProcesslistAggregator => $pla,
);
$w->set_callbacks( show_processlist => \&show_processlist );

is(
   $w->ok(),
   1,
   'Processlist locked count ok'
);

$w = new WatchProcesslist(
   params => 'state:Locked:count:<:10',
   dbh    => 1,
   ProcesslistAggregator => $pla,
);
$w->set_callbacks( show_processlist => \&show_processlist );

is(
   $w->ok(),
   0,
   'Processlist locked count not ok'
);
   
$w = new WatchProcesslist(
   params => 'db:forest:time:=:533',
   dbh    => 1,
   ProcesslistAggregator => $pla,
);
$w->set_callbacks( show_processlist => \&show_processlist );

is(
   $w->ok(),
   1,
   'Processlist db time ok'
);

is_deeply(
   [ $w->get_last_check() ],
   [ '533', '==', '533' ],
   'get_last_check()'
);

# ###########################################################################
# Online tests.
# ###########################################################################
SKIP: {
   skip 'Cannot connect to sandbox master', 1 unless $dbh;

   $w = new WatchProcesslist(
      params => 'command:Binlog Dump:count:=:1',
      dbh    => $dbh,
      ProcesslistAggregator => $pla,
   );

   is(
      $w->ok(),
      1,
      'Processlist count Binlog Dump count ok'
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
