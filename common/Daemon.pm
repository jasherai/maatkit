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
# ###########################################################################
# Daemon package $Revision: $
# ###########################################################################

# Daemon - Daemonize and handle daemon-related tasks
package Daemon;

use strict;
use warnings FATAL => 'all';

use POSIX qw(setsid);
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class ) = @_;
   return bless {
      PID_file => undef
   }, $class;
}

sub daemonize {
   my ( $self ) = @_;

   defined( my $pid = fork ) or die "Can't fork: $OS_ERROR";
   exit if $pid;

   POSIX::setsid()           or die "Can't start a new session: $OS_ERROR";
   chdir '/'                 or die "Can't chdir to /: $OS_ERROR";
   open STDIN,  '/dev/null'  or die "Can't read /dev/null: $OS_ERROR";
   open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $OS_ERROR";
   open STDERR, '>&STDOUT'   or die "Can't dup STDOUT: $OS_ERROR";

   # TODO: check for existing PID/running instance of same daemonized script?
   # TODO: don't allow MKDEBUG=1

   return;
}

sub create_PID_file {
   my ( $self, $PID_file_dir ) = @_;
   $PID_file_dir ||= '/tmp/';
   $self->{PID_file} = $PID_file_dir . "$PROGRAM_NAME.pid";
   open PID_FILE, "+> $self->{PID_file}"
      or die "Can't open PID file '$self->{PID_file}': $OS_ERROR";
   print PID_FILE $PID;
   close PID_FILE
      or die "Can't close PID file '$self->{PID_file}': $OS_ERROR";
   return;
}

sub remove_PID_file {
   my ( $self ) = @_;
   if ( defined $self->{PID_file} ) {
      unlink $self->{PID_file}
         or warn "Can't remove PID file '$self->{PID_file}': $OS_ERROR";
   }
   return;
}

sub DESTROY {
   my ( $self ) = @_;
   $self->remove_PID_file();
   return;
}

1;

# ###########################################################################
# End Daemon package
# ###########################################################################
