#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 10;

use MaatkitCommon;
use MaatkitTest;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

MaatkitCommon->import(qw(
   get_number_of_cpus
   _d
));

# #############################################################################
# Test get_number_of_cpus().
# #############################################################################
is(
   get_number_of_cpus('foo'),
   1,
   'get_number_of_cpus default 1'
);
   
is(
   get_number_of_cpus(load_file("common/t/samples/cpuinfo01.txt")),
   2,
   'get_number_of_cpus from /proc/cpuinfo'
);

is(
   get_number_of_cpus('hw.ncpu: 4'),
   4,
   'get_number_of_cpus from sysctl'
);

$ENV{NUMBER_OF_PROCESSORS} = 2;
is(
   get_number_of_cpus('foo'),
   2,
   'get_number_of_cpus from NUMBER_OF_PROCESSORS'
);

# #############################################################################
# Test _d().
# #############################################################################

sub test_d {
   my $output = '';
   local *STDERR;
   open STDERR, '>', \$output
      or die "Cannot capture STDERR to _d.output: $OS_ERROR";
   _d(@_);
   return $output;
}

like(
   test_d('alive'),
   qr/^# main:\d+ \d+ alive\n/,
   '_d lives'
);

like(
   test_d('val:', undef),
   qr/val: undef/,
   'Prints undef for undef'
);

like(
   test_d("foo\nbar"),
   qr/foo\n# bar\n/,
   'Breaks \n and adds #'
);

like(
   test_d('hi', 'there'),
   qr/hi there$/,
   'Prints space between args'
);

my %foo = (
   string => 'value',
   array  => [1],
);
like(
   test_d('Data::Dumper says', Dumper(\%foo)),
   qr/Data::Dumper says \$VAR1 = {\n/,
   'Data::Dumper'
);

my @foo = qw(1 2 3);
like(
   test_d('join array:', join(',', @foo)),
   qr/join array: 1,2,3$/,
   'join array'
);

# #############################################################################
# Done.
# #############################################################################
exit;
