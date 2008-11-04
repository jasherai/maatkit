#!/usr/bin/env perl

require '../MySQLFind.pm';
require '../DSNParser.pm';
require '../Quoter.pm';
require '../MySQLDump.pm';
require '../TableParser.pm';

use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

my $dp  = new DSNParser();
my $q   = new Quoter();
my $du  = new MySQLDump( cache => 0 );
my $tp  = new TableParser();
my $dbh = $dp->get_dbh($dp->get_cxn_params({h=>127.1,P=>12345}));

my $finder = new MySQLFind(
   quoter    => $q,
   useddl    => 1,
   parser    => $tp,
   dumper    => $du,
   databases => {
      permit => undef,
      reject => undef,
   },
   tables => {
      permit => { 'test_mysql_finder_2.b' => 1 },
      reject => undef,
   },
   engines => {
      views  => 0,
      permit => undef,
      reject => { FEDERATED => 1, MRG_MyISAM => 1 },
   },
);

foreach my $db ( $finder->find_databases($dbh) ) {
   foreach my $tbl ( $finder->find_tables($dbh, database => $db) ) {
      print "Found $db.$tbl\n";
   }
}

$dbh->disconnect();
exit;
