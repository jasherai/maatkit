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
require "$trunk/mk-parallel-dump/mk-parallel-dump";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --no-gzip ";
my $mysql = $sb->_use_for('master');

$sb->create_dbs($dbh, ['test']);

my $output;
my $basedir = '/tmp/dump/';
diag(`rm -rf $basedir`);

my @tbls;

# #############################################################################
# Issue 223: mk-parallel-dump includes trig definitions into each chunk file
# #############################################################################

# Triggers are no longer dumped, but we'll keep part of this test to make
# sure triggers really aren't dumped.

$sb->load_file('master', 'mk-parallel-dump/t/samples/issue_223.sql');
diag(`rm -rf $basedir`);

# Dump table t1 and make sure its trig def is not in any chunk.
diag(`MKDEBUG=1 $cmd --base-dir $basedir --chunk-size 30 -d test 1>/dev/null 2>/dev/null`);
is(
   `cat $basedir/test/t1.000000.sql | grep TRIGGER`,
   '',
   'No trigger def in chunk 0 (issue 223)'
);
is(
   `cat $basedir/test/t1.000001.sql | grep TRIGGER`,
   '',
   'No trigger def in chunk 1 (issue 223)'
);
ok(
   !-f '$basedir/test/t1.000000.trg',
   'No triggers dumped'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
