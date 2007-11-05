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
# MySQLFind package $Revision: 1178 $
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package MySQLFind;

# SYNOPSIS:
#   $f = new MySQLFind(
#      dbh       => $dbh,
#      databases => {
#         permit => { a => 1, b => 1, },
#         reject => { ... },
#         regexp => 'pattern',
#         like   => 'pattern',
#      },
#   );

use English qw(-no_match_vars);

sub new {
   my ( $class, %opts ) = @_;
   bless \%opts, $class;
}

sub find_databases {
   my ( $self ) = @_;
   my $permit = $self->{databases}->{permit};
   my $reject = $self->{databases}->{reject};
   my $regexp = $self->{databases}->{regexp};
   return grep {
      $_ !~ m/^(information_schema|lost\+found)$/i
         && ( !$reject || !$reject->{$_} )
         && ( !$permit ||  $permit->{$_} )
         && ( !$regexp ||  m/$regexp/ )
   } $self->_fetch_db_list();
}

sub find_tables {
   my ( $self, %opts ) = @_;
   die "database is required" unless $opts{database};
   my $permit = $self->{tables}->{permit};
   my $reject = $self->{tables}->{reject};
   return grep {
      ( !$reject || !$reject->{$_} )
         && ( !$permit ||  $permit->{$_} )
   } $self->_fetch_table_list($opts{database});
}

sub _fetch_db_list {
   my ( $self ) = @_;
   my $sql = 'SHOW DATABASES';
   my @params;
   if ( $self->{databases}->{like} ) {
      $sql .= ' LIKE ?';
      push @params, $self->{databases}->{like};
   }
   my $sth = $self->{dbh}->prepare($sql);
   $sth->execute( @params );
   return map { $_->[0] } @{$sth->fetchall_arrayref()};
}

1;

# ###########################################################################
# End MySQLFind package
# ###########################################################################

__DATA__
   my $need_table_status = $age || $opts{C} =~ m/\D/;

   my $tables = $dbh->selectall_arrayref(
      $need_table_status
         ? "SHOW TABLE STATUS FROM `$database`"
         : "SHOW /*!50002 FULL*/ TABLES FROM `$database`",
      { Slice => {} });

   if ( @$tables ) {

      my ( $name_key )
         = $need_table_status
         ? ( qw(name) )
         : ( grep { $_ ne 'table_type' } keys %{$tables->[0]} );
      my $type_key = $need_table_status ? 'comment' : 'table_type';

