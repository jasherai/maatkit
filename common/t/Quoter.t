#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;
use English qw(-no_match_vars);

require "../Quoter.pm";

my $q = new Quoter;

is_deeply(
   [$q->quote('a')],
   ['`a`'],
   'Simple quote OK',
);

is_deeply(
   [$q->quote('a','b')],
   ['`a`', '`b`'],
   'multi value',
);

is_deeply(
   [$q->quote('`a`')],
   ['```a```'],
   'already quoted',
);

is_deeply(
   [$q->quote('a`b')],
   ['`a``b`'],
   'internal quote',
);
