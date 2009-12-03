#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

require '../ErrorLogPatternMatcher.pm';
require '../ErrorLogParser.pm';

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $p = new ErrorLogParser();
my $m = new ErrorLogPatternMatcher();

isa_ok($m, 'ErrorLogPatternMatcher');

my $output;

sub new_pattern {
   my ( $err ) = @_;
   $err =~ s/\b\d+\b/\\d+/g;
   return $err;
}

sub parse {
   my ( $file ) = @_;
   my @e;
   my @m;
   open my $fh, "<", $file or die $OS_ERROR;
   my %args = (
      fh      => $fh,
   );
   while ( my $e = $p->parse_event(%args) ) {
      next unless $e;
      push @m, $m->match(
         event       => $e,
         new_pattern => \&new_pattern,
      );
   }
   close $fh;
   return \@m;
}

is_deeply(
   parse('samples/errlog001.txt'),
   [
      {
        New_pattern  => 'Yes',
        Pattern_no   => 0,
        Pattern      => 'mysqld started',
        arg          => 'mysqld started',
        pos_in_log   => 0,
        ts           => '080721 03:03:57'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 1,
        Pattern      => '\[Warning\] option \'log_slow_rate_limit\': unsigned value \d+ adjusted to \d+',
        Serious      => 'No',
        arg          => '[Warning] option \'log_slow_rate_limit\': unsigned value 0 adjusted to 1',
        pos_in_log   => 32,
        ts           => '080721  3:04:00'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 2,
        Pattern      => '\[ERROR\] /usr/sbin/mysqld: unknown variable \'ssl-key=/opt/mysql\.pdns/\.cert/server-key\.pem\'',
        Serious      => 'Yes',
        arg          => '[ERROR] /usr/sbin/mysqld: unknown variable \'ssl-key=/opt/mysql.pdns/.cert/server-key.pem\'',
        pos_in_log   => 119,
        ts           => '080721  3:04:01'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 3,
        Pattern      => 'mysqld ended',
        arg          => 'mysqld ended',
        pos_in_log   => 225,
        ts           => '080721 03:04:01'
      },
      {
        New_pattern  => 'No',
        Pattern_no   => 0,
        Pattern      => 'mysqld started',
        arg          => 'mysqld started',
        pos_in_log   => 255,
        ts           => '080721 03:10:57'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 4,
        Pattern      => '\[Warning\] No argument was provided to --log-bin\, and --log-bin-index was not used; so replication may break when this MySQL server acts as a master and has his hostname changed\!\! Please use \'--log-bin=/var/run/mysqld/mysqld-bin\' to avoid this problem\.',
        Serious      => 'No',
        arg          => '[Warning] No argument was provided to --log-bin, and --log-bin-index was not used; so replication may break when this MySQL server acts as a master and has his hostname changed!! Please use \'--log-bin=/var/run/mysqld/mysqld-bin\' to avoid this problem.',
        pos_in_log   => 288,
        ts           => '080721  3:10:58'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 5,
        Pattern      => 'InnoDB: Started; log sequence number \d+ \d+',
        arg          => 'InnoDB: Started; log sequence number 1 3703096531',
        pos_in_log   => 556,
        ts           => '080721  3:11:08'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 6,
        Pattern      => '\[Warning\] Neither --relay-log nor --relay-log-index were used; so replication may break when this MySQL server acts as a slave and has his hostname changed\!\! Please use \'--relay-log=/var/run/mysqld/mysqld-relay-bin\' to avoid this problem\.',
        Serious      => 'No',
        arg          => '[Warning] Neither --relay-log nor --relay-log-index were used; so replication may break when this MySQL server acts as a slave and has his hostname changed!! Please use \'--relay-log=/var/run/mysqld/mysqld-relay-bin\' to avoid this problem.',
        pos_in_log   => 878,
        ts           => '080721  3:11:12'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 7,
        Pattern      => '\[ERROR\] Failed to open the relay log \'\./srv-relay-bin\.\d+\' \(relay_log_pos \d+\)',
        Serious      => 'Yes',
        arg          => '[ERROR] Failed to open the relay log \'./srv-relay-bin.000001\' (relay_log_pos 4)',
        pos_in_log   => 878,
        ts           => '080721  3:11:12'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 8,
        Pattern      => '\[ERROR\] Could not find target log during relay log initialization',
        Serious      => 'Yes',
        arg          => '[ERROR] Could not find target log during relay log initialization',
        pos_in_log   => 974,
        ts           => '080721  3:11:12'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 9,
        Pattern      => '\[ERROR\] Failed to initialize the master info structure',
        Serious      => 'Yes',
        arg          => '[ERROR] Failed to initialize the master info structure',
        pos_in_log   => 1056,
        ts           => '080721  3:11:12'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 10,
        Pattern      => '\[Note\] /usr/libexec/mysqld: ready for connections\.',
        Serious      => 'No',
        arg          => '[Note] /usr/libexec/mysqld: ready for connections.',
        pos_in_log   => 1127,
        ts           => '080721  3:11:12'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 11,
        Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
        arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
        pos_in_log   => 1194
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 12,
        Pattern      => '\[Note\] /usr/libexec/mysqld: Normal shutdown',
        Serious      => 'No',
        arg          => '[Note] /usr/libexec/mysqld: Normal shutdown',
        pos_in_log   => 1287,
        ts           => '080721  9:22:14'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 13,
        Pattern      => 'InnoDB: Starting shutdown\.\.\.',
        arg          => 'InnoDB: Starting shutdown...',
        pos_in_log   => 1347,
        ts           => '080721  9:22:17'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 14,
        Pattern      => 'InnoDB: Shutdown completed; log sequence number \d+ \d+',
        arg          => 'InnoDB: Shutdown completed; log sequence number 1 3703096531',
        pos_in_log   => 1472,
        ts           => '080721  9:22:20'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 15,
        Pattern      => '\[Note\] /usr/libexec/mysqld: Shutdown complete',
        Serious      => 'No',
        arg          => '[Note] /usr/libexec/mysqld: Shutdown complete',
        pos_in_log   => 1534,
        ts           => '080721  9:22:20'
      },
      {
        New_pattern  => 'No',
        Pattern_no   => 3,
        Pattern      => 'mysqld ended',
        arg          => 'mysqld ended',
        pos_in_log   => 1534,
        ts           => '080721 09:22:22'
      },
      {
        New_pattern  => 'No',
        Pattern_no   => 0,
        Pattern      => 'mysqld started',
        arg          => 'mysqld started',
        pos_in_log   => 1565,
        ts           => '080721 09:22:31'
      },
      {
        New_pattern  => 'No',
        Pattern_no   => 11,
        Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
        arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
        pos_in_log   => 1598
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 16,
        Pattern      => '\[ERROR\] bdb: log_archive: DB_ARCH_ABS: DB_NOTFOUND: No matching key/data pair found',
        Serious      => 'Yes',
        arg          => '[ERROR] bdb: log_archive: DB_ARCH_ABS: DB_NOTFOUND: No matching key/data pair found',
        pos_in_log   => 1691,
        ts           => '080721  9:34:22'
      },
      {
        New_pattern  => 'No',
        Pattern_no   => 0,
        Pattern      => 'mysqld started',
        arg          => 'mysqld started',
        pos_in_log   => 1792,
        ts           => '080721 09:39:09'
      },
      {
        New_pattern  => 'No',
        Pattern_no   => 5,
        Pattern      => 'InnoDB: Started; log sequence number \d+ \d+',
        arg          => 'InnoDB: Started; log sequence number 1 3703096531',
        pos_in_log   => 1825,
        ts           => '080721  9:39:14'
      },
      { # 23
        New_pattern  => 'No',
        Pattern_no   => 0,
        Pattern      => 'mysqld started',
        arg          => 'mysqld started',
        pos_in_log   => 1924,
        ts           => '080821 19:14:12'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 17,
        Pattern      => 'InnoDB: Database was not shut down normally\! Starting crash recovery\. Reading tablespace information from the \.ibd files\.\.\. Restoring possible half-written data pages from the doublewrite buffer\.\.\.',
        arg          => 'InnoDB: Database was not shut down normally! Starting crash recovery. Reading tablespace information from the .ibd files... Restoring possible half-written data pages from the doublewrite buffer...',
        pos_in_log   => 1924,
        ts           => '080821 19:14:12'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 18,
        Pattern      => 'InnoDB: Starting log scan based on checkpoint at log sequence number \d+ \d+\. Doing recovery: scanned up to log sequence number \d+ \d+ Last MySQL binlog file position \d+ \d+\, file name \./srv-bin\.\d+',
        arg          => 'InnoDB: Starting log scan based on checkpoint at log sequence number 1 3703467071. Doing recovery: scanned up to log sequence number 1 3703467081 Last MySQL binlog file position 0 804759240, file name ./srv-bin.000012',
        pos_in_log   => 2237,
        ts           => '080821 19:14:13'
      },
      {
        New_pattern  => 'No',
        Pattern_no   => 5,
        Pattern      => 'InnoDB: Started; log sequence number \d+ \d+',
        arg          => 'InnoDB: Started; log sequence number 1 3703467081',
        pos_in_log   => 2497,
        ts           => '080821 19:14:13'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 19,
        Pattern      => '\[Note\] Recovering after a crash using srv-bin',
        Serious      => 'No',
        arg          => '[Note] Recovering after a crash using srv-bin',
        pos_in_log   => 2559,
        ts           => '080821 19:14:13'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 20,
        Serious      => 'No',
        Pattern      => '\[Note\] Starting crash recovery\.\.\.',
        arg          => '[Note] Starting crash recovery...',
        pos_in_log   => 2559,
        ts           => '080821 19:14:23'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 21,
        Pattern      => '\[Note\] Crash recovery finished\.',
        Serious      => 'No',
        arg          => '[Note] Crash recovery finished.',
        pos_in_log   => 2609,
        ts           => '080821 19:14:23'
      },
      {
        New_pattern  => 'No',
        Pattern_no   => 11,
        Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
        arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
        pos_in_log   => 2657
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 22,
        Pattern      => '\[Note\] Found \d+ of \d+ rows when repairing \'\./test/a3\'',
        Serious      => 'No',
        arg          => '[Note] Found 5 of 0 rows when repairing \'./test/a3\'',
        pos_in_log   => 2750,
        ts           => '080911 18:04:40'
      },
      {
        New_pattern  => 'No',
        Pattern_no   => 10,
        Pattern      => '\[Note\] /usr/libexec/mysqld: ready for connections\.',
        Serious      => 'No',
        arg          => '[Note] /usr/libexec/mysqld: ready for connections.',
        pos_in_log   => 2818,
        ts           => '081101  9:17:53'
      },
      {
        New_pattern  => 'No',
        Pattern_no   => 11,
        Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
        arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
        pos_in_log   => 2886
      },
      { # 34
        New_pattern  => 'Yes',
        Pattern_no   => 23,
        Pattern      => 'Number of processes running now: \d+',
        arg          => 'Number of processes running now: 0',
        pos_in_log   => 2979
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 24,
        Pattern      => 'mysqld restarted',
        arg          => 'mysqld restarted',
        pos_in_log   => 3015,
        ts           => '081117 16:15:07'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 25,
        Serious      => 'Yes',
        Pattern      => 'InnoDB: Error: cannot allocate \d+ bytes of memory with malloc\! Total allocated memory by InnoDB \d+ bytes\. Operating system errno: \d+ Check if you should increase the swap file or ulimits of your operating system\. On FreeBSD check you have compiled the OS with a big enough maximum process size\. Note that in most \d+-bit computers the process memory space is limited to \d+ GB or \d+ GB\. We keep retrying the allocation for \d+ seconds\.\.\. Fatal error: cannot allocate the memory for the buffer pool',
        arg          => 'InnoDB: Error: cannot allocate 268451840 bytes of memory with malloc! Total allocated memory by InnoDB 8074720 bytes. Operating system errno: 12 Check if you should increase the swap file or ulimits of your operating system. On FreeBSD check you have compiled the OS with a big enough maximum process size. Note that in most 32-bit computers the process memory space is limited to 2 GB or 4 GB. We keep retrying the allocation for 60 seconds... Fatal error: cannot allocate the memory for the buffer pool',
        pos_in_log   => 3049,
        ts           => '081117 16:15:16'
      },
      {
        New_pattern  => 'No',
        Pattern_no   => 10,
        Pattern      => '\[Note\] /usr/libexec/mysqld: ready for connections\.',
        Serious      => 'No',
        arg          => '[Note] /usr/libexec/mysqld: ready for connections.',
        pos_in_log   => 3718,
        ts           => '081117 16:32:55'
      },
   ],
   'errlog001.txt'
);

# #############################################################################
# Done.
# #############################################################################
$output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $m->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
