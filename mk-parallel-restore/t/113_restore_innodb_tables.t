#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
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
   plan tests => 2;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $output;

# #############################################################################
# Issue 683: mk-parellel-restore innodb table empty 
# #############################################################################
`$cmd --drop-tables --create-databases $trunk/mk-parallel-restore/t/samples/issue_683`;
is_deeply(
   $dbh->selectall_arrayref('select count(*) from `f4all-LIVE`.`Season`'),
   [[47]],
   'Commit after restore (issue 683)'
);

`$cmd --drop-tables --create-databases --no-resume --no-commit $trunk/mk-parallel-restore/t/samples/issue_683`;

is_deeply(
   $dbh->selectall_arrayref('select count(*) from `f4all-LIVE`.`Season`'),
   [[0]],
   '--no-commit'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
