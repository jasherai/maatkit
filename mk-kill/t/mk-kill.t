#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';

# Shell out to a sleep(10) query and try to capture the query.  Backticks don't
# work here.
system("mysql -h127.1 -P12345 -e 'select sleep(10)' >/dev/null&");

my $output = `perl ../mk-kill -P 12345 -h 127.1 --busy-time 1s --no-kill --print --iterations 20`;

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
ok(@times > 7 && @times < 12, 'There are approximately 9 or 10 captures');


# This is to catch a bad bug where there wasn't any sleep time when --iterations
# was 0, and another bug when --run-time was not respected.  Do it all over
# again, this time with --iterations 0.
system("mysql -h127.1 -P12345 -e 'select sleep(10)' >/dev/null&");
$output = `perl ../mk-kill -P 12345 -h 127.1 --busy-time 1s --no-kill --print --iterations 0 --run-time 11s`;
@times = $output =~ m/\(Query (\d+) sec\)/g;
ok(@times > 7 && @times < 12, 'Approximately 9 or 10 captures with --iterations 0');
