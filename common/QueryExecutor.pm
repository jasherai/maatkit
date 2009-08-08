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

# Executes a query on the given hosts, calling pre- and post-execution
# callbacks for each host.  The idea is to collect results from various
# operations pertaining to the same query when ran on multiple hosts.  For
# example, the most basic operation called Query_time--which is always
# performed so there is always at least one op=>result returned for each
# host--is timing how long the query takes to execute.  Other operations
# do things like check for warnings after execution.
#
# Each operation is performed via a callback and is expected to return a
# key=>value pair where the key is the name of the operation and the value
# is the operation's results.  The results are a hashref with other
# operation-specific key=>value pairs; there should always be at least an
# error key that is undef for no error or a string saying what failed and
# possibly also an errors key that is an arrayref of strings with more
# specific errors if lots of things failed.
#
# All callbacks are passed the query, the current host's dbh and name,
# and the results from preceding operations.  Each callback is expected to
# handle its own errors, so do not die inside a callback!
#
# All callbacks are ran no matter what.  But since each callback gets the
# results off prior callbacks, you can fail gracefully in a callback by looking
# to see if some expected prior callback had an error or not.  So the important
# point for callbacks is: NEVER ASSUME SUCCESS AND NEVER FAIL SILENTLY.
#
# In fact, operations are checked and if something looks amiss, the module
# will complain and die loudly.
#
# Some common callbacks/operations are provided in this package:
# get_warnings(), clear_warnings(), checksum_results().
#
# Required arguments:
#   * query                The query to execute
#   * pre_exec_callbacks   Arrayref of pre-exec query callback subs
#   * post_exec_callbacks  Arrayref of post-exec query callback subs
#   * hosts                Arrayref of hosts, each of which is a hashref like:
#       {
#         dbh              (req) Already connected DBH
#         dsn              DSN for more verbose debug messages
#       }
#   * DSNParser            DSNParser obj in case any host dsns are given
#
sub exec {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(query hosts pre_exec_callbacks post_exec_callbacks) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $query = $args{query};
   my $hosts = $args{hosts};
   my $pre   = $args{pre_exec_callbacks};
   my $post  = $args{post_exec_callbacks};
   my $dp    = $args{DSNParser};

   MKDEBUG && _d('Executing query:', $query);

   my @results;
   my $hostno = -1;
   HOST:
   foreach my $host ( @$hosts ) {
      $hostno++;  # Increment this now because we might not reach loop's end.
      $results[$hostno] = {};
      my $results       = $results[$hostno];
      my $dbh           = $host->{dbh};
      my $dsn           = $host->{dsn};
      my $host_name     = $dp && $dsn ? $dp->as_string($dsn) : $hostno + 1;
      my %callback_args = (
         query     => $query,
         dbh       => $dbh,
         host_name => $host_name,
         results   => $results,
      );

      MKDEBUG && _d('Starting execution on host', $host_name);

      # Call pre-exec callbacks.
      foreach my $callback ( @$pre ) {
         my ($name, $res) = $callback->(%callback_args);
         _check_results($name, $res, $host_name, \@results);
         $results->{$name} = $res;
      }

      # Execute the query on this host. 
      {
         my ($name, $res) = ('Query_time', { error=>undef, Query_time=>-1, });
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
            $res->{error} = $EVAL_ERROR;
         }
         else {
            $res->{Query_time} = $query_time;
         }
         # Leave nothing to chance: check even ourselves.
         _check_results($name, $res, $host_name, \@results);
         $results->{$name} = $res;
      }

      # Call post-exec callbacks.
      foreach my $callback ( @$post ) {
         my ($name, $res) = $callback->(%callback_args);
         _check_results($name, $res, $host_name, \@results);
         $results->{$name} = $res;
      }

      MKDEBUG && _d('Results for host', $host_name, ':', Dumper($results));
   } # HOST

   return @results;
}

# Returns an array with its name and a hashref with warnings/errors:
# (
#   warnings,
#   {
#     error => undef|string,
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
   my $dbh   = $args{dbh};
   my $error = undef;
   my $name  = 'warnings';
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
      $error = $EVAL_ERROR;
   }

   my $results = {
      error => $error,
      codes => $warnings,
      count => $warning_count->[0]->{'@@warning_count'} || 0,
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
   my $error   = undef;
   my $name    = 'clear_warnings';
   MKDEBUG && _d($name);

   # On some systems, MySQL doesn't always clear the warnings list
   # after a good query.  This causes good queries to show warnings
   # from previous bad queries.  A work-around/hack is to
   # SELECT * FROM table LIMIT 0 which seems to always clear warnings.
   my @tables = $qparser->get_tables($query);
   if ( @tables ) {
      MKDEBUG && _d('tables:', @tables);
      my $sql = "SELECT * FROM $tables[0] LIMIT 0";
      MKDEBUG && _d($sql);
      eval {
         $dbh->do($sql);
      };
      if ( $EVAL_ERROR ) {
         MKDEBUG && _d('Error clearning warnings:', $EVAL_ERROR);
         $error = $EVAL_ERROR;
      }
   }
   else {
      $error = "Cannot clear warnings because the tables for this query cannot "
         . "be parsed.";
   }

   return $name, { error=>$error };
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
   my $error   = undef;
   my $name    = 'pre_checksum_results';
   MKDEBUG && _d($name);

   eval {
      $dbh->do("DROP TABLE IF EXISTS $tmp_tbl");
      $dbh->do("SET storage_engine=MyISAM");
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d('Error dropping table', $tmp_tbl, ':', $EVAL_ERROR);
      $error = $EVAL_ERROR;
   }
   return $name, { error=>$error };
}

# Either call pre_check_results() as a pre-exec callback to exec() or
# do what it does manually before calling this sub as a post-exec callback.
# This sub checksums the tmp table created when the query was executed
# with "CREATE TEMPORARY TABLE database.tmp_table AS" alreay appended to it.
# Since a lot can go wrong in this operation, the returned error will be the
# last error and errors will have all errors.
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
   my $error   = undef;
   my @errors  = ();
   my $name    = 'checksum_results';
   MKDEBUG && _d($name);

   my $tbl_checksum;
   my $n_rows;
   my $tbl_struct;
   eval {
      $n_rows = $dbh->selectall_arrayref("SELECT COUNT(*) FROM $tmp_tbl")->[0]->[0];
      $tbl_checksum = $dbh->selectall_arrayref("CHECKSUM TABLE $tmp_tbl")->[0]->[1];
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d('Error counting rows or checksumming', $tmp_tbl, ':',
         $EVAL_ERROR);
      $error = $EVAL_ERROR;
      push @errors, $error;
   }
   else {
      # We'll need a db to parse the tmp table's struct.
      my $db = $args{database};
      if ( !$db ) {
         # No db given so check if tmp has db.
         ($db, undef) = $q->split_unquote($tmp_tbl);
      }

      # Parse the tmp table's struct.
      if ( $db ) {
         eval {
            my $ddl = $du->get_create_table($dbh, $q, $db, $tmp_tbl);
            if ( $ddl->[0] eq 'table' ) {
               $tbl_struct = $tp->parse($ddl)
            };
         };
         if ( $EVAL_ERROR ) {
            MKDEBUG && _d('Failed to parse', $tmp_tbl, ':', $EVAL_ERROR); 
            $error = $EVAL_ERROR;
            push @errors, $error;
         }
      }
      else {
         $error = "Cannot parse $tmp_tbl struct because its database is unknown";
         push @errors, $error;
         MKDEBUG && _d($error);
      }
   }

   # Event if CHECKSUM TABLE or parsing the tmp table fails, let's try
   # to drop the tmp table so we don't waste space.
   my $sql = "DROP TABLE IF EXISTS $tmp_tbl";
   eval { $dbh->do($sql); };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d('Error dropping tmp table:', $EVAL_ERROR);
      $error = $EVAL_ERROR;
      push @errors, $error;
   }

   # These errors are more important so save them till the end in case
   # someone only looks at the last error and not all errors.
   if ( !defined $n_rows ) { # 0 rows returned is ok.
      $error = "SELECT COUNT(*) for getting the number of rows didn't return a value";
      push @errors, $error;
      MKDEBUG && _d($error);
   }
   if ( !$tbl_checksum ) {
      $error = "CHECKSUM TABLE didn't return a value";
      push @errors, $error;
      MKDEBUG && _d($error);
   }

   my $results = {
      error        => $error,
      errors       => \@errors,
      checksum     => $tbl_checksum || 0,
      n_rows       => $n_rows || 0,
      table_struct => $tbl_struct,
   };
   return $name, $results;
}   

sub _check_results {
   my ( $name, $res, $host_name, $all_res ) = @_;
   _die_bad_op('Operation did not return a name!', @_)
      unless $name;
   _die_bad_op('Operation did not return any results!', @_)
      unless $res || (scalar keys %$res);
   _die_bad_op("Operation results do no have an 'error' key")
      unless exists $res->{error};
   _die_bad_op("Operation error is blank string!")
      if defined $res->{error} && !$res->{error};
   _die_bad_op("Operation errors is not an arrayref!")
      if $res->{errors} && ref $res->{errors} ne 'ARRAY';
   return;
}

sub _die_bad_op {
   my ( $msg, $name, $res, $host_name, $all_res ) = @_;
   die "$msg\n"
      . "Host name: " . ($host_name ? $host_name : 'UNKNOWN') . "\n"
      . "Current results: " . Dumper($res)
      . "Prior results: "   . Dumper($all_res)
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
