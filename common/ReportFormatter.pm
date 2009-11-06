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
      underline_header  => 1,
      line_prefix        => '# ',
      line_width         => 78,
      truncate_underline => 1,
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
      die "Column does not have a name" unless defined $col->{name};
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

sub get_report {
   my ( $self ) = @_;
   my @lines;
   my $p = $self->{line_prefix} || '';

   my $n_cols = scalar @{$self->{cols}} - 1;

   my $fmt = $p;
   my @col_fmts;
   for my $i ( 0..($n_cols-1) ) {
      my $col = $self->{cols}->[$i];
      my $col_fmt = '%'
                  . ($col->{right_justify} ? '' : '-')
                  . "$col->{max_val_width}"
                  . 's';
      push @col_fmts, $col_fmt;
   }
   push @col_fmts,
      '%' . ($self->{cols}->[-1]->{right_justify} ? '' : '-') . 's';
   $fmt .= join(' ', @col_fmts);
   MKDEBUG && _d('Format:', $fmt);

   push @lines, sprintf "${p}$self->{title}" if $self->{title};

   push @lines, sprintf $fmt, map { $_->{name} } @{$self->{cols}};

   if ( $self->{underline_header} ) {
      my $underline_len = 0;
      my @underlines = map {
         my $underline = '=' x $_->{max_val_width};
         $underline_len += length $underline;
         $underline;
      } @{$self->{cols}};
      $underline_len += (scalar @underlines) - 1;
      if ( $self->{truncate_underline}
           && (2 + $underline_len) > $self->{line_width} ) {
         my $over = $self->{line_width} - (2 + $underline_len);
         $underlines[-1] = substr($underlines[-1], 0, $over);
      }

      push @lines, sprintf $fmt, @underlines;
   }

   foreach my $line ( @{$self->{lines}} ) {
      push @lines, sprintf $fmt, @$line;
   }

   return join("\n", @lines) . "\n";
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
