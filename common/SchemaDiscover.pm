# This program is copyright 2008 Percona Inc.
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
# SchemaDiscover package $Revision$
# ###########################################################################

# SchemaDiscover - Discover every db, table and index in the schema
package SchemaDiscover;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Carp;

sub new {
   my ( $class, $params ) = @_;
   if ( scalar keys %{ $params } < 4 ) {
      croak   "Error: Not enough parameters for SchemaDiscover::new()\n"
            . "Required keys in named parameters hash: "
            . "dbh, MySQLDump, Quoter, TableParser\n"
            . "Optional: opts\n";
   }
   my $self = {
      %{ $params },
      dbs    => {},
      counts => {},
   };
   # brevity:
   my $dbs         = $self->{dbs};
   my $counts      = $self->{counts};
   my $dbh         = $self->{dbh};
   my $MySQLDump   = $self->{MySQLDump};
   my $Quoter      = $self->{Quoter};
   my $TableParser = $self->{TableParser};
   my $opts        = $self->{opts} || {};

   %{$dbs} = map { $_ => {} } $MySQLDump->get_databases($dbh, $Quoter);

   delete $dbs->{information_schema}
      if exists $dbs->{information_schema};

   $counts->{TOTAL}->{dbs} = scalar keys %{$dbs};

   foreach my $db ( keys %{$dbs} ) {
      %{$dbs->{$db}} = map { $_->{name} => {} }
                           $MySQLDump->get_table_list($dbh, $Quoter, $db);
      foreach my $tbl_stat ($MySQLDump->get_table_status($dbh, $Quoter, $db)) {
         %{$dbs->{$db}->{"$tbl_stat->{name}"}} = %$tbl_stat;
      }
      foreach my $table ( keys %{$dbs->{$db}} ) {
         my $ddl = $MySQLDump->get_create_table($dbh, $Quoter, $db, $table);
         my $table_info = TableParser->parse($ddl);
         my $n_indexes = scalar keys %{ $table_info->{keys} };
         # TODO: pass mysql version to TableParser->parse()
         # TODO: also aggregate indexes by type: BTREE, HASH, FULLTEXT etc
         #       so we can get a count + size along that dimension too

         my $data_size  = $dbs->{$db}->{$table}->{data_length}  ||= 0;
         my $index_size = $dbs->{$db}->{$table}->{index_length} ||= 0;
         my $rows       = $dbs->{$db}->{$table}->{rows}         ||= 0;
         my $engine     = $dbs->{$db}->{$table}->{engine}; 

         # Per-db counts
         $counts->{dbs}->{$db}->{tables}             += 1;
         $counts->{dbs}->{$db}->{indexes}            += $n_indexes;
         $counts->{dbs}->{$db}->{engines}->{$engine} += 1;
         $counts->{dbs}->{$db}->{rows}               += $rows;
         $counts->{dbs}->{$db}->{data_size}          += $data_size;
         $counts->{dbs}->{$db}->{index_size}         += $index_size;

         # Per-engline counts
         $counts->{engines}->{$engine}->{tables}     += 1;
         $counts->{engines}->{$engine}->{indexes}    += $n_indexes;
         $counts->{engines}->{$engine}->{data_size}  += $data_size;
         $counts->{engines}->{$engine}->{index_size} += $index_size; 

         # Grand total schema counts
         $counts->{TOTAL}->{tables}     += 1;
         $counts->{TOTAL}->{indexes}    += $n_indexes;
         $counts->{TOTAL}->{rows}       += $rows;
         $counts->{TOTAL}->{data_size}  += $data_size;
         $counts->{TOTAL}->{index_size} += $index_size;
      } # foreach table
   } # foreach db

   return bless $self, $class;
}

sub discover_triggers_routines_events {
   my ( $self ) = @_;
   my @tre =
      @{ $self->{dbh}->selectall_arrayref(
            "SELECT EVENT_OBJECT_SCHEMA AS db,
            CONCAT(LEFT(LOWER(EVENT_MANIPULATION), 3), '_trg') AS what,
            COUNT(*) AS num
            FROM INFORMATION_SCHEMA.TRIGGERS GROUP BY db, what
            UNION ALL
            SELECT ROUTINE_SCHEMA AS db,
            LEFT(LOWER(ROUTINE_TYPE), 4) AS what,
            COUNT(*) AS num
            FROM INFORMATION_SCHEMA.ROUTINES GROUP BY db, what
            /*!50106
               UNION ALL
               SELECT EVENT_SCHEMA AS db, 'evt' AS what, COUNT(*) AS num
               FROM INFORMATION_SCHEMA.EVENTS GROUP BY db, what
            */")
      };
   $self->{trigs_routines_events} = ();
   foreach my $x ( @tre ) {
      push @{ $self->{trigs_routines_events} }, "$x->[0] $x->[1] $x->[2]";
   }
   return;
}

1;

# ###########################################################################
# End SchemaDiscover package
# ###########################################################################
