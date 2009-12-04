#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

require "../ErrorLogParser.pm";

my $p = new ErrorLogParser();

my $oktorun = 1;

sub run_test {
   my ( $def ) = @_;
   map     { die "What is $_ for?" }
      grep { $_ !~ m/^(?:misc|file|result|num_events|oktorun)$/ }
      keys %$def;
   my @e;
   eval {
      open my $fh, "<", $def->{file} or die $OS_ERROR;
      my %args = (
         fh      => $fh,
         misc    => $def->{misc},
         oktorun => $def->{oktorun},
      );
      while ( my $e = $p->parse_event(%args) ) {
         push @e, $e;
      }
      close $fh;
   };
   is($EVAL_ERROR, '', "No error on $def->{file}");
   if ( defined $def->{result} ) {
      is_deeply(\@e, $def->{result}, $def->{file})
         or print "Got: ", Dumper(\@e);
   }
   if ( defined $def->{num_events} ) {
      is(scalar @e, $def->{num_events}, "$def->{file} num_events");
   }
}

run_test({
   file    => 'samples/errlog001.txt',
   oktorun => sub { $oktorun = $_[0]; },
   result => [
      {
       arg        => 'mysqld started',
       pos_in_log => 0,
       ts         => '080721 03:03:57',
      },
      {
       Serious    => 'No',
       arg        => '[Warning] option \'log_slow_rate_limit\': unsigned value 0 adjusted to 1',
       pos_in_log => 32,
       ts         => '080721  3:04:00',
      },
      {
       Serious    => 'Yes',
       arg        => '[ERROR] /usr/sbin/mysqld: unknown variable \'ssl-key=/opt/mysql.pdns/.cert/server-key.pem\'',
       pos_in_log => 119,
       ts         => '080721  3:04:01',
      },
      {
       arg        => 'mysqld ended',
       pos_in_log => 225,
       ts         => '080721 03:04:01',
      },
      {
       arg        => 'mysqld started',
       pos_in_log => 255,
       ts         => '080721 03:10:57',
      },
      {
       Serious    => 'No',
       arg        => '[Warning] No argument was provided to --log-bin, and --log-bin-index was not used; so replication may break when this MySQL server acts as a master and has his hostname changed!! Please use \'--log-bin=/var/run/mysqld/mysqld-bin\' to avoid this problem.',
       pos_in_log => 288,
       ts         => '080721  3:10:58',
      },
      {
       arg        => 'InnoDB: Started; log sequence number 1 3703096531',
       pos_in_log => 556,
       ts         => '080721  3:11:08',
      },
      {
       Serious    => 'No',
       arg        => '[Warning] Neither --relay-log nor --relay-log-index were used; so replication may break when this MySQL server acts as a slave and has his hostname changed!! Please use \'--relay-log=/var/run/mysqld/mysqld-relay-bin\' to avoid this problem.',
       pos_in_log => 878,
       ts         => '080721  3:11:12',
      },
      {
       Serious    => 'Yes',
       arg        => '[ERROR] Failed to open the relay log \'./srv-relay-bin.000001\' (relay_log_pos 4)',
       pos_in_log => 878,
       ts         => '080721  3:11:12',
      },
      {
       Serious    => 'Yes',
       arg        => '[ERROR] Could not find target log during relay log initialization',
       pos_in_log => 974,
       ts         => '080721  3:11:12',
      },
      {
       Serious    => 'Yes',
       arg        => '[ERROR] Failed to initialize the master info structure',
       pos_in_log => 1056,
       ts         => '080721  3:11:12',
      },
      {
       Serious    => 'No',
       arg        => '[Note] /usr/libexec/mysqld: ready for connections.',
       pos_in_log => 1127,
       ts         => '080721  3:11:12',
      },
      {
       arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
       pos_in_log => 1194
      },
      {
       Serious    => 'No',
       arg        => '[Note] /usr/libexec/mysqld: Normal shutdown',
       pos_in_log => 1287,
       ts         => '080721  9:22:14',
      },
      {
       arg        => 'InnoDB: Starting shutdown...',
       pos_in_log => 1347,
       ts         => '080721  9:22:17',
      },
      {
       arg        => 'InnoDB: Shutdown completed; log sequence number 1 3703096531',
       pos_in_log => 1472,
       ts         => '080721  9:22:20',
      },
      {
       Serious    => 'No',
       arg        => '[Note] /usr/libexec/mysqld: Shutdown complete',
       pos_in_log => 1534,
       ts         => '080721  9:22:20',
      },
      {
       arg        => 'mysqld ended',
       pos_in_log => 1534,
       ts         => '080721 09:22:22',
      },
      {
       arg        => 'mysqld started',
       pos_in_log => 1565,
       ts         => '080721 09:22:31',
      },
      {
       arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
       pos_in_log => 1598,
      },
      {
       Serious    => 'Yes',
       arg        => '[ERROR] bdb: log_archive: DB_ARCH_ABS: DB_NOTFOUND: No matching key/data pair found',
       pos_in_log => 1691,
       ts         => '080721  9:34:22',
      },
      {
       arg        => 'mysqld started',
       pos_in_log => 1792,
       ts         => '080721 09:39:09',
      },
      {
       arg        => 'InnoDB: Started; log sequence number 1 3703096531',
       pos_in_log => 1825,
       ts         => '080721  9:39:14',
      },
      {
       arg        => 'mysqld started',
       pos_in_log => 1924,
       ts         => '080821 19:14:12',
      },
      {
       pos_in_log => 1924,
       ts         => '080821 19:14:12',
       arg        => 'InnoDB: Database was not shut down normally! Starting crash recovery. Reading tablespace information from the .ibd files... Restoring possible half-written data pages from the doublewrite buffer...',
      },
      {
       pos_in_log => 2237,
       ts         => '080821 19:14:13',
       arg        => 'InnoDB: Starting log scan based on checkpoint at log sequence number 1 3703467071. Doing recovery: scanned up to log sequence number 1 3703467081 Last MySQL binlog file position 0 804759240, file name ./srv-bin.000012',
      },
      {
       arg        => 'InnoDB: Started; log sequence number 1 3703467081',
       pos_in_log => 2497,
       ts         => '080821 19:14:13',
      },
      {
       Serious    => 'No',
       arg        => '[Note] Recovering after a crash using srv-bin',
       pos_in_log => 2559,
       ts         => '080821 19:14:13',
      },
      {
       Serious    => 'No',
       arg        => '[Note] Starting crash recovery...',
       pos_in_log => 2559,
       ts         => '080821 19:14:23',
      },
      {
       Serious    => 'No',
       arg        => '[Note] Crash recovery finished.',
       pos_in_log => 2609,
       ts         => '080821 19:14:23',
      },
      {
       arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
       pos_in_log => 2657,
      },
      {
       Serious    => 'No',
       arg        => '[Note] Found 5 of 0 rows when repairing \'./test/a3\'',
       pos_in_log => 2750,
       ts         => '080911 18:04:40',
      },
      {
       Serious    => 'No',
       arg        => '[Note] /usr/libexec/mysqld: ready for connections.',
       pos_in_log => 2818,
       ts         => '081101  9:17:53',
      },
      {
       arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
       pos_in_log => 2886,
      },
      {
       arg        => 'Number of processes running now: 0',
       pos_in_log => 2979,
      },
      {
       arg        => 'mysqld restarted',
       pos_in_log => 3015,
       ts         => '081117 16:15:07',
      },
      {
       pos_in_log => 3049,
       ts         => '081117 16:15:16',
       Serious    => 'Yes',
       arg        => 'InnoDB: Error: cannot allocate 268451840 bytes of memory with malloc! Total allocated memory by InnoDB 8074720 bytes. Operating system errno: 12 Check if you should increase the swap file or ulimits of your operating system. On FreeBSD check you have compiled the OS with a big enough maximum process size. Note that in most 32-bit computers the process memory space is limited to 2 GB or 4 GB. We keep retrying the allocation for 60 seconds... Fatal error: cannot allocate the memory for the buffer pool',
      },
      {
       Serious    => 'No',
       arg        => '[Note] /usr/libexec/mysqld: ready for connections.',
       pos_in_log => 3718,
       ts         => '081117 16:32:55',
      },
   ],
});

run_test({
   file    => 'samples/errlog003.txt',
   result => [
      {
         Serious     => 'Yes',
         arg         => '[ERROR] /usr/sbin/mysqld: Incorrect key file for table \'./bugs_eventum/eventum_note.MYI\'; try to repair it',
         pos_in_log  => 0,
         ts          => '090902 10:43:55',
      },
      {
         Serious     => 'Yes',
         pos_in_log  => 123,
         ts          => '090902 10:43:55',
         arg         => '[ERROR] Slave SQL: Error \'Incorrect key file for table \'./bugs_eventum/eventum_note.MYI\'; try to repair it\' on query. Default database: \'bugs_eventum\'. Query: \'DELETE FROM                    bugs_eventum.eventum_note                 WHERE                    not_iss_id IN (384, 385, 101056, 101057, 101058, 101067, 101070, 101156, 101163, 101164, 101175, 101232, 101309, 101433, 101434, 101435, 101436, 101437, 101454, 101476, 101488, 101490, 101506, 101507, 101530, 101531, 101573, 101574, 101575, 101583, 101586, 101587, 101588, 101589, 101590, 101729, 101730, 101791, 101865, 102382)\', Error_code: 126',
      },
      {
         Serious     => 'No',
         arg         => '[Warning] Slave: Incorrect key file for table \'./bugs_eventum/eventum_note.MYI\'; try to repair it Error_code: 126',
         pos_in_log  => 747,
         ts          => '090902 10:43:55'
      },
   ]
});

run_test({
   file    => 'samples/errlog004.txt',
   result => [
      {
         Serious     => 'Yes',
         arg         => '[ERROR] Error running query, slave SQL thread aborted. Fix the problem, and restart the slave SQL thread with "SLAVE START". We stopped at log \'mpb-bin.000534\' position 47010998',
         pos_in_log  => 0,
         ts          => '090902 10:43:55',
      },
      {
         arg         => 'InnoDB: Unable to lock ./timer2/rates.ibd, error: 37',
         pos_in_log  => 194,
      },
      {
         arg         => 'InnoDB: Assertion failure in thread 1312495936 in file fil/fil0fil.c line 752 Failing assertion: ret We intentionally generate a memory trap. Submit a detailed bug report to http://bugs.mysql.com. If you get repeated assertion failures or crashes, even immediately after the mysqld startup, there may be corruption in the InnoDB tablespace. Please refer to http://dev.mysql.com/doc/refman/5.1/en/forcing-recovery.html about forcing recovery.',
         pos_in_log  => 342,
         ts          => '090902 11:08:43',
      },
      {
         pos_in_log  => 810,
         ts          => '090902 11:08:43',
         arg         => '- mysqld got signal 6 ;
This could be because you hit a bug. It is also possible that this binary
or one of the libraries it was linked against is corrupt, improperly built,
or misconfigured. This error can also be caused by malfunctioning hardware.
We will try our best to scrape up some info that will hopefully help diagnose
the problem, but since we have already crashed, something is definitely wrong
and this may fail.

key_buffer_size=67108864
read_buffer_size=131072
max_used_connections=2
max_threads=128
threads_connected=2
It is possible that mysqld could use up to 
key_buffer_size + (read_buffer_size + sort_buffer_size)*max_threads = 345366 K
bytes of memory
Hope that\'s ok; if not, decrease some variables in the equation.

thd: 0xf95a8a0
Attempting backtrace. You can use the following information to find out
where mysqld died. If you see no messages after this, something went
terribly wrong...
stack_bottom = 0x4e3b0f20 thread_stack 0x40000
/usr/sbin/mysqld(my_print_stacktrace+0x35)[0x83bd65]
/usr/sbin/mysqld(handle_segfault+0x31d)[0x58dd4d]
/lib64/libpthread.so.0[0x2b869c7984c0]
/lib64/libc.so.6(gsignal+0x35)[0x2b869d2ad215]
/lib64/libc.so.6(abort+0x110)[0x2b869d2aecc0]
/usr/sbin/mysqld[0x741e55]
/usr/sbin/mysqld[0x742078]
/usr/sbin/mysqld[0x744b65]
/usr/sbin/mysqld[0x7300a9]
/usr/sbin/mysqld[0x728337]
/usr/sbin/mysqld[0x7d135e]
/usr/sbin/mysqld[0x7d1439]
/usr/sbin/mysqld[0x7d1b18]
/usr/sbin/mysqld[0x732e45]
/usr/sbin/mysqld[0x73690b]
/usr/sbin/mysqld[0x70b9b8]
/usr/sbin/mysqld(_ZN7handler7ha_openEP8st_tablePKcii+0x3e)[0x66a50e]
/usr/sbin/mysqld(_Z21open_table_from_shareP3THDP14st_table_sharePKcjjjP8st_tableb+0x597)[0x5e6cb7]
/usr/sbin/mysqld[0x5db6fe]
/usr/sbin/mysqld(_Z10open_tableP3THDP10TABLE_LISTP11st_mem_rootPbj+0x59c)[0x5dd0ac]
/usr/sbin/mysqld(_Z11open_tablesP3THDPP10TABLE_LISTPjj+0x4cf)[0x5dddcf]
/usr/sbin/mysqld(_Z28open_and_lock_tables_derivedP3THDP10TABLE_LISTb+0x67)[0x5de087]
/usr/sbin/mysqld[0x684cef]
/usr/sbin/mysqld(_Z17mysql_check_tableP3THDP10TABLE_LISTP15st_ha_check_opt+0x5e)[0x685cce]
/usr/sbin/mysqld(_Z21mysql_execute_commandP3THD+0x28d8)[0x59d4e8]
/usr/sbin/mysqld(_Z11mysql_parseP3THDPKcjPS2_+0x1dc)[0x5a07bc]
/usr/sbin/mysqld(_Z16dispatch_command19enum_server_commandP3THDPcj+0xf98)[0x5a1778]
/usr/sbin/mysqld(_Z10do_commandP3THD+0xe7)[0x5a1cd7]
/usr/sbin/mysqld(handle_one_connection+0x592)[0x594c62]
/lib64/libpthread.so.0[0x2b869c790367]
/lib64/libc.so.6(clone+0x6d)[0x2b869d34ff7d]
Trying to get some variables.
Some pointers may be invalid and cause the dump to abort...
thd->query at 0xf9b1670 = CHECK TABLE `rates`  FOR UPGRADE
thd->thread_id=15
thd->killed=NOT_KILLED
The manual page at http://dev.mysql.com/doc/mysql/en/crashing.html contains
information that should help you find out what is causing the crash.',
      },
      {
         arg         => 'mysqld_safe Number of processes running now: 0',
         pos_in_log  => 3636,
         ts          => '090902 11:08:43'
      },
   ]
});

# #############################################################################
# Done.
# #############################################################################
exit;
