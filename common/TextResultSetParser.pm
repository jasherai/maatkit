# This program is copyright 2008-2009 Percona Inc.
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
# TextResultSetParser package $Revision$
# ###########################################################################
package TextResultSetParser;

# TextResultSetParser converts the formatted text output of a result set, like
# what SHOW PROCESSLIST and EXPLAIN print, into a data struct, like what
# DBI::selectall_arrayref() returns.  So this:
#   +----+------+
#   | Id | User |
#   +----+------+
#   | 1  | bob  |
#   +----+------+
# becomes this:
#   [
#      {
#         Id   => '1',
#         User => 'bob',
#      },
#   ]
#
# Both horizontal and vertical (\G) text outputs are supported.

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

# Possible args:
#   * value_for    Hashref of original_val => new_val, used to alter values
#
sub new {
   my ( $class, %args ) = @_;
   my $self = { %args };
   return bless $self, $class;
}

sub parse_tabular {
   my ( $text, @cols ) = @_;
   my %row;
   my @vals = $text =~ m/\| +([^\|]*?)(?= +\|)/msg;
   return (undef, \@vals) unless @cols;
   @row{@cols} = @vals;
   return (\%row, undef);
}

sub parse_tab_sep {
   my ( $text, @cols ) = @_;
   my %row;
   my @vals = split(/\t/, $text);
   return (undef, \@vals) unless @cols;
   @row{@cols} = @vals;
   return (\%row, undef);
}

sub parse_vertical {
   my ( $text ) = @_;
   my %row = $text =~ m/^\s*(\w+): ([^\n]*)/msg;
   return \%row;
}

# Returns a result set like:
# [
#    {
#       Time     => '5',
#       Command  => 'Query',
#       db       => 'foo',
#    },
# ]
sub parse {
   my ( $self, $text ) = @_;
   my $result_set;

   # Detect text type: tabular, tab-separated, or vertical
   if ( $text =~ m/^\+---/m ) { # standard "tabular" output
      MKDEBUG && _d('text type: standard tabular');
      my $line_pattern  = qr/^(\| .*)[\r\n]+/m;
      $result_set
         = _parse_horizontal_result_set($text, $line_pattern, \&parse_tabular);
   }
   elsif ( $text =~ m/^id\tselect_type\t/m ) { # tab-separated
      MKDEBUG && _d('text type: tab-separated');
      my $line_pattern  = qr/^(.*?\t.*)[\r\n]+/m;
      $result_set
         = _parse_horizontal_result_set($text, $line_pattern, \&parse_tab_sep);
   }
   elsif ( $text =~ m/\*\*\* \d+\. row/ ) { # "vertical" output
      my $n_recs;
      $n_recs++ while $text =~ m/ \d+\. row /g;
      MKDEBUG && _d('text-type: vertical,', $n_recs, 'n_recs');
      if ( $n_recs > 1 ) {
         MKDEBUG && _d('Multiple result sets');
         my @v_result_sets;
         my $v_result_set = _split_vertical_result_sets($text);
         foreach my $v_result_set ( @$v_result_set ) {
            push @v_result_sets, $self->parse($v_result_set);
         }
         return \@v_result_sets;
      }
      $result_set = _parse_vertical_result_set($text, \&parse_vertical);
   }
   else {
      die "Cannot determine if text is tabular, tab-separated or veritcal:\n"
         . $text;
   }

   # Convert values.
   if ( $self->{value_for} ) {
      foreach my $result_set ( @$result_set ) {
         foreach my $key ( keys %$result_set ) {
            $result_set->{$key} = $self->{value_for}->{ $result_set->{$key} }
               if exists $self->{value_for}->{ $result_set->{$key} };
         }
      }
   }

   return $result_set;
}

sub _parse_horizontal_result_set {
   my ( $text, $line_pattern, $sub ) = @_;
   my @result_sets = ();
   my @cols        = ();
   foreach my $line ( $text =~ m/$line_pattern/g ) {
      my ( $row, $cols ) = $sub->($line, @cols);
      if ( $row ) {
         push @result_sets, $row;
      }
      else {
         @cols = @$cols;
      }
   }
   return \@result_sets;
}

sub _parse_vertical_result_set {
   my ( $text, $sub ) = @_;
   return $sub->($text);
}

sub _split_vertical_result_sets {
   my ( $text ) = @_;
   my $ROW_HEADER = '\*{3,} \d+\. row \*{3,}';
   my @result_sets = $text =~ m/($ROW_HEADER.*?)(?=$ROW_HEADER|\z)/omgs;
   return \@result_sets;
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
# End TextResultSetParser package
# ###########################################################################
