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
# LogSplitter package $Revision$
# ###########################################################################

package LogSplitter;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

sub split_logs {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(log_files attribute saveto_dir LogParser) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my @fhs;
   foreach my $log ( @{ $args{log_files} } ) {
      open my $fh, "<", $log or die "Cannot open $log: $OS_ERROR\n";
      push @fhs, $fh;
   }

   $self->{attribute}  = $args{attribute};
   $self->{saveto_dir} = $args{saveto_dir};
   $self->{sessions}   = ();
   $self->{n_sessions} = 0;

   my $callback = sub {
      my ( $event ) = @_;

      my $attrib = $self->{attribute};
      if ( !exists $event->{ $attrib } ) {
         die "Attribute $attrib does not exist in log events.";
      }

      my $session_id = $event->{ $attrib };
      my $session    = $self->{sessions}->{ $session_id } ||= {}; 

      if ( !defined $session->{fh} ) { # New session
         my $session_n = sprintf '%04d', ++$self->{n_sessions};
         my $log_split_file = $self->{saveto_dir}
                            . "mysql_log_split-$session_n";

         open $session->{fh}, ">", $log_split_file
            or die "Cannot open log split file $log_split_file: $OS_ERROR";
         MKDEBUG && _d("Created $log_split_file for session $attrib=$session_id");
      }

      my $log_split_fh = $session->{fh};

      # Print USE db if 1) we haven't done so yet or 2) the db has changed.
      my $db = $event->{db} || $event->{Schema};
      if ( $db && ( !defined $session->{db} || $session->{db} ne $db ) ) {
         print $log_split_fh "USE `$db`\n\n";
         $session->{db} = $db;
      }

      print $log_split_fh "$event->{arg}\n\n";
   };

   my $lp = $args{LogParser};
   foreach my $fh ( @fhs ) {
      1 while $lp->parse_event($fh, $callback)
   }

   return;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# LogSplitter:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End LogSplitter package
# ###########################################################################
