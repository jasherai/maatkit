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
require "$trunk/mk-archiver/mk-archiver";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

my $output;
my $rows;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-archiver/mk-archiver";

$sb->create_dbs($dbh, ['test']);

# #############################################################################
# Issue 655: Using --primary-key-only on a table without a primary key causes
# perl error
# #############################################################################
$dbh->do('CREATE TABLE test.t (i int)');
$output = `$cmd --where 1=1 --source F=$cnf,D=test,t=t --purge --primary-key-only 2>&1`;
unlike(
   $output,
   qr/undefined value/,
   'No error using --primary-key-only on table without pk (issue 655)'
);
like(
   $output,
   qr/does not have a PRIMARY KEY/,
   "Says that table doesn't have a pk (issue 655)"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
