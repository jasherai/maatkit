#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use MaatkitTest;
require "$trunk/mk-loadavg/mk-loadavg";

my $output;
my $watch;

# ###########################################################################
# Test parse_watch().
# ###########################################################################
$watch = 'Status:status:Threads_connected:>:16,Processlist:command:Query:time:<:1,Server:vmstat:free:=:0';

is_deeply(
   [ mk_loadavg::parse_watch($watch) ],
   [
      [ 'Status',       'status:Threads_connected:>:16', ],
      [ 'Processlist',  'command:Query:time:<:1',        ],
      [ 'Server',       'vmstat:free:=:0',               ],
   ],
   'parse_watch()'
);

# #############################################################################
# Done.
# #############################################################################
exit;
