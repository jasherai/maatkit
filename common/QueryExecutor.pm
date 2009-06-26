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
# QueryExecutor package $Revision$
# ###########################################################################
package QueryExecutor;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Time::HiRes qw(time);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw() ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
   };
   return bless $self, $class;
}

# Executes the given query on the two given host dbhs.
# Returns a hashref with query execution time and number of errors
# and warnings produced on each host:
#    {
#       host1 => {
#          Query_time    => 1.123456,  # Query execution time
#          warning_count => 3,         # @@warning_count,
#          warnings      => [          # SHOW WARNINGS
#             [ "Error", "1062", "Duplicate entry '1' for key 1" ],
#          ],
#       },
#       host2 => {
#          etc.
#       }
#    }
# If the query cannot be executed on a host, an error string is returned
# for that host instead of the hashref of results.
sub exec {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(query host1_dbh host2_dbh) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   return {
      host1 => $self->_exec_query($args{query}, $args{host1_dbh}),
      host2 => $self->_exec_query($args{query}, $args{host2_dbh}),
   };
}

# This sub is called by exec() to do its common work:
# execute, time and get warnings for a query on a given host.
sub _exec_query {
   my ( $self, $query, $dbh ) = @_;
   die "I need a query" unless $query;
   die "I need a dbh"   unless $dbh;

   my ( $start, $end, $query_time );
   eval {
      $start = time();
      $dbh->do($query);
      $end   = time();
      $query_time = sprintf '%.6f', $end - $start;
   };
   if ( $EVAL_ERROR ) {
      return $EVAL_ERROR;
   }

   my $warnings = $dbh->selectall_hashref('SHOW WARNINGS', 'Code');
   my $warning_count = @{$dbh->selectall_arrayref('SELECT @@warning_count',
      { Slice => {} })}[0]->{'@@warning_count'};

   my $results = {
      Query_time    => $query_time,
      warnings      => $warnings,
      warning_count => $warning_count,
   };

   return $results;
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
# End QueryExecutor package
# ###########################################################################
