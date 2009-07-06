#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

require '../mk-table-scan';
#require '../../common/Sandbox.pm';
#my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
#my $dbh = $sb->get_dbh_for('master')
#   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-table-scan -F $cnf ";

my $output = `$cmd --help 2>&1`;
like(
   $output,
   qr/--ask-pass/,
   'It runs'
);

#SKIP: {
#   skip 'Sandbox master does not have the sakila database', 2
#      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};
# };

# $sb->wipe_clean($dbh);
exit;
