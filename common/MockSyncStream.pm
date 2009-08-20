# This program is copyright 2009 Percona Inc.
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
# MockSyncStream package $Revision$
# ###########################################################################
package MockSyncStream;

# This package implements a special, mock version of TableSyncStream.
# It's used by mk-upgrade to quickly compare result sets for any differences.
# If any are found, mk-upgrade writes all remaining rows to an outfile.
# This causes RowDiff::compare_sets() to terminate early.  So we don't actually
# sync anything.  Unlike TableSyncStream, we're not working with a table but an
# arbitrary query executed on two servers.

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(query cols same_row not_in_left not_in_right) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   return bless { %args }, $class;
}

sub get_sql {
   my ( $self ) = @_;
   return $self->{query};
}

sub same_row {
   my ( $self, $lr, $rr ) = @_;
   return $self->{same_row}->($lr, $rr);
}

sub not_in_right {
   my ( $self, $lr ) = @_;
   return $self->{not_in_right}->($lr);
}

sub not_in_left {
   my ( $self, $rr ) = @_;
   return $self->{not_in_left}->($rr);
}

sub done_with_rows {
   my ( $self ) = @_;
   $self->{done} = 1;
}

sub done {
   my ( $self ) = @_;
   return $self->{done};
}

sub key_cols {
   my ( $self ) = @_;
   return $self->{cols};
}

# Do any required setup before executing the SQL (such as setting up user
# variables for checksum queries).
sub prepare {
   my ( $self, $dbh ) = @_;
   return;
}

# Return 1 if you have changes yet to make and you don't want the MockSyncer to
# commit your transaction or release your locks.
sub pending_changes {
   my ( $self ) = @_;
   return;
}

# RowDiff::key_cmp() requires $tlb and $key_cols but we're not syncing
# a table so we can't use TableParser.  The following sub use sth
# attributes to return the query's columns and column types (in a pseudo,
# minimal tbl struct sufficient for RowDiff::key_cmp()).  Returns an arrayref
# of columns and a tbl struct hashref.
# TODO: extend this to return more info about the cols so we can compare them
sub get_cols_and_struct {
   my ( $dbh, $sth ) = @_;

   my @cols  = @{$sth->{NAME}};
   my @types = map { scalar $dbh->type_info($_)->{TYPE_NAME} } @{$sth->{TYPE}};

   my $struct = {
      is_numeric    => {},
      # collation_for => {},
   };
   for my $i ( 0..$#cols ) {
      my $col  = $cols[$i];
      my $type = $types[$i];
      $struct->{is_numeric}->{$col} 
         = ($type =~ m/(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/ ? 1 : 0);
   }

   return \@cols, $struct;
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
# End MockSyncStream package
# ###########################################################################
