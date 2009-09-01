#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 16;

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

# #############################################################################
# Issue 445: mk-show-grants --revoke crashes 
# #############################################################################
diag(`/tmp/12345/use -u root -e "GRANT USAGE ON *.* TO ''\@''"`);
my $res = `/tmp/12345/use -e "SELECT user FROM mysql.user WHERE user = ''"`;
like(
   $res,
   qr/user/,
   'Added anonymous user (issue 445)'
);

clear_output();
eval {
   mk_show_grants::main('-F', $cnf, '--revoke');
};
is(
   $EVAL_ERROR,
   '',
   'Does not die on anonymous user (issue 445)',
);
like(
   $output,
   qr/REVOKE USAGE ON \*\.\* FROM ''\@'';/,
   'Prints revoke for anonymous user (issue 445)'
);

diag(`/tmp/12345/use -u root -e "DROP USER ''\@''"`);
$res = `/tmp/12345/use -e "SELECT user FROM mysql.user WHERE user = ''"`;
is(
   $res,
   '',
   'Removed anonymous user (issue 445)'
);


# #############################################################################
# Issue 551: mk-show-grants does not support listing all grants for a single
# user (over multiple hosts)
# #############################################################################
diag(`/tmp/12345/use -u root -e "GRANT USAGE ON *.* TO 'bob'\@'%'"`);
diag(`/tmp/12345/use -u root -e "GRANT USAGE ON *.* TO 'bob'\@'localhost'"`);
diag(`/tmp/12345/use -u root -e "GRANT USAGE ON *.* TO 'bob'\@'192.168.1.1'"`);

clear_output();
mk_show_grants::main('-F', $cnf, qw(--only bob --no-timestamp));
ok(
   0,
   '(issue 551)'
);
print STDERR $output;

diag(`/tmp/12345/use -u root -e "DROP USER 'bob'\@'%'"`);
diag(`/tmp/12345/use -u root -e "DROP USER 'bob'\@'localhost'"`);
diag(`/tmp/12345/use -u root -e "DROP USER 'bob'\@'192.168.1.1'"`);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `../mk-show-grants -F /tmp/12345/my.sandbox.cnf --drop --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
$res = '';
{
   local *STDERR;
   open STDERR, '>', \$res;
   mk_show_grants::_d('Complete test coverage');
}
like(
   $res,
   qr/Complete test coverage/,
   '_d() works'
);
$sb->wipe_clean($dbh);
exit;
