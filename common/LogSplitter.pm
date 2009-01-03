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

   my $self = {
      %args,
      n_dirs          => 0,  # number of dirs created
      n_files         => -1, # number of session files in current dir
      n_sessions      => 0,  # number of sessions saved
      n_session_files => 0,  # number of session files created
      session_fhs     => [], # filehandles for each session
      n_open_fhs      => 0,  # number of open session filehandles
      sessions        => {}, # sessions data store
   };
   # These are "required options."
   # They cannot be undef, so we must check that here.
   $self->{maxfiles}          ||= 100;
   $self->{maxdirs}           ||= 100;
   $self->{maxsessions}       ||= 100000;
   $self->{maxsessionfiles}   ||= 0;
   $self->{verbosity}         ||= 0;
   $self->{session_file_name} ||= 'mysql_log_session_';

   return bless $self, $class;
}

sub split_logs {
   my ( $self, $logs ) = @_;
   my $oktorun = 1; # true as long as we haven't created too many
                    # session files or too many dirs and files

   @{$self}{qw(n_dirs n_files n_sessions n_session_files)} = qw(0 -1 0 0);
   $self->{sessions} = {};

   if ( !defined $logs || scalar @$logs == 0 ) {
      MKDEBUG && _d('Implicitly reading STDIN because no logs were given');
      push @$logs, '-';
   }

   # This sub is called by LogParser::parse_event (below).
   # It saves each event to its proper session file.
   my $callback;
   if ( $self->{maxsessionfiles} ) {
      $callback = sub {
         my ( $event ) = @_;
         my ($session, $sesion_id) = $self->_get_session_ds($event);
         return 1 unless defined $session;
         $self->{n_sessions}++ if !$session->{already_seen}++;
         my $db = $event->{db} || $event->{Schema};
         if ( $db && ( !defined $session->{db} || $session->{db} ne $db ) ) {
            push @{$session->{queries}}, "USE `$db`";
            $session->{db} = $db;
         }
         push @{$session->{queries}}, $event->{arg};
         return 1;
      };
   }
   else {
      $callback = sub {
         my ( $event ) = @_; 
         my ($session, $session_id) = $self->_get_session_ds($event);
         return 1 unless defined $session;

         if ( !defined $session->{fh} ) {
            $self->{n_sessions}++;
            MKDEBUG && _d("New session: $session_id "
                          . "($self->{n_sessions} of $self->{maxsessions})");

            my $session_file = $self->_next_session_file();
            if ( !$session_file ) {
               $oktorun = 0;
               MKDEBUG && _d('No longer oktorun because no _next_session_file');
               return 1;
            }

            # Close Last Recently Used session fhs if opening if this new
            # session fh will cause us to have too many open files.
            $self->_close_lru_session() if $self->{n_open_fhs} >= MAX_OPEN_FILES;

            # Open a fh for the log split file.
            open my $fh, '>', $session_file
               or die "Cannot open log split file $session_file: $OS_ERROR";
            print $fh "-- ONE SESSION\n";
            $session->{fh} = $fh;
            $self->{n_open_fhs}++;

            # Save fh and log split file info for this session.
            $session->{active}       = 1;
            $session->{session_file} = $session_file;
            push @{ $self->{session_fhs} },
               { fh => $fh, session_id => $session_id };

            MKDEBUG && _d("Created $session_file "
                          . "for session $self->{attribute}=$session_id");
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
                           . "for session $self->{attribute}=$session_id");
         }
         else {
            MKDEBUG && _d("Event belongs to active session $session_id");
         }

         my $session_fh = $session->{fh};

         # Print USE db if 1) we haven't done so yet or 2) the db has changed.
         my $db = $event->{db} || $event->{Schema};
         if ( $db && ( !defined $session->{db} || $session->{db} ne $db ) ) {
            print $session_fh "USE `$db`\n\n";
            $session->{db} = $db;
         }

         print $session_fh "$event->{arg}\n\n";

         return 1;
      };
   }

   # Split all the log files.
   LOG:
   foreach my $log ( @$logs ) {
      next unless defined $log;
      if ( !-f $log && $log ne '-' ) {
         warn "Skipping $log because it is not a file";
         next LOG;
      }
      my $fh;
      if ( $log eq '-' ) {
         $fh = *STDIN;
      }
      else {
         open $fh, "<", $log or warn "Cannot open $log: $OS_ERROR\n";
      }
      if ( $fh ) {
         1 while $oktorun && $self->{LogParser}->parse_slowlog_event(
            $fh, undef, $callback);
         close $fh;
         last LOG if !$oktorun;
      }
   }

   if ( $self->{maxsessionfiles} ) {   
      # Open all the needed session files.
      for my $i ( 1..$self->{maxsessionfiles} ) {
         my $session_file = $self->_next_session_file($i);
         last if !$session_file;
         open my $fh, '>', $session_file
            or die "Cannot open session file $session_file: $OS_ERROR";
         $self->{n_session_files}++;
         print $fh "-- MULTIPLE SESSIONS\n";
         push @{ $self->{session_fhs} },
            { fh => $fh, session_file => $session_file };
      }

      my $sessions_per_file = int( $self->{n_sessions}
                                   / $self->{maxsessionfiles} );
      MKDEBUG && _d("$self->{n_sessions} session, "
                    . "$sessions_per_file per file");

      # Save sessions to the files.
      my $i      = 0;
      my $file_n = 0;
      my $fh     = $self->{session_fhs}->[0]->{fh};
      while ( my ($session_id, $session) = each %{$self->{sessions}} ) {
         $session->{session_file}
            = $self->{session_fhs}->[$file_n]->{session_file};
         print $fh "-- session $session_id\n\n";
         print $fh join("\n\n", @{$session->{queries}});
         print $fh "\n\n"; # because join() doesn't do this
         if ( ++$i >= $sessions_per_file ) {
            $i = 0;
            $file_n++ if $file_n < $self->{n_session_files} - 1;
            $fh = $self->{session_fhs}->[$file_n]->{fh};
         }
      }
   }

   # Close session filehandles.
   while ( my $fh = pop @{ $self->{session_fhs} } ) {
      close $fh->{fh};
   }
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

# Returns shortcut to session data store and id for the given event.
# The returned session will be undef if no more sessions are allowed.
sub _get_session_ds {
   my ( $self, $event ) = @_;

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

   my $session;
   my $session_id = $event->{ $attrib };

   # The following is necessary to prevent Perl from auto-vivifying
   # a lot of empty hashes for new sessions that are ignored due to
   # already having maxsessions.
   if ( $self->{n_sessions} < $self->{maxsessions} ) {
      # Will auto-vivify if necessary.
      $session = $self->{sessions}->{ $session_id } ||= {};
   }
   elsif ( exists $self->{sessions}->{ $session_id } ) {
      # Use only existing sessions.
      $session = $self->{sessions}->{ $session_id };
   }
   else {
      MKDEBUG && _d("Skipping new session $session_id because "
                    . "maxsessions is reached");
   }

   return ($session, $session_id);
}

sub _close_lru_session {
   my ( $self ) = @_;
   my $session_fhs = $self->{session_fhs};
   my $lru_n       = $self->{n_sessions} - MAX_OPEN_FILES - 1;
   my $close_to_n  = $lru_n + CLOSE_N_LRU_FILES - 1;

   MKDEBUG && _d("Closing session fhs $lru_n..$close_to_n "
                 . "($self->{n_sessions} sessions, "
                 . "$self->{n_open_fhs} open fhs)");

   foreach my $session ( @$session_fhs[ $lru_n..$close_to_n ] ) {
      close $session->{fh};
      $self->{n_open_fhs}--;
      $self->{sessions}->{ $session->{session_id} }->{active} = 0;
   }

   return;
}

# Returns an empty string on failure, or the next session file name on success.
# This will fail if we have opened maxdirs and maxfiles.
sub _next_session_file {
   my ( $self, $n ) = @_;
   return '' if $self->{n_dirs} >= $self->{maxdirs};

   # n_files will only be < 0 for the first dir and file
   # because n_file is set to -1 in new(). This is a hack
   # to cause the first dir and file to be created automatically.
   if ( $self->{n_files} >= $self->{maxfiles} || $self->{n_files} < 0) {
      $self->{n_dirs}++;
      $self->{n_files} = 0;
      my $new_dir = "$self->{saveto_dir}$self->{n_dirs}";
      if ( !-d $new_dir ) {
         my $retval = system("mkdir $new_dir");
         if ( ($retval >> 8) != 0 ) {
            die "Cannot create new directory $new_dir: $OS_ERROR";
         }
         MKDEBUG && _d("Created new saveto_dir $new_dir");
      }
      elsif ( MKDEBUG ) {
         _d("saveto_dir $new_dir already exists");
      }
   }

   $self->{n_files}++;
   my $dir_n        = $self->{n_dirs} . '/';
   my $session_n    = sprintf '%04d', $n || $self->{n_sessions};
   my $session_file = $self->{saveto_dir}
                    . $dir_n
                    . $self->{session_file_name} . $session_n;
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
