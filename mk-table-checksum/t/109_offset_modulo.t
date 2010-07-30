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
require "$trunk/mk-table-checksum/mk-table-checksum";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf 127.0.0.1";

# Check --offset with --modulo
$output = `$cmd --databases mysql --chunk-size 5 --modulo 7 --offset 'weekday(now())' --tables help_relation --chunk-size-limit 0 2>&1`;
like($output, qr/^mysql\s+help_relation\s+\d+/m, '--modulo --offset runs');
my @chunks = $output =~ m/help_relation\s+(\d+)/g;
my $chunks = scalar @chunks;
ok($chunks, 'There are several chunks with --modulo');

my %differences;
my $first = shift @chunks;
while ( my $chunk = shift @chunks ) {
   $differences{$chunk - $first} ++;
   $first = $chunk;
}
is($differences{7}, $chunks - 1, 'All chunks are 7 apart');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
