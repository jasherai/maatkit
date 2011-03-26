# This program is copyright 2011 Percona Inc.
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
# TableAccess package $Revision$
# ###########################################################################

# Package: TableAccess
# TableAccess determines which tables in a query are read, written and in what
# context.  A single query may read or write to several different tables, and
# the context for each table read/write can differ, too.  For example, the
# simplest case is "SELECT c FROM t": table t is read in the context (i.e.
# "for") the SELECT.  A more complex case is "INSERT INTO t1 SELECT * FROM
# t2 WHERE ...": t1 is written in the context of the INSERT and t2 is read
# in the context of the SELECT.  Any basic SQL statment is a context (SELECT,
# INSERT, UPDATE, DELETE, etc.), and JOIN is also a context.
#
# This package uses both QueryParser and SQLParser.  The former is used for
# simple queries, and the latter is used for more complex queries where table
# access may be hidden in who-knows-which clause of the SQL statement.
package TableAccess;

{ # package scope
use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;
use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Sub: new
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   QueryParser - <QueryParser> object
#   SQLParser   - <SQLParser> object
#
# Returns:
#   TableAccess object
sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw(QueryParser SQLParser);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $self = {
      %args,
   };

   return bless $self, $class;
}

# Sub: get_table_access
#   Get table access info for each table in the given query.  Table access
#   info includes the Context, Access (read or write) and the Table (CAT).
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   query - Query string
#
# Returns:
#   Arrayref of hashrefs, one for each CAT, like:
#   (code start)
#   [
#     { context => 'DELETE',
#       access  => 'write',
#       table   => 'd.t',
#     },
#     { context => 'DELETE',
#       access  => 'read',
#       table   => 'd.t',
#     },
#   ],
#   (code stop)
sub get_table_access {
   my ( $self, %args ) = @_;
   my @required_args = qw(query);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($query)   = @args{@required_args};
   MKDEBUG && _d('Getting table access for',
      substr($query, 0, 100), (length $query > 100 ? '...' : ''));

   my $cats;  # arrayref of CAT hashrefs for each table

   # Try to parse the query first with SQLParser.  This may be overkill for
   # simple queries, but it's probably cheaper to just do this than to try
   # detect first if the query is simple enough to parse with QueryParser.
   my $query_struct;
   eval {
      $query_struct = $self->{SQLParser}->parse($query);
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d('Failed to parse query with SQLParser:', $EVAL_ERROR);
      if ( $EVAL_ERROR =~ m/Cannot parse/ ) {
         # SQLParser can't parse this type of query, so it's probably some
         # data definition statement with just a table list.  Use QueryParser
         # to extract the table list and hope we're not wrong.
         $cats = $self->_get_cats_from_tables(%args);
      }
      else {
         # SQLParser failed to parse the query due to some error.
         die $EVAL_ERROR;
      }
   }
   else {
      # SQLParser parsed the query, so now we need to examine its structure
      # to determine the CATs for each table.
      $cats = $self->_get_cats_from_query_struct(
         query_struct => $query_struct,
         %args,
      );
   }

   MKDEBUG && _d('Query table access:', Dumper($cats));
   return $cats;
}

sub _get_cats_from_tables {
   my ( $self, %args ) = @_;
   my @required_args = qw(query);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($query) = @args{@required_args};
   MKDEBUG && _d('Getting cats from tables');

   my @cats;

   $query = $self->{QueryParser}->clean_query($query);
   my ($context) = $query =~ m/(\w+)\s+/;
   $context = uc $context;
   die "Query does not begin with a word" unless $context;  # shouldn't happen
   MKDEBUG && _d('Context for each table:', $context);

   my $access = $context =~ m/(?:ALTER|CREATE|TRUNCATE|DROP|RENAME)/ ? 'write'
              : $context =~ m/(?:INSERT|REPLACE|UPDATE|DELETE)/      ? 'write'
              : $context eq 'SELECT'                                 ? 'read'
              :                                                        undef;
   MKDEBUG && _d('Access for each table:', $access);

   my @tables = $self->{QueryParser}->get_tables($query);
   foreach my $table ( @tables ) {
      $table =~ s/`//g;
      push @cats, {
         table   => $table,
         context => $context,
         access  => $access,
      };
   }

   return \@cats;
}

sub _get_cats_from_query_struct {
   my ( $self, %args ) = @_;
   my @required_args = qw(query_struct);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($query_struct) = @args{@required_args};
   MKDEBUG && _d('Getting cats from query struct');

   my @cats;
   my $context = uc $query_struct->{type};
   my $access  = $context eq 'SELECT' ? 'read' : 'write';
   my $tables  = $query_struct->{from} || $query_struct->{into};
   foreach my $table ( @$tables ) {
      push @cats, {
         table   => ($table->{db} ? "$table->{db}." : '') . $table->{name},
         context => $table->{join} ? 'JOIN' : $context,
         access  => $access,
      };
   }

   if ( $query_struct->{where} ) {
      foreach my $cond ( @{$query_struct->{where}} ) {
         my $table;
         push @cats, {
            context => 'WHERE',
            access  => 'read',
            table   => $table,
         };
      }
   }

   return \@cats;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

} # package scope
1;

# ###########################################################################
# End TableAccess package
# ###########################################################################
