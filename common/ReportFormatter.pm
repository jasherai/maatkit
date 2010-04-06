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
#  * truncate_underline  bool: don't underline beyond line_width
#  * column_errors       scalar: die or warn on column errors (default warn)
#  * truncate_data_lines bool: truncate data lines to line_width (default yes)
#  * column_spacing      scalar: string between columns (default one space)
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
      truncate_data_lines => 1,
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
#   * name           column's name
#   * truncate       (optional) can truncate column (default yes)
#   * truncate_mark  (optional) append string to truncate col vals (default ...)
#   * fixed_width    (optional) fixed width in characters
#   * min_width      (optional) minimum width in characters
#   * max_width      (optional) maximum width in characters
#   * undef_value    (optional) string for undef values (default '')
#   * trf            (optional) callback to transform values
#   * type           (optional) printf type (default s)
sub set_columns {
   my ( $self, @cols ) = @_;
   push @{$self->{cols}}, map {
      my $col = $_;
      die "Column does not have a name" unless defined $col->{name};
      if ( $col->{fixed_wdith} && $col->{fixed_width} < length $col->{name} ) { 
         die "Fixed width $col->{fixed_wdith} is less than length of "
            . "column name '$col->{name}'";
      }
      if ( $col->{min_width} && $col->{min_width} < length $col->{name} ) {
         die "Minimum width $col->{min_width} is less than length of "
            . "column name '$col->{name}'";
      }
      $col->{truncate_mark} ||= '...';
      $col->{type}          ||= 's';
      $col->{min_width}     ||= $col->{fixed_width} || 0;
      $col->{max_width}     ||= $col->{fixed_width} || 0;
      $col->{min_val_width}   = length $col->{name};
      $col->{max_val_width}   = length $col->{name};
      $col;
   } @cols;
   $self->{n_cols} = scalar @cols;
   return;
}

# Add a line to the report.  Does not print the line or the report.
# @vals is an array of values for each column.  There should be as
# many vals as columns.  Use undef for columns that have no values.
sub add_line {
   my ( $self, @vals ) = @_;
   my $n_vals = scalar @vals;
   $self->_column_error("Number of columns ($self->{n_cols}) and "
      . "values ($n_vals) do not match") unless $self->{n_cols} == $n_vals;

   my @line;
   for my $i ( 0..$#vals ) {
      my $col      = $self->{cols}->[$i];
      my $val      = defined $vals[$i] ? $vals[$i] : $col->{undef_value};
      my $width    = length $val;
      my $too_wide = 0;  # this var does double duty: it's a bool and also
                         # the max width at which to truncate the value
      if ( $col->{fixed_width} && $width > $col->{fixed_width} ) {
         $too_wide = $col->{fixed_width};
      }
      if ( $col->{max_width} && $width > $col->{max_width} ) {
         $too_wide = $col->{max_width};
      }
      if ( $too_wide ) {
         $self->_column_error("Value '$val' is too wide for column "
            . $col->{name}) unless $col->{truncate};
         # If _column_error() dies we never get here.  If it only warns
         # then we truncate the value despite $col->{truncate} being
         # false so the user gets something rather than nothing.
         $val = $self->_truncate($col, $val, $too_wide);
         MKDEBUG && _d('Truncated', $vals[$i], 'to', $val);
      }
      $col->{min_val_width} = min($width, $col->{min_val_width});
      $col->{max_val_width} = max($width, $col->{max_val_width});
      $val = $col->{trf}->($val) if $col->{trf};
      push @line, $val;
   }
   push @{$self->{lines}}, \@line;

   return;
}

# Returns the formatted report for the columsn and lines added earlier.
sub get_report {
   my ( $self ) = @_;

   # Make the printf line format for each row given the columns' settings.
   my $n_cols = $self->{n_cols} - 2;
   my @col_fmts;
   for my $i ( 0..$n_cols ) {
      my $col      = $self->{cols}->[$i];
      my $col_fmt  = '%'
                   . ($col->{right_justify} ? '' : '-')
                   . ($col->{max_width} || $col->{max_val_width} || '')
                   . ($col->{type} || 's');
      push @col_fmts, $col_fmt;
   }
   push @col_fmts, '%s';  # Let the column's value extend rightward forever

   my $fmt = ($self->{line_prefix} || '')
           . join($self->{column_spacing}, @col_fmts);
   MKDEBUG && _d('Format:', $fmt);

   # Make the printf line format for the header and ensure that its labels
   # are always left justified.
   (my $hdr_fmt = $fmt) =~ s/%([^-])/%-$1/g;

   # Build the report line by line, starting with the title and header lines.
   my @lines;
   push @lines, sprintf "$self->{line_prefix}$self->{title}" if $self->{title};
   push @lines, $self->_truncate_to_line_width(
         sprintf($hdr_fmt, map { $_->{name} } @{$self->{cols}}),
         strip => 1,
         mark  => undef,
   );

   if ( $self->{underline_header} ) {
      my @underlines = map {
         my $underline = '=' x $_->{max_val_width};
         $underline;
      } @{$self->{cols}};
      push @lines, $self->_truncate_to_line_width(
         sprintf($fmt, @underlines),
         strip => 1,
         mark  => undef,
      );
   }

   push @lines, map {
      my $line = sprintf($fmt, @$_);
      if ( $self->{truncate_data_lines} ) {
         $self->_truncate_to_line_width($line);
      }
      else {
         $line;
      }
   } @{$self->{lines}};

   return join("\n", @lines) . "\n";
}

sub _truncate {
   my ( $self, $col, $val, $width ) = @_;
   $val  = substr($val, 0, $width - length $col->{truncate_mark});
   $val .= $col->{truncate_mark};
   return $val;
}

sub _truncate_to_line_width {
   my ( $self, $line, %args ) = @_;
   $args{mark} = '...' unless exists $args{mark};
   if ( $line ) {
      $line =~ s/\s+$// if $args{strip};
      my $len  = length($line);
      if ( $len > $self->{line_width} ) {
         my $adj_len = $args{mark} ? length $args{mark} : 0;
         $line  = substr($line, 0, $self->{line_width} - $adj_len);
         $line .= $args{mark} if $args{mark};
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
