# This program is copyright 2008 Percona Inc.
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

# RecordsetFromText - Create recordset (array of hashes) from text output
package RecordsetFromText;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Carp;

# At present $params can contain a hash of alternate values:
#    key:   value_for
#    value: {
#       key:   value from text
#       value: alternate value
#    }
# Example:
# $params = { value_for => {
#                NULL => undef,
#             }
#           }
# That would cause any NULL value in the text to be changed to
# undef in the returned recset.

sub new {
   my ( $class, $params ) = @_;
   my $self = defined $params ? { %{ $params } } : {};
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
   my ( $text, @cols ) = @_;
   my %row = $text =~ m/^ *(\w+): ([^\n]*) *$/msg;
   return (\%row, undef);
}

sub parse {
   my ( $self, $text ) = @_;
   my $started = 0;
   my $lines   = 0;
   my @cols    = ();
   my @result  = ();

   # Detect which kind of input it is
   my ( $line_re, $vals_sub );
   if ( $text =~ m/^\+---/m ) { # standard "tabular" output
      $ENV{MKDEBUG} && _d("text type: standard tabular");
      $line_re  = qr/^(\| .*)[\r\n]+/m;
      $vals_sub = \&parse_tabular;
   }
   elsif ( $text =~ m/^id\tselect_type\t/m ) { # tab-separated
      $ENV{MKDEBUG} && _d("text type: tab-separated");
      $line_re  = qr/^(.*?\t.*)[\r\n]+/m;
      $vals_sub = \&parse_tab_sep;
   }
   elsif ( $text =~ m/\*\*\* 1. row/ ) { # "vertical" output
      $ENV{MKDEBUG} && _d("text-type: vertical");
      $line_re  = qr/^( *.*?^ *Extra:[^\n]*$)/ms;
      $vals_sub = \&parse_vertical;
   }
   else {
      croak "Cannot determine text type in RecordsetFromText::parse()";
   }

   if ( $line_re ) {
      my $value_for
         = (exists $self->{value_for} ? $self->{value_for} : 0);
      # Pull it apart into lines and parse them.
      LINE:
      foreach my $line ( $text =~ m/$line_re/g ) {
         my ( $row, $cols ) = $vals_sub->($line, @cols);
         if ( $row ) {
            foreach my $key ( keys %$row ) {
               if ( $value_for && exists $value_for->{ $row->{$key} } ) {
                  $row->{$key} = $value_for->{ $row->{$key} };
               }
            }
            push @result, $row;
         }
         else {
            @cols = @$cols;
         }
      }
   }

   return \@result;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# RecordsetFromText:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End RecordsetFromText package
# ###########################################################################
