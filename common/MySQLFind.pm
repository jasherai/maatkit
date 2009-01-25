# This program is copyright 2007-@CURRENTYEAR@ Baron Schwartz.
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
package MySQLFind;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 0;
$Data::Dumper::Quotekeys = 0;

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

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(dumper quoter) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   die "Do not pass me a dbh argument" if $args{dbh};
   my $self = bless \%args, $class;
   $self->{need_engine}
      = (   $self->{engines}->{permit}
         || $self->{engines}->{reject}
         || $self->{engines}->{regexp} ? 1 : 0);
   die "I need a parser argument"
      if $self->{need_engine} && !defined $args{parser};
   MKDEBUG && _d('Need engine: ' , $self->{need_engine} ? 'yes' : 'no');
   $self->{engines}->{views} = 1  unless defined $self->{engines}->{views};
   $self->{tables}->{status} = [] unless defined $self->{tables}->{status};
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

   # Get and filter tables by name.
   my @tables
      = $self->_filter('tables', sub { $_[0]->{name} },
         $self->_fetch_tbl_list($dbh, %args));

   # Filter tables by engines if needed.
   if ( $self->{need_engine} ) {
      foreach my $tbl ( @tables ) {
         next if $tbl->{engine};
         # Strip db from tbl name. The tbl name was qualified with its
         # db during _fetch_tbl_list() above.
         my ( $tbl_name ) = $tbl->{name} =~ m/\.(\S+)$/;
         my $struct = $self->{parser}->parse(
            $self->{dumper}->get_create_table(
               $dbh, $self->{quoter}, $args{database}, $tbl_name));
         $tbl->{engine} = $struct->{engine};
      }
      @tables = $self->_filter('engines', sub { $_[0]->{engine} }, @tables);
   }

   # <database>.<table> => <table> 
   map { $_->{name} =~ s/^[^.]*\.// } @tables;

   # Filter tables by status (if any criteria are defined).
   foreach my $crit ( @{$self->{tables}->{status}} ) {
      my ($key, $test) = %$crit;
      @tables
         = grep {
            # TODO: tests other than date...
            $self->_test_date($_, $key, $test, $dbh)
         } @tables;
   }

   # Return list of table names.
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
# lowercase. Table names are returned as <database>.<table> so fully-qualified
# matching can be done later on the database name.
sub _fetch_tbl_list {
   my ( $self, $dbh, %args ) = @_;
   die "database is required" unless $args{database};

   my $curr_db = $self->_use_db($dbh, $args{database});

   # Get list of table names either with SHOW TABLE STATUS if any status
   # criteria are defined, else by SHOW TABLES.
   my @tables;
   if ( scalar @{$self->{tables}->{status}} ) {
      @tables = $self->{dumper}->get_table_status(
         $dbh,
         $self->{quoter},
         $args{database},
         $self->{tables}->{like});
   }
   else {
      @tables = $self->{dumper}->get_table_list(
         $dbh,
         $self->{quoter},
         $args{database},
         $self->{tables}->{like});
   }

   # 2) map:  Qualify tables with their database.
   # 1) grep: Remove views if needed.
   @tables = map {
      my %hash = %$_;
      $hash{name} = join('.', $args{database}, $hash{name});
      \%hash;
   }
   grep {
      ( $self->{engines}->{views} || ($_->{engine} ne 'VIEW') )
   } @tables;

   $self->_use_db($dbh, $curr_db);

   return @tables;
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
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   # Use $$ instead of $PID in case the package
   # does not use English.
   print "# $package:$line $$ ", @_, "\n";
}

1;

# ###########################################################################
# End MySQLFind package
# ###########################################################################
