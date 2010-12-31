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
require "$trunk/mk-archiver/mk-archiver";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 1;
}

my $output;
my $rows;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-archiver/mk-archiver";

$sb->load_file('master', 'mk-archiver/t/samples/issue_1152.sql');

# #############################################################################
# Issue 1152: mk-archiver columns option resulting in null archived table data
# #############################################################################

$output = output(
   sub { mk_archiver::main(
      qw(--header --progress 1000 --statistics --limit 1000),
      qw(--commit-each --why-quit),
      '--source',  'h=127.1,P=12345,D=issue_1152,t=t,u=msandbox,p=msandbox',
      '--dest',    'h=127.1,P=12345,D=issue_1152_archive,t=t',
      '--columns', 'a,b,c',
      '--where',   'id = 5')},
);
print $output;
ok(1, "Issue 1152 test stub");

# #############################################################################
# Done.
# #############################################################################
#$sb->wipe_clean($dbh);
exit;
