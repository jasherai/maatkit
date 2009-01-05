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
   # TODO: ought to go into some common library of utility funcs...
   $server{os}->{regsize} = `file /bin/ls` =~ m/64-bit/ ? '64' : '32';

   $server{os}->{version} = _os_version();

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
      $server{cpu}->{regsize} = $info =~ m/flags.*\blm\b/ ? '64' : '32';
   }
   else {
      # MSWin32, maybe?
      $server{cpu}->{count} = $ENV{NUMBER_OF_PROCESSORS};
   }

   # This requires root access. If it can't run (non-root), there simply
   # won't be any memory slot info reported.
   @{$server{memory}->{slots}} = _memory_slots();

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
   chomp(my $vgs_cmd = `which vgs`);
   if ( -f $vgs_cmd ) {
      chomp(my $vgs_output = `$vgs_cmd`);
      $vgs_output =~ s/^\s*/\t/g;
      $server{storage}->{vgs} = $vgs_output;
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

   $server->{storage}->{raid} = {};
   if ( chomp(my $dmesg = `dmesg | grep '^scsi[0-9]'`) ) {
      if (my ($raid) = $dmesg =~ m/: (.*MegaRaid)/mi) {
         $server->{storage}->{raid}{$raid} = _get_raid_info_megarc();
      }
      if (my ($raid) = $dmesg =~ m/: (aacraid)/m) {
         $server->{storage}->{raid}{$raid} = _get_raid_info_arcconf();
      }
      if (my ($raid) = $dmesg =~ m/: (3ware [0-9]+ Storage Controller)/m) {
         $server->{storage}->{raid}{$raid} = _get_raid_info_tw_cli();
      }
   }
}

sub _get_raid_info_megarc
{
   my $result = '';
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

   if ( $megarc ) {
      $result .= ($megarc =~ /^(Product Name.*\n)/m ? $1 : '');
      $result .= ($megarc =~ /^(BBU.*\n)/m ? $1 : '');
      $result .= ($megarc =~ /^(Battery Warning.*\n)/m ? $1 : '');
      $result .= ($megarc =~ /^(Alarm.*\n)/m ? $1 : '');
      $result .= ($megarc =~ /(Device Present.*?\n)\s+Supported/ms ? $1 : '');
      $result .= ($megarc =~ /(Battery state.*?\n)isSOHGood/ms ? $1 : '');
      $result =~ s/^/   /mg;
   }
   else {
      $result .= "\n*** MegaRAID present but unable to check its status";
   }

   return $result;
}

sub _get_raid_info_arcconf
{
   my $result = '';
   my $arcconf;
   if (-x '/usr/StorMan/arcconf') {
      $arcconf = `/usr/StorMan/arcconf GETCONFIG 1`;
   }
   else {
      $arcconf = `which arcconf && arcconf GETCONFIG 1`;
   }
   if ( $arcconf ) {
      $result .= ($arcconf =~ /^(\s*Controller Model.*\n)/m ? $1 : '');
      $result .= ($arcconf =~ /^(\s*Controller Status.*\n)/m ? $1 : '');
      $result .= ($arcconf =~ /^(\s*Installed memory.*\n)/m ? $1 : '');
      $result .= ($arcconf =~ /^(\s*Temperature.*\n)/m ? $1 : '');
      $result .= ($arcconf =~ /^(\s*Defunct disk drive count.*\n)/m ? $1 : '');
      $result .= ($arcconf =~ /^(\s*Logical devices\/Failed \(error\)\/Degraded.*\n)/m ? $1 : '');
      $result .= ($arcconf =~ /^(\s*Write-cache mode.*\n)/m ? $1 : '');
      $result .= ($arcconf =~ /^(\s*Write-cache setting.*\n)/m ? $1 : '');
      $result .= ($arcconf =~ /^(\s*Controller Battery Information.*?\n\n)/ms ? $1 : '');
   }
   else {
      $result .= "\n*** aacraid present but unable to check its status";
   }

   return $result;
}

sub _get_raid_info_tw_cli
{
   my $result = '';
   my $tw_cli = `which tw_cli && tw_cli /c0 show all`;
   if ( $tw_cli ) {
      $result .= ($tw_cli =~ /^\/c0\s*(Model.*\n)/m ? $1 : '');
      $result .= ($tw_cli =~ /^\/c0\s*(Memory Installed.*\n)/m ? $1 : '');
      $result .= ($tw_cli =~ /\n(\n.*)/ms ? $1 : '');
      $result =~ s/^/   /mg;
   }
   else {
      $result .= "\n*** 3ware Storage Controller present but unable to check its status";
   }

   return $result;
}

sub check_proc_sys_net_ipv4_values
{
   my ( $server, $sysctl_conf ) = @_;

   my %ipv4_defaults = qw(
      ip_forward                        0
      ip_default_ttl                    64
      ip_no_pmtu_disc                   0
      min_pmtu                          562
      ipfrag_secret_interval            600
      ipfrag_max_dist                   64
      somaxconn                         128
      tcp_abc                           0
      tcp_abort_on_overflow             0
      tcp_adv_win_scale                 2
      tcp_allowed_congestion_control    reno
      tcp_app_win                       31
      tcp_fin_timeout                   60
      tcp_frto_response                 0
      tcp_keepalive_time                7200
      tcp_keepalive_probes              9 
      tcp_keepalive_intvl               75
      tcp_low_latency                   0
      tcp_max_syn_backlog               1024
      tcp_moderate_rcvbuf               1
      tcp_reordering                    3
      tcp_retries1                      3
      tcp_retries2                      15
      tcp_rfc1337                       0
      tcp_rmem                          8192_87380_174760
      tcp_slow_start_after_idle         1
      tcp_stdurg                        0
      tcp_synack_retries                5
      tcp_syncookies                    0
      tcp_syn_retries                   5
      tcp_tso_win_divisor               3
      tcp_tw_recycle                    0
      tcp_tw_reuse                      0
      tcp_wmem                          4096_16384_131072
      tcp_workaround_signed_windows     0
      tcp_dma_copybreak                 4096
      ip_nonlocal_bind                  0
      ip_dynaddr                        0
      icmp_echo_ignore_all              0
      icmp_echo_ignore_broadcasts       1
      icmp_ratelimit                    100
      icmp_ratemask                     6168
      icmp_errors_use_inbound_ifaddr    0
      igmp_max_memberships              20
      icmp_ignore_bogus_error_responses 0
   );

   $sysctl_conf ||= '/etc/sysctl.conf';
   load_ipv4_defaults(\%ipv4_defaults, $sysctl_conf);

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

# Load default values for /proc/sys/net/ipv4/ settings from sysctl.conf file
sub load_ipv4_defaults {
   my ( $ipv4_defaults, $sysctl_conf ) = @_;
 
   my %conf_ipv4_defaults = parse_sysctl_conf($sysctl_conf);

   # Yes we could do this with hash slices, but I want to see which
   # sysctl vars are overriden from the conf file
   foreach my $var ( keys %conf_ipv4_defaults ) {
      if ( MKDEBUG && exists $ipv4_defaults->{$var} ) {
         _d("sysctl override $var: conf=$conf_ipv4_defaults{$var} overrides default=$ipv4_defaults->{$var}");
      }
      $ipv4_defaults->{$var} = $conf_ipv4_defaults{$var};
   }

   return;
}

sub parse_sysctl_conf {
   my ( $sysctl_conf ) = @_;
   my %sysctl;

   if ( !-f $sysctl_conf ) {
      MKDEBUG && _d("sysctl file $sysctl_conf does not exist");
      return;
   }

   if ( open my $SYSCTL, "< $sysctl_conf" ) {
      MKDEBUG && _d("Parsing $sysctl_conf");
      while ( my $line = <$SYSCTL> ) {
         next if $line  =~ /^#/; # skip comments
         next unless $line =~ /\s*net.ipv4.(\w+)\s*=\s*(\w+)/;
         my ( $var, $val ) = ( $1, $2 );
         MKDEBUG && _d("sysctl: $var=$val");
         if ( exists $sysctl{$var} && MKDEBUG ) {
            _d("Duplicate sysctl var: $var (was $sysctl{$var}, is now $val)");
         }
         $sysctl{$var} = $val;
      }
   }
   else {
      warn "Cannot read $sysctl_conf: $OS_ERROR";
   }

   return %sysctl;
}

sub _can_run {
   my ( $cmd ) = @_;
   # Throw away all output; we're only interested in the return value.
   my $retval = system("$cmd 2>/dev/null > /dev/null");
   $retval = $retval >> 8;
   MKDEBUG && _d("Running '$cmd' returned $retval");
   return !$retval ? 1 : 0;
}

sub _os_version {
   my $version = 'unknown version';

   if ( _can_run('cat /etc/*release') ) {
      chomp(my $rel = `cat /etc/*release`);
      if ( my ($desc) = $rel =~ m/DISTRIB_DESCRIPTION="(.*)"/ ) {
         $version = $desc;
      }
      else {
         $version = $rel;
      }
   }
   elsif ( -r '/etc/debian_version' ) {
      chomp(my $rel = `cat /etc/debian_version`);
      $version = "Debian (or Debian-based) $rel";
   }
   elsif ( MKDEBUG ) {
      _d('No OS version info because no /etc/*release exists');
   }

   return $version;
}

sub _memory_slots {
   my @memory_slots = ();

   if ( _can_run('dmidecode') ) {
      my $dmi = `dmidecode`;
      chomp $dmi;
      my @mem_info = $dmi =~ m/^(Memory Device\n.*?)\n\n/gsm;
      my @attribs  = ( 'Size', 'Form Factor', 'Type', 'Type Detail', 'Speed' );
      foreach my $mem ( @mem_info ) {
         my %fields = map { split /: / } $mem =~ m/^\s+(\S.*:.*)$/gm;
         push(@memory_slots, join(' ', grep { $_ } @fields{@attribs}));
      }
   }
   elsif ( MKDEBUG ) {
      _d('No memory slots info because dmidecode cannot be ran');
   }

   return @memory_slots;
}

# TODO: remove this sub and use Transformers instead, somehow, maybe.
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

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# ServerSpecs:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End ServerSpecs package
# ###########################################################################
