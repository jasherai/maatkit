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
   GetOptions( map { $_->{s} => \$defaults{$_->{k}} } @specs ) or $defaults{help} = 1;
   return %defaults;
}

sub usage {
   my ( $self ) = @_;
   my @specs = @{$self->{specs}};
   my $maxw = max(map { length($_->{l}) + ($_->{n} ? 4 : 0)} @specs);
   my $usage = '';
   foreach my $spec ( sort { $a->{l} cmp $b->{l} } @specs ) {
      my $long  = $spec->{n} ? "[no]$spec->{l}" : $spec->{l};
      my $short = $spec->{t} ? "-$spec->{t}" : '';
      $usage .= sprintf("  --%-${maxw}s %-4s %s\n", $long, $short, $spec->{d});
   }
   return $usage;
}

1;

# ###########################################################################
# End OptionParser package
# ###########################################################################

