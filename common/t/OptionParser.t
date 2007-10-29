#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 29;
use English qw(-no_match_vars);

require "../OptionParser.pm";

my @specs = (
   { s => 'defaultset!',       d => 'alignment test with a very long thing '
                                    . 'that is longer than 80 characters wide '
                                    . 'and must be wrapped' },
   { s => 'defaults-file|F=s', d => 'alignment test' },
   { s => 'dog|D=s',           d => 'Dogs are fun' },
   { s => 'foo!',              d => 'Foo' },
   { s => 'love|l+',           d => 'And peace' },
);

my $p = new OptionParser(@specs);
my %defaults = ( foo => 1 );
my %opts;
my %basic = ( version => undef, help => undef );

%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { %basic, foo => 1, D => undef, l => undef, F => undef, defaultset => undef },
   'Basics works'
);

@ARGV = qw(--nofoo);
%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { %basic, foo => 0, D => undef, l => undef, F => undef, defaultset => undef },
   'Negated foo'
);

@ARGV = qw(--nodog);
%opts = $p->parse(%defaults);
is_deeply(
   \%opts,
   { %basic, foo => 1, D => undef, help => 1, l => undef, F => undef, defaultset =>
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
   { %basic, foo => 1, D => undef, l => 3, F => undef, defaultset => undef },
   'More love'
);

is($p->usage,
<<EOF
  --defaults-file -F  alignment test
  --[no]defaultset    alignment test with a very long thing that is longer than
                      80 characters wide and must be wrapped
  --dog           -D  Dogs are fun
  --[no]foo           Foo
  --help              Show this help message
  --love          -l  And peace
  --version           Output version information and exit
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
  --help                Show this help message
  --[no]nouniquechecks  Set UNIQUE_CHECKS=0 before LOAD DATA INFILE
  --version             Output version information and exit
EOF
, 'Options aligned right when short options shorter than long'
);

$p = new OptionParser(
   { s => 'cat|C=s', d => 'How to catch the cat; required' }
);

%opts = $p->parse();
is_deeply(
   \%opts,
   { %basic, help => 1, C => undef },
   'Required option sets help',
);

is_deeply(
   $p->{notes},
   ['Required option --cat must be specified'],
   'Note set upon missing --cat',
);

is($p->usage,
<<EOF
  --cat  -C  How to catch the cat; required
  --help     Show this help message
  --version  Output version information and exit
Errors in command-line arguments:
Required option --cat must be specified
EOF
, 'There is a note after missing --cat');

@ARGV = qw(--cat net);
%opts = $p->parse();
is_deeply(
   \%opts,
   { %basic, C => 'net' },
   'Required option OK',
);

$p = new OptionParser(
      { s => 'ignore|i',    d => 'Use IGNORE for INSERT statements' },
      { s => 'replace|r',   d => 'Use REPLACE instead of INSERT statements' },
      '--ignore and --replace are mutually exclusive.',
);

is($p->usage, <<EOF
  --help        Show this help message
  --ignore  -i  Use IGNORE for INSERT statements
  --replace -r  Use REPLACE instead of INSERT statements
  --version     Output version information and exit
  --ignore and --replace are mutually exclusive.
EOF
, 'Usage with instructions');

@ARGV = qw(--replace);
%opts = $p->parse();
is_deeply(
   \%opts,
   { %basic, i => undef, r => 1 },
   '--replace does not trigger --help',
);

@ARGV = qw(--ignore --replace);
%opts = $p->parse();
is_deeply(
   \%opts,
   { %basic, help => 1, i => 1, r => 1 },
   '--ignore --replace triggers --help',
);

is_deeply(
   $p->{notes},
   ['--ignore and --replace are mutually exclusive.'],
   'Note set when instruction violated',
);

$p = new OptionParser(
      { s => 'ignore|i',    d => 'Use IGNORE for INSERT statements' },
      { s => 'replace|r',   d => 'Use REPLACE instead of INSERT statements' },
      { s => 'delete|d',    d => 'Delete' },
      '-ird are mutually exclusive.',
);

@ARGV = qw(--ignore --replace);
%opts = $p->parse();
is_deeply(
   \%opts,
   { %basic, help => 1, i => 1, r => 1, d => undef },
   '--ignore --replace triggers --help when short spec used',
);

is_deeply(
   $p->{notes},
   ['--ignore, --replace and --delete are mutually exclusive.'],
   'Note set with long opt name and nice commas when instruction violated',
);

eval {
   $p = new OptionParser(
         { s => 'ignore|i',    d => 'Use IGNORE for INSERT statements' },
         { s => 'replace|r',   d => 'Use REPLACE instead of INSERT statements' },
         { s => 'delete|d',    d => 'Delete' },
         'Use one and only one of --insert, --replace, or --delete.',
   );
};
like($EVAL_ERROR, qr/No such option --insert/, 'Bad option in one-and-only-one');

$p = new OptionParser(
      { s => 'ignore|i',    d => 'Use IGNORE for INSERT statements' },
      { s => 'replace|r',   d => 'Use REPLACE instead of INSERT statements' },
      { s => 'delete|d',    d => 'Delete' },
      'Use one and only one of --ignore, --replace, or --delete.',
);
@ARGV = qw(--ignore --replace);
%opts = $p->parse();

is_deeply(
   \%opts,
   { %basic, help => 1, i => 1, r => 1, d => undef },
   '--ignore --replace triggers --help for one-and-only-one',
);

is_deeply(
   $p->{notes},
   ['--ignore, --replace and --delete are mutually exclusive.'],
   'Note set with one-and-only-one',
);

$p = new OptionParser(
      { s => 'ignore|i',    d => 'Use IGNORE for INSERT statements' },
      { s => 'replace|r',   d => 'Use REPLACE instead of INSERT statements' },
      { s => 'delete|d',    d => 'Delete' },
      'Use one and only one of --ignore, --replace, or --delete.',
);
@ARGV = ();
%opts = $p->parse();
is_deeply(
   \%opts,
   { %basic, help => 1, i => undef, r => undef, d => undef },
   'Missing options triggers --help for one-and-only-one',
);

is_deeply(
   $p->{notes},
   ['Specify at least one of --ignore, --replace or --delete.'],
   'Note set with one-and-only-one when none specified',
);

$p = new OptionParser(
      { s => 'ignore|i',    d => 'Use IGNORE for INSERT statements' },
      { s => 'replace|r',   d => 'Use REPLACE instead of INSERT statements' },
      { s => 'delete|d',    d => 'Delete' },
      'Use at least one of --ignore, --replace, or --delete.',
);
@ARGV = ();
%opts = $p->parse();
is_deeply(
   \%opts,
   { %basic, help => 1, i => undef, r => undef, d => undef },
   'Missing options triggers --help for at-least-one',
);

is_deeply(
   $p->{notes},
   ['Specify at least one of --ignore, --replace or --delete.'],
   'Note set with at-least-one when none specified',
);

$p = new OptionParser(
      { s => 'ignore|i',    d => 'Use IGNORE for INSERT statements' },
      { s => 'replace|r',   d => 'Use REPLACE instead of INSERT statements' },
      { s => 'delete|d',    d => 'Delete' },
      'Use at least one of --ignore, --replace, or --delete.',
);
@ARGV = qw(-ir);
%opts = $p->parse();
is_deeply(
   \%opts,
   { %basic, help => undef, i => 1, r => 1, d => undef },
   'Multiple options OK for at-least-one',
);

# Defaults encoded in descriptions.
$p = new OptionParser(
   { s => 'foo=i', d => 'Foo (default 5)' },
   { s => 'bar',   d => 'Bar (default)' },
);
@ARGV = ();
%opts = $p->parse();
is_deeply(
   \%opts,
   { %basic, foo => 5, bar => 1 },
   'Defaults encoded in description',
);

$p = new OptionParser(
   { s => 'foo=m', d => 'Time' },
);
@ARGV = qw(--foo 5h);
%opts = $p->parse();
is_deeply(
   \%opts,
   { %basic, foo => 3600*5, },
   'Time value decoded',
);

@ARGV = qw(--foo 5z);
%opts = $p->parse();
is_deeply(
   \%opts,
   { %basic, foo => '5z', help => 1 },
   'Bad time value threw error',
);
is_deeply(
   $p->{notes},
   ['Invalid --foo argument'],
   'Bad time argument set note',
);
