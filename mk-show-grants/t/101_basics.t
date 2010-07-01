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
   plan tests => 9;
}

$sb->wipe_clean($dbh);

my $output;
my $cnf = '/tmp/12345/my.sandbox.cnf';

$output = output(
   sub { mk_show_grants::main('-F', $cnf, qw(--drop --flush --revoke --separate)); }
);
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


$output = output(
   sub { mk_show_grants::main('-F', $cnf, qw(--no-timestamp --drop --flush --revoke --separate)); }
);
unlike(
   $output,
   qr/at \d{4}/,
   'It has no timestamp',
);

$output = output(
   sub { mk_show_grants::main('-F', $cnf, '--ignore', 'baron,msandbox,root,root@localhost,user'); }
);
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
# Done.
# #############################################################################
exit;
