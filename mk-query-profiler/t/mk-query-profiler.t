#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Test::More tests => 3;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-query-profiler -F $cnf ";
my $mysql = $sb->_use_for('master');

my $output;

SKIP: {
   skip 'Sandbox master does not have the sakila database', 3
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   $output = `echo "select * from sakila.film" | $cmd`;
   like(
      $output,
      qr{Questions\s+1},
      'It lives with input on STDIN',
   );

   $output = `$cmd -vvv -i sample.sql`;
   like(
      $output,
      qr{Temp files\s+0},
      'It lives with verbosity, InnoDB, and a file input',
   );
   like(
      $output,
      qr{Handler _+ InnoDB},
      'I found InnoDB stats',
   );
};

$sb->wipe_clean($dbh);
exit;
