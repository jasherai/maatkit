#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Test::More tests => 5;

my $output = `perl ../mk-audit --help`;
like($output, qr/Prompt for a password/, 'It compiles');

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

SKIP: {
   skip 'Sandbox master is not running', 4 unless $dbh;

   my $out_file = '/tmp/mk-audit.output';
   my $output = `../mk-audit 1>$out_file 2>$out_file.err`;

   # mk-audit used to warn about certain things. Ideally, however,
   # it should never error/warn to STDERR and instead make an
   # remark in the report like, "mysqld exists but segfaults when ran."
   # So any output to STDERR probably indicates something is broken
   # inside the code, or some new condition we're not catching gracefully.
   is(`cat $out_file.err`, '', 'No errors or warnings on STDERR');
   diag(`rm -f $out_file.err`);

   like(`grep 'Server Specs' $out_file`, qr/Server Specs/, 'Server Specs');
   like(`grep 'MySQL Instance' $out_file`, qr/MySQL Instance\s+\d+/, 'MySQL Instance');

   # The persistent sandbox is purposefully broken so that
   # long_query_time is out of sync.
   like(`grep long_query_time $out_file`, qr/long_query_time\s+3\s+1/, 'long_query_time out of sync');

   diag(`rm -f $out_file`);
};

exit;
