#!/usr/bin/env perl

use strict;
require '../LogSplitter.pm';
require '../LogParser.pm';

my $lp = new LogParser();
my $ls = new LogSplitter(
   attribute  => 'Thread_id',
   saveto_dir => "/tmp/logettes/",
   LogParser  => $lp,
   verbosity  => 1,
);

my @logs;
push @logs, split(',', $ARGV[0]) if @ARGV;
$ls->split_logs(\@logs);

exit;
