#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 9;
use English qw(-no_match_vars);

require '../LogType.pm';

my $lt = new LogType;

isa_ok($lt, 'LogType');

is($lt->name_for(0), 'unknown', 'Log type 0 is "unknown"');
is($lt->name_for(1), 'slow', 'Log type 1 is "slow"');
is($lt->name_for(2), 'general', 'Log type 2 is "general"');
is($lt->name_for(3), 'binary', 'Log type 3 is "binary"');

cmp_ok($lt->get_log_type('samples/slow001.txt'), '==', 1, 'Detects slow log');
cmp_ok($lt->get_log_type('samples/general001.txt'), '==', 2, 'Detects general log');
cmp_ok($lt->get_log_type('samples/binlog.txt'),  '==', 3, 'Detects binary log');
cmp_ok($lt->get_log_type('samples/date.sql'),  '==', 0, 'Returns unknown log type for non-log file');
cmp_ok($lt->get_log_type('samples/slow010.txt'), '==', 1, 'Detects ');

exit;
