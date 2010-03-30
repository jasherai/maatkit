#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

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

my $output;
my $sample = "common/t/samples/configs/";

$c1->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp001.txt");

is(
   $cc->get_stale_variables($c1),
   undef,
   "Can't check for stale vars without online config"
);

$c1->set_config(from=>'show_variables', rows=>[['query_cache_size', 0]]);

is_deeply(
   $cc->get_stale_variables($c1),
   [],
   "No stale vars"
);

$c1->set_config(from=>'show_variables', rows=>[['query_cache_size', 1024]]);

is_deeply(
   $cc->get_stale_variables($c1),
   [
      {
         var         => 'query_cache_size',
         offline_val => 0,
         online_val  => 1024,
      },
   ],
   "A stale vars"
);

# #############################################################################
# Online tests.
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox master', 1 unless $dbh;

   $c1 = new MySQLConfig();
   $c1->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp001.txt");
   $c1->set_config(from=>'show_variables', dbh=>$dbh);

   # If the sandbox master isn't borked then all its vars should be fresh.
   is_deeply(
      $cc->get_stale_variables($c1),
      [],
      "Sandbox has no stale vars"
   );
}

# #############################################################################
# Done.
# #############################################################################
exit;
