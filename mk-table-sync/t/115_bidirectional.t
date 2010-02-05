#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-table-sync/mk-table-sync";

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $vp = new VersionParser();
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $c1_dbh = $sb->get_dbh_for('master');
my $r1_dbh = $sb->get_dbh_for('slave2');

# Second master 12347 needs to be started manually!

if ( !$c1_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$r1_dbh ) {
   plan skip_all => 'Cannot connect to second sandbox master';

}
else {
   plan tests => 3;
}

my $output;
my $cnf = '/tmp/12345/my.sandbox.cnf';
my @args = ('-F', $cnf, 'h=127.1,P=12345', 'P=12347', qw(-d bidi --bidirectional));

$sb->wipe_clean($c1_dbh);
$sb->wipe_clean($r1_dbh);

sub load_bidi_data {
   $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/table.sql');
   $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/table.sql');
   $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/master-data.sql');
   $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/remote-1.sql');
}

my $r1_data_synced =  [
   [1,   'abc',   1,  '2010-02-01 05:45:30'],
   [2,   'def',   2,  '2010-01-31 06:11:11'],
   [3,   'ghi',   5,  '2010-02-01 09:17:52'],
   [4,   'jkl',   6,  '2010-02-01 10:11:33'],
   [5,   undef,   0,  '2010-02-02 05:10:00'],
   [6,   'p',     4,  '2010-01-31 10:17:00'],
   [7,   'qrs',   5,  '2010-02-01 10:11:11'],
   [8,   'tuv',   6,  '2010-01-31 10:17:20'],
   [9,   'wxy',   7,  '2010-02-01 10:17:00'],
   [10,  'z',     8,  '2010-01-31 10:17:08'],
   [11,  '?',     0,  '2010-01-29 11:17:12'],
   [12,  '',      0,  '2010-02-01 11:17:00'],
   [13,  'hmm',   1,  '2010-02-02 12:17:31'],
   [14,  undef,   0,  '2010-01-31 10:17:00'],
   [15,  'gtg',   7,  '2010-02-02 06:01:08'],
   [17,  'good',  1,  '2010-02-02 21:38:03'],
   [20,  'new', 100,  '2010-02-01 04:15:36'],
];


load_bidi_data();
$c1_dbh->do('use bidi');
$r1_dbh->do('use bidi');

my $res = $c1_dbh->selectall_arrayref('select * from bidi.t order by id');
is_deeply(
   $res,
   [
      [1,   'abc',   1,  '2010-02-01 05:45:30'],
      [2,   'def',   2,  '2010-01-31 06:11:11'],
      [3,   'ghi',   5,  '2010-02-01 09:17:52'],
      [4,   'jkl',   6,  '2010-02-01 10:11:33'],
      [5,   'mno',   3,  '2010-02-01 10:17:40'],
      [6,   'p',     4,  '2010-01-31 10:17:00'],
      [7,   'qrs',   5,  '2010-02-01 10:11:11'],
      [8,   'tuv',   6,  '2010-01-31 10:17:20'],
      [9,   'wxy',   7,  '2010-02-01 10:17:00'],
      [10,  'z',     8,  '2010-01-31 10:17:08'],
      [12,  '',      0,  '2010-02-01 11:17:00'],
      [13,  undef,   0,  '2010-02-01 12:17:31'],
      [14,  undef,   0,  '2010-01-31 10:17:00'],
      [15,  'NA',    0,  '2010-01-31 07:00:01'],
      [20,  'new', 100,  '2010-02-01 04:15:36'],
   ],
   'c1 data before sync'
);

$res = $r1_dbh->selectall_arrayref('select * from bidi.t order by id');
is_deeply(
   $res,
   [
      [1,   'abc',   1,  '2010-02-01 05:45:30'],
      [2,   'def',   2,  '2010-01-31 06:11:11'],
      [3,   'ghi',   5,  '2010-02-01 09:17:51'],
      [4,   'jkl',   6,  '2010-02-01 10:11:33'],
      [5,   undef,   0,  '2010-02-02 05:10:00'],
      [6,   'p',     4,  '2010-01-31 10:17:00'],
      [7,   'qrs',   5,  '2010-02-01 10:11:11'],
      [8,   'tuv',   6,  '2010-01-31 10:17:20'],
      [9,   'wxy',   7,  '2010-02-01 10:17:00'],
      [10,  'z',     8,  '2010-01-31 10:17:08'],
      [11,  '?',     0,  '2010-01-29 11:17:12'],
      [12,  '',      0,  '2010-02-01 11:17:00'],
      [13,  'hmm',   1,  '2010-02-02 12:17:31'],
      [14,  undef,   0,  '2010-01-31 10:17:00'],
      [15,  'gtg',   7,  '2010-02-02 06:01:08'],
      [17,  'good',  1,  '2010-02-02 21:38:03'],
   ],
   'r1 data before sync'
);

$output = output(
   sub { mk_table_sync::main(@args, '--print') }
);

is(
   $output,
"UPDATE `bidi`.`t` SET `c`='ghi', `d`=5, `ts`='2010-02-01 09:17:52' WHERE `id`=3 LIMIT 1
UPDATE `bidi`.`t` SET `c`=NULL, `d`='0', `ts`='2010-02-02 05:10:00' WHERE `id`=5 LIMIT 1
INSERT INTO `bidi`.`t`(`c`, `d`, `id`, `ts`) VALUES ('?', '0', 11, '2010-01-29 11:17:12')
UPDATE `bidi`.`t` SET `c`='hmm', `d`=1, `ts`='2010-02-02 12:17:31' WHERE `id`=13 LIMIT 1
UPDATE `bidi`.`t` SET `c`='gtg', `d`=7, `ts`='2010-02-02 06:01:08' WHERE `id`=15 LIMIT 1
INSERT INTO `bidi`.`t`(`c`, `d`, `id`, `ts`) VALUES ('good', 1, 17, '2010-02-02 21:38:03')
INSERT INTO `bidi`.`t`(`c`, `d`, `id`, `ts`) VALUES ('new', 100, 20, '2010-02-01 04:15:36')
",
   '--print correct SQL for c1<->r1 bidirectional sync'
);

# #############################################################################
# Done.
# #############################################################################
#$sb->wipe_clean($c1_dbh);
#$sb->wipe_clean($r1_dbh);
exit;
