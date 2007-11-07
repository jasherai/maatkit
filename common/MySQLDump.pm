# This program is copyright (c) 2007 Baron Schwartz.
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
# MySQLDump package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package MySQLDump;

use English qw(-no_match_vars);

sub new {
   my ( $class, %opts ) = @_;
   foreach my $opt ( qw(dbh quoter) ) {
      die "You must specify $opt" unless defined $opts{$opt};
   }
   my $self = bless \%opts, $class;
   return $self;
}

sub dump {
   my ( $self, $db, $tbl, $what ) = @_;
   ( my $result = <<'   EOF') =~ s/^      //gm;
      /*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
      /*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
      /*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
      /*!40101 SET NAMES utf8 */;
      /*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
      /*!40103 SET TIME_ZONE='+00:00' */;
      /*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
      /*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
      /*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
      /*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
   EOF

   if ( $what eq 'table' ) {
      my $ddl = $self->get_create_table($db, $tbl);
      $result .= 'DROP TABLE IF EXISTS ' . $self->{quoter}->quote($tbl) . ";\n";
      $result .= $ddl . ";\n";
   }
   elsif ( $what eq 'triggers' ) {
      my $trgs = $self->get_triggers($db, $tbl);
      if ( @$trgs ) {
         $result .= "\nDELIMITER ;;\n";
         foreach my $trg ( @$trgs ) {
            if ( $trg->{sql_mode} ) {
               $result .= "/*!50003 SET SESSION SQL_MODE=\"$trg->{sql_mode}\" */;;\n";
            }
            $result .= "/*!50003 CREATE */ ";
            if ( $trg->{definer} ) {
               my ( $user, $host )
                  = map { s/'/''/g; "'$_'"; }
                    split('@', $trg->{definer}, 2);
               $result .= "/*!50017 DEFINER=$user\@$host */ ";
            }
            $result .= sprintf("/*!50003 TRIGGER %s %s %s ON %s\nFOR EACH ROW %s */;;\n\n",
               $self->{quoter}->quote($trg->{trigger}),
               @{$trg}{qw(timing event)},
               $self->{quoter}->quote($trg->{table}),
               $trg->{statement});
         }
         $result .= "DELIMITER ;\n\n/*!50003 SET SESSION SQL_MODE=\@OLD_SQL_MODE */;\n\n";
      }
   }
   else {
      die "You didn't say what to dump.";
   }

   ( my $after = <<'   EOF') =~ s/^      //gm;
      /*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;
      /*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
      /*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
      /*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
      /*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
      /*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
      /*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
      /*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
   EOF
   return $result . $after;
}

sub get_create_table {
   my ( $self, $db, $tbl ) = @_;
   if ( !$self->{tables}->{$db}->{$tbl} ) {
      $self->{dbh}->do('/*!40101 SET @OLD_SQL_MODE := @@SQL_MODE, '
         . '@@SQL_MODE := REPLACE(REPLACE(@@SQL_MODE, "ANSI_QUOTES", ""), ",,", ","), '
         . '@OLD_QUOTE := @@SQL_QUOTE_SHOW_CREATE, '
         . '@@SQL_QUOTE_SHOW_CREATE := 1 */');
      my $href = $self->{dbh}->selectrow_hashref(
         "SHOW CREATE TABLE "
         . $self->{quoter}->quote($db)
         . '.'
         . $self->{quoter}->quote($tbl)
      );
      $self->{dbh}->do('/*!40101 SET @@SQL_MODE := @OLD_SQL_MODE, '
         . '@@SQL_QUOTE_SHOW_CREATE := @OLD_QUOTE */');
      my ($key) = grep { m/create table/i } keys %$href;
      $self->{tables}->{$db}->{$tbl} = $href->{$key};
   }
   return $self->{tables}->{$db}->{$tbl};
}

sub get_triggers {
   my ( $self, $db, $tbl ) = @_;
   if ( !$self->{triggers}->{$db} ) {
      $self->{triggers}->{$db} = {};
      $self->{dbh}->do('/*!40101 SET @OLD_SQL_MODE := @@SQL_MODE, '
         . '@@SQL_MODE := REPLACE(REPLACE(@@SQL_MODE, "ANSI_QUOTES", ""), ",,", ","), '
         . '@OLD_QUOTE := @@SQL_QUOTE_SHOW_CREATE, '
         . '@@SQL_QUOTE_SHOW_CREATE := 1 */');
      my $trgs = $self->{dbh}->selectall_arrayref(
         "SHOW TRIGGERS FROM " . $self->{quoter}->quote($db),
         { Slice => {} }
      );
      foreach my $trg ( @$trgs ) {
         # Lowercase the hash keys because the NAME_lc property might be set
         # on the $dbh, so the lettercase is unpredictable.  This makes them
         # predictable.
         my %trg;
         @trg{ map { lc $_ } keys %$trg } = values %$trg;
         push @{$self->{triggers}->{$db}->{$trg{table}}}, \%trg;
      }
      $self->{dbh}->do('/*!40101 SET @@SQL_MODE := @OLD_SQL_MODE, '
         . '@@SQL_QUOTE_SHOW_CREATE := @OLD_QUOTE */');
   }
   return $self->{triggers}->{$db}->{$tbl};
}

1;

# ###########################################################################
# End MySQLDump package
# ###########################################################################
