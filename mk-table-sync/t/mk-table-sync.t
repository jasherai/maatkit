#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 1;

`mysql < before.sql`;

# Ensure wacky collations and callbacks to MySQL to compare collations don't
# cause problems.
my $output = `../mk-table-sync --print -a bottomup D=test,t=test1 t=test2`;
my $expected = "DELETE FROM `test`.`test2` WHERE (`a` = '2' AND `b` = 'é');\n"
             . "INSERT INTO `test`.`test2`(`a`,`b`) VALUES('2','ca');\n";
is($output, $expected, "Funny characters got synced okay");
