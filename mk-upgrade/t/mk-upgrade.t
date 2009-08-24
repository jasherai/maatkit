#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 24;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../mk-upgrade';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh1 = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $dbh2 = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

$sb->create_dbs($dbh1, [qw(test)]);
$sb->load_file('master', '../../common/t/samples/issue_11.sql');
$dbh1->do('INSERT INTO test.issue_11 VALUES (1,2,3),(2,2,3),(3,1,1),(4,5,0)');

my @hosts = ('h=127.1,P=12345', 'h=127.1,P=12346');

my $o = new OptionParser(
   'description' => 'mk-upgrade',
);
$o->get_specs('../mk-upgrade');
$o->get_opts();
my $qparser = new QueryParser();
my $tp      = new TableParser();
my $q       = new Quoter();
my $du      = new MySQLDump();
my $syncer  = new TableSyncer();
my $chunker  = new TableChunker( quoter => $q );
my $nibbler  = new TableNibbler();
my $checksum = new TableChecksum();
my $vp       = new VersionParser();
my %common_modules = (
   OptionParser => $o,
   QueryParser  => $qparser,
   TableParser  => $tp,
   Quoter       => $q,
   MySQLDump    => $du,
   TableSyncer  => $syncer,
   TableChunker => $chunker,
   TableNibbler => $nibbler,
   TableChecksum => $checksum,
   VersionParser => $vp,
);

sub output {
   my $output = '';
   open my $output_fh, '>', \$output
      or BAIL_OUT("Cannot capture output to variable: $OS_ERROR");
   select $output_fh;
   eval { mk_upgrade::main(@_); };
   close $output_fh;
   select STDOUT;
   return $EVAL_ERROR ? $EVAL_ERROR : $output;
}

# Returns true (1) if there's no difference between the
# cmd's output and the expected output.
sub test_no_diff {
   my ( $expected_output, @cmd_args ) = @_;
   my $tmp_file = '/tmp/mk-upgrade-test.txt';
   open my $fh, '>', $tmp_file or die "Can't open $tmp_file: $OS_ERROR";
   my $output = normalize(output(@cmd_args));
   print $fh $output;
   close $fh;
   # Uncomment this line to update the $expected_output files when there is a
   # fix.
   # `cat $tmp_file > $expected_output`;
   my $retval = system("diff $tmp_file $expected_output");
   `rm -rf $tmp_file`;
   $retval = $retval >> 8; 
   return !$retval;
}

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

sub normalize {
   my ( $output ) = @_;
   # Zero out vals that change.
   $output =~ s/Query_time: (\S+)/Query_time: 0.000000/g;
   $output =~ s/line (\d+)/line 0/g;
   return $output;
}

# #############################################################################
# Test that it runs.
# #############################################################################
my $output = `../mk-upgrade --help`;
like(
   $output,
   qr/--ask-pass/,
   'It runs'
);

# #############################################################################
# Test diff_rows().
# #############################################################################
diag(`/tmp/12345/use -e 'CREATE DATABASE test' 2>/dev/null`);
$sb->load_file('master', 'samples/diff_results_host1.sql');
$sb->load_file('slave1', 'samples/diff_results_host2.sql');

my $struct = {
   col_posn   => { c => 1, i => 0 },
   cols       => ['i', 'c'],
   is_col     => { c => 1,  i => 1 },
   is_numeric => { c => 0,  i => 1 },
   type_for   => { c => 'char',  i => 'integer'  },
};

my ($missing, $diff) = mk_upgrade::diff_rows(
   hosts    => [{ dbh => $dbh1 }, { dbh => $dbh2 }],
   outfiles => [qw(samples/diff_1-1_outfile.txt samples/diff_1-2_outfile.txt)],
   event    => {
      arg => 'SELECT * FROM diff_results.diff_1',
      db  => 'test',
   },
   struct   => $struct,
   %common_modules,
);
is_deeply(
   $missing,
      [
        [
          {
            __maatkit_count => '1',
            c => 'c',
            i => '3'
          },
          undef
        ],
        [
          {
            __maatkit_count => '1',
            c => 'e',
            i => '5'
          },
          undef
        ],
        [
          {
            __maatkit_count => '1',
            c => 'f',
            i => '6'
          },
          undef
        ],
        [
          {
            __maatkit_count => '1',
            c => 'g',
            i => '7'
          },
          undef
        ]
      ],
   'diff 1 missing'
);
is_deeply(
   $diff,
   [],
   'diff 1 different'
);

($missing, $diff) = mk_upgrade::diff_rows(
   hosts    => [{ dbh => $dbh1 }, { dbh => $dbh2 }],
   outfiles => [qw(samples/diff_2-1_outfile.txt samples/diff_2-2_outfile.txt)],
   event    => {
      arg => 'SELECT * FROM diff_results.diff_2',
      db  => 'test',
   },
   struct   => $struct,
   %common_modules,
);
is_deeply(
   $missing,
   [
      [
         undef,
         {
            __maatkit_count => '1',
            c => 'b',
            i => '2'
         },
      ],
      [
         {
            __maatkit_count => '1',
            c => 'a',
            i => '5'
         },
         undef,
      ],
   ],
   'diff 2 missing'
);
is_deeply(
   $diff,
   [
      [
         {
            __maatkit_count => '1',
            c => 'l',
            i => '4'
         },
         {
            __maatkit_count => '1',
            c => 'r',
            i => '4'
         },
         [
            'c',
            'l',
            'r'
         ],
      ],
   ],
   'diff 2 different'
);

($missing, $diff) = mk_upgrade::diff_rows(
   hosts    => [{ dbh => $dbh1 }, { dbh => $dbh2 }],
   outfiles => [qw(samples/diff_3-1_outfile.txt samples/diff_3-2_outfile.txt)],
   event    => {
      arg => 'SELECT * FROM diff_results.diff_3',
      db  => 'test',
   },
   struct   => $struct,
   %common_modules,
);
is_deeply(
   $missing,
   [
      [
         undef,
         {
            __maatkit_count => '1',
            c => 'b',
            i => '2'
         },
      ],
   ],
   'diff 3 missing'
);
is_deeply(
   $diff,
   [
      [
         {
            __maatkit_count => '1',
            c => 'l',
            i => '4'
         },
         {
            __maatkit_count => '1',
            c => 'r',
            i => '4'
         },
         [
            'c',
            'l',
            'r'
         ],
      ],
   ],
   'diff 3 different'
);

@ARGV=qw(--max-differences 5);
$o->get_opts();
($missing, $diff) = mk_upgrade::diff_rows(
   hosts    => [{ dbh => $dbh1 }, { dbh => $dbh2 }],
   outfiles => [qw(samples/diff_4-1_outfile.txt samples/diff_4-2_outfile.txt)],
   event    => {
      arg => 'SELECT * FROM diff_results.diff_4',
      db  => 'test',
   },
   struct   => $struct,
   %common_modules,
);
is_deeply(
   $missing,
   [
      [
        undef,
        {
          __maatkit_count => '1',
          c => 'b',
          i => '2'
        }
      ],
      [
        {
          __maatkit_count => '1',
          c => 'g',
          i => '7'
        },
        undef
      ],
      [
        {
          __maatkit_count => '1',
          c => 'g',
          i => '8'
        },
        undef
      ],
   ],
   'diff 4 missing with --max-differences'
);
is_deeply(
   $diff,
   [
      [
        {
          __maatkit_count => '1',
          c => 'c',
          i => '3'
        },
        {
          __maatkit_count => '1',
          c => 'b',
          i => '3'
        },
        [
          'i',
          3,
          4
        ]
      ],
      [
        {
          __maatkit_count => '1',
          c => '',
          i => '5'
        },
        {
          __maatkit_count => '1',
          c => 'e',
          i => '5'
        },
        [
          'c',
          '',
          'e'
        ]
      ]
   ],
   'diff 4 different with --max-differences'
);

# Reset opts
@ARGV=();
$o->get_opts();

my $diff_5_struct = {
   col_posn => {
     dbl => 1,
     dec => 2,
     flo => 0
   },
   cols => [
     'flo',
     'dbl',
     'dec'
   ],
   is_col => {
     dbl => 1,
     dec => 1,
     flo => 1
   },
   is_nullable => {
     dbl => 1,
     dec => 1,
     flo => 1
   },
   is_numeric => {
     dbl => 1,
     dec => 1,
     flo => 1
   },
   precision => {
     dbl => '(12,10)',
     dec => '(14,10)',
     flo => '(12,10)'
   },
   type_for => {
     dbl => 'double',
     dec => 'decimal',
     flo => 'float'
   },
};
($missing, $diff) = mk_upgrade::diff_rows(
   hosts    => [{ dbh => $dbh1 }, { dbh => $dbh2 }],
   outfiles => [qw(samples/diff_5-1_outfile.txt samples/diff_5-2_outfile.txt)],
   event    => {
      arg => 'SELECT * FROM diff_results.diff_5',
      db  => 'test',
   },
   struct   => $diff_5_struct,
   %common_modules,
);
is_deeply(
   $missing,
   [],
   'diff 5 missing no --float-precision'
);
ok(
   scalar @$diff,
   'diff 5 different no --float-precision'
);

@ARGV=qw(--float-precision 6);
$o->get_opts();
($missing, $diff) = mk_upgrade::diff_rows(
   hosts    => [{ dbh => $dbh1 }, { dbh => $dbh2 }],
   outfiles => [qw(samples/diff_5-1_outfile.txt samples/diff_5-2_outfile.txt)],
   event    => {
      arg => 'SELECT * FROM diff_results.diff_5',
      db  => 'test',
   },
   struct   => $diff_5_struct,
   %common_modules,
);
is_deeply(
   $missing,
   [],
   'diff 5 missing --float-precision 6'
);
is_deeply(
   $diff,
   [],
   'diff 5 different --float-precision 6'
);

# #############################################################################
# Test make_table_ddl().
# #############################################################################
$struct = {
   cols => [
      'id',
      'i',
      'f',
      'd',
      'dt',
      'ts',
      'c',
      'v',
      't',
   ],
   type_for => {
      id => 'integer',
      i  => 'integer',
      f  => 'float',
      d  => 'decimal',
      dt => 'timestamp',
      ts => 'timestamp',
      c  => 'char',
      v  => 'varchar',
      t  => 'blob',
   },
   precision => {
      f  => '(12,10)',
      id => undef,
   },
};
is(
   mk_upgrade::make_table_ddl($struct),
   "(
  `id` integer,
  `i` integer,
  `f` float(12,10),
  `d` decimal,
  `dt` timestamp,
  `ts` timestamp,
  `c` char,
  `v` varchar,
  `t` blob
)",
   'make_table_ddl()'
);

# #############################################################################
# Test that connection opts inherit.
# #############################################################################
like(
   output('h=127.1,P=12345', 'h=127.1', 'samples/q001.txt'),
   qr/Host2_Query_time/,
   'host2 inherits from host1'
);

like(
   output('h=127.1', 'h=127.1', '--port', '12345', 'samples/q001.txt'),
   qr/Host2_Query_time/,
   'DSNs inherit standard connection options'
);

# #############################################################################
# Test some output.
# #############################################################################
ok(
   test_no_diff('samples/r001.txt', @hosts, 'samples/q001.txt'),
   'Basic output'
);

ok(
   test_no_diff('samples/r001-all-errors.txt', @hosts,
      '--all-errors', 'samples/q001.txt'),
   'Basic output --all-errors'
);

ok(
   test_no_diff('samples/r001-no-errors.txt', @hosts,
      '--no-errors', 'samples/q001.txt'),
   'Basic output --no-errors'
);

ok(
   test_no_diff('samples/r001-no-reasons.txt', @hosts,
      '--no-reasons', 'samples/q001.txt'),
   'Basic output --no-reasons'
);

ok(
   test_no_diff('samples/r001-no-reasons-no-errors.txt', @hosts,
      '--no-reasons', '--no-errors', 'samples/q001.txt'),
   'Basic output --no-reasons --no-errors'
);

ok(
   test_no_diff('samples/r001-no-compare-warnings.txt', @hosts,
      '--no-compare-warnings','samples/q001.txt'),
   'Basic output --no-compare-warnings'
);

ok(
   test_no_diff('samples/r001-no-compare-results.txt', @hosts,
      '--no-compare-results','samples/q001.txt'),
   'Basic output --no-compare-results'
);

# TODO: DSNParser clobbers SQL_MODE so we can't set ONLY_FULL_GROUP_BY.
# print output(@hosts, qw(samples/q002.txt --dump-results));

# #############################################################################
# Test that warnings are cleared after each query.
# #############################################################################

# How to reproduce?

# #############################################################################
# Done.
# #############################################################################
$output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   mk_upgrade::_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
$sb->wipe_clean($dbh1);
$sb->wipe_clean($dbh2);
exit;
