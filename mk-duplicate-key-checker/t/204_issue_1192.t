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
require "$trunk/mk-duplicate-key-checker/mk-duplicate-key-checker";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 1;
}

my $output;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-duplicate-key-checker/mk-duplicate-key-checker -F $cnf -h 127.1";

$sb->wipe_clean($dbh);
$sb->create_dbs($dbh, ['issue_1192']);

# #############################################################################
# Issue 1192: DROP/ADD leaves structure unchanged
# #############################################################################
$sb->load_file('master', "common/t/samples/dupekeys/issue-1192.sql", "issue_1192");

ok(
   no_diff(
      "$cmd -d issue_1192 --no-summary",
      "mk-duplicate-key-checker/t/samples/issue_1192.txt",
      sed => ["-i 's/  (/ (/g'"],
   ),
   "Keys are sorted lc so left-prefix magic works (issue 1192)"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
