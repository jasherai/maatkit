#!/usr/bin/perl

BEGIN {
   die
      "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
}

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 18;

use Progress;
use MaatkitTest;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $pr;
my $how_much_done    = 0;
my $callbacks_called = 0;

# #############################################################################
# Simple percentage-based completion.
# #############################################################################

$pr = new Progress(
   jobsize  => 100,
   report   => 'percentage',
   interval => 5,
);

is($pr->fraction_modulo(.01), 0, 'fraction_modulo .01');
is($pr->fraction_modulo(.04), 0, 'fraction_modulo .04');
is($pr->fraction_modulo(.05), 5, 'fraction_modulo .05');
is($pr->fraction_modulo(.09), 5, 'fraction_modulo .09');

$pr->set_callback(
   sub{
      my ( $fraction, $elapsed, $remaining, $eta ) = @_;
      $how_much_done = $fraction * 100;
      $callbacks_called++;
   }
);

# 0 through 4% shouldn't trigger the callback to be called, so $how_much_done
# should stay at 0%.
my $i = 0;
for (0..4) {
   $pr->update(sub{return $i});
   $i++;
}
is($how_much_done, 0, 'Progress has not been updated yet');
is($callbacks_called, 0, 'Callback has not been called');

# Now we cross the 5% threshold... this should call the callback.
$pr->update(sub{return $i});
$i++;
is($how_much_done, 5, 'Progress updated to 5%');
is($callbacks_called, 1, 'Callback has been called');

for (6..99) {
   $pr->update(sub{return $i});
   $i++;
}
is($how_much_done, 95, 'Progress updated to 95%'); # Not 99 because interval=5
is($callbacks_called, 19, 'Callback has been called 19 times');

# Go to 100%
$pr->update(sub{return $i});
is($how_much_done, 100, 'Progress updated to 100%');
is($callbacks_called, 20, 'Callback has been called 20 times');

# Can't go beyond 100%, right?
$pr->update(sub{return 200});
is($how_much_done, 100, 'Progress stops at 100%');
is($callbacks_called, 20, 'Callback not called any more times');

# #############################################################################
# Iteration-based completion.
# #############################################################################

$pr = new Progress(
   jobsize  => 500,
   report   => 'iterations',
   interval => 2,
);
$how_much_done    = 0;
$callbacks_called = 0;
$pr->set_callback(
   sub{
      my ( $fraction, $elapsed, $remaining, $eta ) = @_;
      $how_much_done = $fraction * 100;
      $callbacks_called++;
   }
);

$i = 0;
for ( 0 .. 50 ) {
   $pr->update(sub{return $i});
   $i++;
}
is($how_much_done, 10, 'Progress is 10% done');
is($callbacks_called, 26, 'Callback called every 2 iterations');

# #############################################################################
# Time-based completion.
# #############################################################################

$pr = new Progress(
   jobsize  => 600,
   report   => 'time',
   interval => 10, # Every ten seconds
);
$pr->start(10); # Current time is 10 seconds.
my $completion_arr = [];
$callbacks_called  = 0;
$pr->set_callback(
   sub{
      $completion_arr = [ @_ ];
      $callbacks_called++;
   }
);

$pr->update(sub{return 60}, 35);
is_deeply(
   $completion_arr,
   [.1, 25, 225, 260 ],
   'Got completion info for time-based stuff'
);
is($callbacks_called, 1, 'Callback called once');

# #############################################################################
# Done.
# #############################################################################
exit;
