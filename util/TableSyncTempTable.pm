
# ############################################################################
# Bottom-up algorithm
# ############################################################################

sub bottomup {

   # Ensure branch factor is a power of two.
   $opts{B} = max(2, 2 ** round( log($opts{B}) / log(2) ));

   # Store table prefix in hashes
   $source->{prefix} = "$opts{P}_s_";
   $dest->{prefix}   = "$opts{P}_d_";

   my $levels = 0;
   if ( $opts{U} ) {

      # Begin with estimates of table size to allow calculating the checksum
      # remainder on the first level.
      my $est_size    = $opts{S} || max( estimate_size($source), estimate_size($dest) );
      my $level_est_1 = bu_num_levels($est_size);

      # Determine the data type needed for the remainder column.
      my $rem_col        = bu_size_to_type(( $opts{B} ** ($level_est_1 + 2)) - 1);
      $source->{rem_col} = $rem_col;
      $dest->{rem_col}   = $rem_col;

      # Build the initial checksum tables and calculate how many summary tables to build.
      my $src_size    = bu_build_checksum( $source, $level_est_1 );
      my $level_est_2 = bu_num_levels( max( $est_size, $src_size ) );
      my $dst_size    = bu_build_checksum( $dest, $level_est_2 );
      my $true_size   = max( $src_size, $dst_size );
      $levels         = bu_num_levels( $true_size );

      # Similar to the above, choose a type for the __cnt columns
      my $cnt_col        = bu_size_to_type($true_size);
      $source->{cnt_col} = $cnt_col;
      $dest->{cnt_col}   = $cnt_col;

      # Check and possibly rebuild remainders.
      if ( $levels > $level_est_1 + 2 ) {
         # The initial estimated number of levels caused the first-level tables to
         # have too-small data types, and I don't want to run ALTER TABLE; I'd
         # rather ask the user to re-run.
         die "Table size estimates ($est_size) were too small; specify --size $true_size";
      }
      if ( $level_est_1 != $levels ) {
         bu_rebuild_remainder($source, $levels);
      }
      if ( $level_est_2 != $levels ) {
         bu_rebuild_remainder($dest, $levels);
      }

      # Build the trees, merge them, and clean them up. TODO this part can be
      # parallelized with fork.
      bu_build_tree($source, $levels);
      bu_build_tree($dest,   $levels);
   }
   else {
      $levels  = bu_existing_levels( $source );
   }

   my $finished_work = 1;
   if ( $opts{A} ) {
      # Determine the collation of the primary key columns on the source, then
      # do the comparison.
      find_collation($source->{dbh},
         "$source->{prefix}_0",
         $source->{info}->{keys}->{$source->{i}});
      $finished_work = bu_merge_tree($dest,   $source, $levels);
   }
   bu_cleanup_tree($dest, $source) if $finished_work && $opts{C};
}

# Builds the first-level checksum table and returns the number of rows in it.
# The bitwise & operator in the __rem calculation is essentially the same as
# MOD().  In unsigned arithmetic, num MOD 128 is the same as num & 127.  It has
# the advantage of taking the absolute value of the modulo though, so there will
# be no negative values.
sub bu_build_checksum {
   my ($info, $levels) = @_;
   my $dbh    = $info->{dbh};
   my $tbl    = $info->{info};
   my $pk     = col_list( @{ $tbl->{keys}->{$info->{i}} } );
   my @cols   = @{ $tbl->{cols} };
   my $cols   = col_list(@cols);
   my $pks    = join( ',', @{ $tbl->{defs} }{ @{ $tbl->{keys}->{$info->{i}} } } );
   my @null   = grep { $tbl->{null_hash}->{$_} } @cols;
   my $null = @null
            ? ( ", CONCAT(" . join( ', ', map {"ISNULL(`$_`)"} @null ) . ")" ) : '';
   my $name = "$info->{prefix}_0";
   my $mask = ($opts{B} ** ($levels - 1)) - 1;

   # Create the table
   my $query = "DROP TABLE IF EXISTS `$name`";
   debug_print($query);
   $dbh->do($query);
   ( $query = <<"   END") =~ s/\s+/ /g;
      CREATE $opts{T} TABLE `$name` (
         $pks,
         __crc CHAR(32) NOT NULL,
         __rem $info->{rem_col} UNSIGNED NOT NULL,
         KEY(__rem),
         PRIMARY KEY($pk)
      ) ENGINE=$opts{E}
   END
   debug_print($query);
   $dbh->do($query);

   # Populate it
   ( $query = <<"   END") =~ s/\s+/ /g;
      INSERT /*$info->{db_tbl}*/ INTO `$name`($pk, __crc, __rem)
      SELECT $pk,
         MD5(CONCAT_WS('$opts{e}', $cols$null)) AS __crc,
         CAST(CONV(RIGHT(MD5(CONCAT_WS('$opts{e}', $pk)), 16), 16, 10) AS UNSIGNED) & $mask AS __rem
      FROM $info->{db_tbl}
   END
   debug_print($query);
   my $sth = $dbh->prepare($query);
   $sth->execute();
   return $sth->rows;
}

sub bu_rebuild_remainder {
   my ( $info, $levels ) = @_;
   my $pk   = col_list( @{ $info->{info}->{keys}->{$info->{i}} } );
   my $mask = ($opts{B} ** ($levels - 1)) - 1;
   my $name = "$info->{prefix}_0";
   my $query = "UPDATE `$name` SET __rem = "
      . "CAST(CONV(RIGHT(MD5(CONCAT_WS('$opts{e}', $pk)), 8), 16, 10) AS UNSIGNED) & $mask";
   debug_print($query);
   $info->{dbh}->do($query);
}

# Builds the nth-level summary tables.
# TODO: allow to use other hash functions like SHA1, and genericize the substringing code
# and the required size of the columns.
sub bu_build_tree {
   my ($info, $levels) = @_;
   my $dbh = $info->{dbh};
   my $tbl = $info->{info};

   # Do from 1 because level 0 has already been built.
   foreach my $i ( 1 .. $levels ) {
      my $modulo   = int($opts{B} ** ( $levels - $i - 1 ));
      my $last_mod = $modulo * $opts{B};
      my $this_tbl = "$info->{prefix}_" . $i;
      my $last_tbl = "$info->{prefix}_" . ( $i - 1 );
      my $mask     = max(0, $modulo - 1);
      my $cnt_sum  = $i > 1 ? 'SUM(__cnt)' : 'COUNT(*)';

      # Create the table
      my $query = "DROP TABLE IF EXISTS `$this_tbl`";
      debug_print($query);
      $dbh->do($query);
      ( $query = <<"      END" ) =~ s/\s+/ /g;
         CREATE $opts{T} TABLE `$this_tbl` (
            __par INT NOT NULL,
            __crc CHAR(32) NOT NULL,
            __rem $info->{rem_col} UNSIGNED NOT NULL,
            __cnt $info->{cnt_col} UNSIGNED NOT NULL,
            KEY(__rem),
            PRIMARY KEY(__par)
         ) ENGINE=$opts{E}
      END
      debug_print($query);
      $dbh->do($query);

      # Populate it
      ( $query = <<"      END" ) =~ s/\s+/ /g;
         INSERT /*$info->{db_tbl}*/ INTO `$this_tbl`
            (__par, __crc, __rem, __cnt)
         SELECT __rem,
            CONCAT(
               LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(__crc, 1,  16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'),
               LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(__crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0')
            ) AS this_crc,
            __rem & $mask AS this_remainder,
            $cnt_sum AS total_rows
         FROM `$last_tbl`
         GROUP BY __rem
         ORDER BY NULL
      END
      debug_print($query);
      $dbh->do($query);
   }
}

# There are actually 1 more than $levels summary tables; there are tables 0 ..
# $levels (see bu_build_tree).  Level 0 has a different structure.  It has
# primary keys instead of a __par pointer.
# Returns true if it finished working.
# TODO: there is a lot of shared code here with topdown, maybe factor out the
# FULL OUTER JOIN-ish code into a subroutine?
sub bu_merge_tree {
   my ($dest, $source, $levels) = @_;

   my $level = $levels;
   my @bad_parents; # List of parents that must differ at current level
   my ( $rows_in_src, $rows_in_dst ) = (0,0);

   # Lists of rows that differ in the target tables.
   my (@to_update, @to_delete, @to_insert);
   my (@bulk_insert, @bulk_delete);

   # Counters
   my %count = map { $_ => 0 } qw(ins upd del bad);

   do {
      my $src_sth = bu_fetch_level($source, $level, @bad_parents);
      my $dst_sth = bu_fetch_level($dest,   $level, @bad_parents);

      # Reset for next loop, once used to fetch this loop
      @bad_parents = ();
      $rows_in_src = $rows_in_dst = 0;

      my @key = $level ? '__par' : @{$source->{info}->{keys}->{$source->{i}}};
      my ($sr, $dr); # Source row, dest row

      # The statements fetch in order, so use a 'merge' algorithm of advancing
      # after rows match.  This is essentially a FULL OUTER JOIN.
      MERGE:
      while ( 1 ) { # Exit this loop via 'last'

         if ( !$sr && $src_sth->{Active} ) {
            $sr = $src_sth->fetchrow_hashref;
            if ( $sr ) {
               $rows_in_src += $sr->{__cnt} || 1;
            }
         }
         if ( !$dr && $dst_sth->{Active} ) {
            $dr = $dst_sth->fetchrow_hashref;
            if ( $dr ) {
               $rows_in_dst += $dr->{__cnt} || 1;
            }
         }

         # Compare the rows if both exist.  The result is used several places.
         my $cmp;
         if ( $sr && $dr ) {
            $cmp = key_cmp($source, $sr, $dr, \@key);
         }

         last MERGE unless $sr || $dr;

         # If the current row is the "same row" on both sides...
         if ( $sr && $dr && defined $cmp && $cmp == 0 ) {
            # The "same" row descends from parents that differ.
            if ( $sr->{__crc} ne $dr->{__crc} ) {
               if ( $level ) {
                  push @bad_parents, $sr;
                  if ( $level && $opts{v} > 2 ) {
                     printf("-- Level %1d UPDATE parent:   %5d\n",
                        $level, $sr->{__par});
                  }
               }
               else {
                  $count{upd}++;
                  $count{bad}++;
                  push @to_update, $sr;
               }
            }
            $sr = $dr = undef;
         }

         # The row in the source doesn't exist at the destination
         elsif ( !$dr || ( defined $cmp && $cmp < 0 ) ) {
            if ( $level ) {
               push @bulk_insert, $sr;
               if ( $level && $opts{v} > 2 ) {
                  printf("-- Level %1d BULKIN parent:   %5d\n",
                     $level, $sr->{__par});
               }
            }
            else {
               push @to_insert, $sr;
               if ( $level && $opts{v} > 2 ) {
                  printf("-- Level %1d INSERT parent:   %5d\n",
                     $level, $sr->{__par});
               }
            }
            $count{ins} += $sr->{__cnt} || 1;
            $count{bad} += $sr->{__cnt} || 1;
            $sr = undef;
         }

         # Symmetric to the above
         elsif ( !$sr || ( defined $cmp && $cmp > 0 ) ) {
            if ( $level ) {
               push @bulk_delete, $dr;
               if ( $level && $opts{v} > 2 ) {
                  printf("-- Level %1d BULKDE parent:   %5d\n",
                     $level, $dr->{__par});
               }
            }
            else {
               push @to_delete, $dr;
               if ( $level && $opts{v} > 2 ) {
                  printf("-- Level %1d DELETE parent:   %5d\n",
                     $level, $dr->{__par});
               }
            }
            $count{del} += $dr->{__cnt} || 1;
            $count{bad} += $dr->{__cnt} || 1;
            $dr = undef;
         }

         else {
            die "This code should never have run.  This is a bug.";
         }

         if ( $level < $levels && $opts{m} && $opts{m} < $count{bad} ) {
            print "-- Level $level halt: $count{bad} rows, --maxcost=$opts{m}\n";
            return 0;
         }

      }

      my $sum_bulk_ins = sum(map { $_->{__cnt} } @bulk_insert) || 0;
      my $sum_bulk_del = sum(map { $_->{__cnt} } @bulk_delete) || 0;
      my $sum_parents  = sum(map { $_->{__cnt} || 1 } @bad_parents) || 0;
      my $num_bad_rows = scalar(@to_update) + scalar(@to_insert) + $sum_bulk_ins
                       + scalar(@to_delete) + $sum_bulk_del + $sum_parents;

      if ( $opts{v} ) {
         printf("--         Level %1d total:   %5d rows\n", $level, $num_bad_rows);
      }
      if ( $opts{v} > 1 ) {
         printf("--         Level %1d summary: %5d parents %5d src rows %5d dst rows\n",
            $level, scalar(@bad_parents), $rows_in_src, $rows_in_dst);
         printf("--         Level %1d changes: %5d updates %5d inserts  %5d deletes %5d total\n",
            $level, scalar(@to_update), scalar(@to_insert) + $sum_bulk_ins,
            scalar(@to_delete) + $sum_bulk_del,
            scalar(@to_update) + scalar(@to_insert) + $sum_bulk_ins
               + scalar(@to_delete) + $sum_bulk_del
         );
         printf("--         Level %1d bulk-op: %5d inserts %5d ins-rows %5d deletes %5d del-rows\n",
            $level, scalar(@bulk_insert), $sum_bulk_ins,
            scalar(@bulk_delete), $sum_bulk_del);
      }

      $level--;
   } while ( $level >= 0 && @bad_parents );

   bu_handle_data_change('DELETE', @to_delete);
   bu_handle_bulk_change('DELETE', $levels, $dest,   @bulk_delete);
   # Do UPDATE before INSERT because the current (bad) values may conflict with
   # newly INSERTed rows otherwise.
   if ( $opts{l} ) {
      bu_handle_data_change('DELETE', @to_update);
      bu_handle_data_change('INSERT', @to_update);
   }
   else {
      bu_handle_data_change('UPDATE', @to_update);
   }
   bu_handle_data_change('INSERT', @to_insert);
   bu_handle_bulk_change('INSERT', $levels, $source, @bulk_insert);

   return 1; # Finished the work.
}

sub bu_cleanup_tree {
   my @servers = @_;
   foreach my $info ( @servers ) {
      my @tables = @{$info->{dbh}->selectcol_arrayref('SHOW TABLES')};
      foreach my $table ( grep { m/^$info->{prefix}_\d+$/ } @tables ) {
         my $query = "DROP TABLE IF EXISTS `$table`";
         debug_print($query);
         $info->{dbh}->do($query);
      }
   }
}

# Finds atomic rows that got folded into an entirely insertable or deleteable
# part of the tree.
sub bu_handle_bulk_change {
   my ( $action, $levels, $info, @rows ) = @_;
   return unless $action =~ m/$opts{o}/i;
   my $pk = col_list( @{ $info->{info}->{keys}->{$info->{i}} } );
   my @rows_to_do;
   my $mask = ($opts{B} ** ($levels - 1)) - 1;

   foreach my $row ( @rows ) {

      # TODO: optimization.
      # This is logically correct, but MySQL won't use indexes:
      # "SELECT $pk FROM $info->{prefix}_0 WHERE __rem & $mask = $row->{__par}"
      # This ends up looking like __rem & 255 = 3.  This will match any of the
      # following (partial list):
      # +-------+--------+
      # | __rem | binary |
      # +-------+--------+
      # |     3 |     11 |
      # |    11 |   1011 |
      # |    15 |   1111 |
      # |    19 |  10011 |
      # |    31 |  11111 |
      # |    51 | 110011 |
      # |    59 | 111011 |
      # +-------+--------+
      # Notice the rightmost two bits are the same in each number.  All these
      # combinations can be generated by adding 3 and every number from 4 to the
      # maximum possible __rem value.  This is easiest to do by mentally
      # left-shifting by the appropriate number of digits and adding.  Suppose
      # $levels is such that the maximum __rem is 63; something like
      # $i = 1; while ( $i * 4 < 63 ) { print 3 + $i * 4; $i++; }
      # If the list is really long, it'll be less efficient for MySQL, so I'd
      # say only do this if the list is less than 20% of the number of __rem
      # values.

      my $parent = $row->{__par};
      my $query  = "SELECT $pk FROM $info->{prefix}_0 WHERE __rem & $mask = $parent";
      debug_print($query);
      my $vals = $info->{dbh}->selectall_arrayref($query, { Slice => {} });
      push @rows_to_do, @$vals;
   }

   bu_handle_data_change($action, @rows_to_do);
}

sub bu_handle_data_change {
   my ( $action, @rows ) = @_;
   return unless $action =~ m/$opts{o}/i;

   foreach my $row ( @rows ) {
      delete $row->{__crc}; # Now the row can be used as a WHERE clause
      handle_data_change($action, $row);
   }
}

sub bu_fetch_level {
   my ( $info, $level, @bad_parents ) = @_;
   my $dbh = $info->{dbh};
   my $tbl = "$info->{prefix}_" . $level;

   my $cols  = $level
             ? '__par, __cnt'
             : col_list( @{ $info->{info}->{keys}->{$info->{i}} } );
   my $where = @bad_parents
             ? "WHERE __rem IN(" . join(',', map { $_->{__par} } @bad_parents) . ")"
             : '';
   my $order = $level
             ? '__par'
             : col_list( @{ $info->{info}->{keys}->{$info->{i}} } );

   my $query = "SELECT $cols, __crc FROM $tbl $where ORDER BY $order";
   debug_print($query);
   my $sth = $dbh->prepare($query, { mysql_use_result => !$opts{bufferresults}});
   $sth->execute();
   return $sth;
}

# Returns how many levels of tables you need to build for a table of a given
# size.  If your B factor is 4 and you pass in 100, you need the summaries
# to be grouping mod 64, 16, 4, 1 so you need 4 levels (5 total including 0,
# which is row-for-row with the real table).
sub bu_num_levels {
   my ( $size ) = @_;
   return int( log($size) / log($opts{B}) );
}

# Returns the maximum modulus that the tables will need.
sub bu_size_to_type {
   my ( $size ) = @_;
   return $size < 256        ? 'TINYINT'
        : $size < 65536      ? 'SMALLINT'
        : $size < 16777216   ? 'MEDIUMINT'
        : $size < 4294967296 ? 'INT'
        :                      'BIGINT';
}

# Figure out how many levels exist for pre-existing tables.
sub bu_existing_levels {
   my ($info) = @_;
   my @tables = @{$info->{dbh}->selectcol_arrayref("SHOW TABLES")};
   @tables    = grep { m/^$info->{prefix}_\d+$/ } @tables;
   die "No existing tables with prefix $info->{prefix} found" unless @tables;
   return max(map { $_ =~ m/(\d+)$/g } @tables);
}
