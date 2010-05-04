#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use MaatkitTest;
require "$trunk/util/slowlog-to-outfile";

my $cmd    = "$trunk/util/slowlog-to-outfile";
my $sample = "$trunk/common/t/samples/";
my $output = '';

$output = `$cmd $sample/slow001.txt`;
is(
   $output,
"071015 21:43:52\t\\N\t2\t0\t1\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\ttest\tselect sleep(2) from n
071015 21:45:10\t\\N\t2\t0\t1\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\tsakila\tselect sleep(2) from test.n
",
   "slow001.txt"
);

$output = `$cmd --attributes db,ts,arg $sample/slow001.txt`;
is(
   $output,
"test\t071015 21:43:52\tselect sleep(2) from n
sakila\t071015 21:45:10\tselect sleep(2) from test.n
",
   "slow001.txt --attributes db,ts,arg"
);

$output = `$cmd --filter '\$event->{db} eq "sakila"' $sample/slow001.txt`;
is(
   $output,
"071015 21:45:10\t\\N\t2\t0\t1\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\tsakila\tselect sleep(2) from test.n
",
   "slow001.txt --filter"
);

$output = `$cmd --filter '\$event->{arg} =~ m/899/' $sample/slow002.txt`;
is(
   $output,
"\\N\t10\t0.000530\t0.000027\t0\t0\tNo\tNo\tNo\tNo\tNo\tNo\tNo\t0\t0\t0\t0.000000\t0.000000\t0.000000\t18\t\\N\tUPDATE bizzle.bat SET    boop='bop: 899' WHERE  fillze='899'
",
   "slow002.txt multi-line arg, InnoDB attributes"
);

$output = `$cmd $sample/slow003.txt`;
is(
   $output,
"071218 11:48:27\t10\t0.000012\t0.000000\t0\t0\tNo\tNo\tNo\tNo\tNo\tNo\tNo\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\tBEGIN
",
   "slow003.txt"
);

$output = `$cmd $sample/slow004.txt`;
is(
   $output,
"071015 21:43:52\t\\N\t2\t0\t1\t0\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\t\\N\tselect 12_13_foo from (select 12foo from 123_bar) as 123baz
",
   "slow004.txt"
);

# #############################################################################
# Done.
# #############################################################################
exit;
