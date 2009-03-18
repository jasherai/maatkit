#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 83;

require "../OptionParser-2.pm";
require "../DSNParser.pm";

my $dp = new DSNParser();
my $o  = new OptionParser(
      description  => 'parses command line options.',
   prompt       => '[OPTIONS]',
   dsn          => $dp,
);

isa_ok($o, 'OptionParser');

my @opt_specs;
my %opts;

# #############################################################################
# Test basic usage.
# #############################################################################
@opt_specs = $o->_pod_to_specs('samples/pod_sample_01.txt');
is_deeply(
   \@opt_specs,
   [
      { spec => 'database|D=s', desc => 'database string'            },
      { spec => 'port|p=i',     desc => 'port (default 3306)'        },
      { spec => 'price=f',      desc => 'price float (default 1.23)' },
      { spec => 'hash-req=H',   desc => 'hash required'              },
      { spec => 'hash-opt=h',   desc => 'hash optional'              },
      { spec => 'array-req=A',  desc => 'array required'             },
      { spec => 'array-opt=a',  desc => 'array optional'             },
      { spec => 'host=d',       desc => 'host DSN'                   },
      { spec => 'chunk-size=z', desc => 'chunk size'                 },
      { spec => 'time=m',       desc => 'time'                       },
      { spec => 'help+',        desc => 'help cumulative'            },
      { spec => 'magic!',       desc => 'magic negatable'            },
   ],
   'Convert POD OPTIONS to opt specs (pod_sample_01.txt)',
);

%opts = $o->opts();
$o->_parse_specs(@opt_specs);
is_deeply(
   \%opts,
   {
      'database'   => {
         spec           => 'database|D=s',
         desc           => 'database string',
         group          => 'default',
         short          => 'D',
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 's',
         got            => 0,
         value          => undef,
      },
      'port'       => {
         spec           => 'port|p=i',
         desc           => 'port (default 3306)',
         group          => 'default',
         short          => 'p',
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 'i',
         got            => 0,
         value          => undef,
      },
      'price'      => {
         spec           => 'price=f',
         desc           => 'price float (default 1.23)',
         group          => 'default',
         short          => undef,
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 'f',
         got            => 0,
         value          => undef,
      },
      'hash-req'   => {
         spec           => 'hash-req=s',
         desc           => 'hash required',
         group          => 'default',
         short          => undef,
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 'H',
         got            => 0,
         value          => undef,
      },
      'hash-opt'   => {
         spec           => 'hash-opt=s',
         desc           => 'hash optional',
         group          => 'default',
         short          => undef,
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 'h',
         got            => 0,
         value          => undef,
      },
      'array-req'  => {
         spec           => 'array-req=s',
         desc           => 'array required',
         group          => 'default',
         short          => undef,
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 'A',
         got            => 0,
         value          => undef,
      },
      'array-opt'  => {
         spec           => 'array-opt=s',
         desc           => 'array optional',
         group          => 'default',
         short          => undef,
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 'a',
         got            => 0,
         value          => undef,
      },
      'host'       => {
         spec           => 'host=s',
         desc           => 'host DSN',
         group          => 'default',
         short          => undef,
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 'd',
         got            => 0,
         value          => undef,
      },
      'chunk-size' => {
         spec           => 'chunk-size=s',
         desc           => 'chunk size',
         group          => 'default',
         short          => undef,
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 'z',
         got            => 0,
         value          => undef,
      },
      'time'       => {
         spec           => 'time=s',
         desc           => 'time',
         group          => 'default',
         short          => undef,
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 'm',
         got            => 0,
         value          => undef,
      },
      'help'       => {
         spec           => 'help+',
         desc           => 'help cumulative',
         group          => 'default',
         short          => undef,
         is_cumulative  => 1,
         is_negatable   => 0,
         is_required    => 0,
         type           => undef,
         got            => 0,
         value          => undef,
      },
      'magic'      => {
         spec           => 'magic!',
         desc           => 'magic negatable',
         group          => 'default',
         short          => undef,
         is_cumulative  => 0,
         is_negatable   => 1,
         is_required    => 0,
         type           => undef,
         got            => 0,
         value          => undef,
      }
   },
   'Parse opt specs'
);

%opts = $o->short_opts();
is_deeply(
   \%opts,
   {
      'D' => 'database',
      'p' => 'port',
   },
   'Short opts => log opts'
);

# get() single option
is(
   $o->get('database'),
   undef,
   'Get valueless long opt'
);
is(
   $o->get('p'),
   undef,
   'Get valuless short opt'
);
eval { $o->get('foo'); };
like(
   $EVAL_ERROR,
   qr/Option --foo does not exist/,
   'Die trying to get() nonexistent long opt'
);
eval { $o->get('x'); };
like(
   $EVAL_ERROR,
   qr/Option -x does not exist/,
   'Die trying to get() nonexistent short opt'
);

# set()
$o->set('database', 'foodb');
is(
   $o->get('database'),
   'foodb',
   'Set long opt'
);
$o->set('p', 12345);
is(
   $o->get('p'),
   12345,
   'Set short opt'
);
eval { $o->set('foo', 123); };
like(
   $EVAL_ERROR,
   qr/Option --foo does not exist/,
   'Die trying to set() nonexistent long opt'
);
eval { $o->set('x', 123); };
like(
   $EVAL_ERROR,
   qr/Option -x does not exist/,
   'Die trying to set() nonexistent short opt'
);

# got()
@ARGV = qw(--port 12345);
is(
   $o->got('port'),
   1,
   'Got long opt'
);
is(
   $o->got('p'),
   1,
   'Got short opt'
);
is(
   $o->got('database'),
   1,
   'Did not "got" long opt'
);
is(
   $o->got('D'),
   1,
   'Did not "got" short opt'
);
is(
   $o->got('foo'),
   1,
   'Did not "got" nonexistent long opt'
);
is(
   $o->got('p'),
   1,
   'Did not "got" nonexistent short opt'
);

# Strict mode is enabled by default.
@ARGV = qw(--bar);
$o->get_opts();
is_deeply(
   $o->errors(),
   ['Option --bar does not exist'],
   'Nonexistent opt sets an error in strict mode'
);
ok(
   scalar $o->errors() == 0,
   'get_opts() resets errors'
);

$o->disable_strict_mode();

$o->get_opts();
eval { $o->get('bar'); };
like(
   $EVAL_ERROR,
   qr/Option --bar does not exist/,
   'Die trying to get nonexistent option when strict mode off'
); 

$o->enable_strict_mode();

# #############################################################################
# Test hostile, broken usage.
# #############################################################################
eval { $o->_pod_to_specs('samples/pod_sample_02.txt'); };
like(
   $EVAL_ERROR,
   qr/POD has no valid specs/,
   'Dies on POD without an OPTIONS section'
);

eval { $o->_pod_to_specs('samples/pod_sample_03.txt'); };
like(
   $EVAL_ERROR,
   qr/POD has no valid specs/,
   'Dies on POD with an OPTIONS section but no option items'
);

eval { $o->_pod_to_specs('samples/pod_sample_04.txt'); };
like(
   $EVAL_ERROR,
   qr/No description found for option foo at paragraph/,
   'Dies on option with no description'
);

# TODO: more hostile tests: duplicate opts, can't parse long opt from spec,
# unrecognized rules, ...

# #############################################################################
# Test passed-in option defaults.
# #############################################################################
$o->_parse_specs(
   {
      spec => 'defaultset!',
      desc => 'alignment test with a very long thing '
            . 'that is longer than 80 characters wide '
            . 'and must be wrapped'
   },
   { spec => 'defaults-file|F=s', desc => 'alignment test'  },
   { spec => 'dog|D=s',           desc => 'Dogs are fun'    },
   { spec => 'foo!',              desc => 'Foo'             },
   { spec => 'love|l+',           desc => 'And peace'       },
);

$o->set_defaults('foo' => 1);

# We could just check that $o->get('foo') == 1, but the
# whole opts hash is checked for thoroughness.
%opts = $o->opts();
is_deeply(
   \%opts,
   {
      'foo'           => {
         spec           => 'foo!',
         desc           => 'FOo',
         group          => 'default',
         short          => undef,
         is_cumulative  => 0,
         is_negatable   => 1,
         is_required    => 0,
         type           => undef,
         got            => 0,
         value          => 1,
      },
      'defaultset'    => {
         spec           => 'defaultset!',
         desc           => 'alignment test with a very long thing '
                         . 'that is longer than 80 characters wide '
                         . 'and must be wrapped',
         group          => 'default',
         short          => undef,
         is_cumulative  => 0,
         is_negatable   => 1,
         is_required    => 0,
         type           => undef,
         got            => 0,
         value          => undef,
      },
      'defaults-file' => {
         spec           => 'defaults-file|F=s',
         desc           => 'alignment test',
         group          => 'default',
         short          => 'F',
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 's',
         got            => 0,
         value          => undef,
      },
      'dog'           => {
         spec           => 'dog|D=s',
         desc           => 'Dogs are fun',
         group          => 'default',
         short          => 'D',
         is_cumulative  => 0,
         is_negatable   => 0,
         is_required    => 0,
         type           => 's',
         got            => 0,
         value          => undef,
      },
      'love'          => {
         spec           => 'love|l+',
         desc           => 'And love',
         group          => 'default',
         short          => 'l',
         is_cumulative  => 1,
         is_negatable   => 0,
         is_required    => 0,
         type           => undef,
         got            => 0,
         value          => undef,
      },
   },
   'Parse dog specs with defaults'
);

$o->set_defaults('bone' => 1);
eval { $o->_parse_specs(@opt_specs); };
is(
   $EVAL_ERROR,
   "Cannot set default for non-existent option 'bone'\n",
   'Cannot set default for non-existent option'
);

# #############################################################################
# Test option attributes negatable and cumulative.
# #############################################################################

# These tests use the dog opt specs from above.

@ARGV = qw(--nofoo);
$o->get_opts();
is(
   $o->get('foo'),
   0,
   'Can negate negatable opt'
);

@ARGV = qw(--nodog);
$o->get_opts();
is_deeply(
   $o->get('dog'),
   undef,
   'Cannot negate non-negatable opt'
);
is_deeply(
   $o->errors(),
   ['Cannot negate non-negatable option --dog'],
   'Trying to negate non-negatable opt sets an error'
);

@ARGV = qw(--love -l -l);
$o->get_opts();
is(
   $o->get('love'),
   3,
   'Cumulative opt val increases (--love -l -l)'
);
is(
   $o->got('love'),
   1,
   "got('love') when given multiple times short and long"
);

@ARGV = qw(--love);
$o->get_opts();
is(
   $o->got('love'),
   1,
   "got('love') long once"
);

@ARGV = qw(-l);
$o->get_opts();
is(
   $o->got('l'),
   1,
   "got('l') short once"
);


# #############################################################################
# Test usage output.
# #############################################################################

# The following one test uses the dog opt specs from above.

is(
   $o->usage(),
<<EOF
OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc OptionParser.t' for complete documentation.

Usage: OptionParser.t [OPTIONS]

Options:
  --defaults-file -F  alignment test
  --[no]defaultset    alignment test with a very long thing that is longer than
                      80 characters wide and must be wrapped
  --dog           -D  Dogs are fun
  --[no]foo           Foo
  --love          -l  And peace

Options and values after processing arguments:
  --defaults-file     (No value)
  --defaultset        FALSE
  --dog               (No value)
  --foo               FALSE
  --love              (No value)
EOF
,
   'Options aligned and prompt included'
);

$o->_parse_specs(
   { spec => 'database|D=s',    desc => 'Specify the database for all tables' },
   { spec => 'nouniquechecks!', desc => 'Set UNIQUE_CHECKS=0 before LOAD DATA INFILE' },
);

$o->set_prompt(undef);

is(
   $o->usage(),
<<EOF
OptionParser.t parses command line options. For more details, please use the --help option, or try 'perldoc OptionParser.t' for complete documentation.

Usage: OptionParser.t <options>

Options:
  --database        -D  Specify the database for all tables
  --help                Show this help message
  --[no]nouniquechecks  Set UNIQUE_CHECKS=0 before LOAD DATA INFILE
  --version             Output version information and exit

Options and values after processing arguments:
  --database            (No value)
  --nouniquechecks      FALSE
EOF
,
   'Really long option aligns with shorts, and prompt defaults to <options>'
);

# #############################################################################
# Test _get_participants()
# #############################################################################
is_deeply(
   [$o->_get_participants('L<"--foo"> disables --bar-bar and C<--baz>')],
   [qw(foo bar-bar baz)],
   'Extract option names from a string',
);

is_deeply(
   [$o->_get_participants('L<"--foo"> disables L<"--[no]bar-bar">.'],
   [qw(foo bar-bar)],
   'Extract [no]-negatable option names from a string',
);
# TODO: test w/ opts that don't exist, or short opts

# #############################################################################
# Test required options.
# #############################################################################
$o->_parse_specs(
   { spec => 'cat|C=s', desc => 'How to catch the cat; required' }
);

@ARGV = ();
$o->get_opts();
is_deeply(
   $o->errors(),
   ['Required option --cat must be specified'],
   'Missing required option sets an error',
);

$o->set_prompt('foofoo');
$o->set_description('barbar');

is(
   @{$o->errors()}[0],
<<EOF
Usage: OptionParser.t foofoo

Errors in command-line arguments:
  * Required option --cat must be specified

OptionParser.t barbar  For more details, please use the --help option, or try
'perldoc OptionParser.t' for complete documentation.
EOF
,
   'Error output includes note about missing required option'
);

@ARGV = qw(--cat net);
$o->get_opts();
is(
   $o->get('cat'),
   'net',
   'Required option OK',
);

# #############################################################################
# Test option rules.
# #############################################################################
$o->_parse_specs(
   { spec => 'ignore|i',  desc => 'Use IGNORE for INSERT statements'         },
   { spec => 'replace|r', desc => 'Use REPLACE instead of INSERT statements' },
   '--ignore and --replace are mutually exclusive.',
);

$o->set_prompt(undef);
$o->set_description(undef);
$o->set_defaults();

is(
   $o->usage(),
<<EOF
OptionParser.t   For more details, please use the --help option, or try 'perldoc
OptionParser.t' for complete documentation.

Usage: OptionParser.t <options>

Options:
  --ignore  -i  Use IGNORE for INSERT statements
  --replace -r  Use REPLACE instead of INSERT statements
  --ignore and --replace are mutually exclusive.

Options and values after processing arguments:
  --ignore      FALSE
  --replace     FALSE
EOF
,
   'Usage with rules'
);

@ARGV = qw(--replace);
$o->get_opts();
ok(
   scalar $o->errors() == 0,
   '--replace does not trigger an error',
);

@ARGV = qw(--ignore --replace);
$o->get_opts();
is_deeply(
   $o->errors(),
   ['--ignore and --replace are mutually exclusive.'],
   'Error set when rule violated',
);

# These are used several times in the follow tests.
my @ird_specs = (
   { spec => 'ignore|i',   desc => 'Use IGNORE for INSERT statements'         },
   { spec => 'replace|r',  desc => 'Use REPLACE instead of INSERT statements' },
   { spec => 'delete|d',   desc => 'Delete'                                   },
);

$o->_parse_specs(
   @ird_specs,
   '-ird are mutually exclusive.',
);
@ARGV = qw(--ignore --replace);
$o->get_opts();
is_deeply(
   $o->errors(),
   ['--ignore, --replace and --delete are mutually exclusive.'],
   'Error set with long opt name and nice commas when rule violated',
);

eval {
   $o->_parse_specs(
      @ird_specs,
     'Use one and only one of --insert, --replace, or --delete.',
   );
};
like(
   $EVAL_ERROR,
   qr/No such option 'insert'/,
   'Die on using nonexistent option in one-and-only-one rule'
);

$o->_parse_specs(
   @ird_specs,
   'Use one and only one of --ignore, --replace, or --delete.',
);
@ARGV = qw(--ignore --replace);
$o->get_opts();
is_deeply(
   $o->errors(),
   ['--ignore, --replace and --delete are mutually exclusive.'],
   'Error set with one-and-only-one rule violated',
);

$o->_parse_specs(
   @ird_specs,
   'Use one and only one of --ignore, --replace, or --delete.',
);
@ARGV = ();
$o->get_opts();
is_deeply(
   $o->errors(),
   ['Specify at least one of --ignore, --replace or --delete'],
   'Error set with one-and-only-one when none specified',
);

$o->_parse_specs(
   @ird_specs,
   'Use at least one of --ignore, --replace, or --delete.',
);
@ARGV = ();
$o->get_opts();
is_deeply(
   $o->errors(),
   ['Specify at least one of --ignore, --replace or --delete'],
   'Error set with at-least-one when none specified',
);

$o->_parse_specs(
   @ird_specs,
   'Use at least one of --ignore, --replace, or --delete.',
);
@ARGV = qw(-ir);
$o->get_opts();
ok(
   $o->get('insert') == 1 && $o->get('replace') == 1,
   'Multiple options OK for at-least-one',
);

$o->_parse_specs(
   { specs => 'foo=i', desc => 'Foo disables --bar'   },
   { specs => 'bar',   desc => 'Bar (default 1)'      },
);
@ARGV = qw(--foo 5);
$o->get_opts();
is_deeply(
   $o->get('foo') == 5 && $o->get('bar') == undef,
   '--foo disables --bar',
);

# Option can't disable a non-existent option.
eval {
   $o->_parse_specs(
      { spec => 'foo=i', desc => 'Foo disables --fox' },
      { spec => 'bar',   desc => 'Bar (default 1)'    },
   );
};
like(
   $EVAL_ERROR,
   qr/No such option 'fox' while processing foo/,
   'Invalid option name in disable rule',
);

# Option can't 'allowed with' a non-existent option.
eval {
   $o->_parse_specs(
      { spec => 'foo=i', d => 'Foo disables --bar' },
      { spec => 'bar',   d => 'Bar (default 1)'    },
      'allowed with --foo: --fox',
   );
};
like(
   $EVAL_ERROR,
   qr/No such option 'fox' while processing allowed with --foo: --fox/,
   'Invalid option name in \'allowed with\' rule',
);

# #############################################################################
# Test default values encoded in description.
# #############################################################################
$o->_parse_specs(
   { spec => 'foo=i',   desc => 'Foo (default 5)'                 },
   { spec => 'bar',     desc => 'Bar (default)'                   },
   { spec => 'price=f', desc => 'Price (default 12345.123456)'    },
   { spec => 'size=z',  desc => 'Size (default 128M)'             },
   { spec => 'time=m',  desc => 'Time (default 24h)'              },
   { spec => 'host=d',  desc => 'Host (default h=127.1,P=12345)'  },
);
@ARGV = ();
$o->get_opts();
is(
   $o->get('foo'),
   5,
   'Default integer value encoded in description'
);
is(
   $o->get('bar'),
   1,
   'Default option enabled encoded in description'
);
is(
   $o->get('price'),
   12345.123456,
   'Default float value encoded in description'
);
is(
   $o->get('size'),
   134217728,
   'Default size value encoded in description'
);
is(
   $o->get('time'),
   86400,
   'Default time value encoded in description'
);
is_deeply(
   $o->get('host'),
   {
      S => undef,
      F => undef,
      A => undef,
      p => undef,
      u => undef,
      h => '127.1',
      D => undef,
      P => '12345'
   },
   'Default time value encoded in description'
);

# #############################################################################
# Test size option type.
# #############################################################################
$o->_parse_specs(
   { spec => 'size=z', desc => 'size' }
);

@ARGV = qw(--size 5k);
$o->get_opts();
is_deeply(
   $o->get('size'),
   1024*5,
   '5K expanded',
);

@ARGV = qw(--size -5k);
$o->get_opts();
is_deeply(
   $o->get('size'),
   -1024*5,
   '-5K expanded',
);

@ARGV = qw(--size +5k);
$o->get_opts();
is_deeply(
   $o->get('size'),
   '+' . (1024*5),
   '+5K expanded',
);

@ARGV = qw(--size 5);
$o->get_opts();
is_deeply(
   $o->get('size'),
   5,
   '5 expanded',
);

@ARGV = qw(--size 5z);
$o->get_opts();
is_deeply(
   $o->errors(),
   ['Invalid --size argument'],
   'Bad size argument sets an error',
);

# #############################################################################
# Test time option type.
# #############################################################################
$o->_parse_specs(
   { spec => 't=m', desc => 'Time'            },
   { spec => 's=m', desc => 'Time (suffix s)' },
   { spec => 'm=m', desc => 'Time (suffix m)' },
   { spec => 'h=m', desc => 'Time (suffix h)' },
   { spec => 'd=m', desc => 'Time (suffix d)' },
);

@ARGV = qw(-t 10 -s 20 -m 30 -h 40 -d 50);
$o->get_opts();
is_deeply(
   $o->get('t'),
   10,
   'Time value with default suffix decoded',
);
is_deeply(
   $o->get('s'),
   20,
   'Time value with s suffix decoded',
);
is_deeply(
   $o->get('m'),
   30*60,
   'Time value with m suffix decoded',
);
is_deeply(
   $o->get('h'),
   40*3600,
   'Time value with h suffix decoded',
);
is_deeply(
   $o->get('d'),
   50*86400,
   'Time value with d suffix decoded',
);

# Use shorter, simpler specs to test usage for time blurb.
$o->_parse_specs(
   { spec => 'foo=m', desc => 'Time' },
   { spec => 'bar=m', desc => 'Time (suffix m)' },
);

is(
   $o->usage(),
<<EOF
OptionParser.t   For more details, please use the --help option, or try 'perldoc
OptionParser.t' for complete documentation.

Usage: OptionParser.t <options>

Options:
  --bar      Time.  Optional suffix s=seconds, m=minutes, h=hours, d=days; if no
             suffix, m is used.
  --foo      Time.  Optional suffix s=seconds, m=minutes, h=hours, d=days; if no
             suffix, s is used.

Options and values after processing arguments:
  --bar      (No value)
  --foo      (No value)
EOF
,
   'Usage for time value');

@ARGV = qw(--foo 5z);
$o->get_opts();
is_deeply(
   $o->errors(),
   ['Invalid --foo argument'],
   'Bad time argument sets an error',
);

# #############################################################################
# Test DSN option type.
# #############################################################################
$o->_parse_specs(
   { spec => 'foo=d', desc => 'DSN foo' },
   { spec => 'bar=d', desc => 'DSN bar' },
   'DSN values in --foo default to values in --bar if COPY is yes.',
);

is(
   $o->usage(),
<<EOF
OptionParser.t   For more details, please use the --help option, or try 'perldoc
OptionParser.t' for complete documentation.

Usage: OptionParser.t <options>

Options:
  --bar      DSN bar
  --foo      DSN foo
  DSN values in --foo default to values in --bar if COPY is yes.

DSN syntax is key=value[,key=value...]  Allowable DSN keys:
  KEY  COPY  MEANING
  ===  ====  =============================================
  A    yes   Default character set
  D    yes   Database to use
  F    yes   Only read default options from the given file
  P    yes   Port number to use for connection
  S    yes   Socket file to use for connection
  h    yes   Connect to host
  p    yes   Password to use when connecting
  u    yes   User for login if not current user

Options and values after processing arguments:
  --bar      (No value)
  --foo      (No value)
EOF
,
   'DSN is integrated into help output'
);

@ARGV = ('--bar', 'D=DB,u=USER,h=localhost', '--foo', 'h=otherhost');
$o->get_opts();
is_deeply(
   $o->get('bar'),
   {
      D => 'DB',
      u => 'USER',
      S => undef,
      F => undef,
      P => undef,
      h => 'localhost',
      p => undef,
      A => undef,
   },
   'DSN parsing on type=d',
);
is_deeply(
   $o->get('foo'),
   {
      D => 'DB',
      u => 'USER',
      S => undef,
      F => undef,
      P => undef,
      h => 'otherhost',
      p => undef,
      A => undef,
   },
   'DSN parsing on type=d inheriting from --bar',
);

is(
   $o->usage(%opts),
<<EOF
OptionParser.t   For more details, please use the --help option, or try 'perldoc
OptionParser.t' for complete documentation.

Usage: OptionParser.t <options>

Options:
  --bar      DSN bar
  --foo      DSN foo
  --help     Show this help message
  --version  Output version information and exit
  DSN values in --foo default to values in --bar if COPY is yes.

DSN syntax is key=value[,key=value...]  Allowable DSN keys:
  KEY  COPY  MEANING
  ===  ====  =============================================
  A    yes   Default character set
  D    yes   Database to use
  F    yes   Only read default options from the given file
  P    yes   Port number to use for connection
  S    yes   Socket file to use for connection
  h    yes   Connect to host
  p    yes   Password to use when connecting
  u    yes   User for login if not current user

Options and values after processing arguments:
  --bar      D=DB,h=localhost,u=USER
  --foo      D=DB,h=otherhost,u=USER
  --help     FALSE
  --version  FALSE
EOF
,
   'DSN stringified with inheritance into post-processed args'
);

$o->_parse_specs(
   { spec => 'foo|f=d', desc => 'DSN foo' },
   { spec => 'bar|b=d', desc => 'DSN bar' },
   'DSN values in --foo default to values in --bar if COPY is yes.',
);
@ARGV = ('-b', 'D=DB,u=USER,h=localhost', '-f', 'h=otherhost');
$o->get_opts();
is_deeply(
   $o->get('f'),
   {
      D => 'DB',
      u => 'USER',
      S => undef,
      F => undef,
      P => undef,
      h => 'otherhost',
      p => undef,
      A => undef,
   },
   'DSN parsing on type=d inheriting from --bar with short options',
);

# #############################################################################
# Test [Hh]ash and [Aa]rray option types.
# #############################################################################
$o->_parse_specs(
   { spec => 'columns|C=H',   desc => 'cols required'       },
   { spec => 'tables|t=h',    desc => 'tables optional'     },
   { spec => 'databases|d=A', desc => 'databases required'  },
   { spec => 'books|b=a',     desc => 'books optional'      },
);

@ARGV = ();
$o->get_opts();
%opts = $o->get(qw(C t d b));
is_deeply(
   \%opts,
   { 
      C => {},
      t => undef,
      d => [],
      b => undef,
   },
   'Comma-separated lists: uppercase created even when not given',
);

@ARGV = ('-C', 'a,b', '-t', 'd,e', '-d', 'f,g', '-b', 'o,p' );
$o->get_opts();
%opts = $o->get(qw(C t d b));
is_deeply(
   \%opts,
   {
      C => { a => 1, b => 1 },
      t => { d => 1, e => 1 },
      d => [qw(f g)],
      b => [qw(o p)],
   },
   'Comma-separated lists: all processed when given',
);

is(
   $o->usage(%opts),
<<EOF
OptionParser.t   For more details, please use the --help option, or try 'perldoc
OptionParser.t' for complete documentation.

Usage: OptionParser.t <options>

Options:
  --books     -b  Comma-separated list of books to output
  --columns   -C  Comma-separated list of columns to output
  --databases -d  Comma-separated list of databases to output
  --help          Show this help message
  --tables    -t  Comma-separated list of tables to output
  --version       Output version information and exit

Options and values after processing arguments:
  --books         o,p
  --columns       a,b
  --databases     f,g
  --help          FALSE
  --tables        d,e
  --version       FALSE
EOF
,
   'Lists properly expanded into usage information',
);

# #############################################################################
# Test groups.
# #############################################################################

# TODO: refine these tests after I think more about how
# groups will be implemented.

$o->_parse_specs(
   { spec  => 'help',   desc  => 'Help',                         },
   { spec  => 'user=s', desc  => 'User',                         },
   { spec  => 'dog',    desc  => 'dog option', group => 'Dogs',  },
   { spec  => 'cat',    desc  => 'cat option', group => 'Cats',  },
);

@ARGV = ();
$o->get_opts();
is(
   $o->usage(%opts),
<<EOF
OptionParser.t   For more details, please use the --help option, or try 'perldoc
OptionParser.t' for complete documentation.

Usage: OptionParser.t <options>

Options:
  --help          Help
  --user          user

Dogs:
  --dog           dog option

Cats:
  --cat           cat option

Options and values after processing arguments:
  --cat           FALSE
  --dog           FALSE
  --help          FALSE
  --user          FALSE
EOF
,
   'Option groupings usage',
);

@ARGV = qw(--user foo --dog);
$o->get_opts();
is(
   $o->get('user') eq 'foo' && $o->get('dog') == 1,
   'Grouped option allowed with default group option'
);

@ARGV = qw(--dog --cat);
eval { $o->get_opts(); };
like(
   $EVAL_ERROR,
   qr/Option --cat is not allowed with option --dog/,
   'Options from different non-default groups not allowed together'
);

# #############################################################################
# Test issues. Any other tests should find their proper place above.
# #############################################################################

# #############################################################################
# Issue 140: Check that new style =item --[no]foo works like old style:
#    =item --foo
#    negatable: yes
# #############################################################################
@opt_specs = $o->_pod_to_spec("samples/pod_sample_issue_140.txt");
is_deeply(
   \@opt_specs,
   [
      { spec => 'foo',   desc => 'Basic foo'          },
      { spec => 'bar!',  desc => 'New negatable bar'  },
   ],
   'New =item --[no]foo style for negatables'
);

# #############################################################################
# Issue 92: extract a paragraph from POD.
# #############################################################################
is(
   $o->_read_para_after("samples/pod_sample_issue_92.txt", qr/magic/),
   'This is the paragraph, hooray',
   'read_para_after'
);

# The first time I wrote this, I used the /o flag to the regex, which means you
# always get the same thing on each subsequent call no matter what regex you
# pass in.  This is to test and make sure I don't do that again.
is(
   $o->read_para_after("samples/podsample_issue92.txt", qr/abracadabra/),
   'This is the next paragraph, hooray',
   'read_para_after again'
);

exit;
