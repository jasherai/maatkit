#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Test::More tests => 7;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-show-grants -F $cnf ";

my $output = `$cmd -d -f -r -s`;
like(
   $output,
   qr/Grants dumped by/,
   'It lives',
);

like(
   $output,
   qr/REVOKE/,
   'It converted to revokes',
);

like(
   $output,
   qr/FLUSH/,
   'added FLUSH/',
);

like(
   $output,
   qr/DROP/,
   'Added DROP',
);

like(
   $output,
   qr/DELETE/,
   'Added DELETE for older MySQL versions',
);
like(
   $output,
   qr/at \d{4}/,
   'It has a timestamp',
);

$output = `$cmd --no-timestamp -d -f -r -s`;
unlike(
   $output,
   qr/at \d{4}/,
   'It has no timestamp',
);

exit;
