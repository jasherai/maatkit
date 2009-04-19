#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

require '../InstanceReporter.pm';


my $mi_reporter = new MySQLInstanceReporter();


isa_ok($mi_reporter, 'MySQLInstanceReporter');


exit;
