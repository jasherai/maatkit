#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 13;

use Retry;
use MaatkitTest;

my $success;
my $failure;
my $waitno;
my $tryno;
my $tries;
my $die;

my $rt = new Retry();

my $try = sub {
   if ( $die ) {
      $die = 0;
      die "Arrrgh!";
   }
   return $tryno++ == $tries ? "succeed" : 0;
};
my $wait = sub {
   $waitno++;
};
my $on_success = sub {
   $success = "succeed on $tryno";
};
my $on_failure = sub {
   $failure = "failed on $tryno";
};
sub try_it {
   my ( %args ) = @_;
   $success = "";
   $failure = "";
   $waitno  = $args{wainot} || 0;
   $tryno   = $args{tryno}  || 1;
   $tries   = $args{tries}  || 3;

   return $rt->retry(
      try          => $try,
      wait         => $wait,
      on_success   => $on_success,
      on_failure   => $on_failure,
      retry_on_die => $args{retry_on_die},
   );
}

my $retval = try_it();
is(
   $retval,
   "succeed",
   "Retry succeeded"
);

is(
   $success,
   "succeed on 4",
   "Called on_success code"
);

is(
   $waitno,
   2,
   "Called wait code"
);

# Default tries is 3 so allowing ourself 4 tries will cause the retry
# to fail and the on_failure code should be called.
$retval = try_it(tries=>4);
ok(
   !defined $retval,
   "Returned undef on failure"
);

is(
   $failure,
   "failed on 4",
   "Called on_failure code"
);

is(
   $success,
   "",
   "Did not call on_success code"
);

# Test what happens if the try code dies.  try_it() will reset $die to 0.
$die = 1;
try_it();
ok(
   !defined $retval,
   "Returned undef on try die"
);

is(
   $failure,
   "",
   "Did not call on_failure code on try die without retry_on_die"
);

is(
   $success,
   "",
   "Did not call on_success code"
);

# Test retry_on_die.  This should work with tries=2 because the first
# try will die leaving with only 2 more retries.
$die = 1;
$retval = try_it(retry_on_die=>1, tries=>2);
is(
   $retval,
   "succeed",
   "Retry succeeded with retry_on_die"
);

is(
   $success,
   "succeed on 3",
   "Called on_success code with retry_on_die"
);

is(
   $waitno,
   2,
   "Called wait code with retry_on_die"
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $rt->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
