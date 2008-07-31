#!/usr/bin/perl

# This program is copyright 
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

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);

use File::Temp ();

package MySQLInstance;

my $option_pattern = '([^\s=]+)(?:=(\S+))?';

sub new {
   my ( $class, $cmd ) = @_;
   my $self = {};
   ($self->{mysqld_binary}) = $cmd =~ m/(\S+mysqld)\s/;
   $self->{'64bit'} = `file $self->{mysqld_binary}` =~ m/64-bit/ ? 'Yes' : 'No';
   %{ $self->{cmd_line_ops} }
      = map {
           my ( $var, $val ) = m/$option_pattern/o;
           $var =~ s/-/_/go;
           $var => $val;
        } ($cmd =~ m/--(\S+)/g);
   $self->{cmd_line_ops}->{defaults_file} ||= '';
   return bless $self, $class;
}

sub load_default_sys_vars {
   my ( $self ) = @_;
   my $defaults_file = '';
   my $tmp_file = undef;
   if ( $self->{cmd_line_ops}->{defaults_file} ) {
      # Copy defaults file to /tmp/ because Debian/Ubuntu mysqld apparently
      # has a bug which prevents it from being read from non-standard locations.
      $tmp_file = File::Temp->new();
      my $cp_cmd = "cp $self->{cmd_line_ops}->{defaults_file} "
                   . $tmp_file->filename;
      `$cp_cmd`;
      $defaults_file = "--defaults-file=" . $tmp_file->filename;
   }
   my $cmd = "$self->{mysqld_binary} $defaults_file --help --verbose";
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
              $var => $val;
           } split "\n", $sys_vars;
   }
   return;
}

sub load_online_sys_vars {
   my ( $self, $dbh ) = @_;
   %{ $self->{online_system_vars} }
      = map { $_->{Variable_name} => $_->{Value} }
           @{ $$dbh->selectall_arrayref('SHOW VARIABLES',
                                        { Slice => {} })
            };
   return;
}

sub get_DSN {
   my ( $self ) = @_;
   my $port   = $self->{cmd_line_ops}->{port}     || '';
   my $socket = $self->{cmd_line_ops}->{'socket'} || '';
   my $host   = $port ne 3306 ? '127.0.0.1' : 'localhost';
   my $dsn = {
      P => $port,
      S => $socket,
      h => $host,
   };
   return $dsn;
}

1;
