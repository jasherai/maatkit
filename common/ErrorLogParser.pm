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
# ErrorLogParser package $Revision$
# ###########################################################################
package ErrorLogParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

my $ts = qr/(\d{6}\s{1,2}[\d:]+)\s*/;
my $ml = qr{\A(?:
   InnoDB:\s
   |-\smysqld\sgot\ssignal
   |Status\sinformation
   |Memory\sstatus
)}x;

sub new {
   my ( $class, %args ) = @_;
   my $self = {
      %args,
      pending => [],
   };
   return bless $self, $class;
}

sub parse_event {
   my ( $self, %args ) = @_;
   my @required_args = qw(fh);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($fh) = @args{@required_args};

   my $pending = $self->{pending};

   my $pos_in_log = tell($fh);
   my $line;
   EVENT:
   while ( defined($line = shift @$pending) or defined($line = <$fh>) ) {
      next if $line =~ m/^\s*$/;  # lots of blank lines in error logs
      chomp $line;
      my @properties = ('pos_in_log', $pos_in_log);
      $pos_in_log = tell($fh);

      # timestamp
      if ( my ($ts) = $line =~ /^$ts/o ) {
         MKDEBUG && _d('Got ts:', $ts);
         push @properties, 'ts', $ts;
         $line =~ s/^$ts//;
      }

      # Level: error, warning, info or unknown
      my $level;
      if ( ($level) = $line =~ /\[((?:ERROR|Warning|Note))\]/ ) {
         $level = $level =~ m/error/i   ? 'error'
                : $level =~ m/warning/i ? 'warning'
                :                         'info';
      }
      else {
         $level = 'unknown';
      }
      MKDEBUG && _d('Level:', $level);
      push @properties, 'Level', $level;

      # A special case error
      if ( my ($level) = $line =~ /InnoDB: Error/ ) {
         MKDEBUG && _d('Got serious InnoDB error');
         push @properties, 'Level', 'error';
      }

      # Collapse whitespace after removing stuff above.
      $line =~ s/^\s+//;
      $line =~ s/\s{2,}/ /;
      $line =~ s/\s+$//;

      # Handle multi-line error messagess.  There are several types: debug
      # messages from 'mysqladmin debug', crash and stack trace, and InnoDB.
      # InnoDB prints multi-line messages like:
      #   080821 19:14:12  InnoDB: Database was not shut down normally!
      #   InnoDB: Starting crash recovery.
      # We strip off the InnoDB: prefix after the first line, and keep going
      # until we find a line that begins a new message.

      if ( $line =~ m/$ml/o ) {
         MKDEBUG && _d('Multi-line message:', $line);
         $line =~ s/- //; # Trim "- msyqld got signal" special case.
         my $next_line;
         while ( defined($next_line = <$fh>)
                 && $next_line !~ m/^$ts/o ) {
            chomp $next_line;
            next if $next_line eq '';
            $next_line =~ s/^InnoDB: //; # InnoDB special-case.
            $line     .= " " . $next_line;
         }
         MKDEBUG && _d('Pending next line:', $next_line);
         push @$pending, $next_line;
      }
      # Multi-line query for errors like "[ERROR] Slave SQL: Error ... Query:"
      elsif ( $line =~ m/\bQuery: '/ ) {
         MKDEBUG && _d('Error query:', $line);
         my $next_line;
         my $last_line = 0;
         while ( !$last_line && defined($next_line = <$fh>) ) {
            chomp $next_line;
            MKDEBUG && _d('Error query:', $next_line);
            $line     .= $next_line;
            $last_line = 1 if $next_line =~ m/, Error_code:/;
         }
      }
		# Multi-line query to fix issue 921, innodb error message: [ERROR] Cannot find table
      elsif ( $line =~ m/\bCannot find table/) {
         MKDEBUG && _d('Special Multiline message:', $line);
         my $next_line;
         my $last_line = 0;
         while ( !$last_line && defined($next_line = <$fh>) ) {
            chomp $next_line;
            MKDEBUG && _d('Pending next line:', $next_line);
				$line     .= ' ';
            $line     .= $next_line;
            $last_line = 1 if $next_line =~ m/\bhow you can resolve the problem/;	      
         }
      }

      # Save the error line.
      chomp $line;
      push @properties, 'arg', $line;

      # Don't dump $event; want to see full dump of all properties, and after
      # it's been cast into a hash, duplicated keys will be gone.
      MKDEBUG && _d('Properties of event:', Dumper(\@properties));
      my $event = { @properties };
      return $event;

   } # EVENT

   @$pending = ();
   $args{oktorun}->(0) if $args{oktorun};
   return;
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
# End ErrorLogParser package
# ###########################################################################
