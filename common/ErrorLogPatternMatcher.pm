# This program is copyright 2009-2010 Percona Inc.
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

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

sub new {
   my ( $class, %args ) = @_;
   my $self = {
      %args,
      patterns => [],
      compiled => [],
      level    => [],
      name     => [],
   };
   return bless $self, $class;
}

sub add_patterns {
   my ( $self, $patterns ) = @_;
   foreach my $p ( @$patterns ) {
      next unless $p && scalar @$p;
      my ($name, $level, $regex) = @$p;
      push @{$self->{names}},    $name;
      push @{$self->{levels}},   $level;
      push @{$self->{patterns}}, $regex;
      push @{$self->{compiled}}, qr/$regex/;
      MKDEBUG && _d('Added new pattern:', $name, $level, $regex,
         $self->{compiled}->[-1]);
   }
   return;
}

sub load_patterns_file {
   my ( $self, $fh ) = @_;
   local $INPUT_RECORD_SEPARATOR = '';
   my %seen;
   my $pattern;
   while ( defined($pattern = <$fh>) ) {
      my ($name, $level, $regex) = split("\n", $pattern);
      if ( !($name && $level && $regex) ) {
         warn "Pattern missing name, level or regex:\n$pattern";
         next;
      }
      if ( $seen{$name}++ ) {
         warn "Duplicate pattern: $name";
         next;
      }
      $self->add_patterns( [[$name, $level, $regex]] );
   }
   return;
}

sub reset_patterns {
   my ( $self ) = @_;
   $self->{names}    = [];
   $self->{levels}   = [];
   $self->{patterns} = [];
   $self->{compiled} = [];
   MKDEBUG && _d('Reset patterns');
   return;
}

sub patterns {
   my ( $self ) = @_;
   return @{$self->{patterns}};
}

sub names {
   my ( $self ) = @_;
   return @{$self->{names}};
}

sub levels {
   my ( $self ) = @_;
   return @{$self->{levels}};
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

   # If there's a query, let QueryRewriter fingerprint it.   
   if ( $self->{QueryRewriter}
        && (my ($query) = $err =~ m/Statement: (.+)$/) ) {
      $query = $self->{QueryRewriter}->fingerprint($query);
      $err =~ s/Statement: .+$/Statement: $query/;
   }

   my $compiled = $self->{compiled};
   my $n        = (scalar @$compiled) - 1;
   my $pno;
   PATTERN:
   for my $i ( 0..$n ) {
      if ( $err =~ m/$compiled->[$i]/ ) {
         $pno = $i;
         last PATTERN;
      } 
   }

   if ( defined $pno ) {
      MKDEBUG && _d($err, 'matches', $self->{patterns}->[$pno]);
      $event->{New_pattern} = 'No';
      $event->{Pattern_no}  = $pno;

      # Set Level if missing and we know it.
      if ( !$event->{Level} && $self->{levels}->[$pno] ) {
         $event->{Level} = $self->{levels}->[$pno];
      }
   }
   else {
      MKDEBUG && _d('New pattern');
      my $regex = $self->fingerprint($err);
      my $name  = substr($err, 0, 160);
      $self->add_patterns( [ [$name, $event->{Level}, $regex] ] );
      $event->{New_pattern} = 'Yes';
      $event->{Pattern_no}  = (scalar @{$self->{patterns}}) - 1;
   }

   $event->{Pattern} = $self->{patterns}->[ $event->{Pattern_no} ];

   return $event;
}

sub fingerprint {
   my ( $self, $err ) = @_;

   # Escape special regex characters like ( and ) so they
   # are literal matches in the compiled pattern.
   $err =~ s/([\(\)\[\].+?*\{\}])/\\$1/g;

   # Abstract the error message.
   $err =~ s/\b\d+\b/\\d+/g;              # numbers
   $err =~ s/\b0x[0-9a-zA-Z]+\b/0x\\S+/g; # hex values

   return $err;
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
