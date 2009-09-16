#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 11;

require '../mk-slave-prefetch';
require '../../common/Sandbox.pm';

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $slave_dbh  = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

my $du = new MySQLDump(cache => 0);
my $tp = new TableParser();
my $qp = new QueryParser();
my $q  = new Quoter();
my %common_modules = (
   MySQLDump   => $du,
   TableParser => $tp,
   QueryParser => $qp,
   Quoter      => $q,
);

my $output = `perl ../mk-slave-prefetch --help`;
like($output, qr/Prompt for a password/, 'It compiles');

# ###########################################################################
# Test making queries for secondary indexes.
# ###########################################################################
$sb->load_file('slave1', 'samples/secondary_indexes.sql');

my @queries = mk_slave_prefetch::get_secondary_index_queries(
   dbh         => $slave_dbh,
   db          => 'test2',
   query       => 'select 1 from test2.t order by a',
   %common_modules,
);
is_deeply(
   \@queries,
   [
      "SELECT `c` FROM `test2`.`t` FORCE INDEX(`c`) WHERE `c`=3 LIMIT 1
UNION ALL SELECT `c` FROM `test2`.`t` FORCE INDEX(`c`) WHERE `c`=2 LIMIT 1
UNION ALL SELECT `c` FROM `test2`.`t` FORCE INDEX(`c`) WHERE `c`=5 LIMIT 1
UNION ALL SELECT `c` FROM `test2`.`t` FORCE INDEX(`c`) WHERE `c`='0' LIMIT 1
UNION ALL SELECT `c` FROM `test2`.`t` FORCE INDEX(`c`) WHERE `c` IS NULL LIMIT 1
UNION ALL SELECT `c` FROM `test2`.`t` FORCE INDEX(`c`) WHERE `c`=7 LIMIT 1",


      "SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b`=2 AND `c`=3 LIMIT 1
UNION ALL SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b`=2 AND `c`=2 LIMIT 1
UNION ALL SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b`=4 AND `c`=5 LIMIT 1
UNION ALL SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b`='0' AND `c`='0' LIMIT 1
UNION ALL SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b`=1 AND `c`=2 LIMIT 1
UNION ALL SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b`=6 AND `c` IS NULL LIMIT 1
UNION ALL SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b` IS NULL AND `c`=7 LIMIT 1
UNION ALL SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b` IS NULL AND `c` IS NULL LIMIT 1",
   ],
   'Secondary index queries for multi-row prefetch query'
);

@queries = mk_slave_prefetch::get_secondary_index_queries(
   dbh         => $slave_dbh,
   db          => 'test2',
   query       => 'select 1 from test2.t where a=1 and b=2',
   %common_modules,
);
is_deeply(
   \@queries,
   [
      "SELECT `c` FROM `test2`.`t` FORCE INDEX(`c`) WHERE `c`=3 LIMIT 1",

      "SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b`=2 AND `c`=3 LIMIT 1",
   ],
   'Secondary index queries for single-row prefetch query'
);

@queries = mk_slave_prefetch::get_secondary_index_queries(
   dbh         => $slave_dbh,
   db          => 'test2',
   query       => 'select 1 from `test2`.`t` where a>5',
   %common_modules,
);
is_deeply(
   \@queries,
   [
      "SELECT `c` FROM `test2`.`t` FORCE INDEX(`c`) WHERE `c` IS NULL LIMIT 1
UNION ALL SELECT `c` FROM `test2`.`t` FORCE INDEX(`c`) WHERE `c`=7 LIMIT 1",

      "SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b`=6 AND `c` IS NULL LIMIT 1
UNION ALL SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b` IS NULL AND `c`=7 LIMIT 1
UNION ALL SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b` IS NULL AND `c` IS NULL LIMIT 1",
   ],
   'Secondary index queries with NULL row values'
);

# ###########################################################################
# Check daemonization.
# ###########################################################################
my $cmd = '../mk-slave-prefetch -F /tmp/12346/my.sandbox.cnf --daemonize --pid /tmp/mk-slave-prefetch.pid --print';
diag(`$cmd 1>/dev/null 2>/dev/null`);
$output = `ps -eaf | grep 'mk-slave-prefetch \-F' | grep -v grep`;
like($output, qr/$cmd/, 'It lives daemonized');
ok(-f '/tmp/mk-slave-prefetch.pid', 'PID file created');

my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-slave-prefetch.pid`;
is($output, $pid, 'PID file has correct PID');

# Kill it by testing --stop.
$output = `../mk-slave-prefetch --stop`;
like(
   $output,
   qr{created file /tmp/mk-slave-prefetch-sentinel},
   'Create sentinel file'
);

sleep 1;
$output = `ps -eaf | grep 'mk-slave-prefetch \-F' | grep -v grep`;
is($output, '', 'Stops for sentinel');
ok(! -f '/tmp/mk-slave-prefetch.pid', 'PID file removed');

`rm -f /tmp/mk-slave-prefetch-sentinel`;

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `../mk-slave-prefetch -F /tmp/12346/my.sandbox.cnf --print --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;


# #############################################################################
# Done.
# #############################################################################
exit;
