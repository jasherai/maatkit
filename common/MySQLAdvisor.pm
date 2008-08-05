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

# MySQLAdvisor - Check MySQL system variables and status values for problems
package MySQLAdvisor;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);

# These check subs return 0 if the check passes or a string describing what
# failed. $sys_vars is a ref to a hash of sys var => vals. Depending on the
# caller, it should be the live sys var val. $status_vals is a ref to a hash
# of status val => vals. If a check can't be tested (e.g. no Innodb_ status
# values), return 0.
my %checks = (
   innodb_flush_method =>
      sub {
         my ( $sys_vars, $status_vals ) = @_;
         return "innodb_flush_method != O_DIRECT"
            if $sys_vars->{innodb_flush_method} ne 'O_DIRECT';
         return 0;
      },
   log_slow_queries =>
      sub {
         my ( $sys_vars, $status_vals ) = @_;
         return "Slow query logging is disabled (log_slow_queries = OFF)"
            if $sys_vars->{log_slow_queries} eq 'OFF';
         return 0;
      },
   max_connections =>
      sub {
         my ( $sys_vars, $status_vals ) = @_;
         return "max_connections has been modified from its default (100): "
                . $sys_vars->{max_connections}
            if $sys_vars->{max_connections} != 100;
         return 0;
      },
   thread_cache_size =>
      sub {
         my ( $sys_vars, $status_vals ) = @_;
         return "Zero thread cache (thread_cache_size = 0)"
            if $sys_vars->{thread_cache_size} == 0;
         return 0;
      },
   'socket' =>
      sub {
         my ( $sys_vars, $status_vals ) = @_;
         if ( ! (-e $sys_vars->{'socket'} && -S $sys_vars->{'socket'}) ) {
            return "Socket is missing ($sys_vars->{socket})";
         }
         return 0;
      },
   'query_cache' =>
      sub {
         my ( $sys_vars, $status_vals ) = @_;
         if ( exists $sys_vars->{query_cache_type} ) {
            if (    $sys_vars->{query_cache_type} eq 'ON'
                 && $sys_vars->{query_cache_size} == 0) {
               return "Query cache enabled but size zero";
            }
         }
         return 0;
      },
   'Innodb_buffer_pool_pages_free' =>
      sub {
         my ( $sys_vars, $status_vals ) = @_;
         if ( exists $status_vals->{Innodb_buffer_pool_pages_free} ) {
            if ( $status_vals->{Innodb_buffer_pool_pages_free} == 0 ) {
               return "InnoDB: zero free buffer pool pages";
            }
         }
         return 0;
      },
);

sub new {
   my ( $class ) = @_;
   return bless {}, $class;
}

# run_all_checks() returns a hash of checks that failed:
#    key   = name of check
#    value = description of failure
sub run_all_checks {
   my ( $self, $sys_vars, $status_vals ) = @_;
   my %problems;
   foreach my $check_name ( keys %checks ) {
      if ( my $problem = $checks{$check_name}->($sys_vars, $status_vals) ) {
         $problems{$check_name} = $problem;
      }
   }
   return %problems;
}

# run_check() returns a hash exactly like run_all_checks() unless the given
# check name does not exist, in which case a hash with a single key = ERROR,
# value = error msg is returned.
sub run_check {
   my ( $self, $sys_vars, $status_vals, $check_name ) = @_;
   my %problems;
   if ( exists $checks{$check_name} ) {
      if ( my $problem = $checks{$check_name}->($sys_vars, $status_vals) ) {
         $problems{$check_name} = $problem;
      }
   }
   else {
      $problems{ERROR} = "No check named $check_name exists.";
   }
   return %problems;
}

1;
