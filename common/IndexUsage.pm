# This program is copyright 2010-@CURRENTYEAR@ Percona Inc.
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
# IndexUsage package $Revision$
# ###########################################################################

# Package: IndexUsage
# IndexUsage tracks index and tables usage of queries.  It can then show which
# indexes are not used.  You use it by telling it about all the tables and
# indexes that exist, and then you give it index usage stats from
# <ExplainAnalyzer>.  Afterwards, you ask it to show you unused indexes.
#
# If the object is created with a dbh and db, then results (the indexes,
# tables, queries and index usages) are saved in tables.
package IndexUsage;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Sub: new
#
# Parameters:
#   %args - Arguments
#
# Returns:
#   IndexUsage object
sub new {
   my ( $class, %args ) = @_;
 
   my $self = {
      %args,
      tables_for  => {}, # Keyed off db
      indexes_for => {}, # Keyed off db->tbl
   };

   my $dbh = $args{dbh};
   my $db  = $args{db};
   if ( $dbh && $db ) {
      MKDEBUG && _d("Saving results to tables in database", $db);
      $self->{save_results} = 1;

      # See mk-index-usage --save-results-database for the table defs.
      $self->{insert_index_sth} = $dbh->prepare(
         "INSERT INTO `$db`.`indexes` (db, tbl, idx) VALUES (?, ?, ?) "
         . "ON DUPLICATE KEY UPDATE usage_cnt = usage_cnt + 1");
      $self->{insert_query_sth} = $dbh->prepare(
         "INSERT IGNORE INTO `$db`.`queries` (query_id, fingerprint, sample) "
         . " VALUES (CONV(?, 16, 10), ?, ?)");
      $self->{insert_tbl_sth} = $dbh->prepare(
         "INSERT INTO `$db`.`tables` (db, tbl) "
         . "VALUES (?, ?) "
         . "ON DUPLICATE KEY UPDATE usage_cnt = usage_cnt + 1");
      $self->{insert_index_usage_sth} = $dbh->prepare(
         "INSERT IGNORE INTO `$db`.`index_usage` (query_id, db, tbl, idx) "
         . "VALUES (CONV(?, 16, 10), ?, ?, ?)");
      $self->{insert_index_alt_sth} = $dbh->prepare(
         "INSERT IGNORE INTO `$db`.`index_alternatives` "
         . "(query_id, db, tbl, idx, alt_idx) "
         . "VALUES (CONV(?, 16, 10), ?, ?, ?, ?)");
   }

   return bless $self, $class;
}

# Sub: add_indexes
#   Tell the object that an index exists.  Internally, it just creates usage
#   counters for the index and the table it belongs to.  If saving results,
#   the index is inserted into the indexes table, too.
#
# Parameteres:
#   %args - Arguments
#
# Required Arguments:
#   db      - Database name
#   tbl     - Table name
#   indexes - Hashref to an indexes struct returned by <TableParser::get_keys()>
sub add_indexes {
   my ( $self, %args ) = @_;
   my @required_args = qw(db tbl indexes);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($db, $tbl, $indexes) = @args{@required_args};

   $self->{tables_for}->{$db}->{$tbl}  = 0;
   if ( $self->{save_results} ) {
      $self->{insert_tbl_sth}->execute($db, $tbl);
   }

   # Add to the indexes struct a cnt key for each index which is
   # incremented in add_index_usage().
   $self->{indexes_for}->{$db}->{$tbl} = $indexes;
   foreach my $index ( keys %$indexes ) {
      $indexes->{$index}->{cnt} = 0;
      if ( $self->{save_results} ) {
         $self->{insert_index_sth}->execute($db, $tbl, $index);
      }
      MKDEBUG && _d("Added index", $db, $tbl, $index);
   }

   return;
}

# Sub: add_table_usage
#   Increase usage count for table (even if no indexes in it are used). 
#   If saving results, the tables table is updated, too.
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   db      - Database name
#   tbl     - Table name
sub add_table_usage {
   my ( $self, $db, $tbl ) = @_;
   die "I need a db and table" unless defined $db && defined $tbl;
   ++$self->{tables_for}->{$db}->{$tbl};
   if ( $self->{save_results} ) {
      $self->{insert_tbl_sth}->execute($db, $tbl);
   }
   return;
}

# Sub: add_query
#   Add a query to the save results query table.  Duplicate queries are
#   ignored (easier to ignore than check if query is already in the table).
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   query_id    - Query ID (hex checksum of fingerprint)
#   fingerprint - Query fingerprint (<QueryRewriter::fingerprint()>)
#   sample      - Query SQL
sub add_query {
   my ( $self, %args ) = @_;
   my @required_args = qw(query_id fingerprint sample);
   foreach my $arg ( @required_args  ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my ($query_id, $fingerprint, $sample) = @args{@required_args};
   $self->{insert_query_sth}->execute($query_id, $fingerprint, $sample);
   return;
}

# Sub: add_index_usage
#   Save information about how a query used an index.
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   usage - Uusage information, in the same format as the output from
#           <ExplainAnalyzer::get_index_usage()>
#
# Optional Arguments:
#   query_id - Query ID, if saving results
sub add_index_usage {
   my ( $self, %args ) = @_;
   my @required_args = qw(usage);
   foreach my $arg ( @required_args  ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my ($usage) = @args{@required_args};

   ACCESS:
   foreach my $access ( @$usage ) {
      my ($db, $tbl, $idx, $alt) = @{$access}{qw(db tbl idx alt)};

      # Increment the index(es)'s usage counter.
      INDEX:
      foreach my $index ( @$idx ) {
         $self->{indexes_for}->{$db}->{$tbl}->{$index}->{cnt}++;

         if ( $self->{save_results} ) {
            $self->{insert_index_sth}->execute($db, $tbl, $index);
            if ( $args{query_id} ) {
               $self->{insert_index_usage_sth}->execute(
                  $args{query_id}, $db, $tbl, $index);

               foreach my $alt_index ( @$alt ) {
                  $self->{insert_index_alt_sth}->execute(
                     $args{query_id}, $db, $tbl, $index, $alt_index);
               }
            }
         }

      }  # INDEX
   } # ACCESS

   return;
}

# Sub: find_unused_indexes
#   Find unused indexes and pass them to the callback.
#   For every table in every database, determine whether each index was used or
#   not.  But only if the table was used.  Don't say "this index should be
#   dropped" if the table was never queried.  For each table, collect the unused
#   indexes and execute the callback subroutine with a hashref that looks like
#   this:
#   (start code)
#   { db => db, tbl => tbl, idx => [<list of unused indexes on this table>] }
#   (end code)
#
# Parameters:
#   $callback - Coderef called with unused indexes
sub find_unused_indexes {
   my ( $self, $callback ) = @_;
   die "I need a callback" unless $callback;

   # Local references to save typing
   my %indexes_for = %{$self->{indexes_for}};
   my %tables_for  = %{$self->{tables_for}};

   DATABASE:
   foreach my $db ( sort keys %{$self->{indexes_for}} ) {
      TABLE:
      foreach my $tbl ( sort keys %{$self->{indexes_for}->{$db}} ) {
         next TABLE unless $self->{tables_for}->{$db}->{$tbl}; # Skip unused
         my $indexes = $self->{indexes_for}->{$db}->{$tbl};
         my @unused_indexes;
         foreach my $index ( sort keys %$indexes ) {
            if ( !$indexes->{$index}->{cnt} ) { # count of times accessed/used
               push @unused_indexes, $indexes->{$index};
            }
         }
         if ( @unused_indexes ) {
            $callback->(
               {  db  => $db,
                  tbl => $tbl,
                  idx => \@unused_indexes,
               }
            );
         }
      } # TABLE
   } # DATABASE

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
# End IndexUsage package
# ###########################################################################
