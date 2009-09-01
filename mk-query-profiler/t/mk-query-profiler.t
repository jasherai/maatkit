#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

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
   skip 'Sandbox master does not have the sakila database', 4 
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   $output = `echo "select * from sakila.film" | $cmd`;
   like(
      $output,
      qr{Questions\s+1},
      'It lives with input on STDIN',
   );

   $output = `$cmd -vvv --innodb sample.sql`;
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

   # #########################################################################
   # Issue 391: Add --pid option to all scripts
   # #########################################################################
   `touch /tmp/mk-script.pid`;
   $output = `$cmd -vvv --innodb sample.sql --pid /tmp/mk-script.pid 2>&1`;
   like(
      $output,
      qr{PID file /tmp/mk-script.pid already exists},
      'Dies if PID file already exists (issue 391)'
   );
   `rm -rf /tmp/mk-script.pid`;
};

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
