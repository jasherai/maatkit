#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

require "../MockSth.pm";

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $pat, $msg );
}

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
