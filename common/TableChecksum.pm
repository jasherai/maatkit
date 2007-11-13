# This program is copyright (c) 2007 Baron Schwartz.
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
# TableChecksum package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableChecksum;

use English qw(-no_match_vars);
use POSIX qw(ceil);
use List::Util qw(min max);

our %ALGOS = (
   CHECKSUM => { pref => 0, hash => 0 },
   ACCUM    => { pref => 1, hash => 1 },
   BIT_XOR  => { pref => 2, hash => 1 },
);

sub new {
   bless {}, shift;
}

# Options:
#   algorithm   Optional: one of CHECKSUM, ACCUM, BIT_XOR
#   vp          VersionParser object
#   dbh         DB handle
#   where       bool: whether user wants a WHERE clause applied
#   chunk       bool: whether user wants to checksum in chunks
#   replicate   bool: whether user wants to do via replication
#   count       bool: whether user wants a row count too
sub best_algorithm {
   my ( $self, %opts ) = @_;
   my ($alg, $vp, $dbh) = @opts{ qw(algorithm vp dbh) };
   my @choices = sort { $ALGOS{$a}->{pref} <=> $ALGOS{$b}->{pref} } keys %ALGOS;
   die "Invalid checksum algorithm $alg"
      if $alg && ! grep { $_ eq $alg } @choices;

   # CHECKSUM is eliminated by lots of things...
   if ( 
      $opts{where} || $opts{chunk}        # CHECKSUM does whole table
      || $opts{replicate}                 # CHECKSUM can't do INSERT.. SELECT
      || !$vp->version_ge($dbh, '4.1.1')) # CHECKSUM doesn't exist
   {
      @choices = grep { $_ ne 'CHECKSUM' } @choices;
   }

   # BIT_XOR isn't available till 4.1.1 either
   if ( !$vp->version_ge($dbh, '4.1.1') ) {
      @choices = grep { $_ ne 'BIT_XOR' } @choices;
   }

   # Choose the best (fastest) among the remaining choices.
   if ( $alg && grep { $_ eq $alg } @choices ) {
      # Honor explicit choices.
      return $alg;
   }

   # If the user wants a count, prefer something other than CHECKSUM, because it
   # requires an extra query for the count.
   if ( $opts{count} && grep { $_ ne 'CHECKSUM' } @choices ) {
      @choices = grep { $_ ne 'CHECKSUM' } @choices;
   }

   return $choices[0];
}

sub is_hash_algorithm {
   my ( $self, $algorithm ) = @_;
   return $ALGOS{$algorithm} && $ALGOS{$algorithm}->{hash};
}

sub choose_hash_func {
   my ( $self, %opts ) = @_;
   my @funcs = qw(SHA1 MD5);
   if ( $opts{func} && !grep { uc $opts{func} eq $_ } @funcs ) {
      unshift @funcs, $opts{func};
   }
   my ($result, $error);
   do {
      my $func;
      eval {
         $func = shift(@funcs);
         $opts{dbh}->do("SELECT $func('test-string')");
         $result = $func;
      };
      if ( $EVAL_ERROR && $EVAL_ERROR =~ m/failed: (.*?) at \S+ line/ ) {
         $error .= qq{$func cannot be used because "$1"\n};
      }
   } while ( @funcs && !$result );

   die $error unless $result;
   return $result;
}

# Figure out which slice in a sliced BIT_XOR checksum should have the actual
# concat-columns-and-checksum, and which should just get variable references.
# Stash the slice in $self for later reference.
sub optimize_xor {
   my ( $self, $dbh, $func ) = @_;

   my $crc_slice = 0;
   my $unsliced  = uc $dbh->selectall_arrayref("SELECT $func('a')")->[0]->[0];
   my $sliced    = '';
   my $start     = 1;
   my $crc_wid   = length($unsliced) < 16 ? 16 : length($unsliced);

   do { # Try different positions till sliced result equals non-sliced.
      $dbh->do('SET @crc := NULL, @cnt := 0');
      my $slices = $self->make_slices($crc_slice, "\@crc := $func('a')");
      my $sql    = "SELECT CONCAT($slices) AS TEST FROM (SELECT NULL) AS x";
      $sliced    = ($dbh->selectrow_array($sql))[0];
      if ( $sliced ne $unsliced ) {
         $start += 16;
         ++$crc_slice;
      }
   } while ( $start < $crc_wid && $sliced ne $unsliced );

   if ( $sliced ne $unsliced ) {
      # Disable the user-variable optimization.
   }
}

# Returns an expression that will do a bitwise XOR over a very wide integer,
# such as that returned by SHA1, which is too large to just put into BIT_XOR().
# $query is an expression that returns a row's checksum, $crc_wid is the width
# of that expression in characters.  If the opt_xor argument is given, use a
# variable to avoid calling the $query expression multiple times.  The variable
# goes in slice $opt_slice.
sub make_xor_slices {
   my ( $self, %opts ) = @_;
   my ( $query, $crc_wid, $opt_xor, $opt_slice )
      = @opts{qw(query crc_wid opt_xor opt_slice)};

   # Create a series of slices with @crc as a placeholder.
   my @slices;
   for ( my $start = 1; $start <= $crc_wid; $start += 16 ) {
      my $len = $crc_wid - $start + 1;
      if ( $len > 16 ) {
         $len = 16;
      }
      push @slices,
         "LPAD(CONV(BIT_XOR("
         . "CAST(CONV(SUBSTRING(\@crc, $start, $len), 16, 10) AS UNSIGNED))"
         . ", 10, 16), $len, '0')";
   }

   # Replace the placeholder with the expression.  If specified, add a
   # user-variable optimization so the expression goes in only one of the
   # slices.
   if ( defined $opt_slice && $opt_slice < @slices && $opt_xor ) {
      $slices[$opt_slice] =~ s/\@crc/\@crc := $query/;
   }
   else {
      map { s/\@crc/$query/ } @slices;
   }

   return join(', ', @slices);
}

1;

# ###########################################################################
# End TableChecksum package
# ###########################################################################
