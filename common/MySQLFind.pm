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

use Data::Dumper;
$Data::Dumper::Indent    = 0;
$Data::Dumper::Quotekeys = 0;

# SYNOPSIS:
#   $f = new MySQLFind(
#      dbh       => $dbh,
#      quoter    => new Quoter(),
#      useddl    => 1/0 (default 0, 1 requires parser/dumper)
#      parser    => new TableParser(), # optional
#      dumper    => new MySQLDump(), # optional
#      nullpass  => 1/0 # whether an undefined status test is true
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
#         status => [
#            { update => '[+-]seconds' }, # age of Update_time
#         ],
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
   my ( $class, %args ) = @_;
   my $self = bless \%args, $class;
   $self->{engines}->{views} = 1 unless defined $self->{engines}->{views};
   die "Specify dbh" unless $args{dbh};
   if ( $args{useddl} ) {
      $ENV{MKDEBUG} && _d('Will prefer DDL');
      die "Specifying useddl requires parser and dumper"
         unless $args{parser} && $args{dumper};
   }
   if ( $args{tables}->{status} ) {
      my $sql = 'SELECT CURRENT_TIMESTAMP';
      $ENV{MKDEBUG} && _d($sql);
      ($self->{timestamp}->{now}) = $args{dbh}->selectrow_array($sql);
      $ENV{MKDEBUG} && _d("Current timestamp: $self->{timestamp}->{now}");
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
   $ENV{MKDEBUG} && _d($sql, @params);
   $sth->execute( @params );
   return map { $_->[0] } @{$sth->fetchall_arrayref()};
}

sub find_tables {
   my ( $self, %args ) = @_;
   my $views = $self->{engines}->{views};
   my @tables 
      = $self->_filter('engines', sub { $_[0]->{engine} },
         $self->_filter('tables', sub { $_[0]->{name} },
            $self->_fetch_tbl_list(%args)));
   @tables = grep {
         ( $views || ($_->{engine} ne 'VIEW') )
      } @tables;
   map { $_->{name} =~ s/^[^.]*\.// } @tables; # <database>.<table> => <table> 
   foreach my $crit ( @{$self->{tables}->{status}} ) {
      my ($key, $test) = %$crit;
      @tables
         = grep {
            # TODO: tests other than date...
            $self->_test_date($_, $key, $test)
         } @tables;
   }
   return map { $_->{name} } @tables;
}

# Returns hashrefs in the format SHOW TABLE STATUS would, but doesn't
# necessarily call SHOW TABLE STATUS unless it needs to.  Hash keys are all
# lowercase.  Table names are returned as <database>.<table> so fully-qualified
# matching can be done later on the database name.
sub _fetch_tbl_list {
   my ( $self, %args ) = @_;
   die "database is required" unless $args{database};
   my $need_engine = $self->{engines}->{permit}
        || $self->{engines}->{reject}
        || $self->{engines}->{regexp};
   my $need_status = $self->{tables}->{status};
   my @params;
   if ( $need_status || ($need_engine && !$self->{useddl}) ) {
      my $sql = "SHOW TABLE STATUS FROM "
              . $self->{quoter}->quote($args{database});
      if ( $self->{tables}->{like} ) {
         $sql .= ' LIKE ?';
         push @params, $self->{tables}->{like};
      }
      $ENV{MKDEBUG} && _d($sql, @params);
      my $sth = $self->{dbh}->prepare($sql);
      $sth->execute(@params);
      my @tables = @{$sth->fetchall_arrayref({})};
      return map {
         my %tbl; # Make a copy with lowercased keys
         @tbl{ map { lc $_ } keys %$_ } = values %$_;
         $tbl{engine} ||= $tbl{type} || $tbl{comment};
         $tbl{name} = join('.', $args{database}, $tbl{name});
         delete $tbl{type};
         \%tbl;
      } @tables;
   }
   else {
      my $sql = "SHOW /*!50002 FULL*/ TABLES FROM "
              . $self->{quoter}->quote($args{database});
      if ( $self->{tables}->{like} ) {
         $sql .= ' LIKE ?';
         push @params, $self->{tables}->{like};
      }
      $ENV{MKDEBUG} && _d($sql, @params);
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
                  $self->{dbh}, $self->{quoter}, $args{database}, $tbl->[0]));
            $engine = $struct->{engine};
         }
         push @result,
         {  name   => "$args{database}.$tbl->[0]",
            engine => $engine,
         }
      }
      return @result;
   }
}

sub _filter {
   my ( $self, $thing, $sub, @vals ) = @_;
   $ENV{MKDEBUG} && _d("Filtering $thing list on ", Dumper($self->{$thing}));
   my $permit = $self->{$thing}->{permit};
   my $reject = $self->{$thing}->{reject};
   my $regexp = $self->{$thing}->{regexp};
   return grep {
      my $val = $sub->($_);
      $val = '' unless defined $val;
      # 'tables' is a special case, because it can be matched on either the
      # table name or the database and table name.
      if ( $thing eq 'tables' ) {
         (my $tbl = $val) =~ s/^.*\.//;
         ( !$reject || (!$reject->{$val} && !$reject->{$tbl}) )
            && ( !$permit || $permit->{$val} || $permit->{$tbl} )
            && ( !$regexp || $val =~ m/$regexp/ )
      }
      else {
         ( !$reject || !$reject->{$val} )
            && ( !$permit || $permit->{$val} )
            && ( !$regexp || $val =~ m/$regexp/ )
      }
   } @vals;
}

sub _test_date {
   my ( $self, $table, $prop, $test ) = @_;
   $prop = lc $prop;
   if ( !defined $table->{$prop} ) {
      $ENV{MKDEBUG} && _d("$prop is not defined");
      return $self->{nullpass};
   }
   my ( $equality, $num ) = $test =~ m/^([+-])?(\d+)$/;
   die "Invalid date test $test for $prop" unless defined $num;
   my $sql = "SELECT DATE_SUB('$self->{timestamp}->{now}', INTERVAL $num SECOND)";
   $ENV{MKDEBUG} && _d($sql);
   ($self->{timestamp}->{$num}) ||= $self->{dbh}->selectrow_array($sql);
   my $time = $self->{timestamp}->{$num};
   return 
         ( $equality eq '-' && $table->{$prop} gt $time )
      || ( $equality eq '+' && $table->{$prop} lt $time )
      || (                     $table->{$prop} eq $time );
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# MySQLFind:$line ", @_, "\n";
}

1;

# ###########################################################################
# End MySQLFind package
# ###########################################################################
