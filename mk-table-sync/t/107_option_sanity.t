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
use Sandbox;
require "$trunk/mk-table-sync/mk-table-sync";

my $output;


# #############################################################################
# Issue 111: Make mk-table-sync require --print or --execute or --dry-run
# #############################################################################

# This test reuses the test.message table created above for issue 22.
$output = `$trunk/mk-table-sync/mk-table-sync h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=messages P=12346`;
like($output, qr/Specify at least one of --print, --execute or --dry-run/,
   'Requires --print, --execute or --dry-run');

# #############################################################################
# Don't let people try to restrict syncing with D=foo
# #############################################################################
$output = `$trunk/mk-table-sync/mk-table-sync h=localhost,D=test 2>&1`;
like($output, qr/Are you trying to sync/, 'Throws error on D=');

# #############################################################################
# Done.
# #############################################################################
exit;
