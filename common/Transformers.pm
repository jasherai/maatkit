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
# ###########################################################################
# Transformers package $Revision$
# ###########################################################################

# Transformers - Common transformation and beautification subroutines
package Transformers;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

require Exporter;
our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ();
our @EXPORT      = ();
our @EXPORT_OK   = qw(float_6 micro_t secs_to_time shorten ts);

sub float_6 {
   my ( $val ) = @_;
   return sprintf('%.6f', $val);
}

sub micro_t {
   my ( $t ) = @_;
   my $f;

   $t = 0 if $t < 0;

   # "Remove" scientific notation so the regex below does not make
   # 6.123456e+18 into 6.123456.
   $t = sprintf('%.17f', $t) if $t =~ /e/;

   # Truncate after 6 decimal places to avoid 0.9999997 becoming 1
   # because sprintf() rounds.
   $t =~ s/\.(\d{1,6})\d*/\.$1/;

   if ($t > 0 && $t <= 0.000999) {
      $f = ($t * 1000000) . ' us';
   }
   elsif ($t >= 0.001000 && $t <= 0.999999) {
      $f = sprintf('%.3f', $t * 1000);
      $f = ($f * 1) . ' ms'; # * 1 to remove insignificant zeros
   }
   elsif ($t >= 1) {
      $f = sprintf('%.6f', $t);
      $f = ($f * 1) . ' s'; # * 1 to remove insignificant zeros
   }
   else {
      $f = 0;  # $t should = 0 at this point
   }

   return $f;
}

sub secs_to_time {
   my ( $secs, $fmt ) = @_;
   $secs ||= 0;
   return '00:00' unless $secs;

   # Decide what format to use, if not given
   $fmt ||= $secs >= 86_400 ? 'd'
          : $secs >= 3_600  ? 'h'
          :                   'm';

   return
      $fmt eq 'd' ? sprintf(
         "%d+%02d:%02d:%02d",
         int($secs / 86_400),
         int(($secs % 86_400) / 3_600),
         int(($secs % 3_600) / 60),
         $secs % 60)
      : $fmt eq 'h' ? sprintf(
         "%02d:%02d:%02d",
         int(($secs % 86_400) / 3_600),
         int(($secs % 3_600) / 60),
         $secs % 60)
      : sprintf(
         "%02d:%02d",
         int(($secs % 3_600) / 60),
         $secs % 60);
}

sub shorten {
   my ( $num ) = @_;
   my $n = 0;
   while ( $num >= 1_024 ) {
      $num /= 1_024;
      ++$n;
   }
   return sprintf(
      $num =~ m/\./ || $n
         ? "%.2f%s"
         : '%d',
      $num, ('','k','M','G', 'T')[$n]);
}

sub ts {
   my ( $time ) = @_;
   my ( $sec, $min, $hour, $mday, $mon, $year )
      = localtime($time);
   $mon  += 1;
   $year += 1900;
   return sprintf("%d-%02d-%02dT%02d:%02d:%02d",
      $year, $mon, $mday, $hour, $min, $sec);
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# Transformers:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End Transformers package
# ###########################################################################
