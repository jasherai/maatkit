# This program is copyright 2008-@CURRENTYEAR@ Percona Inc.
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
# MySQLAdvisor package $Revision$
# ###########################################################################

# MySQLAdvisor - Check MySQL system variables and status values for problems
package MySQLAdvisor;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use List::Util qw(max);

use constant MKDEBUG => $ENV{MKDEBUG};

# These check subs return 0 if the check passes or a string describing what
# failed. If a check can't be tested (e.g. no Innodb_ status values), return 0.
my %checks = (
   innodb_flush_method =>
      sub {
         my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
         return "innodb_flush_method is not set to O_DIRECT"
            if $sys_vars->{innodb_flush_method} ne 'O_DIRECT';
         return 0;
      },
   log_slow_queries =>
      sub {
         my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
         return "Slow query logging is disabled (log_slow_queries = OFF)"
            if $sys_vars->{log_slow_queries} eq 'OFF';
         return 0;
      },
   max_connections =>
      sub {
         my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
         return "max_connections has been modified from its default (100): "
                . $sys_vars->{max_connections}
            if $sys_vars->{max_connections} != 100;
         return 0;
      },
   thread_cache_size =>
      sub {
         my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
         return "Zero thread cache (thread_cache_size = 0)"
            if $sys_vars->{thread_cache_size} == 0;
         return 0;
      },
   'socket' =>
      sub {
         my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
         if ( ! (-e $sys_vars->{'socket'} && -S $sys_vars->{'socket'}) ) {
            return "Socket is missing ($sys_vars->{socket})";
         }
         return 0;
      },
   'query_cache' =>
      sub {
         my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
         if ( exists $sys_vars->{query_cache_type} ) {
            if (    $sys_vars->{query_cache_type} eq 'ON'
                 && $sys_vars->{query_cache_size} == 0) {
               return "Query caching is enabled but query_cache_size is zero";
            }
         }
         return 0;
      },
   'Innodb_buffer_pool_pages_free' =>
      sub {
         my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
         if ( exists $status_vals->{Innodb_buffer_pool_pages_free} ) {
            if ( $status_vals->{Innodb_buffer_pool_pages_free} == 0 ) {
               return "InnoDB: zero free buffer pool pages";
            }
         }
         return 0;
      },
   'skip_name_resolve' =>
      sub {
         my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
         if ( !exists $sys_vars->{skip_name_resolve} ) {
            return "skip-name-resolve is not set";
         }
         return 0;
      },
   'key_buffer too large' =>
      sub {
         my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
         return "Key buffer may be too large"
            if $sys_vars->{key_buffer_size}
               > max($counts->{engines}->{MyISAM}->{data_size}, 33554432); # 32M
         return 0;
      },
   'InnoDB buffer pool too small' =>
      sub {
         my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
         if (    exists $sys_vars->{innodb_buffer_pool_size} 
              && exists $counts->{engines}->{InnoDB} ) {
            return "InnoDB: buffer pool too small"
               if $counts->{engines}->{InnoDB}->{data_size}
                  >= $sys_vars->{innodb_buffer_pool_size};
         }
      },
);

sub new {
   my ( $class, $MySQLInstance, $SchemaDiscover ) = @_;
   my $self = {
      sys_vars    => $MySQLInstance->{online_sys_vars},
      status_vals => $MySQLInstance->{status_vals},
      schema      => $SchemaDiscover->{dbs},
      counts      => $SchemaDiscover->{counts},
   };
   return bless $self, $class;
}

# run_checks() returns a hash of checks that fail:
#    key   = name of check
#    value = description of failure
# $check_name is optional: if given, only that check is ran, otherwise
# all checks are ran. If the given check name does not exist, the returned
# hash will have only one key = ERROR => value = error msg
sub run_checks {
   my ( $self, $check_name ) = @_;
   my %problems;
   if ( defined $check_name ) {
      if ( exists $checks{$check_name} ) {
         if ( my $problem = $checks{$check_name}->($self->{sys_vars},
                                                   $self->{status_vals},
                                                   $self->{schema},
                                                   $self->{counts}) ) {
            $problems{$check_name} = $problem;
         }
      }
      else {
         $problems{ERROR} = "No check named $check_name exists.";
      }
   }
   else {
      foreach my $check_name ( keys %checks ) {
         if ( my $problem = $checks{$check_name}->($self->{sys_vars},
                                                   $self->{status_vals},
                                                   $self->{schema},
                                                   $self->{counts}) ) {
            $problems{$check_name} = $problem;
         }
      }
   }
   return \%problems;
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
# End MySQLAdvisor package
# ###########################################################################
