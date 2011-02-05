# This program is copyright 2011 Percona Inc.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
# ###########################################################################
# Pipeline package $Revision$
# ###########################################################################

# Package: Pipeline
# Pipeline executes and controls a list of pipeline processes.
package Pipeline;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use constant MKDEBUG => $ENV{MKDEBUG} || 0;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;
use Time::HiRes qw(time usleep);

sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw();
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }

   my $self = {
      # default values for optional args
      instrument        => 0,
      continue_on_error => 0,

      # specified arg values override defaults
      %args,

      # private/internal vars
      procs      => [],  # coderefs for pipeline processes
      names      => [],  # names for each ^ pipeline proc
      instrument => {    # instrumenation values, keyed on proc index in procs
         Pipeline => {
            time  => 0,
            calls => 0,
         },
      },
   };
   return bless $self, $class;
}

sub add {
   my ( $self, %args ) = @_;
   my @required_args = qw(process name);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my ($process, $name) = @args{@required_args};

   push @{$self->{procs}}, $process;
   push @{$self->{names}}, $name;
   if ( $self->{instrument} ) {
      $self->{instrument}->{$name} = { time => 0, calls => 0 };
   }
   MKDEBUG && _d("Added pipeline process", $name);

   return;
}

sub processes {
   my ( $self ) = @_;
   return @{$self->{names}};
}

# Sub: execute
#   Execute all pipeline processes until not oktorun.  The oktorun arg
#   must be a reference.  The pipeline will run until oktorun is false.
#   The oktorun ref is passed to every pipeline proc so they can completely
#   terminate pipeline execution.  A proc signals that it wants to restart
#   execution of the pipeline from the first proc by returning undef.
#   If a proc both sets oktorun to false and returns undef, this sub will
#   return with some info about where the pipeline stopped.
#
# Parameters:
#   %args    - Arguments passed to each pipeline process.
#
# Required Arguments:
#   oktorun - Scalar ref that indicates it's ok to run when true.
#
# Optional Arguments:
#   pipeline_data - Hashref passed through all processes.
#
# Returns:
#   Hashref with information about where and why the pipeline terminated.
sub execute {
   my ( $self, %args ) = @_;

   die "Cannot execute pipeline because no process have been added"
      unless scalar @{$self->{procs}};

   my $oktorun = $args{oktorun};
   die "I need an oktorun argument" unless $oktorun;
   die '$oktorun argument must be a reference' unless ref $oktorun;

   my $pipeline_data = $args{pipeline_data} || {};
   $pipeline_data->{oktorun} = $oktorun;

   MKDEBUG && _d("Pipeline starting at", time);
   my $instrument  = $self->{instrument};
   my $last_proc   = scalar @{$self->{procs}} - 1;
   my $proc_name;    # current/last proc name executed
   EVENT:
   while ( $$oktorun ) {
      eval {
         PIPELINE_PROCESS:
         for my $procno ( 0..$last_proc ) {
            $proc_name     = $self->{names}->[$procno];
            my $call_start = $instrument ? time : 0;

            # Execute this pipeline process.
            MKDEBUG && _d("Pipeline process", $proc_name);
            my $output = $self->{procs}->[$procno]->($pipeline_data);

            if ( $instrument ) {
               my $call_end = time;
               my $call_t   = $call_end - $call_start;
               $self->{instrument}->{$proc_name}->{time} += $call_t;
               $self->{instrument}->{$proc_name}->{count}++;
               $self->{instrument}->{Pipeline}->{time} += $call_t;
               $self->{instrument}->{Pipeline}->{count}++;
            }
            if ( !$output ) {
               MKDEBUG && _d("Pipeline restarting early after", $proc_name);
               last PIPELINE_PROCESS;
            }
         }
      };
      if ( $EVAL_ERROR ) {
         warn "Pipeline process $proc_name caused an error: $EVAL_ERROR";
         last EVENT unless $self->{continue_on_error};
      }
   }

   my $retval = {
      process_name => $proc_name,
      eval_error   => $EVAL_ERROR,
      oktorun      => $$oktorun,
   };
   MKDEBUG && _d("Pipeline stopped at", time, Dumper($retval));
   return $retval;
}

sub instrumentation {
   my ( $self ) = @_;
   return $self->{instrument};
}

sub reset {
   my ( $self ) = @_;
   foreach my $proc_name ( @{$self->{names}} ) {
      if ( exists $self->{instrument}->{$proc_name} ) {
         $self->{instrument}->{$proc_name}->{calls} = 0;
         $self->{instrument}->{$proc_name}->{time}  = 0;
      }
   }
   $self->{instrument}->{Pipeline}->{calls} = 0;
   $self->{instrument}->{Pipeline}->{time}  = 0;
   return;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

1;

# ###########################################################################
# End Pipeline package
# ###########################################################################
