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
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

# SYNOPSIS:
#   $f = new MySQLFind(
#      dbh       => $dbh,
#      quoter    => new Quoter(),
#      useddl    => 1/0 (default 0),
#      parser    => new TableParser(),
#      dumper    => new MySQLDump(),
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
   map { die "I need a $_ argument" unless defined $args{$_} } qw(dumper quoter);
   die "Do not pass me a dbh argument" if $args{dbh};
   $self->{engines}->{views} = 1 unless defined $self->{engines}->{views};
   if ( $args{useddl} ) {
      MKDEBUG && _d('Will prefer DDL');
   }
   return $self;
}

sub init_timestamp {
   my ( $self, $dbh ) = @_;
   return if $self->{timestamp}->{$dbh}->{now};
   my $sql = 'SELECT CURRENT_TIMESTAMP';
   MKDEBUG && _d($sql);
   ($self->{timestamp}->{$dbh}->{now}) = $dbh->selectrow_array($sql);
   MKDEBUG && _d("Current timestamp: $self->{timestamp}->{$dbh}->{now}");
}

sub find_databases {
   my ( $self, $dbh ) = @_;
   return grep {
      $_ !~ m/^(information_schema|lost\+found)$/i
   }  $self->_filter('databases', sub { $_[0] },
         $self->{dumper}->get_databases(
            $dbh,
            $self->{quoter},
            $self->{databases}->{like}));
}

sub find_tables {
   my ( $self, $dbh, %args ) = @_;
   my $views = $self->{engines}->{views};
   my @tables 
      = $self->_filter('engines', sub { $_[0]->{engine} },
         $self->_filter('tables', sub { $_[0]->{name} },
            $self->_fetch_tbl_list($dbh, %args)));
   @tables = grep {
         ( $views || ($_->{engine} ne 'VIEW') )
      } @tables;
   map { $_->{name} =~ s/^[^.]*\.// } @tables; # <database>.<table> => <table> 
   foreach my $crit ( @{$self->{tables}->{status}} ) {
      my ($key, $test) = %$crit;
      @tables
         = grep {
            # TODO: tests other than date...
            $self->_test_date($_, $key, $test, $dbh)
         } @tables;
   }
   return map { $_->{name} } @tables;
}

sub find_views {
   my ( $self, $dbh, %args ) = @_;
   my @tables = $self->_fetch_tbl_list($dbh, %args);
   @tables = grep { $_->{engine} eq 'VIEW' } @tables;
   map { $_->{name} =~ s/^[^.]*\.// } @tables; # <database>.<table> => <table> 
   return map { $_->{name} } @tables;
}

# USEs the given database, and returns the previous default database.
sub _use_db {
   my ( $self, $dbh, $new ) = @_;
   if ( !$new ) {
      MKDEBUG && _d('No new DB to use');
      return;
   }
   my $sql = 'SELECT DATABASE()';
   MKDEBUG && _d($sql);
   my $curr = $dbh->selectrow_array($sql);
   if ( $curr && $new && $curr eq $new ) {
      MKDEBUG && _d('Current and new DB are the same');
      return $curr;
   }
   $sql = 'USE ' . $self->{quoter}->quote($new);
   MKDEBUG && _d($sql);
   $dbh->do($sql);
   return $curr;
}

# Returns hashrefs in the format SHOW TABLE STATUS would, but doesn't
# necessarily call SHOW TABLE STATUS unless it needs to.  Hash keys are all
# lowercase.  Table names are returned as <database>.<table> so fully-qualified
# matching can be done later on the database name.
sub _fetch_tbl_list {
   my ( $self, $dbh, %args ) = @_;
   die "database is required" unless $args{database};
   my $curr_db = $self->_use_db($dbh, $args{database});
   my $need_engine = $self->{engines}->{permit}
        || $self->{engines}->{reject}
        || $self->{engines}->{regexp};
   my $need_status = $self->{tables}->{status};
   if ( $need_status || ($need_engine && !$self->{useddl}) ) {
      my @tables = $self->{dumper}->get_table_status(
         $dbh,
         $self->{quoter},
         $args{database},
         $self->{tables}->{like});
      @tables = map {
         my %hash = %$_;
         $hash{name} = join('.', $args{database}, $hash{name});
         \%hash;
      } @tables;
      return @tables;
   }
   else {
      my @result;
      my @tables = $self->{dumper}->get_table_list(
         $dbh,
         $self->{quoter},
         $args{database},
         $self->{tables}->{like});
      foreach my $tbl ( @tables ) {
         if ( $need_engine && !$tbl->{engine} ) {
            my $struct = $self->{parser}->parse(
               $self->{dumper}->get_create_table(
                  $dbh, $self->{quoter}, $args{database}, $tbl->{name}));
            $tbl->{engine} = $struct->{engine};
         }
         push @result,
         {  name   => join('.', $args{database}, $tbl->{name}),
            engine => $tbl->{engine},
         }
      }
      return @result;
   }
   $self->_use_db($dbh, $curr_db);
}

sub _filter {
   my ( $self, $thing, $sub, @vals ) = @_;
   MKDEBUG && _d("Filtering $thing list on ", Dumper($self->{$thing}));
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
   my ( $self, $table, $prop, $test, $dbh ) = @_;
   $prop = lc $prop;
   if ( !defined $table->{$prop} ) {
      MKDEBUG && _d("$prop is not defined");
      return $self->{nullpass};
   }
   my ( $equality, $num ) = $test =~ m/^([+-])?(\d+)$/;
   die "Invalid date test $test for $prop" unless defined $num;
   $self->init_timestamp($dbh);
   my $sql = "SELECT DATE_SUB('$self->{timestamp}->{$dbh}->{now}', "
           . "INTERVAL $num SECOND)";
   MKDEBUG && _d($sql);
   ($self->{timestamp}->{$dbh}->{$num}) ||= $dbh->selectrow_array($sql);
   my $time = $self->{timestamp}->{$dbh}->{$num};
   return 
         ( $equality eq '-' && $table->{$prop} gt $time )
      || ( $equality eq '+' && $table->{$prop} lt $time )
      || (                     $table->{$prop} eq $time );
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# MySQLFind:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End MySQLFind package
# ###########################################################################
