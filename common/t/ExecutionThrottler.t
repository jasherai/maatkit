#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 10;

require '../ExecutionThrottler.pm';

use Time::HiRes qw(usleep);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

my $rate    = 100;
my $oktorun = 1;
my %args = (
   event   => { arg => 'query', Skip_exec => 'No', },
   oktorun => sub { return $oktorun; },
);
my $get_rate = sub { return $rate; };

my $et = new ExecutionThrottler(
   rate_max  => 90,
   get_rate  => $get_rate,
   check_int => 0.4,
   step      => 0.8,
);

isa_ok($et, 'ExecutionThrottler');

# This event won't be checked because 0.4 seconds haven't passed
# so Skip_exec should still be 0 even though the rate is past max.
is_deeply(
   $et->throttle(%args),
   $args{event},
   'Event before first check'
);

# Since the event above wasn't checked, the skip prop should still be zero.
is(
   $et->skip_probability,
   0.0,
   'Zero skip prob'
);

# Let a time interval pass, 0.4s.
usleep 450000;

# This event will be checked because a time interval has passed.
# The avg int rate will be 100, so skip prop should be stepped up
# by 0.8 and Skip_exec will have an 80% chance of being set true.
# Therefore, this test will fail 20% of the time.  :-)
my $event = $et->throttle(%args);
is(
   $event->{Skip_exec},
   'Yes',
   'Event after check, exceeds rate max, Skip_exec = Yes'
);

is(
   $et->skip_probability,
   0.8,
   'Skip prob stepped by 0.8'
);

# Inject another rate sample and then sleep until the next check.
$rate = 50;
$et->throttle(%args);
usleep 450000;

# This event should be ok because the avg rate dropped below max.
# skip prob should be stepped down by 0.8, to zero.
is_deeply(
   $et->throttle(%args),
   $args{event},
   'Event ok at min rate'
);

is(
   $et->skip_probability,
   0,
   'Skip prob stepped down'
);

# Increase the rate to max and check that it's still ok.
$rate = 90;
$et->throttle(%args);
usleep 450000;

is_deeply(
   $et->throttle(%args),
   $args{event},
   'Event ok at max rate'
);

# The avg int rates were 100, 50, 90 = avg 80.
is(
   $et->rate_avg,
   80,
   'Calcs average rate'
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $et->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
