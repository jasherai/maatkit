#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 6;
use English qw(-no_match_vars);

require "../OptionParser.pm";

my @specs = (
   { s => 'foo!',    d => 'Foo' },
   { s => 'dog|D=s', d => 'Dogs are fun' },
   { s => 'love|l+', d => 'And peace' },
);

my $p = new OptionParser(@specs);
my %defaults = ( foo => 1 );
my %opts;

%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { foo => 1, D => undef, l => undef },
   'Basics works'
);

@ARGV = qw(--nofoo);
%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { foo => 0, D => undef, l => undef },
   'Negated foo'
);

@ARGV = qw(--nodog);
%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { foo => 1, D => undef, help => 1, l => undef },
   'Bad dog'
);

$defaults{bone} = 1;
eval {
   %opts = $p->parse(%defaults);
};
is ($EVAL_ERROR, "No such option 'bone'\n", 'No bone');

delete $defaults{bone};
@ARGV = qw(--love -l -l);
%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { foo => 1, D => undef, l => 3 },
   'More love'
);

is($p->usage,
'  --dog     -D   Dogs are fun
  --[no]foo      Foo
  --love    -l   And peace
',
   'Use me'
);
