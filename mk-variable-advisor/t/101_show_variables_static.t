#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use MaatkitTest;
shift @INC;  # These two shifts are required for tools that use base and
shift @INC;  # derived classes.  See mk-query-digest/t/101_slowlog_analyses.t
require "$trunk/mk-variable-advisor/mk-variable-advisor";

# #############################################################################
# SHOW VARIABLES from text files.
# #############################################################################
my @args   = qw();
my $sample = "$trunk/common/t/samples/show-variables/";

ok(
   no_diff(
      sub { mk_variable_advisor::main(@args,
         qw(--show-variables), "$sample/vars001.txt") },
      "mk-variable-advisor/t/vars001.txt",
   ),
   "vars001.txt"
);

ok(
   no_diff(
      sub { mk_variable_advisor::main(@args,
         qw(-v --show-variables), "$sample/vars001.txt") },
      "mk-variable-advisor/t/vars001-verbose.txt",
   ),
   "vars001.txt --verbose"
);

ok(
   no_diff(
      sub { mk_variable_advisor::main(@args,
         qw(-v -v --show-variables), "$sample/vars001.txt") },
      "mk-variable-advisor/t/vars001-verbose-verbose.txt",
   ),
   "vars001.txt --verbose --verbose"
);

ok(
   no_diff(
      sub { mk_variable_advisor::main(@args,
         qw(--show-variables), "$sample/vars001.txt",
         qw(--ignore-rules), "sync_binlog,myisam_recover_options") },
      "mk-variable-advisor/t/vars001-ignore-rules.txt",
   ),
   "--ignore-rules"
);

# #############################################################################
# Done.
# #############################################################################
exit;
