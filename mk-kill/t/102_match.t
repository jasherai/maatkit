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

my $output;

# #############################################################################
# Test match commands.
# #############################################################################
$output = output(
   sub { mk_kill::main("$trunk/common/t/samples/recset001.txt", qw(--match-info show --print)); }
);
like(
   $output,
   qr/KILL 9 \(Query 0 sec\) show processlist/,
   '--match-info'
);

$output = output(
   sub { mk_kill::main("$trunk/common/t/samples/recset002.txt", qw(--match-command Query --print)); }
);
is(
   $output,
   '',
   'Ignore State=Locked by default'
);

$output = output(
   sub { mk_kill::main("$trunk/common/t/samples/recset002.txt", qw(--match-command Query --ignore-state), "''", "--print"); }
);
like(
   $output,
   qr/KILL 2 \(Query 5 sec\) select \* from foo2/,
   "Can override default ignore State=Locked with --ignore-state ''"
);

$output = output(
   sub { mk_kill::main("$trunk/common/t/samples/recset003.txt", "--match-state", "Sorting result", "--print"); }
);
like(
   $output,
   qr/KILL 29393378 \(Query 3 sec\)/,
   '--match-state'
);

$output = output(
   sub { mk_kill::main("$trunk/common/t/samples/recset003.txt", qw(--match-state Updating --print --no-only-oldest)); }
);
like(
   $output,
   qr/KILL 29393612.+KILL 29393640/s,
   '--no-only-oldest'
);

$output = output(
   sub { mk_kill::main("$trunk/common/t/samples/recset003.txt", qw(--ignore-user remote --match-command Query --print)); }
);
like(
   $output,
   qr/KILL 29393138/,
   '--ignore-user'
);

$output = output(
   sub { mk_kill::main("$trunk/common/t/samples/recset004.txt", qw(--busy-time 25 --print)); }
);
like(
   $output,
   qr/KILL 54595/,
   '--busy-time'
);

$output = output(
   sub { mk_kill::main("$trunk/common/t/samples/recset004.txt", qw(--busy-time 30 --print)); }
);
is(
   $output,
   '',
   '--busy-time but no query is busy enough'
);

$output = output(
   sub { mk_kill::main("$trunk/common/t/samples/recset005.txt", qw(--idle-time 15 --print)); }
);
like(
   $output,
   qr/KILL 29392005 \(Sleep 17 sec\) NULL/,
   '--idle-time'
);

$output = output(
   sub { mk_kill::main("$trunk/common/t/samples/recset006.txt", qw(--match-state Locked --ignore-state), "''", qw(--busy-time 5 --print)); }
);
like(
   $output,
   qr/KILL 2 \(Query 9 sec\) select \* from foo2/,
   "--match-state Locked --ignore-state '' --busy-time 5"
);

# #############################################################################
# Done.
# #############################################################################
exit;
