#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 8;

use MaatkitTest;
require "$trunk/util/slowlog-to-outfile";

my $cmd    = "$trunk/util/slowlog-to-outfile";
my $sample = "$trunk/common/t/samples/";
my $output = '';

$output = `$cmd $sample/slow001.txt`;
is(
   $output,
"0x7F7D57ACDD8A346E\t2007-10-15 21:43:52\t\\N\t2\t0\t1\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\ttest\tselect sleep(?) from n\tselect sleep(2) from n
0x3A99CC42AEDCCFCD\t2007-10-15 21:45:10\t\\N\t2\t0\t1\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\tsakila\tselect sleep(?) from test.n\tselect sleep(2) from test.n
",
   "slow001.txt"
);

$output = `$cmd --attributes db,ts,arg $sample/slow001.txt`;
is(
   $output,
"test\t2007-10-15 21:43:52\tselect sleep(2) from n
sakila\t2007-10-15 21:45:10\tselect sleep(2) from test.n
",
   "slow001.txt --attributes db,ts,arg"
);

$output = `$cmd --filter '\$event->{db} eq "sakila"' $sample/slow001.txt`;
is(
   $output,
"0x3A99CC42AEDCCFCD\t2007-10-15 21:45:10\t\\N\t2\t0\t1\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\tsakila\tselect sleep(?) from test.n\tselect sleep(2) from test.n
",
   "slow001.txt --filter"
);

$output = `$cmd --filter '\$event->{arg} =~ m/899/' $sample/slow002.txt`;
is(
   $output,
"0x6969975466519B81\t\\N\t10\t0.000530\t0.000027\t0\t0\tNo\tNo\tNo\tNo\tNo\tNo\tNo\t0\t0\t0\t0.000000\t0.000000\t0.000000\t18\t\\N\t\\N\t\\N\t\\N\tupdate bizzle.bat set boop=? where fillze=?\tUPDATE bizzle.bat SET    boop='bop: 899' WHERE  fillze='899'
",
   "slow002.txt multi-line arg, InnoDB attributes"
);

$output = `$cmd $sample/slow003.txt`;
is(
   $output,
"0x85FFF5AA78E5FF6A\t2007-12-18 11:48:27\t10\t0.000012\t0.000000\t0\t0\tNo\tNo\tNo\tNo\tNo\tNo\tNo\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\tbegin\tBEGIN
",
   "slow003.txt"
);

# Fingerprints are required for checksums.
#$output = `$cmd --no-fingerprints $sample/slow003.txt`;
#is(
#   $output,
#"2007-12-18 11:48:27\t10\t0.000012\t0.000000\t0\t0\tNo\tNo\tNo\tNo\tNo\tNo\tNo\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\tBEGIN
#",
#   "slow003.txt --no-fingerprints"
#);

$output = `$cmd $sample/slow004.txt`;
is(
   $output,
"0xB16C9E5B3D9C484F\t2007-10-15 21:43:52\t\\N\t2\t0\t1\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\tselect ?_?_foo from (select ?oo from ?_bar) as ?z\tselect 12_13_foo from (select 12foo from 123_bar) as 123baz
",
   "slow004.txt"
);

$output = `$cmd $sample/slow044.txt`;
is(
   $output,
"0x7CE9953EA3A36141\t2010-05-25 10:22:00\t342\t0.000173\t0.000048\t18\t18\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t1\t2\t\\N\t\\N\tselect foo\tselect /*this is only parsable by slowlog-to-outfile, not by mqd*/ foo
0x7CE9953EA3A36141\t2010-05-25 10:22:00\t342\t0.000173\t0.000048\t19\t19\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t3\t4\t\\N\t\\N\tselect foo\tselect /*this is only parsable by slowlog-to-outfile, not by mqd*/ foo
",
   "Schema: Last_errno: 1"
);

$output = `$cmd $sample/slow045.txt`;
is(
   $output,
"0xB5C92ABD838A97F9\t\\N\t342\t0.000173\t0.000048\t18\t18\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t0\t0\t839DE234\tdb1\tselect col from tbl\tselect /*not for mqd*/ col from tbl
0x813031B8BBC3B329\t\\N\t342\t0.000019\t0.000000\t0\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t0\t0\t839DE234\tdb1\tcommit\tcommit
",
   "Add InnoDB_trx_id to COMMIT from same Thread_id"
);

# #############################################################################
# Done.
# #############################################################################
exit;
