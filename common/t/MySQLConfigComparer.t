#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 9;

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

my $cc = new MySQLConfigComparer();
my $c1 = new MySQLConfig();
my $c2 = new MySQLConfig();

my $diff;
my $missing;
my $output;
my $sample = "common/t/samples/configs/";

sub diff {
   my ( @configs ) = @_;
   my @diffs = $cc->diff(
      configs => \@configs,
   );
   return \@diffs;
}

sub missing {
   my ( @configs ) = @_;
   my @missing= $cc->missing(
      configs => \@configs,
   );
   return \@missing;
}

$c1->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp001.txt");
is_deeply(
   diff($c1, $c1),
   [],
   "mysqld config does not differ with itself"
);

$c2->set_config(from=>'show_variables', rows=>[['query_cache_size', 0]]);
is_deeply(
   diff($c2, $c2),
   [],
   "SHOW VARS config does not differ with itself"
);


$c2->set_config(from=>'show_variables', rows=>[['query_cache_size', 1024]]);
is_deeply(
   diff($c1, $c2),
   [
      {
         var   => 'query_cache_size',
         vals  => [0, 1024],
      },
   ],
   "diff() sees a difference"
);

# #############################################################################
# Compare one config against another.
# #############################################################################
$c1->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp001.txt");
$c2->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp002.txt");

$diff = diff($c1, $c2);
is_deeply(
   $diff,
   [
      { var  => 'basedir',
        vals => [
          '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23',
          '/usr/'
        ],
      },
      { var  => 'character_sets_dir',
        vals => [
          '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/charsets/',
          '/usr/share/mysql/charsets/'
        ],
      },
      { var  => 'connect_timeout',
        vals => ['10','5'],
      },
      { var  => 'datadir',
        vals => ['/tmp/12345/data/', '/mnt/data/mysql/'],
      },
      { var  => 'innodb_data_home_dir',
        vals => ['/tmp/12345/data',''],
      },
      { var  => 'innodb_file_per_table',
        vals => ['FALSE', 'TRUE'],
      },
      { var  => 'innodb_flush_log_at_trx_commit',
        vals => ['1','2'],
      },
      { var  => 'innodb_flush_method',
        vals => ['','O_DIRECT'],
      },
      { var  => 'innodb_log_file_size',
        vals => ['5242880','67108864'],
      },
      { var  => 'key_buffer_size',
        vals => ['16777216','8388600'],
      },
      { var  => 'language',
        vals => [
          '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/english/',
          '/usr/share/mysql/english/'
        ],
      },
      { var  => 'log_bin',
        vals => ['mysql-bin', 'sl1-bin'],
      },
      { var  => 'log_slave_updates',
        vals => ['TRUE','FALSE'],
      },
      { var  => 'max_binlog_cache_size',
        vals => ['18446744073709547520','18446744073709551615'],
      },
      { var  => 'myisam_max_sort_file_size',
        vals => ['9223372036853727232', '9223372036854775807'],
      },
      { var  => 'old_passwords',
        vals => ['FALSE','TRUE'],
      },
      { var  => 'pid_file',
        vals => [
          '/tmp/12345/data/mysql_sandbox12345.pid',
          '/mnt/data/mysql/sl1.pid'
        ],
      },
      { var  => 'port',
        vals => ['12345','3306'],
      },
      { var  => 'range_alloc_block_size',
        vals => ['4096','2048'],
      },
      { var  => 'relay_log',
        vals => ['mysql-relay-bin',''],
      },
      { var  => 'report_host',
        vals => ['127.0.0.1', ''],
      },
      { var  => 'report_port',
        vals => ['12345','3306'],
      },
      { var  => 'server_id',
        vals => ['12345','1'],
      },
      { var  => 'socket',
        vals => [
          '/tmp/12345/mysql_sandbox12345.sock',
          '/mnt/data/mysql/mysql.sock'
        ],
      },
      { var  => 'ssl',
        vals => ['FALSE','TRUE'],
      },
      { var  => 'ssl_ca',
        vals => ['','/opt/mysql.pdns/.cert/ca-cert.pem'],
      },
      { var  => 'ssl_cert',
        vals => ['','/opt/mysql.pdns/.cert/server-cert.pem'],
      },
      { var  => 'ssl_key',
        vals => ['','/opt/mysql.pdns/.cert/server-key.pem'],
      },
   ],
   "Diff two different configs"
) or print Dumper($diff);

# #############################################################################
# Missing vars.
# #############################################################################
$c1 = new MySQLConfig();
$c2 = new MySQLConfig();

$c1->set_config(from=>'show_variables', rows=>[['query_cache_size', 1024]]);
$missing = missing($c1, $c2);
is_deeply(
   $missing,
   [
      { var=>'query_cache_size', missing=>[qw(0 1)] },
   ],
   "Missing var, right"
);

$c2->set_config(from=>'show_variables', rows=>[['query_cache_size', 1024]]);
$missing = missing($c1, $c2);
is_deeply(
   $missing,
   [],
   "No missing vars"
);

$c2->set_config(
   from =>'show_variables',
   rows => [
    ['query_cache_size', 1024],
    ['foo', 1],
   ]
);
$missing = missing($c1, $c2);
is_deeply(
   $missing,
   [
      { var=>'foo', missing=>[qw(1 0)] },
   ],
   "Missing var, left"
);

# #############################################################################
# Online tests.
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox master', 2 unless $dbh;

   $c1 = new MySQLConfig();
   $c2 = new MySQLConfig();

   my $file = "$trunk/$sample/"
            . ($sandbox_version eq '5.0' ? 'mysqldhelp001.txt'
                                         : 'mysqldhelp003.txt');
   $c1->set_config(from=>'show_variables', dbh=>$dbh);
   $c2->set_config(from=>'mysqld',         file=>$file);

   like(
      $c1->version(),
      qr/\d+.\d+.\d+/,
      "Got version",
   );

   # If the sandbox master isn't borked then all its vars should be fresh.
   $diff = diff($c1, $c2);
   is_deeply(
      $diff,
      [],
      "Sandbox has no different vars"
   ) or print Dumper($diff);
}

# #############################################################################
# Done.
# #############################################################################
exit;
