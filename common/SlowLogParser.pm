# This program is copyright (c) 2007 Baron Schwartz.
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
# LogParser package $Revision$
# ###########################################################################
package SlowLogParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

my $slow_log_ts_line = qr/^# Time: (\d{6}\s+\d{1,2}:\d\d:\d\d)/;
my $slow_log_uh_line = qr/# User\@Host: ([^\[]+|\[[^[]+\]).*?@ (\S*) \[(.*)\]/;
# These can appear in the log file when it's opened -- for example, when someone
# runs FLUSH LOGS or the server starts.
# /usr/sbin/mysqld, Version: 5.0.67-0ubuntu6-log ((Ubuntu)). started with:
# Tcp port: 3306  Unix socket: /var/run/mysqld/mysqld.sock
# Time                 Id Command    Argument
# These lines vary depending on OS and whether it's embedded.
my $slow_log_hd_line = qr{
      ^(?:
      T[cC][pP]\s[pP]ort:\s+\d+ # case differs on windows/unix
      |
      [/A-Z].*mysqld,\sVersion.*(?:started\swith:|embedded\slibrary)
      |
      Time\s+Id\s+Command
      ).*\n
   }xm;

# This method accepts an open slow log filehandle and callback functions.
# It reads events from the filehandle and calls the callbacks with each event.
# It may find more than one event per call.  $misc is some placeholder for the
# future and for compatibility with other query sources.
#
# Each event is a hashref of attribute => value pairs like:
#  my $event = {
#     ts  => '',    # Timestamp
#     id  => '',    # Connection ID
#     arg => '',    # Argument to the command
#     other attributes...
#  };
#
# Returns the number of events it finds.
#
# NOTE: If you change anything inside this subroutine, you need to profile
# the result.  Sometimes a line of code has been changed from an alternate
# form for performance reasons -- sometimes as much as 20x better performance.
#
# TODO: pass in hooks to let something filter out events as early as possible
# without parsing more of them than needed.
sub parse_event {
   my ( $self, $fh, $misc, @callbacks ) = @_;
   my $num_events = 0;

   # Read a whole stmt at a time.  But, to make things even more fun, sometimes
   # part of the log entry might continue past the separator.  In these cases we
   # peek ahead (see code below.)  We do it this way because in the general
   # case, reading line-by-line is too slow, and the special-case code is
   # acceptable.  And additionally, the line terminator doesn't work for all
   # cases; the header lines might follow a statement, causing the paragraph
   # slurp to grab more than one statement at a time.
   my @pending;
   local $INPUT_RECORD_SEPARATOR = ";\n#";
   my $trimlen    = length($INPUT_RECORD_SEPARATOR);
   my $pos_in_log = tell($fh);
   my $stmt;

   EVENT:
   while ( defined($stmt = shift @pending) or defined($stmt = <$fh>) ) {
      my @properties = ('cmd', 'Query', 'pos_in_log', $pos_in_log);
      $pos_in_log = tell($fh);

      # If there were such lines in the file, we may have slurped > 1 event.
      # Delete the lines and re-split if there were deletes.  This causes the
      # pos_in_log to be inaccurate, but that's really okay.
      if ( $stmt =~ s/$slow_log_hd_line//go ){ # Throw away header lines in log
         my @chunks = split(/$INPUT_RECORD_SEPARATOR/o, $stmt);
         if ( @chunks > 1 ) {
            $stmt = shift @chunks;
            unshift @pending, @chunks;
         }
      }

      # There might not be a leading '#' because $INPUT_RECORD_SEPARATOR will
      # have gobbled that up.  And the end may have all/part of the separator.
      $stmt = '#' . $stmt unless $stmt =~ m/\A#/;
      $stmt =~ s/;\n#?\Z//;

      # The beginning of a slow-query-log event should be something like
      # # Time: 071015 21:43:52
      # Or, it might look like this, sometimes at the end of the Time: line:
      # # User@Host: root[root] @ localhost []

      # The following line contains variables intended to be sure we do
      # particular things once and only once, for those regexes that will
      # match only one line per event, so we don't keep trying to re-match
      # regexes.
      my ($got_ts, $got_uh, $got_ac, $got_db, $got_set, $got_embed);
      my $pos = 0;
      my $len = length($stmt);
      my $found_arg = 0;
      LINE:
      while ( $stmt =~ m/^(.*)$/mg ) { # /g is important, requires scalar match.
         $pos     = pos($stmt);  # Be careful not to mess this up!
         my $line = $1;          # Necessary for /g and pos() to work.

         # Handle meta-data lines.  These are case-sensitive.  If they appear in
         # the log with a different case, they are from a user query, not from
         # something printed out by sql/log.cc.
         if ($line =~ m/^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o) {

            # Maybe it's the beginning of the slow query log event.
            if ( !$got_ts
               && (my ( $time ) = $line =~ m/$slow_log_ts_line/o)
            ) {
               push @properties, 'ts', $time;
               ++$got_ts;
               # The User@Host might be concatenated onto the end of the Time.
               if ( !$got_uh
                  && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
               ) {
                  push @properties, 'user', $user, 'host', $host, 'ip', $ip;
                  ++$got_uh;
               }
            }

            # Maybe it's the user/host line of a slow query log
            # # User@Host: root[root] @ localhost []
            elsif ( !$got_uh
                  && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
            ) {
               push @properties, 'user', $user, 'host', $host, 'ip', $ip;
               ++$got_uh;
            }

            # A line that looks like meta-data but is not:
            # # administrator command: Quit;
            elsif (!$got_ac && $line =~ m/^# (?:administrator command:.*)$/) {
               push @properties, 'cmd', 'Admin', 'arg', $line;
               push @properties, 'bytes', length($properties[-1]);
               ++$found_arg;
               ++$got_ac;
            }

            # Maybe it's the timing line of a slow query log, or another line
            # such as that... they typically look like this:
            # # Query_time: 2  Lock_time: 0  Rows_sent: 1  Rows_examined: 0
            # If issue 234 bites us, we may see something like
            # Query_time: 18446744073708.796870.000036 so we match only up to
            # the second decimal place for numbers.
            elsif ( my @temp = $line =~ m/(\w+):\s+(\d+(?:\.\d+)?|\S+)/g ) {
               push @properties, @temp;
            }

            # Include the current default database given by 'use <db>;'  Again
            # as per the code in sql/log.cc this is case-sensitive.
            elsif ( !$got_db && (my ( $db ) = $line =~ m/^use ([^;]+)/ ) ) {
               push @properties, 'db', $db;
               ++$got_db;
            }

            # Some things you might see in the log output, as printed by
            # sql/log.cc (this time the SET is uppercaes, and again it is
            # case-sensitive).
            # SET timestamp=foo;
            # SET timestamp=foo,insert_id=123;
            # SET insert_id=123;
            elsif (!$got_set && (my ($setting) = $line =~ m/^SET\s+([^;]*)/)) {
               # Note: this assumes settings won't be complex things like
               # SQL_MODE, which as of 5.0.51 appears to be true (see sql/log.cc,
               # function MYSQL_LOG::write(THD, char*, uint, time_t)).
               push @properties, split(/,|\s*=\s*/, $setting);
               ++$got_set;
            }

            # Handle pathological special cases. The "# administrator command"
            # is one example: it can come AFTER lines that are not commented,
            # so it looks like it belongs to the next event, and it won't be
            # in $stmt. Profiling shows this is an expensive if() so we do
            # this only if we've seen the user/host line.
            if ( !$found_arg && $pos == $len ) {
               local $INPUT_RECORD_SEPARATOR = ";\n";
               if ( defined(my $l = <$fh>) ) {
                  chomp $l;
                  push @properties, 'cmd', 'Admin', 'arg', '#' . $l;
                  push @properties, 'bytes', length($properties[-1]);
                  $found_arg++;
               }
               else {
                  # Unrecoverable -- who knows what happened.  This is possible,
                  # for example, if someone does something like "head -c 10000
                  # /path/to/slow.log | mk-log-parser".  Or if there was a
                  # server crash and the file has no newline.
                  next EVENT;
               }
            }
         }
         else {
            # This isn't a meta-data line.  It's the first line of the
            # whole query. Grab from here to the end of the string and
            # put that into the 'arg' for the event.  Then we are done.
            # Note that if this line really IS the query but we skip in
            # the 'if' above because it looks like meta-data, later
            # we'll remedy that.
            my $arg = substr($stmt, $pos - length($line));
            push @properties, 'arg', $arg, 'bytes', length($arg);
            # Handle embedded attributes.
            if ( $misc && $misc->{embed}
               && ( my ($e) = $arg =~ m/($misc->{embed})/)
            ) {
               push @properties, $e =~ m/$misc->{capture}/g;
            }
            last LINE;
         }
      }

      my $event = { @properties };
      foreach my $callback ( @callbacks ) {
         last unless $event = $callback->($event);
      }
      ++$num_events;
      last EVENT unless @pending;
   }
   return $num_events;
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
# End SlowLogParser package
# ###########################################################################
