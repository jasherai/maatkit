#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# ###########################################################################
# Issue 391: Add --pid option to all scripts
# ###########################################################################
`touch /tmp/mk-script.pid`;
$output = `$cmd -D test $basedir --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
diag(`rm -rf /tmp/mk-script.pid`);


# #############################################################################
# Done.
# #############################################################################
exit;
