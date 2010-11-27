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
require "$trunk/mk-kill/mk-kill";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-kill/mk-kill -F $cnf -h 127.1";

# Shell out to a sleep(10) query and try to capture the query.
# Backticks don't work here.
system("mysql -h127.1 -P12345 -umsandbox -pmsandbox -e 'select sleep(5)' >/dev/null&");

$output = `$cmd --busy-time 1s --print --run-time 10`;

# $output ought to be something like
# 2009-05-27T22:19:40 KILL 5 (Query 1 sec) select sleep(10)
# 2009-05-27T22:19:41 KILL 5 (Query 2 sec) select sleep(10)
# 2009-05-27T22:19:42 KILL 5 (Query 3 sec) select sleep(10)
# 2009-05-27T22:19:43 KILL 5 (Query 4 sec) select sleep(10)
# 2009-05-27T22:19:44 KILL 5 (Query 5 sec) select sleep(10)
# 2009-05-27T22:19:45 KILL 5 (Query 6 sec) select sleep(10)
# 2009-05-27T22:19:46 KILL 5 (Query 7 sec) select sleep(10)
# 2009-05-27T22:19:47 KILL 5 (Query 8 sec) select sleep(10)
# 2009-05-27T22:19:48 KILL 5 (Query 9 sec) select sleep(10)
my @times = $output =~ m/\(Query (\d+) sec\)/g;
ok(@times > 2 && @times < 7, "There were 2 to 5 captures");

# This is to catch a bad bug where there wasn't any sleep time when
# --iterations  was 0, and another bug when --run-time was not respected.
# Do it all over again, this time with --iterations 0.
# Re issue 1181, --iterations no longer exists, but we'll still keep this test.
system("mysql -h127.1 -P12345 -umsandbox -pmsandbox -e 'select sleep(10)' >/dev/null&");
$output = `$cmd --busy-time 1s --print --run-time 11s`;
@times = $output =~ m/\(Query (\d+) sec\)/g;
ok(@times > 7 && @times < 12, 'Approximately 9 or 10 captures with --iterations 0');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
