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
require "$trunk/mk-show-grants/mk-show-grants";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 4;
}

$sb->wipe_clean($dbh);

my $output;
my $cnf = '/tmp/12345/my.sandbox.cnf';

# #############################################################################
# Issue 445: mk-show-grants --revoke crashes 
# #############################################################################
diag(`/tmp/12345/use -u root -e "GRANT USAGE ON *.* TO ''\@''"`);
$output = `/tmp/12345/use -e "SELECT user FROM mysql.user WHERE user = ''"`;
like(
   $output,
   qr/user/,
   'Added anonymous user (issue 445)'
);

eval {
   $output = output(
      sub { mk_show_grants::main('-F', $cnf, '--revoke'); }
   );
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
$output = `/tmp/12345/use -e "SELECT user FROM mysql.user WHERE user = ''"`;
is(
   $output,
   '',
   'Removed anonymous user (issue 445)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
