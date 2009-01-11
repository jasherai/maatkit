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
# Daemon package $Revision$
# ###########################################################################

# Daemon - Daemonize and handle daemon-related tasks
package Daemon;

use strict;
use warnings FATAL => 'all';

use POSIX;
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   my $self = { %args };
   $self->{reopen_STDIN}  ||= '/dev/null';
   $self->{reopen_STDOUT} ||= '/dev/null';
   $self->{reopen_STDERR} ||= '&STDOUT';

   # PID_file cannot be given here; it must be given to create_PID_file().
   # See that sub for why.
   $self->{PID_file}        = undef;

   return bless $self, $class;
}

sub daemonize {
   my ( $self ) = @_;

   defined( my $pid = fork ) or die "Can't fork: $OS_ERROR";
   exit if $pid;
   POSIX::setsid() or die "Can't start a new session: $OS_ERROR";

   chdir '/' or die "Can't chdir to /: $OS_ERROR";

   open STDIN,  "$self->{reopen_STDIN}",
      or die "Cannot reopen STDIN $self->{reopen_STDIN}: $OS_ERROR";
   open STDOUT, ">$self->{reopen_STDOUT}"
      or die "Cannot reopen STDOUT >$self->{reopen_STDOUT}: $OS_ERROR";
   open STDERR, ">$self->{reopen_STDERR}"
      or die "Cannot reopen STDERR >$self->{reopen_STDERR}: $OS_ERROR";

   # TODO: don't allow MKDEBUG=1

   return;
}

sub create_PID_file {
   my ( $self, $PID_file ) = @_;
   return if !$PID_file;
   # PID_file must be given here and not new() because if it is already
   # set then the parent will unlink it when its copy of this daemon obj
   # is destoried.
   $self->{PID_file} = $PID_file; # save for unlink in DESTORY()
   open my $PID_FILE, "+> $self->{PID_file}"
      or die "Cannot open PID file '$self->{PID_file}': $OS_ERROR";
   print $PID_FILE $PID;
   close $PID_FILE
      or die "Cannot close PID file '$self->{PID_file}': $OS_ERROR";
   return;
}

sub remove_PID_file {
   my ( $self ) = @_;
   if ( defined $self->{PID_file} ) {
      unlink $self->{PID_file}
         or warn "Cannot remove PID file '$self->{PID_file}': $OS_ERROR";
   }
   return;
}

sub DESTROY {
   my ( $self ) = @_;
   $self->remove_PID_file();
   return;
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
# End Daemon package
# ###########################################################################
