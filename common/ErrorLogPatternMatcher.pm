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
# ErrorLogPatternMatcher package $Revision$
# ###########################################################################
package ErrorLogPatternMatcher;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   my $self = {
      %args,
      patterns => [],
      compiled => [],
   };
   return bless $self, $class;
}

# Escape characters that have special regex meaning.
sub _escape_regex {
   my ( $self, $str ) = @_;
   $str =~ s!([^A-Za-z_0-9 /:'"=;-])!\\$1!g;
   return $str;
}

sub add_patterns {
   my ( $self, @patterns ) = @_;
   my $patterns = $self->{patterns};
   foreach my $p ( @patterns ) {
      next unless $p;
      push @{$self->{patterns}}, $p;
      push @{$self->{compiled}}, qr/$p/;
      MKDEBUG && _d('Added new pattern:', $p, $self->{compiled}->[-1]);
   }
   return;
}

sub patterns {
   my ( $self ) = @_;
   return @{$self->{patterns}};
}

sub match {
   my ( $self, %args ) = @_;
   my @required_args = qw(event);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $event = @args{@required_args};
   my $err   = $event->{arg};
   return unless $err;

   my $compiled = $self->{compiled};
   my $n        = (scalar @$compiled) - 1;
   my $matches;
   PATTERN:
   for my $i ( 0..$n ) {
      if ( $err =~ m/$compiled->[$i]/ ) {
         $matches = $i;
         last PATTERN;
      } 
   }

   if ( defined $matches ) {
      MKDEBUG && _d($err, 'matches', $self->{patterns}->[$matches]);
      $event->{New_pattern} = 'No';
      $event->{Pattern_no}  = $matches;
   }
   else {
      MKDEBUG && _d('New pattern');

      # Call _escape_regex before new_pattern so we do not escape
      # the regex that new_pattern may insert.
      $err = $self->_escape_regex($err);

      my $new_pattern = $args{new_pattern} ?  $args{new_pattern}->($err)
                      : $err;
      $self->add_patterns($new_pattern);

      $event->{New_pattern} = 'Yes';
      $event->{Pattern_no}  = (scalar @{$self->{patterns}}) - 1;
   }

   $event->{Pattern} = $self->{patterns}->[ $event->{Pattern_no} ];

   return $event;
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
# End ErrorLogPatternMatcher package
# ###########################################################################
