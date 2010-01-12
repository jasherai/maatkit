#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 10;

use MaatkitTest;
require "$trunk/mk-kill/mk-kill";

sub output {
   my ( $args ) = @_;
   return `$trunk/mk-kill/mk-kill $args`;
}

# #############################################################################
# Test match commands.
# #############################################################################
like(
   output("$trunk/common/t/samples/recset001.txt --match-info show --print"),
   qr/KILL 9 \(Query 0 sec\) show processlist/,
   '--match-info'
);

is(
   output("$trunk/common/t/samples/recset002.txt --match-command Query --print"),
   '',
   'Ignore State=Locked by default'
);

like(
   output("$trunk/common/t/samples/recset002.txt --match-command Query --ignore-state '' --print"),
   qr/KILL 2 \(Query 5 sec\) select \* from foo2/,
   "Can override default ignore State=Locked with --ignore-state ''"
);

like(
   output("$trunk/common/t/samples/recset003.txt --match-state 'Sorting result' --print"),
   qr/KILL 29393378 \(Query 3 sec\)/,
   '--match-state'
);

like(
   output("$trunk/common/t/samples/recset003.txt --match-state Updating --print --no-only-oldest"),
   qr/KILL 29393612.+KILL 29393640/s,
   '--no-only-oldest'
);

like(
   output("$trunk/common/t/samples/recset003.txt --ignore-user remote --match-command Query --print"),
   qr/KILL 29393138/,
   '--ignore-user'
);

like(
   output("$trunk/common/t/samples/recset004.txt --busy-time 25 --print"),
   qr/KILL 54595/,
   '--busy-time'
);

is(
   output("$trunk/common/t/samples/recset004.txt --busy-time 30 --print"),
   '',
   '--busy-time but no query is busy enough'
);

like(
   output("$trunk/common/t/samples/recset005.txt --idle-time 15 --print"),
   qr/KILL 29392005 \(Sleep 17 sec\) NULL/,
   '--idle-time'
);

like(
   output("$trunk/common/t/samples/recset006.txt --match-state Locked --ignore-state '' --busy-time 5 --print"),
   qr/KILL 2 \(Query 9 sec\) select \* from foo2/,
   "--match-state Locked --ignore-state '' --busy-time 5"
);

# #############################################################################
# Done.
# #############################################################################
exit;
