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
require "$trunk/mk-parallel-dump/mk-parallel-dump";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'Sandbox master does not have the sakila database';
}
else {
   plan tests => 1;
}

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf ";
my $basedir = '/tmp/dump/';

# #############################################################################
# Issue 642: mk-parallel-dump --progress is incorrect when using --chunk-size
# #############################################################################
diag(`rm -rf $basedir`);
my @lines = `$cmd --base-dir $basedir -v -v -d sakila -t actor --threads 1 --progress --chunk-size 50`;
shift @lines;  # header
pop @lines;  # all
my @progress = map { grep { $_ =~ m/k\// } split(/\s+/, $_) } @lines;

is_deeply(
   \@progress,
   [
      '3.96k/16.00k',
      '7.91k/16.00k',
      '11.87k/16.00k',
      '15.82k/16.00k',
      '15.82k/16.00k',
      '15.82k/16.00k'
   ],
   '--progress with --chunk-size (issue 642)'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
exit;
