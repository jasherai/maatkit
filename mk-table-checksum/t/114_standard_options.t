#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use MaatkitTest;
require "$trunk/mk-table-checksum/mk-table-checksum";

my $output;

# Test DSN value inheritance
$output = `$trunk/mk-table-checksum/mk-table-checksum h=127.1 h=127.2,P=12346 --port 12345 --explain-hosts`;
like(
   $output,
   qr/^Server 127.1:\s+P=12345,h=127.1\s+Server 127.2:\s+P=12346,h=127.2/,
   'DSNs inherit values from --port, etc. (issue 248)'
);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `$trunk/mk-table-checksum/mk-table-checksum h=127.1,P=12345,u=msandbox,p=msandbox -d test -t issue_122,issue_94 --pid /tmp/mk-script.pid 2>&1`;
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
