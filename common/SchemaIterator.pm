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
#   --ignore-databases  List of databases to ignore
#   --databases-regex   List of allowed databases that match pattern
#   --tables    -t      List of allowed tables
#   --ignore-tables     List of tables to ignore
#   --tables-regex      List of allowed tables that match pattern
#   --engines   -e      List of allowed engines
#   --ignore-engines    List of engines to ignore 
# The filters in the sub are created in that order for efficiency.  For
# example, the table filters are not checked if the database doesn't first
# pass its filters.  Each filter is only created if specified.  Since the
# database and tables are given separately we no longer have to worry about
# splitting db.tbl to match db and/or tbl.  The filter returns true if the
# schema object is allowed.
sub make_filter {
   my ( $self, $o ) = @_;
   my @lines = (
      'sub {',
      '   my ( $dbh, $db, $tbl ) = @_;',
      '   my $engine = undef;',
   );

   # Filter schema objs in this order: db, tbl, engine.  It's not efficient
   # to check the table if, for example, the database isn't allowed.

   my @permit_dbs = _make_filter('unless', '$db', $o->get('databases'))
      if $o->has('databases');
   my @reject_dbs = _make_filter('if', '$db', $o->get('ignore-databases'))
      if $o->has('ignore-databases');
   my @dbs_regex;
   if ( $o->has('databases-regex') && (my $p = $o->get('databases-regex')) ) {
      push @dbs_regex, "      return 0 unless \$db && (\$db =~ m/$p/o);";
   }
   if ( @permit_dbs || @reject_dbs || @dbs_regex ) {
      push @lines,
         '   if ( $db ) {',
            (@permit_dbs ? @permit_dbs : ()),
            (@reject_dbs ? @reject_dbs : ()),
            (@dbs_regex  ? @dbs_regex  : ()),
         '   }';
   }

   if ( $o->get('tables') || $o->get('ignore-tables') ) {
      my @permit_tbls = _make_filter('unless', '$tbl', $o->get('tables'))
         if $o->has('tables');
      my @reject_tbls = _make_filter('if', '$tbl', $o->get('ignore-tables'))
         if $o->has('ignore-tables');
      my @tbls_regex;
      if ( $o->has('tables-regex') && (my $p = $o->get('tables-regex')) ) {
         push @tbls_regex, "      return 0 unless \$tbl && (\$tbl =~ m/$p/o);";
      }

      my @get_eng;
      my @permit_engs;
      my @reject_engs;
      if ( $o->get('engines') || $o->get('ignore-engines') ) {
         push @get_eng,
            '      my $sql = "SHOW TABLE STATUS "',
            '              . ($db ? "FROM `$db`" : "")',
            '              . " LIKE \'$tbl\'";',
            '      MKDEBUG && _d($sql);',
            '      eval {',
            '         $engine = $dbh->selectrow_hashref($sql)->{engine};',
            '      };',
            '      MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);',
            '      MKDEBUG && _d($tbl, "uses engine", $engine);',
            '      $engine = lc $engine if $engine;',
         @permit_engs = _make_filter('unless', '$engine', $o->get('engines'), 1)
            if $o->has('engines');
         @reject_engs = _make_filter('if', '$engine', $o->get('ignore-engines'), 1)
            if $o->has('ignore-engines');
      }

      if ( @permit_tbls || @reject_tbls || @tbls_regex
           || @permit_engs || @reject_engs ) {
         push @lines,
            '   if ( $tbl ) {',
               (@permit_tbls ? @permit_tbls : ()),
               (@reject_tbls ? @reject_tbls : ()),
               (@tbls_regex  ? @tbls_regex  : ()),
               (@get_eng     ? @get_eng     : ()),
               (@permit_engs ? @permit_engs : ()),
               (@reject_engs ? @reject_engs : ()),
            '   }';
      }
   }

   push @lines, '   return 1;',  '}';

   # Make the subroutine.
   my $code = join("\n", @lines);
   MKDEBUG && _d('filter sub:', $code);
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
   my ( $self, %args ) = @_;
   my @required_args = qw(dbh);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($dbh) = @args{@required_args};

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
#   * dbh    dbh: an active dbh
#   * db     scalar: database name
# Optional args:
#   * views  bool: Permit/return views (default no)
# Returns: itr
# Can die: no
# get_tbl_itr() returns an iterator which returns the next table found,
# in the given db, according to any set filters, when called successively.
# Make sure $dbh->{FetchHashKeyName} = 'NAME_lc' was set, else engine
# filters won't work.
sub get_tbl_itr {
   my ( $self, %args ) = @_;
   my @required_args = qw(dbh db);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($dbh, $db, $views) = @args{@required_args, 'views'};

   my $filter = $self->{filter};
   my @tbls;
   if ( $db ) {
      eval {
         my $sql = 'SHOW /*!50002 FULL*/ TABLES FROM '
                 . $self->{Quoter}->quote($db);
         MKDEBUG && _d($sql);
         @tbls = map {
            $_->[0]
         }
         grep {
            my $ok = $filter ? $filter->($dbh, $db, $_->[0]) : 1;
            if ( !$views ) {
               # We don't want views therefore we have to check the table
               # type.  Views are actually available in 5.0.1 but "FULL"
               # in SHOW FULL TABLES was not added until 5.0.2.  So 5.0.1
               # is an edge case that we ignore.  If >=5.0.2 then there
               # might be views and $_->[1] will be Table_type and we check
               # as normal.  Else, there cannot be views so we default
               # $_->[1] to 'VIEW' so that every table passes.
               $ok = 0 if ($_->[1] || 'VIEW') eq 'VIEW';
            }
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

# Required args:
#   * cond      scalar: condition for check, "if" or "unless"
#   * var_name  scalar: literal var name to compare to obj values
#   * objs      hashref: object values (as the hash keys)
# Optional args:
#   * lc  bool: lowercase object values
# Returns: scalar
# Can die: no
# _make_filter() return a test condtion like "$var eq 'foo' || $var eq 'bar'".
sub _make_filter {
   my ( $cond, $var_name, $objs, $lc ) = @_;
   my @lines;
   if ( scalar keys %$objs ) {
      my $test = join(' || ',
         map { "$var_name eq '" . ($lc ? lc $_ : $_) ."'" } keys %$objs);
      push @lines, "      return 0 $cond $var_name && ($test);",
   }
   return @lines;
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
