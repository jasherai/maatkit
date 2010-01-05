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

use MySQLInstanceReporter;
use MySQLInstance;
use OptionParser;
use MySQLAdvisor;
use SchemaDiscover;
use TableParser;
use MySQLDump;
use DSNParser;
use VersionParser;
use Quoter;
use Sandbox;
use MaatkitTest;

my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

# See MySQLInstance.t regarding these two vars.
my $msandbox_basedir = $ENV{MSANDBOX_BASEDIR};
if ( !defined $msandbox_basedir || !-d $msandbox_basedir ) {
   BAIL_OUT("The MSANDBOX_BASEDIR environment variable is not set or valid.");
}
my $cmd = "$msandbox_basedir/bin/mysqld --defaults-file=/tmp/12345/my.sandbox.cnf --basedir=/usr --datadir=/tmp/12345/data --pid-file=/tmp/12345/data/mysql_sandbox12345.pid --skip-external-locking --port=12345 --socket=/tmp/12345/mysql_sandbox12345.sock --long-query-time=3";

my $mi = new MySQLInstance($cmd);
my $q  = new Quoter();
my $tp = new TableParser(Quoter => $q);
my $du = new MySQLDump();
my $vp = new VersionParser();
my $sd = new SchemaDiscover(du=>$du, q=>$q, tp=>$tp, vp=>$vp);

$mi->load_sys_vars($dbh);
$mi->load_status_vals($dbh);

my $mi_reporter = new MySQLInstanceReporter();
isa_ok($mi_reporter, 'MySQLInstanceReporter');

exit;
