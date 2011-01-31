#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 12;

use Time::HiRes qw(usleep);

use MaatkitTest;
use Pipeline;

my $output  = '';
my $oktorun = 1;
my $retval;

# #############################################################################
# A simple run stopped by a proc returning and exit status.
# #############################################################################

my $pipeline = new Pipeline();
$pipeline->add(
   name    => 'proc1',
   process => sub {
      my ( %args ) = @_;
      print "proc1";
      return 0;
   },
);

$output = output(
   sub { $retval = $pipeline->execute(\$oktorun); },
);

is(
   $output,
   "proc1",
   "Pipeline ran"
);

is_deeply(
   $retval,
   {
      process_name => 'proc1',
      exit_status  => 0,
      oktorun      => 1,
      eval_error   => '',
   },
   "Pipeline terminate as expected"
);


# #############################################################################
# oktorun to control the loop.
# #############################################################################

$oktorun = 0;
$pipeline = new Pipeline();
$pipeline->add(
   name    => 'proc1',
   process => sub {
      my ( %args ) = @_;
      print "proc1";
      return 0;
   },
);

$output = output(
   sub { $retval = $pipeline->execute(\$oktorun); },
);

is(
   $output,
   "",
   "oktorun prevented pipeline from running"
);

is_deeply(
   $retval,
   {
      process_name => undef,
      exit_status  => undef,
      eval_error   => '',
      oktorun      => 0,
   },
   "Pipeline terminated because not oktorun"
);

# #############################################################################
# Run multiple procs.
# #############################################################################

$oktorun = 1;
$pipeline = new Pipeline();
$pipeline->add(
   name    => 'proc1',
   process => sub {
      print "proc1";
      return;
   },
);
$pipeline->add(
   name    => 'proc2',
   process => sub {
      my ( %args ) = @_;
      print "proc2";
      return 2;
   },
);

$output = output(
   sub { $retval = $pipeline->execute(\$oktorun); },
);

is(
   $output,
   "proc1proc2",
   "Multiple procs ran"
);

is_deeply(
   $retval,
   {
      process_name => "proc2",
      exit_status  => 2,
      eval_error   => '',
      oktorun      => 1,
   },
   "Pipeline terminated after proc2"
);


# #############################################################################
# Instrumentation.
# #############################################################################
$oktorun = 1;
$pipeline = new Pipeline(instrument => 1);
$pipeline->add(
   name    => 'proc1',
   process => sub {
      usleep(500000);
      return;
   },
);
$pipeline->add(
   name    => 'proc2',
   process => sub {
      return 2;
   },
);

$pipeline->execute(\$oktorun);

my $inst = $pipeline->instrumentation();
ok(
   $inst->{proc1}->{calls} = 1 && $inst->{proc2}->{calls} = 1,
   "Instrumentation counted calls"
);

ok(
   $inst->{proc1}->{time} > 0.4 && $inst->{proc1}->{time} < 0.6,
   "Instrumentation timed procs"
);

# #############################################################################
# Procs should be able to incr stats.
# #############################################################################
$oktorun = 1;
$pipeline = new Pipeline(instrument => 1);
$pipeline->add(
   name    => 'proc1',
   process => sub {
      my ( %args ) = @_;
      my ($pipeline, $proc_name) = @args{qw(Pipeline process_name)};
      $pipeline->incr_stat(%args, stat=>'foo');
      $pipeline->incr_stat(%args, stat=>'foo');
      return 1;
   },
);
$pipeline->execute(\$oktorun);

my $stats = $pipeline->stats();

is(
   $stats->{proc1}->{foo},
   2,
   "Proc can increment stats"
);


# #############################################################################
# Reset the previous ^ pipeline.
# #############################################################################
$pipeline->reset();
$inst  = $pipeline->instrumentation();
$stats = $pipeline->stats();
is(
   $stats->{proc1}->{foo},
   undef,
   "Reset stats"
);
is(
   $inst->{proc1}->{calls},
   0,
   "Reset instrumentation"
);

# #############################################################################
# Done.
# #############################################################################
{
   local *STDERR;
   open STDERR, '>', \$output;
   $pipeline->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
