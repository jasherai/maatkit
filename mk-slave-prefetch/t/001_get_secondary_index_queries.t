#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-slave-prefetch/mk-slave-prefetch";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 5;
}

my $q  = new Quoter();
my $du = new MySQLDump(cache => 0);
my $tp = new TableParser(Quoter => $q);
my $qp = new QueryParser();
my %common_modules = (
   MySQLDump   => $du,
   TableParser => $tp,
   QueryParser => $qp,
   Quoter      => $q,
);

# ###########################################################################
# Test making queries for secondary indexes.
# ###########################################################################
$sb->load_file('master', 'mk-slave-prefetch/t/samples/secondary_indexes.sql');

my @queries = mk_slave_prefetch::get_secondary_index_queries(
   dbh   => $dbh,
   query => 'select 1 from test2.t order by a',
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
   dbh   => $dbh,
   query => 'select 1 from test2.t where a=1 and b=2',
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
   dbh   => $dbh,
   query => 'select 1 from `test2`.`t` where a>5',
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


# #############################################################################
# Use default_db only if necessary.
# #############################################################################
@queries = mk_slave_prefetch::get_secondary_index_queries(
   dbh         => $dbh,
   default_db  => 'other_db',
   query       => 'select 1 from `t` where a=1',
   %common_modules,
);
is_deeply(
   \@queries,
   [
      'SELECT `c` FROM `other_db`.`t` FORCE INDEX(`c`) WHERE `c`=3 LIMIT 1',
      'SELECT `b`, `c` FROM `other_db`.`t` FORCE INDEX(`b`) WHERE `b`=2 AND `c`=3 LIMIT 1',
   ],
   'Use default db if no db from table',
);

@queries = mk_slave_prefetch::get_secondary_index_queries(
   dbh         => $dbh,
   default_db  => 'other_db',
   query       => 'select 1 from `test2`.`t` where a=1',
   %common_modules,
);
is_deeply(
   \@queries,
   [
      'SELECT `c` FROM `test2`.`t` FORCE INDEX(`c`) WHERE `c`=3 LIMIT 1',
      'SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b`=2 AND `c`=3 LIMIT 1',
   ],
   "Don't use default db if db from table",
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
