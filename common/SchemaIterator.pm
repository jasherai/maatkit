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
# SchemaIterator package $Revision$
# ###########################################################################
package SchemaIterator;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(Quoter) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
      %args,
      filter => undef,
   };
   return bless $self, $class;
}

# Required args:
#   * o  obj: OptionParser module
# Returns: subref
# Can die: yes
# make_filter() uses an OptionParser obj and the following standard filter
# options to make a filter sub suitable for set_filter():
#   --databases -d      List of allowed databases
#   --tables    -t      List of allowed tables
#   --engines   -e      List of allowed engines
#   --ignore-databases  List of databases to ignore
#   --ignore-tables     List of tables to ignore
#   --ignore-engines    List of engines to ignore 
# The filter returns true if the schema object is allowed.
sub make_filter {
   my ( $self, $o ) = @_;
   my @lines = (
      'sub {',
      '   my ( $dbh, $db, $tbl ) = @_;',
      '   my $engine = "";',
   );

   # If filtering by engines, the filter sub will need to SHOW TABLE STATUS
   # to get the table's engine if a table was given.
   if ( $o->get('engines') || $o->get('ignore-engines') ) {
   }

   my %var_for = (
      databases          => '$db',
      'ignore-databases' => '$db',
      tables             => '$tbl',
      'ignore-tables'    => '$tbl',
      engines            => '$engine',
      'ignore-engines'   => '$engine',
   );
   # qw() the filter objs manually instead of doing keys %filter_objs so
   # that they're checked in this order which will make the filter more
   # efficient (i.e. don't check the engine for a bunch of tables if the
   # database is rejected).
   foreach my $obj (
      qw(databases ignore-databases tables ignore-tables engines ignore-engines)
   ) {
      next unless $o->has($obj);
      if ( my $objs = $o->get($obj) ) {
         next unless scalar keys %$objs;
         MKDEBUG && _d('Making', $obj, 'filter');
         my $cond = $obj =~ m/^ignore/ ? 'if' : 'unless';
         push @lines,
            "return 0 $cond $var_for{$obj} && (",
               join(' || ', map { "$var_for{$obj} eq '$_'" } keys %$objs),
            ');',
      }
   }

   push @lines, 'return 1; }';

   # Make the subroutine.
   my $code = join("\n", @lines);
   MKDEBUG && _d('filter sub:', @lines);
   my $filter_sub= eval $code
      or die "Error compiling subroutine code:\n$code\n$EVAL_ERROR";

   return $filter_sub;
}

# Required args:
#   * filter_sub  subref: Filter sub, usually from make_filter()
# Returns: undef
# Can die: no
# set_filter() sets the filter sub that get_db_itr() and get_tbl_itr()
# use to filter the schema objects they find.  If no filter sub is set
# then every possible schema object is returned by the iterators.  The
# filter should return true if the schema object is allowed.
sub set_filter {
   my ( $self, $filter_sub ) = @_;
   $self->{filter} = $filter_sub;
   MKDEBUG && _d('Set filter sub');
   return;
}

# Required args:
#   * dbh  dbh: an active dbh
# Returns: itr
# Can die: no
# get_db_itr() returns an iterator which returns the next db found,
# according to any set filters, when called successively.
sub get_db_itr {
   my ( $self, $dbh ) = @_;
   my $filter = $self->{filter};
   my @dbs;
   eval {
      my $sql = 'SHOW DATABASES';
      MKDEBUG && _d($sql);
      @dbs = map {
         $_->[0]
      }
      grep {
         my $ok = $filter ? $filter->($dbh, $_->[0], undef) : 1;
         $ok;
      }
      @{ $dbh->selectall_arrayref($sql) };
      MKDEBUG && _d('Found', scalar @dbs, 'databases');
   };
   MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
   return sub {
      return shift @dbs;
   };
}

# Required args:
#   * dbh  dbh: an active dbh
#   * db   scalar: database name
# Returns: itr
# Can die: no
# get_tbl_itr() returns an iterator which returns the next table found,
# in the given db, according to any set filters, when called successively.
sub get_tbl_itr {
   my ( $self, $dbh, $db ) = @_;
   my $filter = $self->{filter};
   my @tbls;
   if ( $db ) {
      eval {
         my $sql = 'SHOW TABLES FROM ' . $self->{Quoter}->quote($db);
         MKDEBUG && _d($sql);
         @tbls = map {
            $_->[0]
         }
         grep {
            my $ok = $filter ? $filter->($dbh, $db, $_->[0]) : 1;
            $ok;
         }
         @{ $dbh->selectall_arrayref($sql) };
         MKDEBUG && _d('Found', scalar @tbls, 'tables in', $db);
      };
      MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
   }
   else {
      MKDEBUG && _d('No db given so no tables');
   }
   return sub {
      return shift @tbls;
   };
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
# End SchemaIterator package
# ###########################################################################
