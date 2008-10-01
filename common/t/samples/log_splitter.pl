#!/usr/bin/env perl

# This script is to test that LogSplitter will read STDIN.

require '../LogSplitter.pm';
require '../LogParser.pm';

my $lp = new LogParser();
my $ls = new LogSplitter();

$ls->split_logs(
   log_files  => [ '-' ],  # - tells LogSplitter to read STDIN
   attribute  => 'Thread_id',
   saveto_dir => "/tmp/logettes/",
   LogParser  => $lp,
);

exit;
