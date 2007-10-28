#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 14;
use English qw(-no_match_vars);

require "../OptionParser.pm";

my @specs = (
   { s => 'defaultset!',       d => 'alignment test' },
   { s => 'defaults-file|F=s', d => 'alignment test' },
   { s => 'dog|D=s',           d => 'Dogs are fun' },
   { s => 'foo!',              d => 'Foo' },
   { s => 'love|l+',           d => 'And peace' },
);

my $p = new OptionParser(@specs);
my %defaults = ( foo => 1 );
my %opts;

%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { foo => 1, D => undef, l => undef, F => undef, defaultset => undef },
   'Basics works'
);

@ARGV = qw(--nofoo);
%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { foo => 0, D => undef, l => undef, F => undef, defaultset => undef },
   'Negated foo'
);

@ARGV = qw(--nodog);
%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { foo => 1, D => undef, help => 1, l => undef, F => undef, defaultset =>
   undef },
   'Bad dog'
);

$defaults{bone} = 1;
eval {
   %opts = $p->parse(%defaults);
};
is ($EVAL_ERROR, "Cannot set default for non-existent option 'bone'\n", 'No bone');

delete $defaults{bone};
@ARGV = qw(--love -l -l);
%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { foo => 1, D => undef, l => 3, F => undef, defaultset => undef },
   'More love'
);

is($p->usage,
<<EOF
  --defaults-file -F  alignment test
  --[no]defaultset    alignment test
  --dog           -D  Dogs are fun
  --[no]foo           Foo
  --love          -l  And peace
EOF
, 'Options aligned right'
);

$p = new OptionParser(
      { s => 'database|D=s',      d => 'Specify the database for all tables' },
      { s => 'nouniquechecks!',   d => 'Set UNIQUE_CHECKS=0 before LOAD DATA INFILE' },
);
is($p->usage,
<<EOF
  --database        -D  Specify the database for all tables
  --[no]nouniquechecks  Set UNIQUE_CHECKS=0 before LOAD DATA INFILE
EOF
, 'Options aligned right when short options shorter than long'
);

$p = new OptionParser(
   { s => 'cat|C=s', d => 'How to catch the cat; required' }
);

%opts = $p->parse();
is_deeply(
   \%opts,
   { help => 1, C => undef },
   'Required option sets help',
);

is_deeply(
   $p->{notes},
   ['Required option --cat must be specified'],
   'Note set upon missing --cat',
);

is($p->usage,
<<EOF
  --cat -C  How to catch the cat; required
Errors while processing:
Required option --cat must be specified
EOF
, 'There is a note after missing --cat');

@ARGV = qw(--cat net);
%opts = $p->parse();
is_deeply(
   \%opts,
   { C => 'net' },
   'Required option OK',
);

$p = new OptionParser(
      { s => 'ignore|i',    d => 'Use IGNORE for INSERT statements' },
      { s => 'replace|r',   d => 'Use REPLACE instead of INSERT statements' },
      '--ignore and --replace are mutually exclusive',
);

@ARGV = qw(--replace);
%opts = $p->parse();
is_deeply(
   \%opts,
   { i => undef, r => 1 },
   '--replace does not trigger --help',
);

@ARGV = qw(--ignore --replace);
%opts = $p->parse();
is_deeply(
   \%opts,
   { help => 1, i => 1, r => 1 },
   '--ignore --replace triggers --help',
);

is_deeply(
   $p->{notes},
   [],
   'No note set when instruction violated',
);

