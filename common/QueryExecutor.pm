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
# QueryExecutor package $Revision$
# ###########################################################################
package QueryExecutor;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Time::HiRes qw(time);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw() ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {};
   return bless $self, $class;
}

# Executes a query on the given host dbhs, calling pre- and post-execution
# callbacks for each host.  Returns an array of hashrefs, one for each host,
# with results from whatever the callbacks return.  Each callback usually
# returns a name (of what its results are called) and hashref with values
# for its results.  Or, a callback my return nothing in which case it's
# ignored (to allow setting MySQL vars, etc.)
#
# All callbacks are passed the query and the current host's dbh.  Post-exec
# callbacks get an extra args: Query_time which is the query's execution time
# rounded to six places (microsecond precision).
#
# Some common callbacks are provided in this package: get_Query_time(),
# get_warnings(), clear_warnings(), checksum_results().
#
# If the query cannot be executed on a host, an error string is returned
# for that host instead of a hashref of results.
#
# Required arguments:
#   * query                The query to execute
#   * pre_exec_callbacks   Arrayref of pre-exec query callback subs
#   * post_exec_callbacks  Arrayref of post-exec query callback subs
#   * dbhs                 Arrayref of host dbhs
#
sub exec {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(query dbhs pre_exec_callbacks post_exec_callbacks) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $query = $args{query};
   my $dbhs  = $args{dbhs};
   my $pre   = $args{pre_exec_callbacks};
   my $post  = $args{post_exec_callbacks};

   MKDEBUG && _d('exec:', $query);

   my @results;
   my $hostno = -1;
   HOST:
   foreach my $dbh ( @$dbhs ) {
      $hostno++;  # Increment this now because we might not reach loop's end.
      $results[$hostno] = {};
      my $results = $results[$hostno];

      # Call pre-exec callbacks.
      foreach my $callback ( @$pre ) {
         my ($name, $res);
         eval {
            ($name, $res) = $callback->(
               query => $query,
               dbh   => $dbh
            );
         };
         if ( $EVAL_ERROR ) {
            MKDEBUG && _d('Error during pre-exec callback:', $EVAL_ERROR);
            $results = $EVAL_ERROR;
            next HOST;
         }
         $results->{$name} = $res if $name;
      }

      # Execute the query on this host. 
      my ( $start, $end, $query_time );
      eval {
         $start = time();
         $dbh->do($query);
         $end   = time();
         $query_time = sprintf '%.6f', $end - $start;
      };
      if ( $EVAL_ERROR ) {
         MKDEBUG && _d('Error executing query on host', $hostno, ':',
            $EVAL_ERROR);
         $results = $EVAL_ERROR;
         next HOST;
      }

      # Call post-exec callbacks.
      foreach my $callback ( @$post ) {
         my ($name, $res);
         eval {
            ($name, $res) = $callback->(
               query      => $query,
               dbh        => $dbh,
               Query_time => $query_time,
            );
         };
         if ( $EVAL_ERROR ) {
            MKDEBUG && _d('Error during post-exec callback:', $EVAL_ERROR);
            $results = $EVAL_ERROR;
            next HOST;
         }
         $results->{$name} = $res if $name;
      }
   } # HOST

   MKDEBUG && _d('results:', Dumper(\@results));
   return @results;
}

sub get_query_time {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(Query_time) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $name = 'Query_time';
   MKDEBUG && _d($name);
   return $name, $args{Query_time};
}

# Returns an array with its name and a hashref with warnings/errors:
# (
#   warnings,
#   {
#     count => 3,         # @@warning_count,
#     codes => {          # SHOW WARNINGS
#       1062 => {
#         Level   => "Error",
#         Code    => "1062",
#         Message => "Duplicate entry '1' for key 1",
#       }
#     },
#   }
# )
sub get_warnings {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(dbh) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $dbh = $args{dbh};

   my $name = 'warnings';
   MKDEBUG && _d($name);

   my $warnings;
   my $warning_count;
   eval {
      $warnings      = $dbh->selectall_hashref('SHOW WARNINGS', 'Code');
      $warning_count = $dbh->selectall_arrayref('SELECT @@warning_count',
         { Slice => {} });
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d('Error getting warnings:', $EVAL_ERROR);
      return $name, $EVAL_ERROR;
   }
   my $results = {
      codes => $warnings,
      count => $warning_count->[0]->{'@@warning_count'},
   };

   return $name, $results;
}

sub clear_warnings {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(dbh query QueryParser) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $dbh     = $args{dbh};
   my $query   = $args{query};
   my $qparser = $args{QueryParser};

   MKDEBUG && _d('clear_warnings');

   # On some systems, MySQL doesn't always clear the warnings list
   # after a good query.  This causes good queries to show warnings
   # from previous bad queries.  A work-around/hack is to
   # SELECT * FROM table LIMIT 0 which seems to always clear warnings.
   my @tables = $qparser->get_tables($query);
   if ( @tables ) {
      MKDEBUG && _d('tables:', @tables);
      my $sql = "SELECT * FROM $tables[0] LIMIT 0";
      MKDEBUG && _d($sql);
      $dbh->do($sql);
   }
   else {
      warn "Cannot clear warnings because the tables for this query cannot "
         . "be parsed: $query";
   }
   return;
}

# This sub and checksum_results() require that you append
# "CREATE TEMPORARY TABLE database.tmp_table AS" to the query before
# calling exec().  This sub drops an old tmp table if it exists,
# and sets the default storage engine to MyISAM.
sub pre_checksum_results {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(dbh tmp_table Quoter) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $dbh     = $args{dbh};
   my $tmp_tbl = $args{tmp_table};
   my $q       = $args{Quoter};

   MKDEBUG && _d('pre_checksum_results');

   eval {
      $dbh->do("DROP TABLE IF EXISTS $tmp_tbl");
      $dbh->do("SET storage_engine=MyISAM");
   };
   die $EVAL_ERROR if $EVAL_ERROR;
   return;
}

# Either call pre_check_results() as a pre-exec callback to exec() or
# do what it does manually before calling this sub as a post-exec callback.
# This sub checksums the tmp table created when the query was executed
# with "CREATE TEMPORARY TABLE database.tmp_table AS" alreay appended to it.
sub checksum_results {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(dbh tmp_table MySQLDump TableParser Quoter) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $dbh     = $args{dbh};
   my $tmp_tbl = $args{tmp_table};
   my $du      = $args{MySQLDump};
   my $tp      = $args{TableParser};
   my $q       = $args{Quoter};

   my $name = 'results';
   MKDEBUG && _d($name);

   my $n_rows;
   my $tbl_checksum;
   eval {
      $n_rows = $dbh->selectall_arrayref("SELECT COUNT(*) FROM $tmp_tbl");
      $tbl_checksum = $dbh->selectall_arrayref("CHECKSUM TABLE $tmp_tbl");
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d('Error counting rows or checksumming', $tmp_tbl, ':',
         $EVAL_ERROR);
      return $name, $EVAL_ERROR;
   }

   # Get parse the tmp table's struct if we can.
   my $tbl_struct;
   my $db = $args{database};
   if ( !$db ) {
      # No db given so check if tmp has db.
      ($db, undef) = $q->split_unquote($tmp_tbl);
   }
   if ( $db ) {
      my $ddl = $du->get_create_table($dbh, $q, $db, $tmp_tbl);
      if ( $ddl->[0] eq 'table' ) {
         eval {
            $tbl_struct = $tp->parse($ddl)
         };
         if ( $EVAL_ERROR ) {
            MKDEBUG && _d('Failed to parse', $tmp_tbl, ':', $EVAL_ERROR);
            return $name, $EVAL_ERROR;
         }
      }
   }
   else {
      MKDEBUG && _d('Cannot parse', $tmp_tbl, 'because no database');
   }

   my $sql = "DROP TABLE IF EXISTS $tmp_tbl";
   eval { $dbh->do($sql); };
   if ( $EVAL_ERROR ) {
      warn "Cannot $sql: $EVAL_ERROR";
   }

   my $results = {
      checksum     => $tbl_checksum->[0]->[1],
      n_rows       => $n_rows->[0]->[0],
      table_struct => $tbl_struct,
   };

   return $name, $results;
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
# End QueryExecutor package
# ###########################################################################
