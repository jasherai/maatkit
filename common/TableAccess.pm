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

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

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
   my ($query) = @args{@required_args};

   my $cat;  # Context, Access, Table for each table

   return $cat;
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
# End TableAccess package
# ###########################################################################
