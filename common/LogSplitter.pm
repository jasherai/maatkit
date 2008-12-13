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

use constant MKDEBUG           => $ENV{MKDEBUG};
use constant MAX_OPEN_FILES    => 1000;
use constant CLOSE_N_LRU_FILES => 100;

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(attribute saveto_dir LogParser) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   # TODO: this is probably problematic on Windows
   $args{saveto_dir} .= '/' if substr($args{saveto_dir}, -1, 1) ne '/';

   my %self = (
      maxfiles          => 100,
      maxdirs           => 100,
      maxsessions       => 100000,
      verbosity         => 1,
      base_session_name => 'mysql_log_session_',
      %args, # override default above
      n_dirs       => 0,  # number of dirs created
      n_files      => -1, # number of session files created in current dir
      n_sessions   => 0,  # total number of session files created in all dirs
      session_fhs  => [], # filehandles for each session
      n_open_fhs   => 0,  # number of open session filehandles
      sessions     => {}, # sessions data store
   );
   return bless \%self, $class;
}

sub split_logs {
   my ( $self, $logs ) = @_;
   my $oktorun = 1; # true as long as we haven't created too many
                    # session files or too many dirs and files

   @{$self}{qw(n_dirs n_files n_sessions)} = (0, -1, 0);
   $self->{sessions} = {};

   if ( !defined $logs || scalar @$logs == 0 ) {
      MKDEBUG && _d('Implicitly reading STDIN because no logs were given');
      push @$logs, '-';
   }

   # Open a filehandle for each log file.
   my @fhs;
   foreach my $log ( @$logs ) {
      next unless defined $log;
      if ( !-f $log && $log ne '-' ) {
         MKDEBUG && _d("Skipping $log because it is not a file");
         next;
      }
      my $fh;
      if ( $log eq '-' ) {
         $fh = *STDIN;
      }
      else {
         open $fh, "<", $log or die "Cannot open $log: $OS_ERROR\n";
      }
      push @fhs, $fh;
   }

   # This sub is called by LogParser::parse_event (below).
   # It saves each event to its proper session file.
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

      # Don't print admin commands like quit or ping because these
      # cannot be played.
      return if $event->{cmd} eq 'Admin';

      my $session_id = $event->{ $attrib };
      my $session    = $self->{sessions}->{ $session_id } ||= {}; 

      # Init new session.
      if ( !defined $session->{fh} ) {
         if ( $self->{n_sessions} >= $self->{maxsessions} ) {
            $oktorun = 0;
            MKDEBUG && _d('No longer oktorun because '
                          . "$self->{n_sessions} >= $self->{maxessions}");
            return;
         }
         $self->{n_sessions}++;

         my $session_file = $self->_next_session_file();
         if ( !$session_file ) {
            $oktorun = 0;
            MKDEBUG && _d('No longer oktorun because no _next_session_file()');
            return;
         }

         # Close Last Recently Used session fhs if opening if this new
         # session fh will cause us to have too many open files.
         $self->_close_lru_session() if $self->{n_open_fhs} >= MAX_OPEN_FILES;

         # Open a fh for the log split file.
         open $session->{fh}, '>', $session_file
            or die "Cannot open log split file $session_file: $OS_ERROR";
         $self->{n_open_fhs}++;

         # Save fh and log split file info for this session.
         $session->{active}       = 1;
         $session->{session_file} = $session_file;
         push @{ $self->{session_fhs} },
            { fh => $session->{fh}, session_id => $session_id };

         MKDEBUG && _d("Created $session_file "
                       . "for session $attrib=$session_id");
      }
      elsif ( !$session->{active} ) {
         # Reopen the existing but inactive session. This happens when
         # a new session (above) had to close LRU session fhs.

         # Again, close Last Recently Used session fhs if reopening if this
         # session's fh will cause us to have too many open files.
         $self->_close_lru_session() if $self->{n_open_fhs} >= MAX_OPEN_FILES;

          # Reopen this session's fh.
          open $session->{fh}, '>>', $session->{session_file}
             or die "Cannot reopen log split file "
               . "$session->{session_file}: $OS_ERROR";
          $self->{n_open_fhs}++;

          # Mark this session as active again;
          $session->{active} = 1;

          MKDEBUG && _d("Reopend $session->{session_file} "
                        . "for session $attrib=$session_id");
      }

      my $session_fh = $session->{fh};

      # Print USE db if 1) we haven't done so yet or 2) the db has changed.
      my $db = $event->{db} || $event->{Schema};
      if ( $db && ( !defined $session->{db} || $session->{db} ne $db ) ) {
         print $session_fh "USE `$db`\n\n";
         $session->{db} = $db;
      }

      print $session_fh "$event->{arg}\n\n";
   };

   # Split all the log files.
   LOG:
   foreach my $fh ( @fhs ) {
      1 while $oktorun && $self->{LogParser}->parse_event($fh, $callback);
      last LOG if !$oktorun;
   }

   # Close session filehandles.
   foreach my $session_fh ( @{ $self->{session_fhs} } ) {
      close $session_fh->{fh};
   }
   $self->{session_fhs} = [];
   $self->{n_open_fhs}  = 0;

   # Report what session files were created.
   if ( $self->{verbosity} >= 1 ) {
      print "Parsed $self->{n_sessions} sessions:\n";
      my $fmt = "   %-16s %-60s\n";
      printf($fmt, $self->{attribute}, 'Saved to log split file');
      foreach my $session_id ( sort keys %{ $self->{sessions} } ) {
         my $session = $self->{sessions}->{ $session_id };
         printf($fmt, $session_id, $session->{session_file}); 
      }
   }

   return;
}

sub _close_lru_session {
   my ( $self ) = @_;
   my $session_fhs = $self->{session_fhs};
   my $lru_n       = $self->{n_sessions} - MAX_OPEN_FILES - 1;
   my $close_to_n  = $lru_n + CLOSE_N_LRU_FILES - 1;

   MKDEBUG && _d("Closing session fhs $lru_n..$close_to_n "
                 . "($self->{n_sessions} sessions, "
                 . "$self->{n_open_files} open files)");

   foreach my $session ( @$session_fhs[ $lru_n..$close_to_n ] ) {
      close $session->{fh};
      $self->{n_open_files}--;
      $self->{sessions}->{ $session->{session_id} }->{active} = 0;
   }

   return;
}

# Returns an empty string on failure, or the next session file name on success.
# This will fail if we have opened maxdirs and maxfiles.
sub _next_session_file {
   my ( $self ) = @_;
   return '' if $self->{n_dirs} >= $self->{maxdirs};

   # n_files will only be < 0 for the first dir and file
   # because n_file is set to -1 in new(). This is a hack
   # to cause the first dir and file to be created automatically.
   if ( $self->{n_files} >= $self->{maxfiles} || $self->{n_files} < 0) {
      $self->{n_dirs}++;
      $self->{n_files} = 0;
      my $retval = system("mkdir $self->{saveto_dir}$self->{n_dirs}");
      if ( ($retval >> 8) != 0 ) {
         die "Cannot create new directory $self->{saveto_dir}$self->{n_dirs}: "
            . $OS_ERROR;
      }
   }

   $self->{n_files}++;
   my $dir_n        = $self->{n_dirs} . '/';
   my $session_n    = sprintf '%04d', $self->{n_sessions};
   my $session_file = $self->{saveto_dir}
                    . $dir_n
                    . $self->{base_session_name} . $session_n;
   MKDEBUG && _d("Next session file $session_file");
   return $session_file;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# LogSplitter:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End LogSplitter package
# ###########################################################################
