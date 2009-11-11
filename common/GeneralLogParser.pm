# This program is copyright 2009 Percona Inc.
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
# GeneralLogParser package $Revision$
# ###########################################################################
package GeneralLogParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class ) = @_;
   return bless {}, $class;
}

my $genlog_line_1= qr{
   \A
   (?:(\d{6}\s\d{1,2}:\d\d:\d\d))? # Timestamp
   \s+
   (?:\s*(\d+))                        # Thread ID
   \s
   (\w+)                               # Command
   \s+
   (.*)                                # Argument
   \Z
}xs;

# This method accepts an open filehandle, a callback function, and a mode
# (slow, log, undef).  It reads events from the filehandle and calls the
# callback with each event.
sub parse_event {
   my ( $self, $fh, $misc, @callbacks ) = @_;
   my $oktorun_here = 1;
   my $oktorun      = $misc->{oktorun} ? $misc->{oktorun} : \$oktorun_here;
   my $num_events   = 0;

   my $line;
   my $pos_in_log = tell($fh);
   LINE:
   while ( $$oktorun && defined($line = <$fh>) ) {
      MKDEBUG && _d($line);
      my ($ts, $thread_id, $cmd, $arg) = $line =~ m/$genlog_line_1/;
      if ( !($thread_id && $cmd) ) {
         MKDEBUG && _d('Not start of general log event');
         next;
      }
      # Don't save cmd or arg yet, we may need to modify them later.
      my @properties = ('pos_in_log', $pos_in_log, 'ts', $ts,
         'Thread_id', $thread_id);

      $pos_in_log = tell($fh);

      my $redo = 0;
      if ( $cmd eq 'Query' ) {
         # There may be more lines to this query.
         my $done = 0;
         do {
            $line = <$fh>;
            if ( $line ) {
               ($ts, $thread_id, $cmd, undef) = $line =~ m/$genlog_line_1/;
               if ( $thread_id && $cmd ) {
                  MKDEBUG && _d('Event done');
                  $done = 1;
                  $redo = 1;
               }
               else {
                  MKDEBUG && _d('More arg:', $line);
                  $arg .= $line;
               }
            }
            else {
               MKDEBUG && _d('No more lines');
               $done = 1;
            }
         } until ( $done );

         chomp $arg;
         $arg .= ';';  # Add ending ; like slowlog events.
         push @properties, 'cmd', 'Query', 'arg', $arg;
         push @properties, 'bytes', length($properties[-1]);
      }
      else {
         # If it's not a query it's some admin command.
         push @properties, 'cmd', 'Admin';

         if ( $cmd eq 'Connect' ) {
            if ( $arg =~ m/^Access denied/ ) {
               # administrator command: Access denied for user ...
               $cmd = $arg;
            }
            else {
               # The Connect command may or may not be followed by 'on'.
               # When it is, 'on' may or may not be followed by a database.
               my ($user, undef, $db) = $arg =~ /(\S+)/g;
               my $host;
               ($user, $host) = split(/@/, $user);
               MKDEBUG && _d('Connect', $user, '@', $host, 'on', $db);

               push @properties, 'user', $user if $user;
               push @properties, 'host', $host if $host;
               push @properties, 'db',   $db   if $db;
            }
         }
         elsif ( $cmd eq 'Init' ) {
            # The full command is "Init DB" so arg starts with "DB"
            # because our regex expects single word commands.
            $cmd = 'Init DB';
            $arg =~ s/^DB\s+//;
            my ($db) = $arg =~ /(\S+)/;
            MKDEBUG && _d('Init DB:', $db);
            push @properties, 'db',   $db   if $db;
         }

         push @properties, 'arg', "administrator command: $cmd;";
         push @properties, 'bytes', length($properties[-1]);
      }

      # The Query_time attrib is expected by mk-query-digest but
      # general logs have no Query_time so we fake it.
      push @properties, 'Query_time', 0;

      # Don't dump $event; want to see full dump of all properties,
      # and after it's been cast into a hash, duplicated keys will
      # be gone.
      MKDEBUG && _d('Properties of event:', Dumper(\@properties));
      my $event = { @properties };
      foreach my $callback ( @callbacks ) {
         last unless $event = $callback->($event);
      }
      ++$num_events;

      if ( $redo ) {
         MKDEBUG && _d('Redoing');
         redo;
      }
   } # LINE

   return $num_events;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

1;

# ###########################################################################
# End GeneralLogParser package
# ###########################################################################
