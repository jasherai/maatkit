#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-log-player/mk-log-player";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 19;
}

my $output;
my $tmpdir = '/tmp/mk-log-player';
my $cmd = "$trunk/mk-log-player/mk-log-player --play $tmpdir -F /tmp/12345/my.sandbox.cnf h=127.1 --no-results";

diag(`rm -rf $tmpdir 2>/dev/null; mkdir $tmpdir`);


# #############################################################################
# Test that all session files gets assigned.
# #############################################################################
my @args = (qw(--dry-run --play), "$trunk/mk-log-player/t/samples/16sessions");
for my $n ( 1..16 ) {
   ok(
      no_diff(
         sub { mk_log_player::main(@args, '--threads', $n) },
         "mk-log-player/t/samples/assigned16-$n.txt",
         trf => "sed 's!$trunk/mk-log-player/t/samples/16sessions/!!g'",
      ),
      "Assigned 16 sessions to $n threads"
   );
}

# #############################################################################
# Test session playing.
# #############################################################################

$sb->load_file('master', 'mk-log-player/t/samples/log.sql');
`$trunk/mk-log-player/mk-log-player --base-dir $tmpdir --session-files 2 --split Thread_id $trunk/mk-log-player/t/samples/log001.txt`;
`$cmd`;
is_deeply(
   $dbh->selectall_arrayref('select * from mk_log_player_1.tbl1 where a = 100 OR a = 555;'),
   [[100], [555]],
   '--play made table changes',
);

$sb->load_file('master', 'mk-log-player/t/samples/log.sql');

`$cmd --only-select`;
is_deeply(
   $dbh->selectall_arrayref('select * from mk_log_player_1.tbl1 where a = 100 OR a = 555;'),
   [],
   'No table changes with --only-select',
);

# #############################################################################
# Issue 418: mk-log-player dies trying to play statements with blank lines
# #############################################################################
diag(`rm -rf $tmpdir 2>/dev/null; mkdir $tmpdir`);
`$trunk/mk-log-player/mk-log-player --split Thread_id --base-dir $tmpdir $trunk/common/t/samples/slow020.txt`;

ok(
   no_diff(
      "$cmd --threads 1 --print",
      "mk-log-player/t/samples/play_slow020.txt",
   ),
   'Play session from log with blank lines in queries (issue 418)' 
);

diag(`rm session-results-*.txt 2>/dev/null`);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $tmpdir 2>/dev/null`);
$sb->wipe_clean($dbh);
exit;
