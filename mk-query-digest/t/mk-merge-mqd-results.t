#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use MaatkitTest;
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift

my $cmd       = "$trunk/mk-query-digest/mk-merge-mqd-results --report-format header,query_report,profile";
my $mqd       = "$trunk/mk-query-digest/mk-query-digest --report-format header,query_report,profile";
my $sample    = "$trunk/common/t/samples/";
my $ressample = "$trunk/mk-query-digest/t/samples/save-results/";
my $resdir    = "/tmp/mqd-res/";
my $diff      = "";

diag(`rm -rf $resdir ; mkdir $resdir`);

`$mqd $sample/slow002.txt    > $resdir/orig`;
`$cmd $ressample/slow002.txt > $resdir/mrgd`;

# A difference is expect.  The original saw all 7 unique queries,
# but only the top worst query was saved so the merged report only
# differs in that it reports 1 unique query instead of 7.
$diff = `diff $resdir/orig $resdir/mrgd`;
is(
   $diff,
"2c2
< # Overall: 8 total, 7 unique, 0 QPS, 0x concurrency ______________________
---
> # Overall: 8 total, 1 unique, 0 QPS, 0x concurrency ______________________
",
   "slow002.txt default results"
);

# Going to have a similar diff: mrgd sees only the 3 unique queries
# that were saved instead of the original 7.
diag(`rm -rf $resdir/*`);
`$mqd $sample/slow002.txt --limit 3            > $resdir/orig`;
`$cmd $ressample/slow002-limit-3.txt --limit 3 > $resdir/mrgd`;
$diff = `diff $resdir/orig $resdir/mrgd`;
is(
   $diff,
"2c2
< # Overall: 8 total, 7 unique, 0 QPS, 0x concurrency ______________________
---
> # Overall: 8 total, 3 unique, 0 QPS, 0x concurrency ______________________
",
   "slow002.txt --limit 3 results"
);


# #############################################################################
# A more realistic example, merging 3 different results.
# #############################################################################
diag(`rm -rf $resdir/*`);
`$mqd $sample/slow002.txt $sample/slow006.txt $sample/slow028.txt > $resdir/orig`;
`$cmd $ressample/slow002.txt $ressample/slow006.txt $ressample/slow028.txt > $resdir/mrgd`;

# merge-mqd-results is more correct than mqd in this case because mqd
# --inherit-attributes is causing a query to inherit db foo from a previous
# query in a different file which is probably wrong/misleading.  Ran
# separately, the 3 slowlogs have 4 unique queries (w/ default 95% --limit),
# so the new "4 unique" is correct, too.
$diff = `diff $resdir/orig $resdir/mrgd`;
is(
   $diff,
'2c2
< # Overall: 15 total, 10 unique, 0.00 QPS, 0.00x concurrency ______________
---
> # Overall: 15 total, 4 unique, 0.00 QPS, 0.00x concurrency _______________
29d28
< # Databases              1     foo
42,43c41,42
< #    SHOW TABLE STATUS FROM `foo` LIKE \'a\'\G
< #    SHOW CREATE TABLE `foo`.`a`\G
---
> #    SHOW TABLE STATUS LIKE \'a\'\G
> #    SHOW CREATE TABLE `a`\G
',
   "slow002.txt, slow006.txt, slow0028.txt"
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $resdir`);
exit;
