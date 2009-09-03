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
# TableSyncNibble package $Revision$
# ###########################################################################
package TableSyncNibble;
# This package implements a moderately complex sync algorithm:
# * Prepare to nibble the table (see TableNibbler.pm)
# * Fetch the nibble'th next row (say the 500th) from the current row
# * Checksum from the current row to the nibble'th as a chunk
# * If a nibble differs, make a note to checksum the rows in the nibble (state 1)
# * Checksum them (state 2)
# * If a row differs, it must be synced
# See TableSyncStream for the TableSync interface this conforms to.
#
# TODO: a variation on this algorithm and benchmark:
# * create table __temp(....);
# * insert into  __temp(....) select pk_cols, row_checksum limit N;
# * select group_checksum(row_checksum) from __temp;
# * if they differ, select each row from __temp;
# * if rows differ, fetch back and sync as usual.
# * truncate and start over.

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use List::Util qw(max);
use Data::Dumper;
$Data::Dumper::Indent    = 0;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(dbh database table handler nibbler quoter struct
                        parser checksum cols vp chunksize where chunker
                        versionparser possible_keys trim) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }

   # Sanity check.  The row-level (state 2) checksums use __crc, so the table
   # had better not use that...
   $args{crc_col} = '__crc';
   while ( $args{struct}->{is_col}->{$args{crc_col}} ) {
      $args{crc_col} = "_$args{crc_col}"; # Prepend more _ until not a column.
   }
   MKDEBUG && _d('CRC column will be named', $args{crc_col});

   $args{sel_stmt} = $args{nibbler}->generate_asc_stmt(
      parser   => $args{parser},
      tbl      => $args{struct},
      index    => $args{possible_keys}->[0],
      quoter   => $args{quoter},
      asconly  => 1,
   );

   die "No suitable index found"
      unless $args{sel_stmt}->{index}
         && $args{struct}->{keys}->{$args{sel_stmt}->{index}}->{is_unique};
   $args{key_cols} = $args{struct}->{keys}->{$args{sel_stmt}->{index}}->{cols};

   # Decide on checksumming strategy and store checksum query prototypes for
   # later. TODO: some of this code might be factored out into TableSyncer.
   $args{algorithm} = $args{checksum}->best_algorithm(
      algorithm   => 'BIT_XOR',
      vp          => $args{vp},
      dbh         => $args{dbh},
      where       => 1,
      chunk       => 1,
      count       => 1,
   );
   $args{func} = $args{checksum}->choose_hash_func(
      dbh  => $args{dbh},
      func => $args{func},
   );
   $args{crc_wid}    = $args{checksum}->get_crc_wid($args{dbh}, $args{func});
   ($args{crc_type}) = $args{checksum}->get_crc_type($args{dbh}, $args{func});
   if ( $args{algorithm} eq 'BIT_XOR' && $args{crc_type} !~ m/int$/ ) {
      $args{opt_slice}
         = $args{checksum}->optimize_xor(dbh => $args{dbh}, func => $args{func});
   }

   $args{nibble_sql} ||= $args{checksum}->make_checksum_query(
      dbname    => $args{database},
      tblname   => $args{table},
      table     => $args{struct},
      quoter    => $args{quoter},
      algorithm => $args{algorithm},
      func      => $args{func},
      crc_wid   => $args{crc_wid},
      crc_type  => $args{crc_type},
      opt_slice => $args{opt_slice},
      cols      => $args{cols},
      trim      => $args{trim},
      buffer    => $args{bufferinmysql},
      precision => $args{float_precision},
   );
   $args{row_sql} ||= $args{checksum}->make_row_checksum(
      table     => $args{struct},
      quoter    => $args{quoter},
      func      => $args{func},
      cols      => $args{cols},
      trim      => $args{trim},
      precision => $args{float_precision},
   );

   $args{state}  = 0;
   $args{nibble} = 0;
   $args{handler}->fetch_back($args{dbh});
   return bless { %args }, $class;
}

# Returns a SELECT statement that either gets a nibble of rows (state=0) or,
# if the last nibble was bad (state=1 or 2), gets the rows in the nibble.
# This way we can sync part of the table before moving on to the next part.
# Required args: database, table
# Optional args: where
sub get_sql {
   my ( $self, %args ) = @_;
   if ( $self->{state} ) {
      # Selects the individual rows so that they can be compared.
      return 'SELECT /*rows in nibble*/ '
         . ($self->{bufferinmysql} ? 'SQL_BUFFER_RESULT ' : '')
         . join(', ', map { $self->{quoter}->quote($_) } @{$self->key_cols()})
         . ', ' . $self->{row_sql} . " AS $self->{crc_col}"
         . ' FROM ' . $self->{quoter}->quote(@args{qw(database table)})
         . ' WHERE (' . $self->__get_boundaries() . ')'
         . ($args{where} ? " AND ($args{where})" : '');
   }
   else {
      # Selects the rows as a nibble.
      my $where = $self->__get_boundaries();
      return $self->{chunker}->inject_chunks(
         database  => $args{database},
         table     => $args{table},
         chunks    => [$where],
         chunk_num => 0,
         query     => $self->{nibble_sql},
         where     => [$args{where}],
         quoter    => $self->{quoter},
      );
   }
}

# Returns a WHERE clause for selecting rows in a nibble relative to lower
# and upper boundary rows.  Initially neither boundary is defined, so we
# get the first upper boundary row and return a clause like:
#   WHERE rows < upper_boundary_row1
# This selects all "lowest" rows: those before/below the first nibble
# boundary.  The upper boundary row is saved (as cached_row) so that on the
# next call it becomes the lower boundary and we get the next upper boundary,
# resulting in a clause like:
#   WHERE rows > cached_row && col < upper_boundary_row2
# This process repeats for subsequent calls. Assuming that the source and
# destination tables have different data, executing the same query against
# them might give back a different boundary row, which is not what we want,
# so each boundary needs to be cached until the nibble increases.
sub __get_boundaries {
   my ( $self ) = @_;
   my $q = $self->{quoter};
   my $s = $self->{sel_stmt};
   my $lb;   # Lower boundary part of WHERE
   my $ub;   # Upper boundary part of WHERE
   my $row;  # Next upper boundary row or cached_row

   if ( $self->{cached_boundaries} ) {
      MKDEBUG && _d('Using cached boundaries');
      return $self->{cached_boundaries};
   }

   if ( $self->{cached_row} && $self->{cached_nibble} == $self->{nibble} ) {
      # If there's a cached (last) row and the nibble number hasn't increased
      # then a differing row was found in this nibble.  We re-use its
      # boundaries so that instead of advancing to the next nibble we'll look
      # at the row in this nibble (get_sql() will return its SELECT
      # /*rows in nibble*/ query).
      MKDEBUG && _d('Using cached row for boundaries');
      $row = $self->{cached_row};
   }
   else {
      MKDEBUG && _d('Getting next upper boundary row');
      my $sql;
      ($sql, $lb) = $self->__make_boundary_sql();  # $lb from outer scope!

      # Check that $sql will use the index chosen earlier in new().
      # Only do this for the first nibble.  I assume this will be safe
      # enough since the WHERE should use the same columns.
      if ( $self->{nibble} == 0 ) {
         my $explain_index = $self->__get_explain_index($sql);
         if ( ($explain_index || '') ne $s->{index} ) {
         die 'Cannot nibble table '.$q->quote($self->{database},$self->{table})
            . " because MySQL chose "
            . ($explain_index ? "the `$explain_index`" : 'no') . ' index'
            . " instead of the `$s->{index}` index";
         }
      }

      $row = $self->{dbh}->selectrow_hashref($sql);
      MKDEBUG && _d($row ? 'Got a row' : "Didn't get a row");
   }

   if ( $row ) {
      # Add the row to the WHERE clause as the upper boundary.  As such,
      # the table rows should be <= to this boundary.  (Conversely, for
      # any lower boundary the table rows should be > the lower boundary.)
      my $i = 0;
      $ub   = $s->{boundaries}->{'<='};
      $ub   =~ s/\?/$q->quote_val($row->{$s->{scols}->[$i++]})/eg;
   }
   else {
      # This usually happens at the end of the table, after we've nibbled
      # all the rows.
      MKDEBUG && _d('No upper boundary');
      $ub = '1=1';
   }

   # If $lb is defined, then this is the 2nd or subsequent nibble and
   # $ub should be the previous boundary.  Else, this is the first nibble.
   my $where = $lb ? "($lb AND $ub)" : $ub;

   $self->{cached_row}        = $row;
   $self->{cached_nibble}     = $self->{nibble};
   $self->{cached_boundaries} = $where;

   MKDEBUG && _d('WHERE clause:', $where);
   return $where;
}

# Returns a SELECT statement for the next upper boundary row and the
# lower boundary part of WHERE if this is the 2nd or subsequent nibble.
# (The first nibble doesn't have a lower boundary.)  The returned SELECT
# is largely responsible for nibbling the table because if the boundaries
# are off then the nibble may not advance properly and we'll get stuck
# in an infinite loop (issue 96).
sub __make_boundary_sql {
   my ( $self ) = @_;
   my $lb;
   my $q   = $self->{quoter};
   my $s   = $self->{sel_stmt};
   my $sql = "SELECT /*nibble boundary $self->{nibble}*/ "
      . join(',', map { $q->quote($_) } @{$s->{cols}})
      . " FROM " . $q->quote($self->{database}, $self->{table})
      . ($self->{versionparser}->version_ge($self->{dbh}, '4.0.9')
         ? " FORCE" : " USE")
      . " INDEX(" . $q->quote($s->{index}) . ")";
   if ( $self->{nibble} ) {
      # The lower boundaries of the nibble must be defined, based on the last
      # remembered row.
      my $tmp = $self->{cached_row};
      my $i   = 0;
      $lb     = $s->{boundaries}->{'>'};
      $lb     =~ s/\?/$q->quote_val($tmp->{$s->{scols}->[$i++]})/eg;
      $sql   .= ' WHERE ' . $lb;
   }
   $sql .= " ORDER BY " . join(',', map { $q->quote($_) } @{$self->{key_cols}})
         . ' LIMIT ' . ($self->{chunksize} - 1) . ', 1';
   MKDEBUG && _d('Lower boundary:', $lb);
   MKDEBUG && _d('Next boundary sql:', $sql);
   return $sql, $lb;
}

# Returns just the index value from EXPLAIN for the given query (sql).
sub __get_explain_index {
   my ( $self, $sql ) = @_;
   return unless $sql;
   my $explain;
   eval {
      $explain = $self->{dbh}->selectall_arrayref("EXPLAIN $sql",{Slice => {}});
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d($EVAL_ERROR);
      return;
   }
   MKDEBUG && _d('EXPLAIN key:', $explain->[0]->{key}); 
   return $explain->[0]->{key}
}

sub prepare {
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
         $self->{handler}->change('UPDATE', $lr, $self->key_cols());
      }
   }
   elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
      MKDEBUG && _d('Rows:', Dumper($lr, $rr));
      MKDEBUG && _d('Will examine this nibble before moving to next');
      $self->{state} = 1; # Must examine this nibble row-by-row
   }
}

# This (and not_in_left) should NEVER be called in state 0.  If there are
# missing rows in state 0 in one of the tables, the CRC will be all 0's and the
# cnt will be 0, but the result set should still come back.
sub not_in_right {
   my ( $self, $lr ) = @_;
   die "Called not_in_right in state 0" unless $self->{state};
   $self->{handler}->change('INSERT', $lr, $self->key_cols());
}

sub not_in_left {
   my ( $self, $rr ) = @_;
   die "Called not_in_left in state 0" unless $self->{state};
   $self->{handler}->change('DELETE', $rr, $self->key_cols());
}

sub done_with_rows {
   my ( $self ) = @_;
   if ( $self->{state} == 1 ) {
      $self->{state} = 2;
      MKDEBUG && _d('Setting state =', $self->{state});
   }
   else {
      $self->{state} = 0;
      $self->{nibble}++;
      delete $self->{cached_boundaries};
      MKDEBUG && _d('Setting state =', $self->{state},
         ', nibble =', $self->{nibble});
   }
}

sub done {
   my ( $self ) = @_;
   MKDEBUG && _d('Done with nibble', $self->{nibble});
   MKDEBUG && $self->{state} && _d('Nibble differs; must examine rows');
   return $self->{state} == 0 && $self->{nibble} && !$self->{cached_row};
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
      @cols = @{$self->{key_cols}};
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
# End TableSyncNibble package
# ###########################################################################
