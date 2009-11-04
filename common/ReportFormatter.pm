# This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
# ReportFormatter package $Revision$
# ###########################################################################
package ReportFormatter;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use List::Util qw(min max);

use constant MKDEBUG => $ENV{MKDEBUG};

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw();
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
      %args,
   };
   return bless $self, $class;
}

sub set_title {
   my ( $self, $title ) = @_;
   $self->{title} = $title;
   return;
}

sub set_columns {
   my ( $self, @cols ) = @_;
   push @{$self->{cols}}, map {
      my $col = $_;
      die "Column does not have a name" unless $col->{name};
      if ( $col->{fixed_wdith} && $col->{fixed_width} < length $col->{name} ) {
         die "Fixed width is less than the column name";
      }
      $col->{min_val_width} = length $col->{name};
      $col->{max_val_width} = length $col->{name};
      $col;
   } @cols;
   return;
}

sub add_line {
   my ( $self, @vals ) = @_;

   my $n_cols = scalar @{$self->{cols}};
   my $n_vals = scalar @vals;
   die "Number of columns ($n_cols) and values ($n_vals) do not match"
      unless $n_cols == $n_vals;

   my @line;
   for my $i ( 0..$#vals ) {
      my $col = $self->{cols}->[$i];
      my $val = $vals[$i];
      my $width = length $val;
      if ( $col->{fixed_width} && $width > $col->{fixed_width} ) {
         if ( $col->{truncate} ) {
            $val  = substr($val, 0, $col->{fixed_width} - 3);
            $val .= '...';
            MKDEBUG && _d('Truncated', $vals[$i], 'to', $val);
         }
         else {
            die "Value '$val' is too wide for column $col->{name}";
         }
      }
      $col->{max_val_width} = max($width, $col->{max_val_width});
      push @line, $val;
   }
   push @{$self->{lines}}, \@line;

   return;
}

sub print {
   my ( $self, $fh ) = @_;

   $fh ||= *STDOUT;

   print "# $self->{title}\n" if $self->{title};

   my $fmt = '# '
           . join(' ',
               map {
                  my $col = $_;
                  my $col_fmt = '%'
                              . ($col->{right_justify} ? '' : '-')
                              . "$col->{max_val_width}"
                              . 's';
                  $col_fmt;
               } @{$self->{cols}}
            )
          . "\n";
   MKDEBUG && _d('Format:', $fmt);

   printf $fmt, map { $_->{name} } @{$self->{cols}};
   printf $fmt, map { '=' x $_->{max_val_width} } @{$self->{cols}};

   foreach my $line ( @{$self->{lines}} ) {
      printf $fmt, @$line;
   }

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
# End ReportFormatter package
# ###########################################################################
