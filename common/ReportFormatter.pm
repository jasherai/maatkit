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

eval { require Term::ReadKey };
my $have_term = $EVAL_ERROR ? 0 : 1;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

# Arguments:
#  * underline_header    bool: underline headers with =
#  * line_prefix         scalar: prefix every line with this string
#  * line_width          scalar: line width in characters or 'auto'
#  * column_spacing      scalar: string between columns (default one space)
#  * extend_right        bool: allow right-most column to extend beyond
#                              line_width (default: no)
#  * column_errors       scalar: die or warn on column errors (default warn)
sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw();
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
      underline_header    => 1,
      line_prefix         => '# ',
      line_width          => 78,
      column_spacing      => ' ',
      extend_right        => 0,
      truncate_line_mark  => '...',
      column_errors       => 'warn',
      %args,              # args above can be overriden, args below cannot
      n_cols              => 0,
   };

   if ( ($self->{line_width} || '') eq 'auto' ) {
      die "Cannot auto-detect line width because the Term::ReadKey module "
         . "is not installed" unless $have_term;
      ($self->{line_width}) = GetTerminalSize();
   }
   MKDEBUG && _d('Line width:', $self->{line_width});

   return bless $self, $class;
}

sub set_title {
   my ( $self, $title ) = @_;
   $self->{title} = $title;
   return;
}

# @cols is an array of hashrefs.  Each hashref describes a column and can
# have the following keys:
# Required args:
#   * name           column's name
# Optional args:
#   * truncate           can truncate column (default yes)
#   * truncate_mark      append string to truncate col vals (default ...)
#   * truncate_side      truncate left or right side of value (default right)
#   * truncate_callback  coderef to do truncation; overrides other truncate_*
#
#   * width_max      maximum character width; min is length of name
#   * width_pct      percentage character width
#
#   * undef_value    string for undef values (default '')
sub set_columns {
   my ( $self, @cols ) = @_;
   my $min_hdr_wid = 0;

   push @{$self->{cols}}, map {
      my $col      = $_;
      my $col_name = $col->{name};
      die "Column does not have a name"
         unless $col_name;

      # Set defaults if another value wasn't given.
      $col->{truncate}        = 1 unless defined $col->{truncate};
      $col->{truncate_mark} ||= '...';
      $col->{truncate_side} ||= 'right';
      $col->{undef_value}   ||= '';

      # These values will be computed/updated as lines are added.
      $col->{min_val} = length $col_name;
      $col->{max_val} = length $col_name;

      # Calculate if the minimum possible header width will exceed
      # the line width....
      $min_hdr_wid += $col->{min_val};

      $col;
   } @cols;

   $self->{n_cols} = scalar @cols;

   # Add to the minimum possible header width the spacing between columns.
   $min_hdr_wid += ($self->{n_cols} - 1) * length $self->{column_spacing};
   MKDEBUG && _d("Minimum header width:", $min_hdr_wid);
   if ( $min_hdr_wid > $self->{line_width} ) {
      die "Minimum possible header width $min_hdr_wid is greater than "
         . "the line width $self->{line_width}";
   }

   return;
}

# Add a line to the report.  Does not print the line or the report.
# @vals is an array of values for each column.  There should be as
# many vals as columns.  Use undef for columns that have no values.
sub add_line {
   my ( $self, @vals ) = @_;
   if ( scalar @vals != $self->{n_cols} ) {
      $self->_column_error("Number of columns ($self->{n_cols}) and "
         . "values (", scalar @vals, ") do not match");
   }
   my $line = $self->_check_line_vals(\@vals);
   push @{$self->{lines}}, $line if $line;
   return;
}

sub _check_line_vals {
   my ( $self, $vals ) = @_;
   my @line;
   my $n_vals = scalar @$vals - 1;
   for my $i ( 0..$n_vals ) {
      my $col   = $self->{cols}->[$i];
      my $val   = defined $vals->[$i] ? $vals->[$i] : $col->{undef_value};
      my $width = length $val;

      if ( $col->{width_max} && $width > $col->{width_max} ) {
         if ( !$col->{truncate} ) {
            $self->_column_error("Value '$val' is too wide for column "
               . $col->{name});
         }

         # If _column_error() dies then we never get here.  If it warns
         # then we truncate the value despite $col->{truncate} being
         # false so the user gets something rather than nothing.
         my $callback  = $self->{truncate_callback};
         my $width_max = $col->{width_max};
         $val = $callback ? $callback->($col, $val, $width_max)
              :             $self->truncate_val($col, $val, $width_max);
         MKDEBUG && _d('Truncated', $vals->[$i], 'to', $val,
            '; max width:', $width_max);
      }

      $col->{max_val} = max($width, $col->{max_val});
      push @line, $val;
   }

   return \@line;
}

# Returns the formatted report for the columsn and lines added earlier.
sub get_report {
   my ( $self ) = @_;

   my @col_fmts = $self->_make_col_formats();
   my $fmt = ($self->{line_prefix} || '')
           . join($self->{column_spacing}, @col_fmts);
   MKDEBUG && _d('Format:', $fmt);

   # Make the printf line format for the header and ensure that its labels
   # are always left justified.
   (my $hdr_fmt = $fmt) =~ s/%([^-])/%-$1/g;

   # Build the report line by line, starting with the title and header lines.
   my @lines;
   push @lines, sprintf "$self->{line_prefix}$self->{title}" if $self->{title};
   push @lines, $self->truncate_line(
         sprintf($hdr_fmt, map { $_->{name} } @{$self->{cols}}),
         strip => 1,
         mark  => '',
   );

   if ( $self->{underline_header} ) {
      my @underlines = map {
         my $underline = '=' x ($_->{width_max} || $_->{max_val});
         $underline;
      } @{$self->{cols}};
      push @lines, $self->truncate_line(
         sprintf($fmt, @underlines),
         strip => 1,
         mark  => '',
      );
   }

   push @lines, map {
      my $line = sprintf($fmt, @$_);
      if ( $self->{extend_right} ) {
         $line;
      }
      else {
         $self->truncate_line($line);
      }
   } @{$self->{lines}};

   return join("\n", @lines) . "\n";
}

sub truncate_val {
   my ( $self, $col, $val, $width ) = @_;
   return $val if length $val <= $width;
   my $mark = $col->{truncate_mark};
   if ( $col->{truncate_side} eq 'right' ) {
      $val  = substr($val, 0, $width - length $mark);
      $val .= $mark;
   }
   elsif ( $col->{truncate_side} eq 'left') {
      $val = $mark . substr($val, -1 * ((length $val) - $width));
   }
   else {
      MKDEBUG && _d("Don't know how to", $col->{truncate_side}, "line");
   }
   return $val;
}

sub truncate_line {
   my ( $self, $line, %args ) = @_;
   my $mark = defined $args{mark} ? $args{mark} : $self->{truncate_line_mark};
   if ( $line ) {
      $line =~ s/\s+$// if $args{strip};
      my $len  = length($line);
      if ( $len > $self->{line_width} ) {
         $line  = substr($line, 0, $self->{line_width} - length $mark);
         $line .= $mark if $mark;
      }
   }
   return $line;
}

sub _column_error {
   my ( $self, $err ) = @_;
   my $msg = "Column error: $err";
   $self->{column_errors} eq 'die' ? die $msg : warn $msg;
   return;
}

# Make the printf line format for each row given the columns' settings.
sub _make_col_formats {
   my ( $self ) = @_;
   my @col_fmts;
   my $n_cols = $self->{n_cols} - 1;

   # Check for relative/percentage width columns.  There there are any,
   # then resolve their final print width.
   $self->_resolve_col_widths();

   for my $i ( 0..$n_cols ) {
      my $col      = $self->{cols}->[$i];
      my $wid      = $i == $n_cols && !$col->{right_justify} ? ''
                   : $col->{width_max} || $col->{max_val};
      my $col_fmt  = '%'
                   . ($col->{right_justify} ? '' : '-')
                   . $wid
                   . 's';
      push @col_fmts, $col_fmt;
   }
   return @col_fmts;
}

sub _resolve_col_widths {
   my ( $self ) = @_;
   my $n_cols   = $self->{n_cols} - 1;
   my $line_wid
      = $self->{line_width}; # - (($n_cols - 1) * length $self->{column_spacing});

   my $have_relative_cols = 0;
   for my $i ( 0..$n_cols ) {
      my $col = $self->{cols}->[$i];
      if ( $col->{width_max} ) {
         $line_wid -= $col->{width_max};
      }
      else {
         $have_relative_cols = 1;
      }
   }
   MKDEBUG && _d('Have relative cols:', $have_relative_cols);

   if ( $have_relative_cols ) {
      MKDEBUG && _d($line_wid, 'chars for pct widths');
      for my $i ( 0..$n_cols ) {
         my $col = $self->{cols}->[$i];
         if ( $col->{width_pct} ) {
            my $wid = int($line_wid * ($col->{width_pct} / 100));
            MKDEBUG && _d($col->{name}, $col->{width_pct}, '% ==',
               $wid, 'chars');
            if ( $wid < $col->{min_val} ) {
               MKDEBUG && _d('Increased to min val width:', $col->{min_val});
               $wid = $col->{min_val}
            }
            elsif ( $wid > $col->{max_val} ) {
               MKDEBUG && _d('Reduced to max val width:', $col->{max_val});
               $wid = $col->{max_val};
            }
            $col->{width_max} = $wid;
         }
      }

      my @new_lines;
      foreach my $vals ( @{$self->{lines}} ) {
         push @new_lines, $self->_check_line_vals($vals);
      }
      $self->{lines} = \@new_lines;
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
