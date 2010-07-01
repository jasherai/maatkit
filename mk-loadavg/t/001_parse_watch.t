#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
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
