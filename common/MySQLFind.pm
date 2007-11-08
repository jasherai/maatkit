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
# MySQLFind package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package MySQLFind;

# SYNOPSIS:
#   $f = new MySQLFind(
#      dbh       => $dbh,
#      quoter    => new Quoter(),
#      useddl    => 1/0 (default 0, 1 requires parser/dumper)
#      parser    => new TableParser(), # optional
#      dumper    => new MySQLDump(), # optional
#      databases => {
#         permit => { a => 1, b => 1, },
#         reject => { ... },
#         regexp => 'pattern',
#         like   => 'pattern',
#      },
#      tables => {
#         permit => { a => 1, b => 1, },
#         reject => { ... },
#         regexp => 'pattern',
#         like   => 'pattern',
#      },
#      engines => {
#         views  => 1/0, # 1 default
#         permit => {},
#         reject => {},
#         regexp => 'pattern',
#      },
#   );

use English qw(-no_match_vars);

sub new {
   my ( $class, %opts ) = @_;
   my $self = bless \%opts, $class;
   $self->{engines}->{views} = 1 unless defined $self->{engines}->{views};
   if ( $opts{useddl} ) {
      die "Specifying useddl requires parser and dumper"
         unless $opts{parser} && $opts{dumper};
   }
   return $self;
}

sub find_databases {
   my ( $self ) = @_;
   return grep {
      $_ !~ m/^(information_schema|lost\+found)$/i
   }
   $self->_filter('databases', sub { $_[0] }, $self->_fetch_db_list());
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

sub find_tables {
   my ( $self, %opts ) = @_;
   my $views = $self->{engines}->{views};
   my @tables = grep {
         ( $views || $_->{Engine} ne 'VIEW' )
      }
      $self->_filter('engines', sub { $_[0]->{Engine} },
         $self->_filter('tables', sub { $_[0]->{Name} },
            $self->_fetch_tbl_list(%opts)));
   return map { $_->{Name} } @tables;
}

# Returns hashrefs in the format SHOW TABLE STATUS would, but doesn't
# necessarily call SHOW TABLE STATUS unless it needs to.
sub _fetch_tbl_list {
   my ( $self, %opts ) = @_;
   die "database is required" unless $opts{database};
   my $need_engine = $self->{engines}->{permit}
        || $self->{engines}->{reject}
        || $self->{engines}->{regexp};
   my @params;
   if ( !$self->{useddl} && $need_engine ) {
      my $sql = "SHOW TABLE STATUS FROM "
              . $self->{quoter}->quote($opts{database});
      if ( $self->{tables}->{like} ) {
         $sql .= ' LIKE ?';
         push @params, $self->{tables}->{like};
      }
      my $sth = $self->{dbh}->prepare($sql);
      $sth->execute(@params);
      my @tables = @{$sth->fetchall_arrayref({})};
      return map {
         $_->{Engine} ||= $_->{Type} || $_->{Comment};
         delete $_->{Type};
         $_;
      } @tables;
   }
   else {
      my $sql = "SHOW /*!50002 FULL*/ TABLES FROM "
              . $self->{quoter}->quote($opts{database});
      if ( $self->{tables}->{like} ) {
         $sql .= ' LIKE ?';
         push @params, $self->{tables}->{like};
      }
      my $sth = $self->{dbh}->prepare($sql);
      $sth->execute(@params);
      my @tables = @{$sth->fetchall_arrayref()};
      my @result;
      foreach my $tbl ( @tables ) {
         my $engine = '';
         if ( ($tbl->[1] || '') eq 'VIEW' ) {
            $engine = 'VIEW';
         }
         elsif ( $need_engine ) {
            my $struct = $self->{parser}->parse(
               $self->{dumper}->get_create_table(
                  $self->{dbh}, $self->{quoter}, $opts{database}, $tbl->[0]));
            $engine = $struct->{engine};
         }
         push @result,
         {  Name   => $tbl->[0],
            Engine => $engine,
         }
      }
      return @result;
   }
}

sub _filter {
   my ( $self, $thing, $sub, @vals ) = @_;
   my $permit = $self->{$thing}->{permit};
   my $reject = $self->{$thing}->{reject};
   my $regexp = $self->{$thing}->{regexp};
   return grep {
      my $val = $sub->($_);
      $val = '' unless defined $val;
      ( !$reject || !$reject->{$val} )
         && ( !$permit ||  $permit->{$val} )
         && ( !$regexp ||  $val =~ m/$regexp/ )
   } @vals
}

1;

# ###########################################################################
# End MySQLFind package
# ###########################################################################
