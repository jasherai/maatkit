#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

my $tmp_file = '/tmp/mk-merge-sessions.output';
my $output;

diag(`../mk-merge-sessions $tmp_file samples/log001_session_?.txt >/dev/null`);
$output = `diff $tmp_file samples/log001_merged.txt`;
is(
   $output,
   '',
   'merge log001 sessions'
);

diag(`rm -rf $tmp_file`);
exit;
