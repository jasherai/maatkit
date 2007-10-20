# ###########################################################################
# OptionParser package
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package OptionParser;

use Getopt::Long;
use List::Util qw(max);

# Holds command-line options.  Each option is a hashref:
# {
#   s => GetOpt::Long specification,
#   d => --help output
# }
# Supported 's' values are long|short key, whether something is negatable and
# whether it can be specified multiple times.  Returns the options as a hashref.
sub new {
   my ( $class, @opts ) = @_;
   bless { specs => \@opts }, $class;
}

# Expands the compact specs into their full form and gets options.
# k is the option's key
# l is the option's long name
# t is the option's short name
# n is whether the option is negatable
sub parse {
   my ( $self, %defaults ) = @_;
   my @specs = @{$self->{specs}};

   my %opt_seen;
   foreach my $spec ( @specs ) {
      my ( $long, $short ) = $spec->{s} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
      $spec->{k} = $short || $long;
      $spec->{l} = $long;
      $spec->{t} = $short;
      $spec->{n} = $spec->{s} =~ m/!/;
      $defaults{$spec->{k}} = undef unless defined $defaults{$spec->{k}};
      die "Duplicate option $spec->{k}" if $opt_seen{$spec->{k}}++;
   }

   foreach my $key ( keys %defaults ) {
      die "No such option '$key'\n" unless exists $opt_seen{$key};
   }

   Getopt::Long::Configure('no_ignore_case', 'bundling');
   GetOptions( map { $_->{s} => \$defaults{$_->{k}} } @specs )
      or $defaults{help} = 1;
   return %defaults;
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

   # Find how long the longest option is.
   my $maxl = max(map { length($_->{l}) + ($_->{n} ? 4 : 0)} @specs);

   # Find how long the longest option with a short option is.
   my $maxs = max(
      map { length($_->{l}) + ($_->{n} ? 4 : 0)}
      grep { $_->{t} } @specs);

   # Find how wide the 'left column' (long + short opts) is, and therefore how
   # much space to give long options that have a short option.
   my $lcol = max($maxl, ($maxs + 3));
   my $lws  = $lcol - 3;

   # Format and return the options.
   my $usage = '';
   foreach my $spec ( sort { $a->{l} cmp $b->{l} } @specs ) {
      my $long  = $spec->{n} ? "[no]$spec->{l}" : $spec->{l};
      my $short = $spec->{t};
      my $desc  = $spec->{d};
      if ( $short ) {
         $usage .= sprintf("  --%-${lws}s -%s  %s\n", $long, $short, $desc);
      }
      else {
         $usage .= sprintf("  --%-${maxl}s  %s\n", $long, $desc);
      }
   }
   return $usage;
}

1;

# ###########################################################################
# End OptionParser package
# ###########################################################################
