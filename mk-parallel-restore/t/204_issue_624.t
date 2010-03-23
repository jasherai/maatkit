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
require "$trunk/mk-parallel-restore/mk-parallel-restore";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 1;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $output;

# #############################################################################
#  Issue 624: mk-parallel-dump --databases does not filter restored databases
# #############################################################################
$dbh->do('DROP DATABASE IF EXISTS issue_624');
$dbh->do('CREATE DATABASE issue_624');
$dbh->do('USE issue_624');

$output = `$cmd $trunk/mk-parallel-restore/t/samples/issue_624/ -D issue_624 -d d2`;

is_deeply(
   $dbh->selectall_arrayref('SELECT * FROM issue_624.t2'),
   [ [4],[5],[6] ],
   '--databases filters restored dbs (issue 624)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
