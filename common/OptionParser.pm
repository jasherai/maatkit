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
# * y is the option's type.  In addition to Getopt::Long's types (siof), the
#     following types can be used:
#     * t = time, with an optional suffix of s/h/m/d
# Returns the options as a hashref.  Options can also be plain-text
# instructions, and instructions are recognized inside the 'd' as well.
sub new {
   my ( $class, @opts ) = @_;
   my %key_seen;
   my %long_seen;
   my %key_for;
   my %defaults;
   my @mutex;
   my @atleast1;
   my %long_for;
   unshift @opts,
      { s => 'help',    d => 'Show this help message' },
      { s => 'version', d => 'Output version information and exit' };
   foreach my $opt ( @opts ) {
      if ( ref $opt ) {
         my ( $long, $short ) = $opt->{s} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
         $opt->{k} = $short || $long;
         $key_for{$long} = $opt->{k};
         $long_for{$opt->{k}} = $long;
         $opt->{l} = $long;
         die "Duplicate option $opt->{k}" if $key_seen{$opt->{k}}++;
         die "Duplicate long option $opt->{l}" if $long_seen{$opt->{l}}++;
         $opt->{t} = $short;
         $opt->{n} = $opt->{s} =~ m/!/;
         # Option has a type
         if ( (my ($y) = $opt->{s} =~ m/=([m])/) ) {
            $opt->{y} = $y;
            $opt->{s} =~ s/=./=s/;
         }
         # Option is required if it contains the word 'required'
         $opt->{r} = $opt->{d} =~ m/required/;
         # Option has a default value if it says 'default'
         if ( (my ($def) = $opt->{d} =~ m/default(?: ([^)]+))?/) ) {
            $defaults{$opt->{k}} = defined $def ? $def : 1;
         }
      }
      else { # It's an instruction.

         if ( $opt =~ m/are mutually exclusive|one and only one/ ) {
            my @participants;
            foreach my $thing ( $opt =~ m/(--?[\w-]+)/g ) {
               if ( (my ($long) = $thing =~ m/--(.+)/) ) {
                  die "No such option $thing" unless $key_for{$long};
                  push @participants, $key_for{$long}
               }
               else {
                  foreach my $short ( $thing =~ m/([^-])/g ) {
                     push @participants, $short;
                  }
               }
            }
            push @mutex, \@participants;
            if ( $opt =~ m/one and only one/ ) {
               push @atleast1, \@participants;
            }
         }

      }
   }
   return bless {
      specs => [ grep { ref $_ } @opts ],
      notes => [],
      instr => [ grep { !ref $_ } @opts ],
      mutex => \@mutex,
      defaults => \%defaults,
      long_for => \%long_for,
      atleast1 => \@atleast1,
   }, $class;
}

# Gets options from @ARGV.
sub parse {
   my ( $self, %defaults ) = @_;
   my @specs = @{$self->{specs}};

   my %opt_seen;
   my %vals = %{$self->{defaults}};
   # Defaults passed as arg override defaults from descriptions.
   @vals{keys %defaults} = values %defaults;
   foreach my $spec ( @specs ) {
      $vals{$spec->{k}} = undef unless defined $vals{$spec->{k}};
      $opt_seen{$spec->{k}} = 1;
   }

   foreach my $key ( keys %defaults ) {
      die "Cannot set default for non-existent option '$key'\n"
         unless $opt_seen{$key};
   }

   Getopt::Long::Configure('no_ignore_case', 'bundling');
   GetOptions( map { $_->{s} => \$vals{$_->{k}} } @specs )
      or $vals{help} = 1;

   if ( $vals{version} ) {
      (my $prog) = $PROGRAM_NAME =~ m/(mysql-[a-z-]+)$/;
      printf("%s  Ver %s Distrib %s Changeset %s\n",
         $prog, $main::VERSION, $main::DISTRIB, $main::SVN_REV);
      exit(0);
   }

   # Check required options (oxymoron?)
   foreach my $spec ( grep { $_->{r} } @specs ) {
      if ( !defined $vals{$spec->{k}} ) {
         $vals{help} = 1;
         $self->note("Required option --$spec->{l} must be specified");
      }
   }

   # Check mutex options
   foreach my $mutex ( @{$self->{mutex}} ) {
      my @set = grep { defined $vals{$_} } @$mutex;
      if ( @set > 1 ) {
         $vals{help} = 1;
         my $note = join(', ',
            map { "--$self->{long_for}->{$_}" }
                @{$mutex}[ 0 .. scalar(@$mutex) - 2] );
         $note .= " and --$self->{long_for}->{$mutex->[-1]}"
               . " are mutually exclusive.";
         $self->note($note);
      }
   }

   foreach my $required ( @{$self->{atleast1}} ) {
      my @set = grep { defined $vals{$_} } @$required;
      if ( !@set ) {
         $vals{help} = 1;
         my $note = join(', ',
            map { "--$self->{long_for}->{$_}" }
                @{$required}[ 0 .. scalar(@$required) - 2] );
         $note .= " or --$self->{long_for}->{$required->[-1]}.";
         $self->note("Specify at least one of $note");
      }
   }

   foreach my $spec ( grep { $_->{y} && defined $vals{$_->{k}} } @specs ) {
      my $val = $vals{$spec->{k}};
      if ( $spec->{y} eq 'm' ) {
         my ( $num, $suffix ) = $val =~ m/(\d+)([smhd])$/;
         if ( $suffix ) {
            $val = $suffix eq 's' ? $num            # Seconds
                 : $suffix eq 'm' ? $num * 60       # Minutes
                 : $suffix eq 'h' ? $num * 3600     # Hours
                 :                  $num * 86400;   # Days
            $vals{$spec->{k}} = $val;
         }
         else {
            $self->note("Invalid --$spec->{l} argument");
            $vals{help} = 1;
         }
      }
   }

   return %vals;
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
   # much space to give options and how much to give descriptions.
   my $lcol = max($maxl, ($maxs + 3));
   my $rcol = 80 - $lcol - 6;
   my $rpad = ' ' x ( 80 - $rcol );

   # Adjust the width of the options that have long and short both.
   $maxs = max($lcol - 3, $maxs);

   # Format and return the options.
   my $usage = '';
   foreach my $spec ( sort { $a->{l} cmp $b->{l} } @specs ) {
      my $long  = $spec->{n} ? "[no]$spec->{l}" : $spec->{l};
      my $short = $spec->{t};
      my $desc  = $spec->{d};
      # Wrap long descriptions
      $desc = join("\n$rpad", grep { $_ } $desc =~ m/(.{0,$rcol})(?:\s+|$)/g);
      $desc =~ s/ +$//mg;
      if ( $short ) {
         $usage .= sprintf("  --%-${maxs}s -%s  %s\n", $long, $short, $desc);
      }
      else {
         $usage .= sprintf("  --%-${lcol}s  %s\n", $long, $desc);
      }
   }
   if ( (my @instr = @{$self->{instr}}) ) {
      $usage .= join("\n", map { "  $_" } @instr) . "\n";
   }
   if ( (my @notes = @{$self->{notes}}) ) {
      $usage .= join("\n", 'Errors in command-line arguments:', @notes) . "\n";
   }
   return $usage;
}

1;

# ###########################################################################
# End OptionParser package
# ###########################################################################
