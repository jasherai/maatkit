# This program is copyright 2009 Percona Inc.
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
# UpgradeReportFormatter package $Revision$
# ###########################################################################

package UpgradeReportFormatter;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
Transformers->import(qw(make_checksum));

use constant MKDEBUG           => $ENV{MKDEBUG};
use constant LINE_LENGTH       => 74;
use constant MAX_STRING_LENGTH => 10;

# Special formatting functions
my %formatting_function = (
   ts => sub {
      my ( $stats ) = @_;
      my $min = parse_timestamp($stats->{min} || '');
      my $max = parse_timestamp($stats->{max} || '');
      return $min && $max ? "$min to $max" : '';
   },
);

my $bool_format = '# %3s%% %-6s %s';

sub new {
   my ( $class, %args ) = @_;
   return bless { }, $class;
}

sub event_report {
   my ( $self, %args ) = @_;
   my @required_args = qw(where rank worst meta_ea host_eas);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($where, $rank, $worst, $meta_ea, $eas) = @args{@required_args};
   my $meta_stats = $meta_ea->results;
   my @result;

   # Does the data exist?  Is there a sample event?
#   my $store = $stats->{classes}->{$where};
#   return "# No such event $where\n" unless $store;
#   my $sample = $stats->{samples}->{$where};

   # Pick the first attribute to get counts
#   my $global_cnt = $stats->{globals}->{$worst}->{cnt};
#   my $class_cnt  = $store->{$worst}->{cnt};

   # First line
   my $line = sprintf(
      '# Query %d: ID 0x%s at byte %d ',
      $rank || 0,
      make_checksum($where),
      0, # $sample->{pos_in_log} || 0
   );
   $line .= ('_' x (LINE_LENGTH - length($line)));
   push @result, $line;

   # Differences report.
   my $class = $meta_stats->{classes}->{$where};
   push @result,
      'Found ' . ($class->{differences}->{sum} || 0)
      . ' differences in ' . $class->{arg}->{cnt} . " samples:\n";

   my $fmt = "%-15s %d\n";
   my @diffs = grep { $_ =~ m/^different_/ } keys %$class;
   foreach my $diff ( sort @diffs ) {
      push @result,
         sprintf $fmt, '  ' . make_label($diff), $class->{$diff}->{sum};
   }

   return join("\n", map { s/\s+$//; $_ } @result) . "\n";
}

# Convert attribute names into labels
sub make_label {
   my ( $val ) = @_;

   $val =~ s/^different_//;
   $val =~ s/_/ /g;

   return $val;
}

# Does pretty-printing for bool (Yes/No) attributes like QC_Hit.
sub format_bool_attrib {
   my ( $stats ) = @_;
   # Since the value is either 1 or 0, the sum is the number of
   # all true events and the number of false events is the total
   # number of events minus those that were true.
   my $p_true  = percentage_of($stats->{sum},  $stats->{cnt});
   # my $p_false = percentage_of($stats->{cnt} - $stats->{sum}, $stats->{cnt});
   my $n_true = '(' . shorten($stats->{sum}, d=>1_000, p=>0) . ')';
   return $p_true, $n_true;
}

# Does pretty-printing for lists of strings like users, hosts, db.
sub format_string_list {
   my ( $stats ) = @_;
   if ( exists $stats->{unq} ) {
      # Only class stats have unq.
      my $cnt_for = $stats->{unq};
      if ( 1 == keys %$cnt_for ) {
         my ($str) = keys %$cnt_for;
         # - 30 for label, spacing etc.
         $str = substr($str, 0, LINE_LENGTH - 30) . '...'
            if length $str > LINE_LENGTH - 30;
         return (1, $str);
      }
      my $line = '';
      my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
                     keys %$cnt_for;
      my $i = 0;
      foreach my $str ( @top ) {
         my $print_str;
         if ( length $str > MAX_STRING_LENGTH ) {
            $print_str = substr($str, 0, MAX_STRING_LENGTH) . '...';
         }
         else {
            $print_str = $str;
         }
         last if (length $line) + (length $print_str)  > LINE_LENGTH - 27;
         $line .= "$print_str ($cnt_for->{$str}), ";
         $i++;
      }
      $line =~ s/, $//;
      if ( $i < @top ) {
         $line .= "... " . (@top - $i) . " more";
      }
      return (scalar keys %$cnt_for, $line);
   }
   else {
      # Global stats don't have unq.
      return ($stats->{cnt});
   }
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
# End UpgradeReportFormatter package
# ###########################################################################
