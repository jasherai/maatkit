#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 9;

require '../mk-show-grants';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-show-grants -F $cnf ";

my $output = '';
open my $output_fh, '>', \$output
   or BAIL_OUT("Cannot capture output to variable: $OS_ERROR");
select $output_fh;

# Be sure to call this before each test.
sub clear_output {
   $output = '';
   seek($output_fh, 0, 0);
}

clear_output();
mk_show_grants::main('-F', $cnf, qw(--drop --flush --revoke --separate));
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
   'Added FLUSH',
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


clear_output();
mk_show_grants::main('-F', $cnf, qw(--no-timestamp --drop --flush --revoke --separate));
unlike(
   $output,
   qr/at \d{4}/,
   'It has no timestamp',
);

clear_output();
mk_show_grants::main('-F', $cnf, '--ignore', 'baron,msandbox,root,root@localhost,user');
unlike(
   $output,
   qr/uninitialized/,
   'Does not die when all users skipped',
);
like(
   $output,
   qr/\d\d:\d\d:\d\d\n\z/,
   'No output when all users skipped'
);

exit;
