# This program is copyright 2008-@CURRENTYEAR@ Percona Inc.
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

# #############################################################################
# LogType package $Revision$
# #############################################################################
package LogType;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG          => $ENV{MKDEBUG};
use constant LOG_TYPE_UNKNOWN => 0;
use constant LOG_TYPE_SLOW    => 1;
use constant LOG_TYPE_GENERAL => 2;
use constant LOG_TYPE_BINARY  => 3;
# Make sure the constants above and the line below are kept in sync.
my @log_type_names = ( qw(unknown slow general binary) );

my %patterns_for = (
   LogType::LOG_TYPE_SLOW    => [
      qr/^# User\@Host:/,
   ],
   LogType::LOG_TYPE_GENERAL => [
      qr/^\d{6}\s+\d\d:\d\d:\d\d/,
      qr/^\s+\d+\s+[A-Z][a-z]+\s+/,
   ],
   LogType::LOG_TYPE_BINARY  => [
      qr/^.*?server id \d+\s+end_log_pos/,
   ],
);

sub new {
   my ( $class, %args ) = @_;
   my %default_args = (
      sample_size     => 10, # number of lines to read for the log sample
      detection_order => [   # preferred order in which to detect log types
         LOG_TYPE_SLOW,
         LOG_TYPE_GENERAL,
         LOG_TYPE_BINARY,
      ],
   );
   my $self = { %default_args, %args };
   return bless $self, $class;
}

sub get_log_type {
   my ( $self, $log_file ) = @_;
   $log_file ||= '';
   MKDEBUG && _d("Detecting log type for $log_file");
   return LOG_TYPE_UNKNOWN if !$log_file;
   
   my $log_fh;
   if ( !open $log_fh, '<', $log_file ) {
      MKDEBUG && _d("Failed to open $log_file: $OS_ERROR");
      return LOG_TYPE_UNKNOWN;
   }

   my @lines   = ();
   my $n_lines = 0;
   while ( ($n_lines++ < $self->{sample_size}) && (my $line = <$log_fh>) ) {
      push @lines, $line;
   }
   close $log_fh;

   foreach my $log_type ( @{ $self->{detection_order} } ) {
      if ( $self->lines_match_log_type(\@lines, $log_type) ) {
         MKDEBUG && _d("Log is type $log_type");
         return $log_type;
      }
   }

   MKDEBUG && _d("Log type is unknown");
   return LOG_TYPE_UNKNOWN;
}

sub lines_match_log_type {
   my ( $self, $lines, $log_type ) = @_;
   return 0 if ( !ref $lines || scalar @$lines == 0 );
   foreach my $pattern ( @{ $patterns_for{$log_type} } ) {
      foreach my $line  ( @$lines ) {
         if ( $line =~ m/$pattern/ ) {
            MKDEBUG && _d("Log type $log_type pattern $pattern matches $line");
            return 1;
         }
      }
   }
   return 0;
}

sub name_for {
   return $log_type_names[$_[1]];
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# LogType:$line $PID ", @_, "\n";
}

1;
# #############################################################################
# End LogType package
# #############################################################################
