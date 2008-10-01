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

# TODO: handle STDIN -

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG           => $ENV{MKDEBUG};
use constant MAX_OPEN_FILES    => 1000;
use constant CLOSE_N_LRU_FILES => 100;

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

sub split_logs {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(log_files attribute saveto_dir LogParser) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $n_splits_left = $args{max_splits} || -1;

   my @fhs;
   foreach my $log ( @{ $args{log_files} } ) {
      open my $fh, "<", $log or die "Cannot open $log: $OS_ERROR\n";
      push @fhs, $fh;
   }

   # TODO: this is probably problematic on Windows
   $args{saveto_dir} .= '/' if substr($args{saveto_dir}, -1, 1) ne '/';

   $self->{attribute}  = $args{attribute};
   $self->{saveto_dir} = $args{saveto_dir};
   $self->{sessions}   = ();
   $self->{n_sessions} = 0;

   my $session_fhs = ();
   my $n_open_fhs  = 0;

   my $callback = sub {
      my ( $event ) = @_; 

      my $attrib = $self->{attribute};
      if ( !exists $event->{ $attrib } ) {
         if ( MKDEBUG ) {
            use Data::Dumper;
            _d("No attribute $attrib in event: " . Dumper($event));
         }
         return;
      }

      # This could indicate a problem in LogParser not parsing
      # a log event correctly thereby leaving $event->{arg} undefined.
      # Or, it could simply be an event like:
      # USE db;
      # SET NAMES utf8;
      return if !defined $event->{arg};

      # Don't print admin commands like quit or ping.
      return if $event->{cmd} eq 'Admin';

      my $session_id = $event->{ $attrib };
      my $session    = $self->{sessions}->{ $session_id } ||= {}; 

      # Init new session.
      if ( !defined $session->{fh} ) {
         return if !$n_splits_left;
         $n_splits_left--;

         # Set name of next log split file.
         my $session_n = sprintf '%04d', ++$self->{n_sessions};
         my $log_split_file = $self->{saveto_dir}
                               . "mysql_log_split-$session_n";

         # Close Last Recently Used session fhs if opening if this new
         # session fh will cause us to have too many open files.
         $n_open_fhs = $self->_close_lru_session($session_fhs, $n_open_fhs)
         if $n_open_fhs >= MAX_OPEN_FILES;

         # Open a fh for the log split file.
         open $session->{fh}, '>', $log_split_file
            or die "Cannot open log split file $log_split_file: $OS_ERROR";
         $n_open_fhs++;

         # Save fh and log split file info for this session.
         $session->{active}         = 1;
         $session->{log_split_file} = $log_split_file;
         push @$session_fhs,
            { fh => $session->{fh}, session_id => $session_id };

         MKDEBUG && _d("Created $log_split_file "
                       . "for session $attrib=$session_id");
      }
      elsif ( !$session->{active} ) {
         # Reopen the existing but inactive session. This happens when
         # a new session (above) had to close LRU session fhs.

         # Again, close Last Recently Used session fhs if reopening if this
         # session's fh will cause us to have too many open files.
         $n_open_fhs = $self->_close_lru_session($session_fhs, $n_open_fhs)
            if $n_open_fhs >= MAX_OPEN_FILES;

          # Reopen this session's fh.
          open $session->{fh}, '>>', $session->{log_split_file}
             or die "Cannot reopen log split file "
               . "$session->{log_split_file}: $OS_ERROR";
          $n_open_fhs++;

          # Mark this session as active again;
          $session->{active} = 1;

          MKDEBUG && _d("Reopend $session->{log_split_file} "
                        . "for session $attrib=$session_id");
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
      1 while $n_splits_left && $lp->parse_event($fh, $callback);
   }

   if ( !$args{silent} ) {
      print "Parsed $self->{n_sessions} sessions:\n";
      my $fmt = "   %-16s %-60s\n";
      printf($fmt, $self->{attribute}, 'Saved to log split file');
      foreach my $session_id ( sort keys %{ $self->{sessions} } ) {
         my $session = $self->{sessions}->{ $session_id };
         printf($fmt, $session_id, $session->{log_split_file}); 
      }
   }

   return;
}

sub _close_lru_session {
   my ( $self, $session_fhs, $n_open_files ) = @_;
   my $lru_n      = $self->{n_sessions} - MAX_OPEN_FILES - 1;
   my $close_to_n = $lru_n + CLOSE_N_LRU_FILES - 1;

   MKDEBUG && _d("Closing session fhs $lru_n..$close_to_n "
                 . "($self->{n_sessions} sessions, $n_open_files open files)");

   foreach my $session ( @$session_fhs[ $lru_n..$close_to_n ] ) {
      close $session->{fh};
      $n_open_files--;
      $self->{sessions}->{ $session->{session_id} }->{active} = 0;
   }

   return $n_open_files;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# LogSplitter:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End LogSplitter package
# ###########################################################################
