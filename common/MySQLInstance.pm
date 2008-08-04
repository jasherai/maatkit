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

package MySQLInstance;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);

use File::Temp ();

my $option_pattern = '([^\s=]+)(?:=(\S+))?';

my %undef_for = (
   skip_external_locking => 'ON',
   tmpdir                => '',
   innodb_flush_method   => '',
   relay_log_index       => '',
   log_slow_queries      => 'OFF',
   'log'                 => 'OFF',
);

sub new {
   my ( $class, $cmd ) = @_;
   my $self = {};
   ($self->{mysqld_binary}) = $cmd =~ m/(\S+mysqld)\s/;
   $self->{'64bit'} = `file $self->{mysqld_binary}` =~ m/64-bit/ ? 'Yes' : 'No';
   %{ $self->{cmd_line_ops} }
      = map {
           my ( $var, $val ) = m/$option_pattern/o;
           $var =~ s/-/_/go;
           if ( !defined $val && exists $undef_for{$var} ) {
              $val = $undef_for{$var};
           }
           $var => $val;
        } ($cmd =~ m/--(\S+)/g);
   $self->{cmd_line_ops}->{defaults_file} ||= '';
   return bless $self, $class;
}

sub load_default_sys_vars {
   my ( $self ) = @_;
   my ( $defaults_file_op, $tmp_file ) = $self->_defaults_file_op();
   my $cmd = "$self->{mysqld_binary} $defaults_file_op --help --verbose";
   if ( my $mysqld_output = `$cmd` ) {
      # Parse from mysqld output the list of sys vars and their default values
      # listed at the end after all the help info.
      my ($sys_vars) = $mysqld_output =~ m/---\n(.*?)\n\n/ms;
      %{ $self->{conf_sys_vars} }
         = map {
              my ( $var, $val ) = m/^(\S+)\s+(?:(\S+))?/;
              $var =~ s/-/_/go;
              if ( $val && $val =~ m/\(No/ ) { # (No default value)
                 $val = undef;
              }
              if ( !defined $val && exists $undef_for{$var} ) {
                 $val = $undef_for{$var};
              }
              $var => $val;
           } split "\n", $sys_vars;
   }
   # Load sys vars explicitly set in defaults file. This is used later
   # by duplicate_values() and overriden_values()
   $self->{defaults_files_sys_vars}
      = $self->_vars_from_defaults_file($defaults_file_op);
   return;
}

# Returns a --defaults-file cmd line op suitable for mysqld, my_print_defaults,
# etc., or a blank string if the defaults file is unknown.
sub _defaults_file_op {
   my ( $self ) = @_;
   my $defaults_file_op = '';
   my $tmp_file = undef;
   if ( $self->{cmd_line_ops}->{defaults_file} ) {
      # Copy defaults file to /tmp/ because Debian/Ubuntu mysqld apparently
      # has a bug which prevents it from being read from non-standard locations.
      $tmp_file = File::Temp->new();
      my $cp_cmd = "cp $self->{cmd_line_ops}->{defaults_file} "
                   . $tmp_file->filename;
      `$cp_cmd`;
      $defaults_file_op = "--defaults-file=" . $tmp_file->filename;
   }
   # Must return $tmp_file obj so its reference lasts into the caller because
   # when it's destroyed the actual tmp file is automatically unlinked 
   return ( $defaults_file_op, $tmp_file );
}

# Loads $self->{default_files_sys_vars} with only the sys vars that
# are explicitly set in the defaults file. This is used for detecting
# duplicates and overriden var/vals.
sub _vars_from_defaults_file {
   my ( $self, $defaults_file_op ) = @_;
   my $cmd = "my_print_defaults $defaults_file_op mysqld";
   if ( my $my_print_defaults_output = `$cmd` ) {
      foreach my $var_val ( split "\n", $my_print_defaults_output ) {
         # Make sys vars from conf look like those from SHOW VARIABLES
         # (I.e. log_slow_queries instead of log-slow-queries
         # and 33554432 instead of 32M, etc.)
         my ( $var, $val ) = $var_val =~ m/^--$option_pattern/o;
         $var =~ s/-/_/go;
         if ( defined $val && $val =~ /(\d+)M/) {
            $val = $1 * 1_048_576;
         }
         if ( !defined $val && exists $undef_for{$var} ) {
            $val = $undef_for{$var};
         }
         push @{ $self->{defaults_file_sys_vars} }, [ $var, $val ];
      }
   }
}

sub load_online_sys_vars {
   my ( $self, $dbh ) = @_;
   %{ $self->{online_sys_vars} }
      = map { $_->{Variable_name} => $_->{Value} }
            @{ $$dbh->selectall_arrayref('SHOW GLOBAL VARIABLES',
                                         { Slice => {} })
            };
   return;
}

sub get_DSN {
   my ( $self ) = @_;
   my $port   = $self->{cmd_line_ops}->{port}     || '';
   my $socket = $self->{cmd_line_ops}->{'socket'} || '';
   my $host   = $port ne 3306 ? '127.0.0.1' : 'localhost';
   return {
      P => $port,
      S => $socket,
      h => $host,
   };
}

# Returns a simple list of sys var names that appear more that
# appear more than once in the defaults file
sub duplicate_sys_vars {
   my ( $self ) = @_;
   my @duplicate_vars;
   my %have_seen;
   foreach my $var_val ( @{ $self->{defaults_file_sys_vars} } ) {
      my ( $var, $val ) = ( $var_val->[0], $var_val->[1] );
      push @duplicate_vars, $var if $have_seen{$var}++ == 1;
   }
   return @duplicate_vars;
}

# Returned hash of overriden sys vars:
#    key   = sys var that is overriden
#    value = array [ val being used, val overriden ]
sub overriden_sys_vars {
   my ( $self ) = @_;
   my %overriden_vars;
   foreach my $var_val ( @{ $self->{defaults_file_sys_vars} } ) {
      my ( $var, $val ) = ( $var_val->[0], $var_val->[1] );
      if ( exists $self->{cmd_line_ops}->{$var} ) {
         if(    ( !defined $self->{cmd_line_ops}->{$var} && !defined $val)
             || ( $self->{cmd_line_ops}->{$var} ne $val) ) {
            $overriden_vars{$var} = [ $self->{cmd_line_ops}->{$var}, $val ];
         }
      }
   }
   return %overriden_vars;
}

1;
