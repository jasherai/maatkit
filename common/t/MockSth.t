#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use MockSth;
use MaatkitTest;

my $m;

$m = new MockSth();

is($m->{Active}, 0, 'Empty is not active');
is($m->fetchrow_hashref(), undef, 'Cannot fetch from empty');

$m = new MockSth(
   { a => 1 },
);
ok($m->{Active}, 'Has rows, is active');
is_deeply($m->fetchrow_hashref(), { a => 1 }, 'Got the row');
is($m->{Active}, '', 'Not active after fetching');
is($m->fetchrow_hashref(), undef, 'Cannot fetch from empty');

exit;
