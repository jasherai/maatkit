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

my $dp  = new DSNParser();
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
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf -h 127.1 --dry-run";

$sb->wipe_clean($dbh);
$sb->load_file('master', 'mk-table-sync/t/samples/filter_tables.sql');

$output    = `$cmd -v -t issue_806_1.t2`;
my @output = split(/\n/, $output);
$output[1] = '';  # the actual mysqldump cmd line
is_deeply(
   \@output,
   [
      'CHUNK  TIME  EXIT  SKIPPED DATABASE.TABLE ',
      '',
      '  tbl  0.01     0        0 issue_806_1.t2 ',
      '   db  0.01     0        0 issue_806_1    ',
      '  all  0.01     0        0 -              ',
   ],
   "db-qualified --tables (issue 806)"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
