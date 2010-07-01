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
require "$trunk/mk-parallel-restore/mk-parallel-restore";

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $basedir = '/tmp/dump/';
my $output;

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
