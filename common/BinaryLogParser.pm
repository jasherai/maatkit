# This program is copyright 2007-2009 Baron Schwartz.
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
# BinaryLogParser package $Revision$
# ###########################################################################
package BinaryLogParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   return bless {}, $class;
}

my $binlog_line_1 = qr{^# at (\d+)}m;
my $binlog_line_2 = qr/^#(\d{6}\s+\d{1,2}:\d\d:\d\d)\s+server\s+id\s+(\d+)\s+end_log_pos\s+(\d+)\s+(\S+)\s*([^\n]*)$/m;
my $binlog_line_2_rest = qr{Query\s+thread_id=(\d+)\s+exec_time=(\d+)\s+error_code=(\d+)}m;

# This method accepts an open filehandle and a callback function.  It reads
# events from the filehandle and calls the callback with each event.
sub parse_event {
   my ( $self, $fh, $misc, @callbacks ) = @_;
   my $event;
   my $num_events = 0;
   my $term  = $self->{term} || ";\n"; # Corresponds to DELIMITER
   my $tpat  = quotemeta $term;
   local $RS = $term;
   my $line  = <$fh>;

   LINE: {
      return unless $line;

      # Catch changes in DELIMITER
      if ( $line =~ m/^DELIMITER/m ) {
         my($del)      = $line =~ m/^DELIMITER ([^\n]+)/m;
         $self->{term} = $del;
         local $RS     = $del;
         $line         = <$fh>; # Throw away DELIMITER line
         MKDEBUG && _d('New record separator:', $del);
         redo LINE;
      }

      # Throw away the delimiter
      $line =~ s/$tpat\Z//;

      # Match the beginning of an event in the binary log.
      if ( my ( $offset ) = $line =~ m/$binlog_line_1/m ) {
         $self->{last_line} = undef;
         $event = {
            offset => $offset,
         };
         my ( $ts, $sid, $end, $type, $rest ) = $line =~ m/$binlog_line_2/m;
         @{$event}{qw(ts server_id end type)} = ($ts, $sid, $end, $type);
         (my $arg = $line) =~ s/\n*^#.*\n//gm; # Remove comment lines
         $event->{arg} = $arg;
         if ( $type eq 'Xid' ) {
            my ($xid) = $rest =~ m/(\d+)/;
            $event->{xid} = $xid;
         }
         elsif ( $type eq 'Query' ) {
            @{$event}{qw(id time code)} = $rest =~ m/$binlog_line_2_rest/;
         }
         else {
            die "Unknown event type $type"
               unless $type =~ m/Rotate|Start|Execute_load_query|Append_block|Begin_load_query|Rand|User_var|Intvar/;
         }
      }
      else {
         $event = {
            arg => $line,
         };
      }
   }

   # If it was EOF, discard the terminator so statefulness doesn't
   # interfere with the next log file.
   if ( !defined $line ) {
      delete $self->{term};
   }

   foreach my $callback ( @callbacks ) {
      last unless $event = $callback->($event);
   }
   ++$num_events;

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
# End BinaryLogParser package
# ###########################################################################
