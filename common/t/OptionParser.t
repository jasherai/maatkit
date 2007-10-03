#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;
use English qw(-no_match_vars);

require "../OptionParser.pm";

my @specs = (
   { s => 'foo!',    d => 'Foo' },
   { s => 'dog|D=s', d => 'Dogs are fun' },
);

my $p = new OptionParser(@specs);
my %defaults = ( foo => 1 );
my %opts;

%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { foo => 1, D => undef },
   'Basics works'
);

@ARGV = qw(--nofoo);
%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { foo => 0, D => undef },
   'Negated foo'
);

@ARGV = qw(--nodog);
%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { foo => 1, D => undef, help => 1 },
   'Bad dog'
);

$defaults{bone} = 1;
eval {
   %opts = $p->parse(%defaults);
};
is ($EVAL_ERROR, "No such option 'bone'\n", 'No bone');
