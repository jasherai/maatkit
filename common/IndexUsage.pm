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
package IndexUsage;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# This module's job is to keep track of how many times queries use indexes, and
# show which are unused.  You use it by telling it about all the tables and
# indexes that exist, and then you give it index usage stats (from
# ExplainAnalyzer).  Afterwards, you ask it to show you unused indexes.
sub new {
   my ( $class, %args ) = @_;
   my $self = {
      %args,
      tables_for  => {}, # Keyed off db
      indexes_for => {}, # Keyed off db->tbl
   };
   return bless $self, $class;
}

# Tell the object that an index exists.  Internally, it just creates usage
# counters for the index and the table it belongs to.  The arguments are as
# follows:
#   - The name of the database
#   - The name of the table
#   - An arrayref of the names of the indexes
sub add_indexes {
   my ( $self, $db, $tbl, $indexes ) = @_;
   die "I need a db, table, and index"
      if grep { !defined } ($db, $tbl, $indexes);
   $self->{tables_for}->{$db}->{$tbl} = 0;
   foreach my $index ( @$indexes ) {
      $self->{indexes_for}->{$db}->{$tbl}->{$index} = 0;
   }
}

# This method just counts the fact that a table was used (regardless of whether
# any indexes in it are used).  The arguments are just database and table name.
sub add_table_usage {
   my ( $self, $db, $tbl ) = @_;
   die "I need a db and table" unless defined $db && defined $tbl;
   ++$self->{tables_for}->{$db}->{$tbl};
}

# This method accepts information about how a query used an index, and saves it
# for later retrieval.  The arguments are as follows:
#  usage       The usage information, in the same format as the output from
#              ExplainAnalyzer::get_index_usage()
sub add_index_usage {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(usage) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my ($id, $chk, $pos_in_log, $usage) = @args{qw(id chk pos_in_log usage)};
   foreach my $access ( @$usage ) {
      my ($db, $tbl, $idx, $alt) = @{$access}{qw(db tbl idx alt)};
      # Increment the index(es)'s usage counter.
      foreach my $index ( @$idx ) {
         $self->{indexes_for}->{$db}->{$tbl}->{$index}++;
      }
   }
}

# For every table in every database, determine whether each index was used or
# not.  But only if the table was used.  Don't say "this index should be
# dropped" if the table was never queried.  For each table, collect the unused
# indexes and execute the callback subroutine with a hashref that looks like
# this:
# { db => db, tbl => tbl, idx => [<list of unused indexes on this table>] }
sub find_unused_indexes {
   my ( $self, $callback ) = @_;
   die "I need a callback" unless $callback;

   # Local references to save typing
   my %indexes_for = %{$self->{indexes_for}};
   my %tables_for  = %{$self->{tables_for}};

   foreach my $database ( sort keys %indexes_for ) {
      my %tables = %{$indexes_for{$database}};
      TABLE:
      foreach my $table ( sort keys %tables ) {
         next TABLE unless $tables_for{$database}->{$table}; # Skip unused
         my %indexes = %{$tables{$table}};
         my @unused_indexes;
         foreach my $index ( sort keys %indexes ) {
            if (!$indexes{$index}) { # The count of times accessed/used
               push @unused_indexes, $index;
            }
         }
         if ( @unused_indexes ) {
            $callback->(
               {  db  => $database,
                  tbl => $table,
                  idx => \@unused_indexes,
               }
            );
         }
      }
   }
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
