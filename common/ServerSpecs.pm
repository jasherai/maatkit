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
# ServerSpecs package $Revision$
# ###########################################################################

# ServerSpecs - Gather info on server hardware and configuration
package ServerSpecs;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub server_specs {
   my %server;

   @{ $server{problems} } = ();

   $server{os}->{name} = $OSNAME;
   $server{os}->{'64bit'} = `file /bin/ls` =~ m/64-bit/ ? 'Yes' : 'No';

   if ( chomp(my $rel = `cat /etc/*release`) ) {
      if ( my ($desc) = $rel =~ m/DISTRIB_DESCRIPTION="(.*)"/ ) {
         $server{os}->{version} = $desc;
      }
      else {
         $server{os}->{version} = $rel;
      }
   }

   if ( -f '/lib/libc.so.6' ) {
      my $stuff = `/lib/libc.so.6`;
      ($server{sw}->{libc}->{ver}) = $stuff =~ m/GNU C.*release version (.+), /;
      $server{sw}->{libc}->{threading}
         = $stuff =~ m/Native POSIX/    ? 'NPTL'
         : $stuff =~ m/linuxthreads-\d/ ? 'Linuxthreads'
         :                                'Unknown';
      ($server{sw}->{libc}->{compiled_by}) = $stuff =~ m/Compiled by (.*)/;
      $server{sw}->{libc}->{GNU_LIBPTHREAD_VERSION} = do {
         my $ver = `getconf GNU_LIBPTHREAD_VERSION`;
         chomp $ver;
         $ver;
      };
   }

   if ( -f '/proc/cpuinfo' ) {
      my $info = `cat /proc/cpuinfo`;
      my $cores = scalar( map { $_ } $info =~ m/(^processor)/gm );
      $server{cpu}->{cores} = $cores;
      $server{cpu}->{count}
         = `grep 'physical id' /proc/cpuinfo | sort | uniq | wc -l`;
      ($server{cpu}->{speed})
         = join(' ', 'MHz:', $info =~ m/cpu MHz.*: (\d+)/g);
      ($server{cpu}->{cache}) = $info =~ m/cache size.*: (.+)/;
      ($server{cpu}->{model}) = $info =~ m/model name.*: (.+)/;
      ($server{cpu}->{'64bit'}) = $info =~ m/flags.*\blm\b/ ? 'Yes' : 'No';
   }
   else {
      # MSWin32, maybe?
      $server{cpu}->{count} = $ENV{NUMBER_OF_PROCESSORS};
   }

   # This requires root access
   @{$server{memory}->{slots}} = ();
   if ( chomp(my $dmi = `dmidecode`) ) {
      my @keys = ( 'Size', 'Form Factor', 'Type', 'Type Detail', 'Speed');
      my @mem_info = $dmi =~ m/^(Memory Device\n.*?)\n\n/gsm;
      foreach my $mem ( @mem_info ) {
         my %stuff = map { split /: / } $mem =~ m/^\s+(\S.*:.*)$/gm;
         push(@{$server{memory}->{slots}}, join(' ', grep { $_ } @stuff{@keys}));
      }
   }

   if ( chomp(my $mem = `free -b`) ) {
      my @words = $mem =~ m/(\w+)/g;
      my @keys;
      while ( my $key = shift @words ) {
         last if $key eq 'Mem';
         push @keys, $key;
      }
      foreach my $key ( @keys ) {
         $server{memory}->{$key} = shorten(shift @words);
      }
   }

   if ( chomp(my $df = `df -hT` ) ) {
      $df = "\n\t" . join("\n\t",
         grep { $_ !~ m/^(varrun|varlock|udev|devshm|lrm)/ }
         split(/\n/, $df));
      $server{storage}->{df} = $df;
   }

   # LVM
   if ( -f '/sbin/vgs' ) {
      chomp(my $vgs = `vgs`);
      $vgs =~ s/^\s*/\t/g;
      $server{storage}->{vgs} = $vgs;
   }
   else {
      $server{storage}->{vgs} = 'No LVM2';
   }

   get_raid_info(\%server);

   chomp($server{os}->{swappiness} = `cat /proc/sys/vm/swappiness`);
   push @{ $server{problems} },
      "*** Server swappiness != 60; is currently: $server{os}->{swappiness}"
      if $server{os}->{swappiness} != 60;

   check_proc_sys_net_ipv4_values(\%server);

   return \%server;
}

sub get_raid_info
{
   my ( $server ) = @_;

   if ( chomp(my $dmesg = `dmesg`) ) {
      my ($raid) = $dmesg =~ m/(Direct-Access\s+MegaRaid.*$)/m;
      $server->{storage}->{raid} = $raid ? $raid : 'unknown';
   }

   # Try several possible cmds to get raid status
   # TODO: MegaCli may exist on a 64-bit machine, we should choose the correct
   # one based on 64-bitness of the OS.
   my $megarc = `which megarc && megarc -AllAdpInfo -aALL`;
   if ( $megarc ) {
      if ( $megarc =~ /No MegaRAID Found/i ) {
         if ( -f '/opt/MegaRAID/MegaCli/MegaCli' ) {
            $megarc  = `/opt/MegaRAID/MegaCli/MegaCli -AdpAllInfo -aALL`;
            $megarc .= `/opt/MegaRAID/MegaCli/MegaCli -AdpBbuCmd -GetBbuStatus -aALL`;
         }
         elsif ( -f '/opt/MegaRAID/MegaCli/MegaCli64' ) {
            $megarc  = `/opt/MegaRAID/MegaCli/MegaCli64 -AdpAllInfo -aALL`;
            $megarc .= `/opt/MegaRAID/MegaCli/MegaCli64 -AdpBbuCmd -GetBbuStatus -aALL`;
         }
         else {
            $megarc = '';
         }
      }
      else {
         $megarc .= `megarc -AdpBbuCmd -GetBbuStatus -aALL`;
      }
   }

   # Parse raid status if available
   if( $megarc ) {
      $server->{storage}->{megarc}
         .= ($megarc =~ /^(Product Name.*\n)/m ? $1 : '');
      $server->{storage}->{megarc}
         .= ($megarc =~ /^(BBU.*\n)/m ? $1 : '');
      $server->{storage}->{megarc}
         .= ($megarc =~ /^(Battery Warning.*\n)/m ? $1 : '');
      $server->{storage}->{megarc}
         .= ($megarc =~ /^(Alarm.*\n)/m ? $1 : '');
      $server->{storage}->{megarc}
         .= ($megarc =~ /(Device Present.*?\n)\s+Supported/ms ? $1 : '');
      $server->{storage}->{megarc}
         .= ($megarc =~ /(Battery state.*?\n)isSOHGood/ms ? $1 : '');
   }
   else {
      if ( $server->{storage}->{raid} ne 'unknown' ) {
         $server->{storage}->{megarc}
            .= "\n*** RAID present but unable to check its status";
      }
      else {
         $server->{storage}->{megarc} = '';
      }
   }

   return;
}

sub check_proc_sys_net_ipv4_values
{
   my ( $server ) = @_;

   my %ipv4_defaults = qw(
      ip_forward                       0
      ip_default_ttl                   64
      ip_no_pmtu_disc                  0
      min_pmtu                         562
      ipfrag_secret_interval           600
      ipfrag_max_dist                  64
      somaxconn                        128
      tcp_abc                          0
      tcp_abort_on_overflow            0
      tcp_adv_win_scale                2
      tcp_allowed_congestion_control   reno
      tcp_app_win                      31
      tcp_fin_timeout                  60
      tcp_frto_response                0
      tcp_keepalive_time               7200
      tcp_keepalive_probes             9
      tcp_keepalive_intvl              75
      tcp_low_latency                  0
      tcp_max_syn_backlog              1024
      tcp_moderate_rcvbuf              1
      tcp_reordering                   3
      tcp_retries1                     3
      tcp_retries2                     15
      tcp_rfc1337                      0
      tcp_rmem                         8192_87380_174760
      tcp_slow_start_after_idle        1
      tcp_stdurg                       0
      tcp_synack_retries               5
      tcp_syncookies                   0
      tcp_syn_retries                  5
      tcp_tso_win_divisor              3
      tcp_tw_recycle                   0
      tcp_tw_reuse                     0
      tcp_wmem                         4096_16384_131072
      tcp_workaround_signed_windows    0
      tcp_dma_copybreak                4096
      ip_nonlocal_bind                 0
      ip_dynaddr                       0
      icmp_echo_ignore_all             0
      icmp_echo_ignore_broadcasts      1
      icmp_ratelimit                   100
      icmp_ratemask                    6168
      icmp_errors_use_inbound_ifaddr   0
      igmp_max_memberships             20
      icmp_ignore_bogus_error_responses 0
   );

   $server->{os}->{non_default_ipv4_vals} = '';
   if ( chomp(my $ipv4_files = `ls -1p /proc/sys/net/ipv4/`) ) {
      foreach my $ipv4_file ( split "\n", $ipv4_files ) {
         next if !exists $ipv4_defaults{$ipv4_file};
         chomp(my $val = `cat /proc/sys/net/ipv4/$ipv4_file`);
         $val =~ s/\s+/_/g;
         if ( $ipv4_defaults{$ipv4_file} ne $val ) {
            push @{ $server->{problems} },
               "Not default value /proc/sys/net/ipv4/$ipv4_file\:\n" .
               "\t\tset=$val\n\t\tdefault=$ipv4_defaults{$ipv4_file}";
         }
      }
   }

   return;
}

sub shorten
{
   my ( $number, $kb, $d ) = @_;
   my $n = 0;
   my $short;

   $kb ||= 1;
   $d  ||= 2;

   if ( $kb ) {
      while ( $number > 1_023 ) { $number /= 1_024; $n++; }
   }
   else {
      while ($number > 999) { $number /= 1000; $n++; }
   }
   $short = sprintf "%.${d}f%s", $number, ('','k','M','G','T')[$n];
   return $1 if $short =~ /^(.+)\.(00)$/o; # 12.00 -> 12 but not 12.00k -> 12k
   return $short;
}

1;

# ###########################################################################
# End ServerSpecs package
# ###########################################################################
