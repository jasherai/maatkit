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
# RecordsetFromText package $Revision$
# ###########################################################################
package RecordsetFromText;

# RecordsetFromText converts the formatted text output of a recordset, like
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

# Returns an arrayref of recordset hashrefs like:
# [
#    {
#       Time     => '5',
#       Command  => 'Query',
#       db       => 'foo',
#    },
# ]
sub parse {
   my ( $self, $text ) = @_;
   my $recsets_ref;

   # Detect text type: tabular, tab-separated, or vertical
   if ( $text =~ m/^\+---/m ) { # standard "tabular" output
      MKDEBUG && _d('text type: standard tabular');
      my $line_pattern  = qr/^(\| .*)[\r\n]+/m;
      $recsets_ref
         = _parse_horizontal_recset($text, $line_pattern, \&parse_tabular);
   }
   elsif ( $text =~ m/^id\tselect_type\t/m ) { # tab-separated
      MKDEBUG && _d('text type: tab-separated');
      my $line_pattern  = qr/^(.*?\t.*)[\r\n]+/m;
      $recsets_ref
         = _parse_horizontal_recset($text, $line_pattern, \&parse_tab_sep);
   }
   elsif ( $text =~ m/\*\*\* \d+\. row/ ) { # "vertical" output
      my $n_recs;
      $n_recs++ while $text =~ m/ \d+\. row /g;
      MKDEBUG && _d('text-type: vertical,', $n_recs, 'n_recs');
      if ( $n_recs > 1 ) {
         MKDEBUG && _d('Multiple recsets');
         my @v_recsets;
         my $v_recsets_ref = _split_vertical_recsets($text);
         foreach my $v_recset ( @{ $v_recsets_ref } ) {
            push @v_recsets, $self->parse($v_recset);
         }
         return \@v_recsets;
      }
      $recsets_ref = _parse_vertical_recset($text, \&parse_vertical);
   }
   else {
      die "Cannot determine if text is tabular, tab-separated or veritcal:\n"
         . $text;
   }

   # Convert values.
   if ( $self->{value_for} ) {
      foreach my $recset ( @$recsets_ref ) {
         foreach my $key ( keys %$recset ) {
            $recset->{$key} = $self->{value_for}->{ $recset->{$key} }
               if exists $self->{value_for}->{ $recset->{$key} };
         }
      }
   }

   return $recsets_ref;
}

sub _parse_horizontal_recset {
   my ( $text, $line_pattern, $sub ) = @_;
   my @recsets = ();
   my @cols    = ();
   foreach my $line ( $text =~ m/$line_pattern/g ) {
      my ( $row, $cols ) = $sub->($line, @cols);
      if ( $row ) {
         push @recsets, $row;
      }
      else {
         @cols = @$cols;
      }
   }
   return \@recsets;
}

sub _parse_vertical_recset {
   my ( $text, $sub ) = @_;
   return $sub->($text);
}

sub _split_vertical_recsets {
   my ( $text ) = @_;
   my $ROW_HEADER = '\*{3,} \d+\. row \*{3,}';
   my @recsets = $text =~ m/($ROW_HEADER.*?)(?=$ROW_HEADER|\z)/omgs;
   return \@recsets;
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
# End RecordsetFromText package
# ###########################################################################
