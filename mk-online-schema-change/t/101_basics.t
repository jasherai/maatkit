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
require "$trunk/mk-online-schema-change/mk-online-schema-change";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 12;
}

my $output  = "";
my $cnf     = '/tmp/12345/my.sandbox.cnf';
my @args    = ('-F', $cnf);
my $exit    = 0;
my $rows;

#system(" >/dev/null &");


$sb->load_file('master', "mk-online-schema-change/t/samples/small_table.sql");
$dbh->do('use mkosc');

# #############################################################################
# --exit-after-checks
# #############################################################################
eval {
   $exit = mk_online_schema_change::main(@args,
      'D=mkosc,t=a', qw(--exit-after-checks --quiet))
};

is(
   $EVAL_ERROR,
   "",
   "--exit-after-checks"
);

is(
   $exit,
   0,
   "Exit status 0"
);

# #############################################################################
# --cleanup-and-exit
# #############################################################################
eval {
   $exit = mk_online_schema_change::main(@args,
      'D=mkosc,t=a', qw(--cleanup-and-exit --quiet))
};

is(
   $EVAL_ERROR,
   "",
   "--cleanup-and-exit",
);

is(
   $exit,
   0,
   "Exit status 0"
);

# #############################################################################
# The most basic: copy, alter and rename a small table that's not even active.
# #############################################################################

output(
   sub { $exit = mk_online_schema_change::main(@args,
      'D=mkosc,t=a', qw(--alter-new-table ENGINE=InnoDB)) },
);

$rows = $dbh->selectall_hashref('show table status from mkosc', 'name');
is(
   $rows->{a}->{engine},
   'InnoDB',
   "New table ENGINE=InnoDB"
);

is(
   $rows->{__old_a}->{engine},
   'MyISAM',
   "Kept old table, ENGINE=MyISAM"
);

my $org_rows = $dbh->selectall_arrayref('select * from mkosc.__old_a order by i');
my $new_rows = $dbh->selectall_arrayref('select * from mkosc.a order by i');
is_deeply(
   $new_rows,
   $org_rows,
   "New tables rows identical to old table rows"
);

is(
   $exit,
   0,
   "Exit status 0"
);

# #############################################################################
# No --alter-new-table and --drop-old-table.
# #############################################################################
$dbh->do('drop table mkosc.__old_a');  # from previous run
$sb->load_file('master', "mk-online-schema-change/t/samples/small_table.sql");

output(
   sub { $exit = mk_online_schema_change::main(@args,
      'D=mkosc,t=a', qw(--drop-old-table)) },
);

$rows = $dbh->selectall_hashref('show table status from mkosc', 'name');
is(
   $rows->{a}->{engine},
   'MyISAM',
   "No --alter-new-table, new table still ENGINE=MyISAM"
);

ok(
   !exists $rows->{__old_a},
   "--drop-old-table"
);

$new_rows = $dbh->selectall_arrayref('select * from mkosc.a order by i');
is_deeply(
   $new_rows,
   $org_rows,  # from previous run since old table was dropped this run
   "New tables rows identical to old table rows"
);

is(
   $exit,
   0,
   "Exit status 0"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
