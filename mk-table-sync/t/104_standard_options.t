#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-table-sync/mk-table-sync";

my $output;

# Test DSN value inheritance.
$output = `$trunk/mk-table-sync/mk-table-sync h=127.1 h=127.2,P=12346 --port 12345 --explain-hosts`;
is(
   $output,
"# DSN: P=12345,h=127.1
# DSN: P=12346,h=127.2
",
   'DSNs inherit values from --port, etc. (issue 248)'
);

# #############################################################################
# Test --explain-hosts (issue 293).
# #############################################################################

# This is redundant; it crept in over time and I keep it for history.

$output = `$trunk/mk-table-sync/mk-table-sync --explain-hosts localhost,D=foo,t=bar t=baz`;
is($output,
<<EOF
# DSN: D=foo,h=localhost,t=bar
# DSN: D=foo,h=localhost,t=baz
EOF
, '--explain-hosts');

# #############################################################################
# Issue 391: Add --pid option to mk-table-sync
# #############################################################################
`touch /tmp/mk-table-sync.pid`;
$output = `$trunk/mk-table-sync/mk-table-sync h=127.1,P=12346,u=msandbox,p=msandbox --sync-to-master --print --no-check-triggers --pid /tmp/mk-table-sync.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-table-sync.pid already exists},
   'Dies if PID file already exists (issue 391)'
);

`rm -rf /tmp/mk-table-sync.pid`;

# #############################################################################
# Done.
# #############################################################################
exit;
