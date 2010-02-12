# This program is copyright 2010 Baron Schwartz.
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
# PgLogParser package $Revision: 5357 $
# ###########################################################################
package PgLogParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Data::Dumper;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# This regex is partially inspired by one from pgfouine.  But there is no
# documentation on the last capture in that regex, so I omit that.  (TODO: that
# actually seems to be for CSV logging.)
#     (?:[0-9XPFDBLA]{2}[0-9A-Z]{3}:[\s]+)?
# Here I constrain to match at least two spaces after the severity level,
# because the source code tells me to.  I believe this is controlled in elog.c:
# appendStringInfo(&buf, "%s:  ", error_severity(edata->elevel));
my $log_line_regex = qr{
   (LOG|DEBUG|CONTEXT|WARNING|ERROR|FATAL|PANIC|HINT
    |DETAIL|NOTICE|STATEMENT|INFO|LOCATION)
   :\s\s+
   }x;


# The following are taken right from the comments in postgresql.conf for
# log_line_prefix.
my %llp_for = (
   u => 'user',
   d => 'db',
   r => 'host', # With port
   h => 'host',
   p => 'Process_id',
   t => 'ts',
   m => 'ts',   # With milliseconds
   i => 'Query_type',
   c => 'Session_id',
   l => 'Line_no',
   s => 'Session_ts',
   v => 'Vrt_trx_id',
   x => 'Trx_id',
);

# This class's data structure is a hashref with only a little bit of
# statefulness: the deferred line.  This is necessary because we sometimes
# don't know whether the event is complete until we read the next line, so we
# have to defer a line.
sub new {
   my ( $class ) = @_;
   my $self = {
      deferred => undef,
   };
   return bless $self, $class;
}

# This method accepts an iterator that contains an open log filehandle.  It
# reads events from the filehandle by calling the iterator, and returns the
# events.
#
# Each event is a hashref of attribute => value pairs like:
#  my $event = {
#     ts  => '',    # Timestamp
#     arg => '',    # Argument to the command
#     other attributes...
#  };
#
# The log format is ideally prefixed with the following:
#
#  * timestamp with microseconds
#  * session ID, user, database
#
# The format I'd like to see is something like this:
#
# 2010-02-08 15:31:48.685 EST sid=4b7074b4.985,u=user,D=database LOG:
#
# However, pgfouine supports user=user, db=database format.  And I think
# it should be reasonable to grab pretty much any name=value properties out, and
# handle them based on the lower-cased first character of $name, to match the
# special values that are possible to give for log_line_prefix. For example, %u
# = user, so anything starting with a 'u' should be interpreted as a user.
#
# In general the log format is rather flexible, and we don't know by looking at
# any given line whether it's the last line in the event.  So we often have to
# read a line and then decide what to do with the previous line we saw.  Thus we
# use 'deferred' when necessary but we try to do it as little as possible,
# because it's double work to defer and re-parse lines; and we try to defer as
# soon as possible so we don't have to do as much work.
#
# There are 3 categories of lines in a log file:
#
# - Those that start a possibly multi-line event
# - Those that can continue one
# - Those that are neither the start nor the continuation, and thus must be the
#   end.
#
# In cases 1 and 3, we have to check whether information from previous lines has
# been accumulated.  If it has, we defer the current line and create the event.
# Otherwise we keep going, looking for more lines for the event that begins with
# the current line.  Processing the lines is easiest if we arrange the cases in
# this order: 2, 1, 3.
sub parse_event {
   my ( $self, %args ) = @_;
   my @required_args = qw(next_event tell);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   # The subroutine references that wrap the filehandle operations.
   my ($next_event, $tell) = @args{@required_args};

   # These are the properties for the log event, which will later be used to
   # create an event hash ref.
   my @properties = ();

   # Holds the current line being processed.
   my $line;

   # The position in the log is the byte offset from the beginning.  We have to
   # get this before we start reading lines.  In some cases we'll have to reset this
   # later.
   my $pos_in_log = $tell->();
   MKDEBUG && _d('Position in log:', $pos_in_log);

   # If there's something deferred then pos_in_log will be wrong, so we correct
   # for that.  Also, to prevent infinite loops, we set a variable that shows
   # whether we got anything from deferred.  If we later put something back
   # without first doing $next_event->(), then there's a problem.
   my $got_deferred;
   if ( defined($line = $self->deferred) ) {
      $pos_in_log -= length($line);
      $got_deferred = 1;
      MKDEBUG && _d('Got deferred line', $line);
   }

   # For infinite loop detection (see above).
   my $did_get_next;

   # Sometimes we need to accumulate some lines and then join them together.
   # This is used for that.
   my @arg_lines;

   # This is used to signal that an entire event has been found, and thus exit
   # the while loop.
   my $done;

   # This is used to signal that an event's duration has already been found.
   # See the sample file pg-syslog-001.txt and the test for it.
   my $got_duration;

   # Before we start, we read and discard lines until we get one with a header.
   # The only thing we can really count on is that a header line should have
   # the header in it.  But, we only do this if we aren't in the middle of an
   # ongoing event, whose first line was deferred.
   if ( !defined $line ) {
      while ( (defined($line = $next_event->())) && $line !~ m/$log_line_regex/o ) {
         $pos_in_log = $tell->();
         MKDEBUG && _d('Read line', $line);
      }
      MKDEBUG && _d('Found a header line, now at', $pos_in_log);
      # Here we do not need to set $did_get_next, because we'll never be here if
      # $got_deferred is 1.
   }

   # If we're at the end of the file, we finish and tell the caller we're done.
   if ( !defined $line ) {
      return $self->cleanup(%args);
   }

   # We need to keep the line that begins the event we're parsing.
   my $first_line;

   # This is for holding the type of the log line, which is important for
   # choosing the right code to run.
   my $line_type;

   # Parse each line.
   LINE:
   while ( !$done && defined $line ) {

      # This while loop works with LOG lines.  Other lines, such as ERROR and
      # so forth, need to be handled outside this loop.
      if ( (($line_type) = $line =~ m/$log_line_regex/o) && $line_type ne 'LOG' ) {
         MKDEBUG && _d('Found a non-LOG line, exiting loop');
         last LINE;
      }

      # The log isn't just queries.  It also has status and informational lines
      # in it.  We ignore these, but if we see one that's not recognized, we
      # warn.  These types of things are better off in mk-error-log.
      if (
         $line =~ m{
            Address\sfamily\snot\ssupported\sby\sprotocol
            |archived\stransaction\slog\sfile
            |autovacuum:\sprocessing\sdatabase
            |checkpoint\srecord\sis\sat
            |checkpoints\sare\soccurring\stoo\sfrequently\s\(
            |could\snot\sreceive\sdata\sfrom\sclient
            |database\ssystem\sis\sready
            |database\ssystem\sis\sshut\sdown
            |database\ssystem\swas\sshut\sdown
            |incomplete\sstartup\spacket
            |invalid\slength\sof\sstartup\spacket
            |next\sMultiXactId:
            |next\stransaction\sID:
            |received\ssmart\sshutdown\srequest
            |recycled\stransaction\slog\sfile
            |redo\srecord\sis\sat
            |removing\sfile\s"
            |removing\stransaction\slog\sfile\s"
            |shutting\sdown
            |transaction\sID\swrap\slimit\sis
         }x
      ) {
         # We get the next line to process and skip the rest of the loop.
         $line = $next_event->();
         $did_get_next = 1;
         MKDEBUG && _d('Got next line from $next_event->()');
         next LINE;
      }

      # Throw away the newline ending.
      chomp $line;
      MKDEBUG && _d('Line:', $line);

      # Possibly reset $first_line, depending on whether it was determined to be
      # junk and unset.
      $first_line ||= $line;

      # Case 2: non-header lines, optionally starting with a TAB, are a
      # continuation of the previous line.
      if ( $line !~ m/$log_line_regex/o && @arg_lines ) {

         # If this is a line from syslog, it might look like this:
         # 2008 Jan  9 16:16:34 hostname postgres[30059]: [13-2] ...sql query...
         # We have to delete that prefix.
         if ( $line =~ s/\A.*\w+\[\d+\]: \[\d+-\d+\] // ) {
            # We also have to translate characters that syslog has munged.  Some
            # translate TAB into the literal characters '^I' and some, rsyslog
            # on Debian anyway, seem to translate all whitespace control
            # characters into an octal string representing the character code.
            # Example: "#011FROM pg_catalog.pg_class c"
            $line =~ s/#(\d{3})/chr(oct($1))/ge;
            $line =~ s/\^I/\t/g;
         }
         else {
            # Weirdly, some logs (see samples/pg-log-005.txt) have newlines
            # without a leading tab.  Maybe it's an older log format.
            $line =~ s/\A(\S)/\t$1/;
         }

         # The TAB at the beginning of the line indicates that there's a newline
         # at the end of the previous line.
         $line =~ s/\A\t/\n/;

         # Save the remainder.
         push @arg_lines, $line;
         MKDEBUG && _d('This was a continuation line');
      }

      # Cases 1 and 3: These lines start with some optional meta-data, and then
      # the $log_line_regex followed by the line's log message.  The message can be
      # of the form "label: text....".  Examples:
      # LOG:  duration: 1.565 ms
      # LOG:  statement: SELECT ....
      # LOG:  duration: 1.565 ms  statement: SELECT ....
      # In the above examples, the $label is duration, statement, and duration.
      elsif (
         my ( $sev, $label, $rest )
            = $line =~ m/$log_line_regex(.+?):\s+(.*)\Z/o
      ) {
         MKDEBUG && _d('Line is case 1 or case 3');

         # This is either a case 1 or case 3.  If there's previously gathered
         # data in @arg_lines, it doesn't matter which -- we have to create an
         # event (a Query event), and we're $done.  This is case 0xdeadbeef.
         if ( @arg_lines ) {
            $done = 1;
            MKDEBUG && _d('There are saved @arg_lines, we are done');

            # We shouldn't modify @properties based on $line, because $line
            # doesn't have anything to do with the stuff in @properties, which
            # is all related to the previous line(s).  However, there is one
            # case in which the line could be part of the event: when it's a
            # plain 'duration' line.  This happens when the statement is logged
            # on one line, and then the duration is logged afterwards.  If this
            # is true, then we alter @properties, and we do NOT defer the current
            # line.
            if ( $label eq 'duration' && $rest =~ m/[0-9.]+\s+\S+\Z/ ) {
               if ( $got_duration ) {
                  # Just discard the line.
                  MKDEBUG && _d('Discarding line, duration already found');
               }
               else {
                  push @properties, 'Query_time', $self->duration_to_secs($rest);
                  MKDEBUG && _d("This line's duration applies to the event:", $rest);
               }
            }
            else {
               # Do infinite loop detection.
               if ( $got_deferred && !$did_get_next ) {
                  die "Infinite loop detected on line $line";
               }

               # We'll come back to this line later.
               $self->deferred($line);
               MKDEBUG && _d('Deferred line', $line);
            }
         }

         # Here we test for case 1, lines that can start a multi-line event.
         elsif ( $label =~ m/\A(?:duration|statement|query)\Z/ ) {
            MKDEBUG && _d('Case 1: start a multi-line event');

            # If it's a duration, then there might be a statement later on the
            # same line and the duration applies to that.
            if ( $label eq 'duration' ) {

               if (
                  (my ($dur, $stmt)
                     = $rest =~ m/([0-9.]+ \S+)\s+(?:statement|query):\s*(.*)/)
               ) {
                  # It does, so we'll pull out the Query_time etc now, rather
                  # than doing it later, when we might end up in the case above
                  # (case 0xdeadbeef).
                  push @properties, 'Query_time', $self->duration_to_secs($dur);
                  $got_duration = 1;
                  push @arg_lines, $stmt;
                  MKDEBUG && _d('Duration + statement');
               }

               else {
                  # The duration line is just junk.  It's the line after a
                  # statement, but we never saw the statement (else we'd have
                  # fallen into 0xdeadbeef above).  Discard this line and adjust
                  # pos_in_log.
                  $pos_in_log = $tell->();
                  $first_line = undef;
                  MKDEBUG && _d('Line applies to event we never saw, discarding');
               }
            }
            else {
               # This isn't a duration line, it's a statement or query.  Put it
               # onto @arg_lines for later and keep going.
               push @arg_lines, $rest;
               MKDEBUG && _d('Putting onto @arg_lines');
            }
         }

         # Here is case 3, lines that can't be in case 1 or 2.  These surely
         # terminate any event that's been accumulated, and if there isn't any
         # such, then we just create an event without the overhead of deferring.
         else {
            $done = 1;
            MKDEBUG && _d('Line is case 3, event is done');

            # Again, if there's previously gathered data in @arg_lines, we have
            # to defer the current line (not touching @properties) and revisit it.
            if ( @arg_lines ) {
               # Do infinite loop detection.
               if ( $got_deferred && !$did_get_next ) {
                  die "Infinite loop detected on line $line";
               }

               $self->deferred($line);
               MKDEBUG && _d('There was @arg_lines, deferred line');
            }

            # Otherwise we can parse the line and put it into @properties.
            else {
               MKDEBUG && _d('No need to defer, process event from this line now');
               push @properties, 'cmd', 'Admin', 'arg', $label;

               # For some kinds of log lines, we can grab extra meta-data out of
               # the end of the line.
               # LOG:  connection received: host=[local]
               if ( $label =~ m/\A(?:dis)?connection(?: received| authorized)?\Z/ ) {
                  push @properties, $self->get_meta($rest);
               }

               else {
                  die "I don't understand line $line";
               }

            }
         }

      }

      # If the line isn't case 1, 2, or 3 I don't know what it is.
      else {
         die "I don't understand line $line";
      }

      # We get the next line to process.
      if ( !$done ) {
         $line = $next_event->();
         $did_get_next = 1;
         MKDEBUG && _d('Got next line from $next_event->()');
      }
   } # LINE

   # If we're at the end of the file, there's no point in continuing.
   if ( !defined $line ) {
      $self->cleanup(%args);
   }

   # If we got kicked out of the while loop because of a non-LOG line, we handle
   # that line here.
   if ( $line_type && $line_type ne 'LOG' ) {
      if ( $line_type eq 'ERROR' ) {
         # Add the error message to the event.
         push @properties, 'Error_msg', $line =~ m/ERROR:\s*(\S.*)/;
      }
      else {
         MKDEBUG && _d("Unknown line", $line);
      }
   }

   # If $done is true, then some of the above code decided that the full
   # event has been found.  If we reached the end of the file, then we might
   # also have something in @arg_lines, although we didn't find the "line after"
   # that signals the event was done.  In either case we return an event.  This
   # should be the only 'return' statement in this block of code.
   if ( $done || @arg_lines ) {
      MKDEBUG && _d('Making event');

      # Finish building the event.
      push @properties, 'pos_in_log', $pos_in_log;

      # Statement/query lines will be in @arg_lines.
      if ( @arg_lines ) {
         MKDEBUG && _d('Assembling @arg_lines: ', scalar @arg_lines);
         push @properties, 'arg', join('', @arg_lines), 'cmd', 'Query';
      }

      if ( $first_line ) {
         # Handle some meta-data: a timestamp, with optional milliseconds.
         if ( my ($ts) = $first_line =~ m/([0-9-]{10} [0-9:.]{8,12})/ ) {
            MKDEBUG && _d('Getting timestamp', $ts);
            push @properties, 'ts', $ts;
         }

         # Find meta-data embedded in the log line prefix, in name=value format.
         if ( my ($meta) = $first_line =~ m/(.*?)[A-Z]{3,}:  / ) {
            MKDEBUG && _d('Found a meta-data chunk:', $meta);
            push @properties, $self->get_meta($meta);
         }
      }

      # Dump info about what we've found, but don't dump $event; want to see
      # full dump of all properties, and after it's been cast into a hash,
      # duplicated keys will be gone.
      MKDEBUG && _d('Properties of event:', Dumper(\@properties));
      my $event = { @properties };
      $event->{bytes} = length($event->{arg} || '');
      return $event;
   }

}

# Parses key=value meta-data from the $meta string, and returns a list of event
# attribute names and values.
sub get_meta {
   my ( $self, $meta ) = @_;
   my @properties;
   foreach my $set ( $meta =~ m/(\w+=[^, ]+)/g ) {
      my ($key, $val) = split(/=/, $set);
      if ( $key && $val ) {
         if ( my $prop = $llp_for{lc substr($key, 0, 1)} ) {
            # The first letter of the name, lowercased, determines the
            # meaning of the item.
            push @properties, $prop, $val;
         }
         else {
            MKDEBUG && _d('Bad meta key', $set);
         }
      }
      else {
         MKDEBUG && _d("Can't figure out meta from", $set);
      }
   }
   return @properties;
}

# This subroutine defers and retrieves a line of text.  If you give it an
# argument it'll set the stored line.  If not, it'll return it and delete it.
sub deferred {
   my ( $self, $val ) = @_;
   if ( $val ) {
      $self->{deferred} = $val;
   }
   else {
      $val = $self->{deferred};
      $self->{deferred} = undef;
   }
   return $val;
}

# This subroutine converts various formats to seconds.  Examples:
# 10.870 ms
sub duration_to_secs {
   my ( $self, $str ) = @_;
   MKDEBUG && _d('Duration:', $str);
   my ( $num, $suf ) = split(/\s+/, $str);
   my $factor = $suf eq 'ms'  ? 1000
              : $suf eq 'sec' ? 1
              :                 die("Unknown suffix '$suf'");
   return $num / $factor;
}

# If we can't read any more lines, tell the calling scope to quit running.
# Also discard any deferred line, because this instance of the class
# might be used to parse another log file next, and we don't want things
# hanging around from this log file when we do that.
sub cleanup {
   my ($self, %args) = @_;
   MKDEBUG && _d('All done with file, resetting stored state');
   $self->deferred;
   $args{oktorun}->(0) if $args{oktorun};
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
# End PgLogParser package
# ###########################################################################
