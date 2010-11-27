#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-kill/mk-kill";

my $sample = "$trunk/common/t/samples/pl/";
my $output;

# #############################################################################
# Issue 1181: Make mk-kill prevent cache stampedes
# #############################################################################

# The 3rd query (id 4) is user=root.  Next we'll test that we can filter
# that one out.
$output = output(
   sub { mk_kill::main("$sample/recset010.txt", qw(--print),
      qw(--group-by info --query-count 2 --each-busy-time 2 --all),
      qw(--all-but-oldest --print)); }
);
like(
   $output,
   qr/# \S+ KILL 3 \(Query 9 sec\) select c from t where id='foo';\n# \S+ KILL 2 \(Query 9 sec\) select c from t where id='foo';\n# \S+ KILL 4 \(Query 5 sec\) select c from t where id='foo';/,
   "Kill all but oldest"
);

# Now with --match-user user1, the 3rd query is not matched.
$output = output(
   sub { mk_kill::main("$sample/recset010.txt", qw(--print),
      qw(--group-by info --query-count 2 --each-busy-time 2 --match-user user1),
      qw(--all-but-oldest --print)); }
);
like(
   $output,
   qr/# \S+ KILL 3 \(Query 9 sec\) select c from t where id='foo';\n# \S+ KILL 2 \(Query 9 sec\) select c from t where id='foo';/,
   "Kill all but oldest, matching specific user"
);

# Nothing matches because --each-busy-time isn't satifised.
$output = output(
   sub { mk_kill::main("$sample/recset010.txt", qw(--print),
      qw(--group-by info --query-count 2 --each-busy-time 10 --match-user user1),
      qw(--all-but-oldest --print)); }
);
is(
   $output,
   "",
   "Each busy time doesn't match"
);

# Each busy time matches on the lowest possible value.
$output = output(
   sub { mk_kill::main("$sample/recset010.txt", qw(--print),
      qw(--group-by info --query-count 2 --each-busy-time 9 --match-user user1),
      qw(--all-but-oldest --print)); }
);
like(
   $output,
   qr/# \S+ KILL 3 \(Query 9 sec\) select c from t where id='foo';\n# \S+ KILL 2 \(Query 9 sec\) select c from t where id='foo';/,
   "Each busy time matches"
);

# Nothing matches because --query-count isn't satisified.
$output = output(
   sub { mk_kill::main("$sample/recset010.txt", qw(--print),
      qw(--group-by info --query-count 3 --each-busy-time 1 --match-user user1),
      qw(--all-but-oldest --print)); }
);
is(
   $output,
   "",
   "Query count doesn't match"
);

# #############################################################################
# Done.
# #############################################################################
exit;
