# This program is copyright 2008-2009 Baron Schwartz.
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
# Loadavg package $Revision$
# ###########################################################################
package Loadavg;

use strict;
use warnings FATAL => 'all';

use List::Util qw(sum);
use Time::HiRes qw(time);
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

sub new {
   my ( $class ) = @_;
   return bless {}, $class;
}

# Calculates average query time by the Trevor Price method.
sub trevorprice {
   my ( $self, $dbh, %args ) = @_;
   die "I need a dbh argument" unless $dbh;
   my $num_samples = $args{samples} || 100;
   my $num_running = 0;
   my $start = time();
   my (undef, $status1)
      = $dbh->selectrow_array('SHOW /*!50002 GLOBAL*/ STATUS LIKE "Questions"');
   for ( 1 .. $num_samples ) {
      my $pl = $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} });
      my $running = grep { ($_->{Command} || '') eq 'Query' } @$pl;
      $num_running += $running - 1;
   }
   my $time = time() - $start;
   return 0 unless $time;
   my (undef, $status2)
      = $dbh->selectrow_array('SHOW /*!50002 GLOBAL*/ STATUS LIKE "Questions"');
   my $qps = ($status2 - $status1) / $time;
   return 0 unless $qps;
   return ($num_running / $num_samples) / $qps;
}

# Calculates number of locked queries in the processlist.
sub num_locked {
   my ( $self, $dbh ) = @_;
   die "I need a dbh argument" unless $dbh;
   my $pl = $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} });
   my $locked = grep { ($_->{State} || '') eq 'Locked' } @$pl;
   return $locked || 0;
}

# Calculates loadavg from the uptime command.
sub loadavg {
   my ( $self ) = @_;
   my $str = `uptime`;
   chomp $str;
   return 0 unless $str;
   my ( $one ) = $str =~ m/load average:\s+(\S[^,]*),/;
   return $one || 0;
}

# Calculates slave lag.  If the slave is not running, returns 0.
sub slave_lag {
   my ( $self, $dbh ) = @_;
   die "I need a dbh argument" unless $dbh;
   my $sl = $dbh->selectall_arrayref('SHOW SLAVE STATUS', { Slice => {} });
   if ( $sl ) {
      $sl = $sl->[0];
      my ( $key ) = grep { m/behind_master/i } keys %$sl;
      return $key ? $sl->{$key} || 0 : 0;
   }
   return 0;
}

# Calculates any metric from SHOW STATUS, either absolute or over a 1-second
# interval.
sub status {
   my ( $self, $dbh, %args ) = @_;
   die "I need a dbh argument" unless $dbh;
   my (undef, $status1)
      = $dbh->selectrow_array("SHOW /*!50002 GLOBAL*/ STATUS LIKE '$args{metric}'");
   if ( $args{incstatus} ) {
      sleep(1);
      my (undef, $status2)
         = $dbh->selectrow_array("SHOW /*!50002 GLOBAL*/ STATUS LIKE '$args{metric}'");
      return $status2 - $status1;
   }
   else {
      return $status1;
   }
}

# Returns the highest value for a given section and var, like transactions
# and lock_wait_time.
sub innodb {
   my ( $self, $dbh, %args ) = @_;
   die "I need a dbh argument" unless $dbh;
   foreach my $arg ( qw(InnoDBStatusParser section var) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $is      = $args{InnoDBStatusParser};
   my $section = $args{section};
   my $var     = $args{var};

   # Get and parse SHOW INNODB STATUS text.
   my @status_text = $dbh->selectrow_array("SHOW /*!40100 ENGINE*/ INNODB STATUS");
   if ( !$status_text[0] || !$status_text[2] ) {
      MKDEBUG && _d('SHOW ENGINE INNODB STATUS failed');
      return 0;
   }
   my $idb_stats = $is->parse($status_text[2] ? $status_text[2] : $status_text[0]);

   if ( !exists $idb_stats->{$section} ) {
      MKDEBUG && _d('idb status section', $section, 'does not exist');
      return 0;
   }

   # Each section should be an arrayref.  Go through each set of vars
   # and find the highest var that we're checking.
   my $value = 0;
   foreach my $vars ( @{$idb_stats->{$section}} ) {
      MKDEBUG && _d($var, '=', $vars->{$var});
      $value = $vars->{$var} && $vars->{$var} > $value ? $vars->{$var} : $value;
   }

   MKDEBUG && _d('Highest', $var, '=', $value);
   return $value;
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
# End Loadavg package
# ###########################################################################
