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
require "$trunk/mk-visual-explain/mk-visual-explain";

sub run {
   my $output = '';
   open OUTPUT, '>', \$output
      or die 'Cannot open output to variable';
   select OUTPUT;
   mk_visual_explain::main(@_);
   select STDOUT;
   close $output;
   return $output;
}

like(
   run("$trunk/mk-visual-explain/t/samples/simple_union.sql"),
   qr/\+\- UNION/,
   'Read optional input file (issue 394)',
);

like(
   run("$trunk/mk-visual-explain/t/samples/simple_union.sql", qw(--format dump)),
   qr/\$VAR1 = {/,
   '--format dump (issue 393)'
);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
my $output = `$trunk/mk-visual-explain/mk-visual-explain $trunk/mk-visual-explain/t/samples/simple_union.sql --format dump --pid /tmp/mk-script.pid 2>&1`;
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
