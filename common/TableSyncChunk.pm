# This program is copyright 2007-2009 Baron Schwartz.
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
# TableSyncChunk package $Revision$
# ###########################################################################
package TableSyncChunk;
# This package implements a simple sync algorithm:
# * Chunk the table (see TableChunker.pm)
# * Checksum each chunk (state 0)
# * If a chunk differs, make a note to checksum the rows in the chunk (state 1)
# * Checksum them (state 2)
# * If a row differs, it must be synced
# See TableSyncStream for the TableSync interface this conforms to.

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use List::Util qw(max);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(TableChunker Quoter) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my $self = { %args };
   return bless $self, $class;
}

sub name {
   return 'Chunk';
}

sub can_sync {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(tbl_struct) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my ($exact, $cols) = $self->{TableChunker}->find_chunk_columns(
      %args,
      exact => 1,
   );
   # If Chunker can handle it OK, but *not* with exact chunk sizes, it means
   # it's using only the first column of a multi-column index, which could
   # be really bad.  It's better to use Nibble for these, because at least
   # it can reliably select a chunk of rows of the desired size.
   return unless $exact;

   if ( $args{index_struct}
        && !grep { $args{index_struct}->{name} eq $_->{name} } @$cols ) {
      MKDEBUG && _d('Cannot sync with', $args{index_struct}->{name});
      return;
   }

   return (
      chunk_col   => $cols->[0]->{column},
      chunk_index => $cols->[0]->{index},
   );
}

sub prepare_to_sync {
   my ( $self, %args ) = @_;
   my @required_args = qw(dbh db tbl tbl_struct cols
                          chunk_col chunk_index chunk_size ChangeHandler);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my $dbh      = $args{dbh};
   my $chunker  = $self->{TableChunker};

   $self->{chunk_index}   = $args{chunk_index};
   $self->{chunk_col}     = $args{chunk_col};
   $self->{crc_col}       = $args{crc_col};
   $self->{index_hint}    = $args{index_hint};
   $self->{ChangeHandler} = $args{ChangeHandler};

   $self->{ChangeHandler}->fetch_back($dbh);

   my @chunks;
   my %range_params = $chunker->get_range_statistics(%args);
   if ( !grep { !defined $range_params{$_} } qw(min max rows_in_range) ) {
      $args{chunk_size} = $chunker->size_to_rows(%args);
      @chunks = $chunker->calculate_chunks(%args, %range_params);
   }
   else {
      MKDEBUG && _d('No range statistics; using single chunk 1=1');
      @chunks = '1=1';
   }

   $self->{chunks}    = \@chunks;
   $self->{chunk_num} = 0;
   $self->{state}     = 0;

   return;
}

sub uses_checksum {
   return 1;
}

sub set_checksum_queries {
   my ( $self, $chunk_sql, $row_sql ) = @_;
   die "I need a chunk_sql argument" unless $chunk_sql;
   die "I need a row_sql argument" unless $row_sql;
   $self->{chunk_sql} = $chunk_sql;
   $self->{row_sql} = $row_sql;
   return;
}

# Depth-first: if there are any bad chunks, return SQL to inspect their rows
# individually.  Otherwise get the next chunk.  This way we can sync part of the
# table before moving on to the next part.
sub get_sql {
   my ( $self, %args ) = @_;
   if ( $self->{state} ) {
      return 'SELECT '
         . ($args{buffer_in_mysql} ? 'SQL_BUFFER_RESULT ' : '')
         . join(', ', map { $self->{Quoter}->quote($_) } @{$self->key_cols()})
         . ', ' . $self->{row_sql} . " AS $self->{crc_col}"
         . ' FROM ' . $self->{Quoter}->quote(@args{qw(database table)})
         . ' '. ($self->{index_hint} || '')
         . ' WHERE (' . $self->{chunks}->[$self->{chunk_num}] . ')'
         . ($args{where} ? " AND ($args{where})" : '');
   }
   else {
      return $self->{TableChunker}->inject_chunks(
         database   => $args{database},
         table      => $args{table},
         chunks     => $self->{chunks},
         chunk_num  => $self->{chunk_num},
         query      => $self->{chunk_sql},
         index_hint => $self->{index_hint},
         where      => [ $args{where} ],
      );
   }
}

sub prepare_sync_cycle {
   my ( $self, $dbh ) = @_;
   my $sql = 'SET @crc := "", @cnt := 0';
   MKDEBUG && _d($sql);
   $dbh->do($sql);
   return;
}

sub same_row {
   my ( $self, $lr, $rr ) = @_;
   if ( $self->{state} ) {
      if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
         $self->{ChangeHandler}->change('UPDATE', $lr, $self->key_cols());
      }
   }
   elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
      MKDEBUG && _d('Rows:', Dumper($lr, $rr));
      MKDEBUG && _d('Will examine this chunk before moving to next');
      $self->{state} = 1; # Must examine this chunk row-by-row
   }
}

# This (and not_in_left) should NEVER be called in state 0.  If there are
# missing rows in state 0 in one of the tables, the CRC will be all 0's and the
# cnt will be 0, but the result set should still come back.
sub not_in_right {
   my ( $self, $lr ) = @_;
   die "Called not_in_right in state 0" unless $self->{state};
   $self->{ChangeHandler}->change('INSERT', $lr, $self->key_cols());
}

sub not_in_left {
   my ( $self, $rr ) = @_;
   die "Called not_in_left in state 0" unless $self->{state};
   $self->{ChangeHandler}->change('DELETE', $rr, $self->key_cols());
}

sub done_with_rows {
   my ( $self ) = @_;
   if ( $self->{state} == 1 ) {
      $self->{state} = 2;
      MKDEBUG && _d('Setting state =', $self->{state});
   }
   else {
      $self->{state} = 0;
      $self->{chunk_num}++;
      MKDEBUG && _d('Setting state =', $self->{state},
         'chunk_num =', $self->{chunk_num});
   }
}

sub done {
   my ( $self ) = @_;
   MKDEBUG && _d('Done with', $self->{chunk_num}, 'of',
      scalar(@{$self->{chunks}}), 'chunks');
   MKDEBUG && $self->{state} && _d('Chunk differs; must examine rows');
   return $self->{state} == 0
      && $self->{chunk_num} >= scalar(@{$self->{chunks}})
}

sub pending_changes {
   my ( $self ) = @_;
   if ( $self->{state} ) {
      MKDEBUG && _d('There are pending changes');
      return 1;
   }
   else {
      MKDEBUG && _d('No pending changes');
      return 0;
   }
}

sub key_cols {
   my ( $self ) = @_;
   my @cols;
   if ( $self->{state} == 0 ) {
      @cols = qw(chunk_num);
   }
   else {
      @cols = $self->{chunk_col};
   }
   MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
   return \@cols;
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
# End TableSyncChunk package
# ###########################################################################
