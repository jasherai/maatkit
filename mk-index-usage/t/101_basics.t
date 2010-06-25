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
# See http://code.google.com/p/maatkit/wiki/Testing
shift @INC;  # MaatkitTest's unshift
require "$trunk/mk-index-usage/mk-index-usage";

use Sandbox;
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
if ( !@{ $dbh->selectall_arrayref('show databases like "sakila"') } ) {
   plan skip_all => "Sakila database is not loaded";
}
else {
   plan tests => 6;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my @args    = ('-F', $cnf);
my $samples = "mk-index-usage/t/samples/";
my $output;

# This query doesn't use indexes so there's an unused PK and
# an unused secondary index.  Only the secondary index should
# be printed since dropping PKs is not suggested by default.
ok(
   no_diff(
      sub {
          mk_index_usage::main(@args,
            "$trunk/$samples/slow001.txt");
      },
      "$samples/slow001-report.txt"),
   'A simple query that does not use any indexes',
);

# Same test as above but with --drop all to suggest dropping
# the PK.  The PK is printed separately.
ok(
   no_diff(
      sub {
          mk_index_usage::main(@args, qw(--drop all),
            "$trunk/$samples/slow001.txt");
      },
      "$samples/slow001-report-drop-all.txt"),
   '--drop all includes primary key on separate line',
);

# This query uses the primary key so there's one unused secondary index.
ok(
   no_diff(
      sub {
          mk_index_usage::main(@args,
            "$trunk/$samples/slow002.txt");
      },
      "$samples/slow002-report.txt"),
   'A simple query that uses the primary key',
);

# This query uses a secondary index which makes the primary key
# look unused.  The output should be blank because dropping the
# PK isn't suggested by default and there's no other unused indexes.
$output = output(
   sub { mk_index_usage::main(@args, "$trunk/$samples/slow003.txt") },
);
is(
   $output,
   '',
   'A simple query that uses a secondary index',
);

# This query uses the pk on a table with two other indexes, so those
# indexes are printed.
ok(
   no_diff(
      sub {
          mk_index_usage::main(@args,
            "$trunk/$samples/slow005.txt");
      },
      "$samples/slow005-report.txt"),
   'Drop multiple indexes',
);

# #############################################################################
# Capture errors, and ensure that statement blacklisting works OK.
# #############################################################################
$output = output(
   sub { mk_index_usage::main(@args, "$trunk/$samples/slow004.txt") },
   stderr => 1,
);
my @errs = $output =~ m/DBD::mysql::db selectall_arrayref failed/g;
is(
   scalar @errs,
   1,
   'Failing statement was blacklisted'
);

# #############################################################################
# Done.
# #############################################################################
exit;
