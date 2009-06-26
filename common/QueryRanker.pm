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
# QueryRanker package $Revision$
# ###########################################################################
package QueryRanker;

# This module ranks query execution results from QueryExecutor in descending
# order of difference.  (See comments on QueryExecutor::exec() for what an
# execution result looks like.)  We want to know which queries have the
# greatest difference in execution time, warnings, etc. when executed on
# different hosts.  The greater a query's differences, the greater its rank.
#
# The order of hosts does not matter.  We speak of host1 and host2, but
# neither is considered the benchmark.  We are agnostic about the hosts;
# it could be an upgrade scenario where host2 is a newer version of host1,
# or a downgrade scenario where host2 is older than host1, or a comparison
# of the same version on different hardware or something.  So remember:
# we're only interested in "absolute" differences and no host has preference.
# 
# A query's rank (or score) is a simple integer.  Every query starts with
# a zero rank.  Then its rank is increased when a difference is found.  How
# much it increases depends on the difference.  This is discussed next; it's
# different for each comparison.
#
# There are several metrics by which we compare and rank differences.  The
# most basic is time and warnings.  A query's rank increases proportionately
# to the absolute difference in its warning counts.  So if a query produces
# a warning on host1 but not on host2, or vice-versa, its rank increases
# by 1.  Its rank is also increased by 1 for every warning that differs in
# its severity; e.g. if it's an error on host1 but a warning on host2, this
# may seem like a good thing (the error goes away) but it's not because it's
# suspicious and suspicious leads to surprises and we don't like surprises.
# Finally, a query's rank is increased by 1 for significant differences in
# its execution times.  If its times are in the same bucket but differ by
# a factor that is significant for that bucket, then its rank is only
# increased by 1.  But if its time are in different buckets, then its rank
# is increased by 2 times the difference of buckets; e.g. if one time is
# 0.001 and the other time is 0.01, that's 1 bucket different so its rank
# is increased by 2.
#
# Other rank metrics are planned: difference in result checksum, in EXPLAIN
# plan, etc.

use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use English qw(-no_match_vars);

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

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

1;

# ###########################################################################
# End QueryRanker package
# ###########################################################################
