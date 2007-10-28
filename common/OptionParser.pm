# ###########################################################################
# OptionParser package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package OptionParser;

use Getopt::Long;
use List::Util qw(max);
use English qw(-no_match_vars);

# Holds command-line options.  Each option is a hashref:
# {
#   s => GetOpt::Long specification,
#   d => --help output
# }
# Supported 's' values are long|short key, whether something is negatable and
# whether it can be specified multiple times. Expands the compact specs into
# their full form.
# * k is the option's key
# * l is the option's long name
# * t is the option's short name
# * n is whether the option is negatable
# * r is whether the option is required
# Returns the options as a hashref.  Options can also be plain-text
# instructions, and instructions are recognized inside the 'd' as well.
sub new {
   my ( $class, @opts ) = @_;
   my %opt_seen;
   my %key_for;
   my @mutex;
   foreach my $opt ( @opts ) {
      if ( ref $opt ) {
         my ( $long, $short ) = $opt->{s} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
         $opt->{k} = $short || $long;
         $key_for{$long} = $opt->{k};
         $opt->{l} = $long;
         $opt->{t} = $short;
         $opt->{n} = $opt->{s} =~ m/!/;
         # Instructions in the 'd' description.
         $opt->{r} = $opt->{d} =~ m/required/;
         # TODO die on dupe long opts too
         die "Duplicate option $opt->{k}" if $opt_seen{$opt->{k}}++;
      }
      else { # It's an instruction.

         if ( $opt =~ m/are mutually exclusive/ ) {
            my @participants;
            foreach my $thing ( $opt =~ m/(--?\S+)/g ) {
               if ( (my ($long) = $thing =~ m/--(\S+)/) ) {
                  push @participants, $key_for{$long}
                     or die "No such option $thing";
               }
               else {
                  foreach my $short ( $thing =~ m/([^-])/g ) {
                     push @participants, $key_for{$short};
                  }
               }
            }
            push @mutex, \@participants;
         }

      }
   }
   return bless {
      specs => [ grep { ref $_ } @opts ],
      notes => [],
      instr => [ grep { !ref $_ } @opts ],
      mutex => \@mutex,
   }, $class;
}

# Gets options from @ARGV.
sub parse {
   my ( $self, %defaults ) = @_;
   my @specs = @{$self->{specs}};

   my %opt_seen;
   foreach my $spec ( @specs ) {
      $defaults{$spec->{k}} = undef unless defined $defaults{$spec->{k}};
      $opt_seen{$spec->{k}} = 1;
   }

   foreach my $key ( keys %defaults ) {
      die "Cannot set default for non-existent option '$key'\n"
         unless $opt_seen{$key};
   }

   Getopt::Long::Configure('no_ignore_case', 'bundling');
   GetOptions( map { $_->{s} => \$defaults{$_->{k}} } @specs )
      or $defaults{help} = 1;

   if ( $defaults{version} ) {
      (my $prog) = $PROGRAM_NAME =~ m/(mysql-[a-z-]+)$/;
      printf("%s  Ver %s Distrib %s Changeset %s\n",
         $prog, $main::VERSION, $main::DISTRIB, $main::SVN_REV);
      exit(0);
   }

   # Check required options (oxymoron?)
   foreach my $spec ( grep { $_->{r} } @specs ) {
      if ( !defined $defaults{$spec->{k}} ) {
         $defaults{help} = 1;
         $self->note("Required option --$spec->{l} must be specified");
      }
   }

   # Check mutex options
   foreach my $mutex ( @{$self->{mutex}} ) {
      my @set = grep { defined $defaults{$_} } @$mutex;
      if ( @set > 1 ) {
         $defaults{help} = 1;
      }
   }

   return %defaults;
}

sub note {
   my ( $self, $note ) = @_;
   push @{$self->{notes}}, $note;
}

# Prints out command-line help.  The format is like this:
# --foo  -F   Description of --foo
# --bars -B   Description of --bar
# --longopt   Description of --longopt
# Note that the short options are aligned along the right edge of their longest
# long option, but long options that don't have a short option are allowed to
# protrude past that.
sub usage {
   my ( $self ) = @_;
   my @specs = @{$self->{specs}};

   # Find how wide the widest long option is.
   my $maxl = max(map { length($_->{l}) + ($_->{n} ? 4 : 0)} @specs);

   # Find how wide the widest option with a short option is.
   my $maxs = max(
      map { length($_->{l}) + ($_->{n} ? 4 : 0)}
      grep { $_->{t} } @specs);

   # Find how wide the 'left column' (long + short opts) is, and therefore how
   # much space to give options.
   my $lcol = max($maxl, ($maxs + 3));

   # Adjust the width of the options that have long and short both.
   $maxs = max($lcol - 3, $maxs);

   # Format and return the options.
   my $usage = '';
   foreach my $spec ( sort { $a->{l} cmp $b->{l} } @specs ) {
      my $long  = $spec->{n} ? "[no]$spec->{l}" : $spec->{l};
      my $short = $spec->{t};
      my $desc  = $spec->{d};
      if ( $short ) {
         $usage .= sprintf("  --%-${maxs}s -%s  %s\n", $long, $short, $desc);
      }
      else {
         $usage .= sprintf("  --%-${lcol}s  %s\n", $long, $desc);
      }
   }
   if ( (my @notes = @{$self->{notes}}) ) {
      $usage .= join("\n", 'Errors while processing:', @notes) . "\n";
   }
   return $usage;
}

1;

# ###########################################################################
# End OptionParser package
# ###########################################################################
