#!/usr/bin/perl

# This program is copyright 2008 Percona Inc.
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

package ConfigChecker;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);

# These check subs return 0 if the check passes or a string describing what
# failed. $sys_vars is a ref to a hash of sys var => vals. Depending on the
# caller, it should be the live sys var val.
my @config_checks = (
   sub {
      my ( $sys_vars ) = @_;
      return 0 if $sys_vars->{innodb_flush_method} eq 'O_DIRECT';
      return "innodb_flush_method != O_DIRECT";
   },
   sub {
      my ( $sys_vars ) = @_;
      return 0 if $sys_vars->{log_slow_queries} eq 'ON';
      return "Slow query logging is disabled (log_slow_queries = OFF)";
   },
   sub {
      my ( $sys_vars ) = @_;
      return 0 if $sys_vars->{max_connections} == 100;
      return "max_connections has been modified from its default (100): "
             . $sys_vars->{max_connections};
   },
   sub {
      my ( $sys_vars ) = @_;
      return 0 if $sys_vars->{thread_cache_size} > 0;
      return "Zero thread cache (thread_cache_size = 0)";
   },
   sub {
      my ( $sys_vars ) = @_;
      if ( -e $sys_vars->{'socket'} && -S $sys_vars->{'socket'} ) {
         return 0;
      }
      return "Socket is missing ($sys_vars->{socket})";
   },
);

sub new {
   my ( $class ) = @_;
   return bless {}, $class;
}

sub run_all_checks {
   my ( $self, $sys_vars ) = @_;
   my @problems;
   foreach my $check ( @config_checks ) {
      if ( my $problem = $check->($sys_vars) ) {
         push @problems, $problem;
      }
   }
   return @problems;
}

1;
