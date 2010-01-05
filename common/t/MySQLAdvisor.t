#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;
plan skip_all => 'Deprecated mk-audit module';

use MySQLAdvisor;
use MySQLInstance;
use SchemaDiscover;
use DSNParser;
use MySQLDump;
use Quoter;
use TableParser;
use VersionParser;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

use DSNParser;
use Sandbox;
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

# #############################################################################
# First, setup a MySQLInstance. 
# #############################################################################
# The cmd line really is only needed so MySQLInstance::new() has something
# to chew on.
my $myi = new MySQLInstance('/usr/sbin/mysqld --defaults-file=/tmp/12345/my.sandbox.cnf');
$myi->load_sys_vars($dbh);
$myi->load_status_vals($dbh);

# #############################################################################
# Next, we need a SchemaDiscover.
# #############################################################################
my $vp = new VersionParser();
my $d  = new MySQLDump();
my $q  = new Quoter();
my $t  = new TableParser(Quoter=>$q);
my $sd = new SchemaDiscover(
   du  => $d,
   q   => $q,
   tp  => $t,
   vp  => $vp,
);
$sd->discover($dbh);

# #############################################################################
# Now, begin checking MySQLAdvisor.
# #############################################################################
my $ma = new MySQLAdvisor($myi, $sd);
isa_ok($ma, 'MySQLAdvisor');

my $problems = $ma->run_checks();
ok( exists $problems->{innodb_flush_method},
   'checks (all) innodb_flush_method fails' );
ok( exists $problems->{max_connections},
   'checks (all) max_connections fails');
ok( exists $problems->{log_slow_queries},
   'checks (all) log_slow_queries fails');
ok( exists $problems->{thread_cache_size},
   'checks (all) thread_cache_size fails');
ok(!exists $problems->{'socket'},
   'checks (all) socket passes');
ok( exists $problems->{query_cache},
   'checks (all) query_cache fails');
ok( exists $problems->{skip_name_resolve},
   'checks (all) skip_name_resolve fails'   );
ok( exists $problems->{'key_buffer too large'},
   'checks (all) key_buff too large fails');

$problems = $ma->run_checks('foo');
like($problems->{ERROR}, qr/No check named foo exists/, 'check foo does not exist');

$problems = $ma->run_checks('Innodb_buffer_pool_pages_free');
ok(!exists $problems->{ERROR}, 'check Innodb_buffer_pool_pages_free does exist');

# This test was removed because it was unrealiable. If MySQLAdvisor.t was
# tested alone, then the buff pool wasn't filled so the test would pass.
# But if ran as part of prove common/t/*.t, then the other scripts would
# access the sakila db causing the buff pool to fill, and then this test
# would fail.
# ok(!exists $problems->{Innodb_buffer_pool_pages_free}, 'check Innodb_buffer_pool_pages_free fails');

exit;
