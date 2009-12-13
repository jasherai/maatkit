#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../mk-upgrade';

my $cmd = '../mk-upgrade h=127.1,P=12345 P=12347 --compare results,warnings --zero-query-times';

# Issue 391: Add --pid option to all scripts
`touch /tmp/mk-script.pid`;
my $output = `$cmd samples/001/select-one.log --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
exit;
