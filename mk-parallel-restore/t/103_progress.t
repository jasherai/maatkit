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
my $output;

# This is kind of a contrived test, but it's better than nothing.
$output = `$cmd $trunk/mk-parallel-restore/t/samples/issue_31 --progress --dry-run`;
like($output, qr/done: [\d\.]+[Mk]\/[\d\.]+[Mk]/, 'Reporting progress by bytes');

# #############################################################################
# Done.
# #############################################################################
exit;
