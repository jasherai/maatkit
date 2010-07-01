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
use Sandbox;
require "$trunk/mk-log-player/mk-log-player";

my $output;

# #############################################################################
# Issue 391: Add --pid option to all scripts
# #############################################################################
`touch /tmp/mk-script.pid`;
$output = `$trunk/mk-log-player/mk-log-player --split Thread_id $trunk/common/t/samples/binlog001.txt --type binlog --session-files 1  --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
exit;
