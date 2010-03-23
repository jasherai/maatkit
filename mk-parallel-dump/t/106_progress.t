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
require "$trunk/mk-parallel-dump/mk-parallel-dump";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'sakila db not loaded';
}
else {
   plan tests => 1;
}

my $output;
my $basedir = '/tmp/dump/';
my $cnf     = "/tmp/12345/my.sandbox.cnf";
my $cmd     = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf -h 127.1 --dry-run";

$sb->wipe_clean($dbh);

# #########################################################################
# Issue 573: 'mk-parallel-dump --progress --ignore-engine MyISAM' Reports
# progress incorrectly
# #########################################################################
# sakila is mostly InnoDB tables so load some MyISAM tables.
# film_text is the only non-InnoDB table (it's MyISAM).
diag(`/tmp/12345/use < $trunk/mk-table-sync/t/samples/issue_560.sql`);
diag(`/tmp/12345/use < $trunk/mk-table-sync/t/samples/issue_375.sql`);
diag(`rm -rf $basedir`);

# Only issue_560.buddy_list is InnoDB so only its size should be used
# to calculate --progress.
$output = `$cmd --base-dir $basedir -d issue_375,issue_560 --ignore-engines MyISAM --progress`;
like(
   $output,
   qr/16\.00k\/16\.00k 100\.00% ETA 00:00/,
   "--progress doesn't count skipped tables (issue 573)"
); 

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
