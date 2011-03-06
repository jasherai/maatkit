#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use DSNParser;
use Sandbox;
use MaatkitTest;
use OSCCaptureSync;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to MySQL';
  
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => "Sandbox master does not have the sakila database";
}
else {
   plan tests => 4;
}

$sb->load_file("master", "common/t/samples/osc/tbl001.sql");
$dbh->do("USE osc");

my $osc = new OSCCaptureSync();

my $msg = sub { print "$_[0]\n"; };

my $output = output(
   sub {
      $osc->capture(
         dbh          => $dbh,
         old_table    => 'osc.t',
         new_table    => 'osc.__new_t',
         columns      => [qw(id c)],
         chunk_column => 'id',
         msg          => $msg,
      )
   },
);

ok(
   no_diff(
      $output,
      "common/t/samples/osc/capsync001.txt",
      cmd_output => 1,
   ),
   "SQL statments to create triggers"
);

$dbh->do('insert into t values (6, "f")');
$dbh->do('update t set c="z" where id=1');
$dbh->do('delete from t where id=3');

my $rows = $dbh->selectall_arrayref("select id, c from __new_t order by id");
is_deeply(
   $rows,
   [
      [1, 'z'],  # update t set c="z" where id=1
      [6, 'f'],  # insert into t values (6, "f")
   ],
   "Triggers work"
) or print Dumper($rows);

output(sub {
   $osc->cleanup(
      dbh => $dbh,
      db  => 'osc',
      msg => $msg,
   );
});

$rows = $dbh->selectall_arrayref("show triggers from `osc` like 't'");
is_deeply(
   $rows,
   [],
   "Cleanup removes the triggers"
);

# #############################################################################
# Done.
# #############################################################################
$output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $osc->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
$sb->wipe_clean($dbh);
exit;
