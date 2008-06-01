

# ############################################################################
# Top-down algorithm
# ############################################################################

sub topdown {

   # Design a grouping strategy: user-defined, then finally primary key.
   my @groupings = { cols => $source->{info}->{keys}->{$source->{i}} };
   if ( $opts{d} ) {
      push @groupings, reverse map { { cols => [$_] } } $opts{d} =~ m/(\w+)/g;
   }

   # Now that the keys are known, find out the collation on the source.
   my @grp_cols = unique(map { @{$_->{cols}} } @groupings);
   find_collation($source->{dbh}, $source->{db_tbl}, \@grp_cols);

   # Array indices
   my ($WHERE, $LEVEL, $COUNT) = (0, 1, 2);

   # Queue of groups to drill into on next iteration.  Managing as a queue, not
   # stack, is breadth-first search, not depth-first.
   my @to_examine = [ {}, $#groupings, 0 ];

   # Lists of rows that differ in the target tables.
   my (@to_update, @to_delete, @to_insert);

   # Counters
   my %count = map { $_ => 0 } qw(ins upd del bad);

   do {
      my $work  = shift @to_examine;
      my $level = $work->[$LEVEL];
      my $where = $work->[$WHERE];

      my $grouping = $groupings[$level]->{cols};
      my $src_sth  = td_fetch_level($source, $level, $grouping, $where, 'source');
      my $dst_sth  = td_fetch_level($dest,   $level, $grouping, $where, 'dest');

      my ($sr, $dr);       # Source row, dest row
      my %this_level = ( rows => 0, cnt => 0 );

      # TODO: keep track of what the last change was, and accumulate adjacent
      # INSERT and UPDATE statements into IN() lists as I go.

      # The statements fetch in order, so use a 'merge' algorithm of advancing
      # after rows match.  This is essentially a FULL OUTER JOIN.
      MERGE:
      while ( 1 ) { # Exit this loop via 'last'

         if ( !$sr && $src_sth->{Active} ) {
            $sr = $src_sth->fetchrow_hashref;
         }
         if ( !$dr && $dst_sth->{Active} ) {
            $dr = $dst_sth->fetchrow_hashref;
         }

         # Compare the rows if both exist.  The result is used several places.
         my $cmp;
         if ( $sr && $dr ) {
            $cmp = key_cmp($source, $sr, $dr, $grouping);
         }

         last MERGE unless $sr || $dr;

         my %new_where = %$where;  # Will get more cols added and used below.

         # If the current row is the "same row" on both sides...
         if ( $sr && $dr && defined $cmp && $cmp == 0 ) {
            # The "same" row descends from parents that differ.
            if ( $sr->{__crc} ne $dr->{__crc} || ($level && ($sr->{__cnt} != $dr->{__cnt})) ) {
               @new_where{@$grouping} = @{$sr}{@$grouping};
               if ( $level ) {
                  # Special case: push $level - 1 because this will be processed
                  # later.
                  push @to_examine, [ \%new_where, $level - 1, $sr->{__cnt} ];
                  $this_level{cnt}++;
                  $this_level{rows} += $sr->{__cnt};
                  if ( $level && $opts{v} > 2 ) {
                     printf("-- Level %1d: CHECK  group of  %5d rows %s\n",
                        $level, $sr->{__cnt}, make_where_clause($source->{dbh}, \%new_where))
                        or die "Cannot print: $OS_ERROR";
                  }
               }
               else {
                  push @to_update, \%new_where;
                  $count{upd}++;
                  $count{bad}++;
                  if ( $opts{v} > 2 ) {
                     printf("-- Level %1d: UPDATE              1 row  %s\n",
                        $level, make_where_clause($source->{dbh}, \%new_where))
                        or die "Cannot print: $OS_ERROR";
                  }
               }
            }
            $sr = $dr = undef;
         }

         # The row in the source doesn't exist at the destination
         elsif ( !$dr || ( defined $cmp && $cmp < 0 ) ) {
            @new_where{@$grouping} = @{$sr}{@$grouping};
            push @to_insert, \%new_where;
            $count{ins} += $sr->{__cnt} || 1;
            $count{bad} += $sr->{__cnt} || 1;
            if ( $level && $opts{v} > 2 ) {
               printf("-- Level %1d: INSERT group of  %5d rows %s\n",
                  $level, $sr->{__cnt}, make_where_clause($source->{dbh}, \%new_where))
                  or die "Cannot print: $OS_ERROR";
            }
            $sr = undef;
         }

         # Symmetric to the above
         elsif ( !$sr || ( defined $cmp && $cmp > 0 ) ) {
            @new_where{@$grouping} = @{$dr}{@$grouping};
            push @to_delete, \%new_where;
            $count{del} += $dr->{__cnt} || 1;
            $count{bad} += $dr->{__cnt} || 1;
            if ( $level && $opts{v} > 2 ) {
               printf("-- Level %1d: DELETE group of  %5d rows %s\n",
                  $level, $dr->{__cnt}, make_where_clause($source->{dbh}, \%new_where))
                  or die "Cannot print: $OS_ERROR";
            }
            $dr = undef;
         }

         else {
            die "This code should never have run.  This is a bug.";
         }

         if ( $level < $#groupings && $opts{m} && $opts{m} < $count{bad}) {
            print "-- Level $level halt: $count{bad} rows, --maxcost=$opts{m}\n"
               or die "Cannot print: $OS_ERROR";
            return 0;
         }

      }

      if ( $opts{v} ) {
         printf("--          Level %1d total:   %5d bad rows      %5d to inspect\n",
            $level, $count{bad}, sum(map { $_->[$COUNT] } @to_examine) || 0)
            or die "Cannot print: $OS_ERROR";
      }
      if ( $opts{v} > 1 ) {
         printf("--          Level %1d summary: %5d bad groups in %5d src groups %5d dst groups\n",
            $level, scalar(@to_examine), $src_sth->rows, $dst_sth->rows)
            or die "Cannot print: $OS_ERROR";
         printf("--          Level %1d changes: %5d updates       %5d inserts    %5d deletes\n",
            $level, scalar(@to_update), $count{ins}, $count{del})
            or die "Cannot print: $OS_ERROR";
      }

      $level--;
   } while ( @to_examine );

   # Release locks/close transaction as soon as possible.
   if ( $opts{r} && $opts{F} && !$opts{1} ) {
      $dest->{dbh}->commit;
   }

   td_handle_data_change('DELETE', @to_delete);
   # Do UPDATE before INSERT because the current (bad) values may conflict with
   # newly INSERTed rows otherwise.
   if ( $opts{l} ) {
      td_handle_data_change('DELETE', @to_update);
      td_handle_data_change('INSERT', @to_update);
   }
   else {
      td_handle_data_change('UPDATE', @to_update);
   }
   td_handle_data_change('INSERT', @to_insert);
}

sub td_handle_data_change {
   my ( $action, @rows ) = @_;
   return unless $action =~ m/$opts{o}/i;
   foreach my $where ( @rows ) {
      # TODO I'm worried this is double-fetching rows that need to be
      # mass-inserted or updated.
      handle_data_change($action, $where);
   }
}

sub td_fetch_level {
   my ( $info, $level, $groupby, $where, $which ) = @_;
   my $dbh = $info->{dbh};
   my $tbl = $info->{info};

   # Columns that need to be in the checksum list.
   # TODO: why remove columns that are in the WHERE clause?  Answer: because
   # they are constant.  Unless they have some fancy (is null or foo = foo)
   # syntax.
   my @cols = grep { !exists($where->{$_}) } @{$tbl->{cols}};
   my $cols = col_list(@cols);

   # To handle nulls, make a bitmap of nullable columns that are null.
   my @null = grep { $tbl->{null_hash}->{$_} } @cols;
   my $null = @null
            ? (", CONCAT(" . join(', ', map  { "ISNULL(`$_`)" } @null) . ")")
            : '';

   my $grp  = col_list(@$groupby);
   my $crit = make_where_clause($dbh, $where);
   my $lock = '';

   if ( $opts{F} && !$opts{k} ) { # User wants us to lock for consistency.
      # Is this the server where changes will happen?
      my $is_target = $opts{r} ? $which eq 'source' : $which eq 'dest';
      $lock = $is_target ? ' FOR UPDATE' : ' LOCK IN SHARE MODE';
   }

   # Maxia's approach used SUM() as the aggregate function.  This is not a good
   # aggregate function; though it commutes, and is therefore order-independent,
   # the law of large numbers will cause checksum collisions on large data sets.
   # BIT_XOR() is really just a bitwise parity.  It is also order-independent,
   # but you expect any given bit in the result to be essentially a random coin
   # flip over the group.

   my $query;
   # Design the column checksum expression.
   if ( $level ) {
      my $slices = make_slices("$func(CONCAT_WS('$opts{e}', $cols$null))");
      $query = "SELECT /*$which:$info->{db_tbl}*/ $grp, COUNT(*) AS __cnt, "
         . "CONCAT($slices) AS __crc "
         . "FROM $info->{db_tbl} $crit GROUP BY $grp ORDER BY $grp$lock";
   }
   else {
      $query = "SELECT /*$which:$info->{db_tbl}*/ $grp, "
         . "MD5(CONCAT_WS('$opts{e}', $cols$null)) AS __crc "
         . "FROM $info->{db_tbl} $crit "
         . "ORDER BY $grp$lock";
   }
   debug_print($query);

   my $sth = $dbh->prepare($query, { mysql_use_result => !$opts{bufferresults}});
   $sth->execute();
   return $sth;
}

