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
shift @INC;  # These shifts are required for tools that use base and derived
shift @INC;  # classes.  See mk-query-digest/t/101_slowlog_analyses.t
require "$trunk/mk-variable-advisor/mk-variable-advisor";

my $cmd = "$trunk/mk-variable-advisor/mk-variable-advisor";
my $output;

$output = `$cmd --source-of-variables=/tmp/foozy-fazzle-bad-file 2>&1`;
like(
   $output,
   qr/--source-of-variables file \S+ does not exist/,
   "--source-of-variables file doesn't exit"
);

$output = `$cmd --source-of-variables mysql 2>&1`;
like(
   $output,
   qr/DSN must be specified/,
   "--source-of-variablels=mysql requires DSN"
);

# #############################################################################
# Done.
# #############################################################################
exit;
