# This program is copyright 2008-2009 Percona Inc.
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
package SchemaDiscover;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(du q tp vp) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
      %args
   };
   return bless $self, $class;
}

sub discover {
   my ( $self, $dbh ) = @_;
   die "I need a dbh" unless $dbh;

   my $schema = {
      dbs         => {},
      counts      => {},
      stored_code => undef,  # may be either arrayref of error string
   };
   # brevity:
   my $dbs     = $schema->{dbs};
   my $counts  = $schema->{counts};
   my $du      = $self->{du};
   my $q       = $self->{q};
   my $tp      = $self->{tp};
   my $vp      = $self->{vp};

   %$dbs = map { $_ => {} } $du->get_databases($dbh, $q);

   delete $dbs->{information_schema}
      if exists $dbs->{information_schema};

   $counts->{TOTAL}->{dbs} = scalar keys %{$dbs};

   foreach my $db ( keys %$dbs ) {
      %{$dbs->{$db}}
         = map { $_->{name} => {} } $du->get_table_list($dbh, $q, $db);
      foreach my $tbl_stat ($du->get_table_status($dbh, $q, $db)) {
         %{$dbs->{$db}->{"$tbl_stat->{name}"}} = %$tbl_stat;
      }
      foreach my $table ( keys %{$dbs->{$db}} ) {
         my $ddl        = $du->get_create_table($dbh, $q, $db, $table);
         my $table_info = $tp->parse($ddl);
         my $n_indexes  = scalar keys %{ $table_info->{keys} };
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
      }
   }

   if ( $vp->version_ge($dbh, '5.0.0') ) {
      $schema->{stored_code} = $self->discover_stored_code($dbh);
   }
   else {
      $schema->{stored_code}
         = 'This version of MySQL does not support stored code.';
   }

   return $schema;
}

# Returns an arrayref of strings which summarize the stored code
# objects like: "db obj_type count".
sub discover_stored_code {
   my ( $self, $dbh ) = @_;
   die "I need a dbh" unless $dbh;

   my @stored_code_objs;
   eval {
      @stored_code_objs = @{ $dbh->selectall_arrayref(
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
   };
   MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);

   my @formatted_code_objs;
   foreach my $code_obj ( @stored_code_objs ) {
      push @formatted_code_objs, "$code_obj->[0] $code_obj->[1] $code_obj->[2]";
   }

   return \@formatted_code_objs;
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
# End SchemaDiscover package
# ###########################################################################
