#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use WatchProcesslist;
use DSNParser;
use Sandbox;
use ProcesslistAggregator;
use TextResultSetParser;
use MaatkitTest;

my $pla = new ProcesslistAggregator();
my $r   = new TextResultSetParser();
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

my $proc;
sub show_processlist { return $proc };

$proc = $r->parse( load_file('common/t/samples/pl/recset004.txt') );

my $w = new WatchProcesslist(
   params => 'state:Locked:count:<:1000',
   dbh    => 1,
   ProcesslistAggregator => $pla,
);
$w->set_callbacks( show_processlist => \&show_processlist );

is(
   $w->check(),
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
   $w->check(),
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
   $w->check(),
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
      $w->check(),
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
