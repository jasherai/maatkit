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
require "$trunk/mk-table-checksum/mk-table-checksum";

my $dp = new DSNParser(opts=>$dsn_opts);
my $vp = new VersionParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');
$sb->load_file('master', 'mk-table-checksum/t/samples/checksum_tbl.sql');

# #############################################################################
# Issue 77: mk-table-checksum should be able to create the --replicate table
# #############################################################################

# First check that, like a Klingon, it dies with honor.
`/tmp/12345/use -e 'DROP TABLE test.checksum'`;
$output = `$cmd --replicate test.checksum 2>&1`;
like(
   $output,
   qr/replicate table .+ does not exist/,
   'Dies with honor when replication table does not exist'
);

$output = `$cmd --ignore-databases sakila --replicate test.checksum --create-replicate-table`;
like(
   $output,
   qr/DATABASE\s+TABLE\s+CHUNK/,
   '--create-replicate-table creates the replicate table'
);

# In 5.0 "on" in "on update" is lowercase, in 5.1 it's uppercase.
my $create_tbl = lc("CREATE TABLE `checksum` (
  `db` char(64) NOT NULL,
  `tbl` char(64) NOT NULL,
  `chunk` int(11) NOT NULL,
  `boundaries` char(100) NOT NULL,
  `this_crc` char(40) NOT NULL,
  `this_cnt` int(11) NOT NULL,
  `master_crc` char(40) default NULL,
  `master_cnt` int(11) default NULL,
  `ts` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`db`,`tbl`,`chunk`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1");

# In 5.0 there's 2 spaces, in 5.1 there 1.
if ( $vp->version_ge($master_dbh, '5.1.0') ) {
   $create_tbl =~ s/primary key  /primary key /;
}

is(
   lc($master_dbh->selectrow_hashref('show create table test.checksum')->{'Create Table'}),
   $create_tbl,
   'Creates the replicate table'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
