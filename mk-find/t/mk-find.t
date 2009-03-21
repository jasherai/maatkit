#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Test::More tests => 1;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-find -F $cnf ";

my $output = `$cmd mysql --tblregex column`;
like($output, qr/`mysql`.`columns_priv`/, 'Found mysql.columns_priv');
