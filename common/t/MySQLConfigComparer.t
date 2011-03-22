#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 11;

use TextResultSetParser();
use MySQLConfigComparer;
use MySQLConfig;
use DSNParser;
use Sandbox;
use MaatkitTest;

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $trp = new TextResultSetParser();
my $cc  = new MySQLConfigComparer();
my $c1;
my $c2;

my $diff;
my $missing;
my $output;
my $sample = "common/t/samples/configs/";

sub diff {
   my ( @configs ) = @_;
   my $diffs = $cc->diff(
      configs => \@configs,
   );
   return $diffs;
}

sub missing {
   my ( @configs ) = @_;
   my $missing= $cc->missing(
      configs => \@configs,
   );
   return $missing;
}

$c1 = new MySQLConfig(
   source              => "$trunk/$sample/mysqldhelp001.txt",
   TextResultSetParser => $trp,
);
is_deeply(
   diff($c1, $c1),
   {},
   "mysqld config does not differ with itself"
);

$c2 = new MySQLConfig(
   source              => [['query_cache_size', 0]],
   TextResultSetParser => $trp,
);
is_deeply(
   diff($c2, $c2),
   {},
   "SHOW VARS config does not differ with itself"
);


$c2 = new MySQLConfig(
   source              => [['query_cache_size', 1024]],
   TextResultSetParser => $trp,
);
is_deeply(
   diff($c1, $c2),
   {
      'query_cache_size' => [0, 1024],
   },
   "diff() sees a difference"
);

# #############################################################################
# Compare one config against another.
# #############################################################################
$c1 = new MySQLConfig(
   source              => "$trunk/$sample/mysqldhelp001.txt",
   TextResultSetParser => $trp,
);
$c2 = new MySQLConfig(
   source              => "$trunk/$sample/mysqldhelp002.txt",
   TextResultSetParser => $trp,
);

$diff = diff($c1, $c2);
is_deeply(
   $diff,
   {
      basedir => [
          '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23',
          '/usr/'
      ],
      character_sets_dir => [
          '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/charsets/',
          '/usr/share/mysql/charsets/'
      ],
      connect_timeout      => ['10','5'],
      datadir              => ['/tmp/12345/data/', '/mnt/data/mysql/'],
      innodb_data_home_dir => ['/tmp/12345/data',''],
      innodb_file_per_table=> ['FALSE', 'TRUE'],
      innodb_flush_log_at_trx_commit => ['1','2'],
      innodb_flush_method  => ['','O_DIRECT'],
      innodb_log_file_size => ['5242880','67108864'],
      key_buffer_size      => ['16777216','8388600'],
      language             => [
          '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/english/',
          '/usr/share/mysql/english/'
      ],
      log_bin           => ['mysql-bin', 'sl1-bin'],
      log_slave_updates => ['TRUE','FALSE'],
      max_binlog_cache_size => [
         '18446744073709547520',
         '18446744073709551615'
         ],
      myisam_max_sort_file_size => [
         '9223372036853727232',
         '9223372036854775807'
      ],
      old_passwords => ['FALSE','TRUE'],
      pid_file    => [
          '/tmp/12345/data/mysql_sandbox12345.pid',
          '/mnt/data/mysql/sl1.pid'
      ],
      port        => ['12345','3306'],
      range_alloc_block_size => ['4096','2048'],
      relay_log   => ['mysql-relay-bin',''],
      report_host => ['127.0.0.1', ''],
      report_port => ['12345','3306'],
      server_id   => ['12345','1'],
      socket      => [
          '/tmp/12345/mysql_sandbox12345.sock',
          '/mnt/data/mysql/mysql.sock'
      ],
      ssl         => ['FALSE','TRUE'],
      ssl_ca      => ['','/opt/mysql.pdns/.cert/ca-cert.pem'],
      ssl_cert    => ['','/opt/mysql.pdns/.cert/server-cert.pem'],
      ssl_key     => ['','/opt/mysql.pdns/.cert/server-key.pem'],
   },
   "Diff two different configs"
);

# #############################################################################
# Missing vars.
# #############################################################################
$c1 = new MySQLConfig(
   source              => [['query_cache_size', 1024]],
   TextResultSetParser => $trp,
);
$c2 = new MySQLConfig(
   source              => [],
   TextResultSetParser => $trp,
);

$missing = missing($c1, $c2);
is_deeply(
   $missing,
   {
      'query_cache_size' =>[qw(0 1)],
   },
   "Missing var, right"
);

$c2 = new MySQLConfig(
   source              => [['query_cache_size', 1024]],
   TextResultSetParser => $trp,
);
$missing = missing($c1, $c2);
is_deeply(
   $missing,
   {}, 
   "No missing vars"
);

$c2 = new MySQLConfig(
   source              => [['query_cache_size', 1024], ['foo', 1]],
   TextResultSetParser => $trp,
);
$missing = missing($c1, $c2);
is_deeply(
   $missing,
   {
      'foo' => [qw(1 0)],
   },
   "Missing var, left"
);


# #############################################################################
# Special equality subs.
# #############################################################################
$c1 = new MySQLConfig(
   source              => [['log_error', undef]],
   TextResultSetParser => $trp,
);
$c2 = new MySQLConfig(
   source              => [['log_error', '/tmp/12345/data/mysqld.log']],
   TextResultSetParser => $trp,
);
$diff = diff($c1, $c2);
is_deeply(
   $diff,
   {},
   "log_error: undef, value"
);

$c2 = new MySQLConfig(
   source              => [['log_error', undef]],
   TextResultSetParser => $trp,
);
$c1 = new MySQLConfig(
   source              => [['log_error', '/tmp/12345/data/mysqld.log']],
   TextResultSetParser => $trp,
);
$diff = diff($c1, $c2);
is_deeply(
   $diff,
   {},
   "log_error: value, undef"
);

# ############################################################################
# Vars with relative paths.
# ############################################################################

my $basedir = '/opt/mysql';
my $datadir = '/tmp/12345/data';

# This simulates a my.cnf.  We just need vars with relative paths, so no need
# to parse a real my.cnf with other vars that we don't need.
$c1 = new MySQLConfig(
   TextResultSetParser => $trp,
   source              => [
      ['basedir',    $basedir             ],  # must have this
      ['datadir',    $datadir             ],  # must have this
      ['language',   './share/english'    ],
      ['log_error',  'mysqld-error.log'   ],
   ],
); 

# This simulates SHOW VARIABLES.  Like $c1, we just need vars with relative
# paths.  But be sure to get real values because the whole point here is the
# different way these vars are listed in my.cnf vs. SHOW VARS.
$c2 = new MySQLConfig(
   TextResultSetParser => $trp,
   source              => [
      ['basedir',    $basedir                   ],  # must have this
      ['datadir',    $datadir                   ],  # must have this
      ['language',   "$basedir/share/english"   ],
      ['log_error',  "$datadir/mysqld-error.log"],
   ], 
); 

$diff = diff($c1, $c2);
is_deeply(
   $diff,
   {},
   "Variables with relative paths"
) or print Dumper($diff);

# #############################################################################
# Done.
# #############################################################################
{
   local *STDERR;
   open STDERR, '>', \$output;
   $cc->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
