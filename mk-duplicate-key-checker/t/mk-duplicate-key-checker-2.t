#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw('-no_match_vars);
use Test::More tests => 2;

require '../mk-duplicate-key-checker-2';
# Do not require any modules that are already in the script (like OptionParser)
# because they will cause a "subroutine redefined" error.
require '../../common/Sandbox.pm';

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
$sb->wipe_clean($dbh);

my $cnf = '/tmp/12345/my.sandbox.cnf'; # TODO: use $sb

# Redirect script's STDOUT output to tmp file to avoid doing
# $output = `...` which Devel::Cover cannot cover.
use File::Temp qw(tempfile);
my ($tmpfh, $tmpfile) = tempfile()
   or BAIL_OUT("Cannot open temp file: $OS_ERROR");
my $output;

`echo -n > $tmpfile`; # clear tmp file
select $tmpfh;
mk_duplicate_key_checker::main('-F', $cnf, qw(-d mysql -t columns_priv -v));
$output = `cat $tmpfile`;
select STDOUT;
like($output,
   qr/PRIMARY \(`Host`,`Db`,`User`,`Table_name`,`Column_name`\)/,
   'Finds mysql.columns_priv PK'
);

`echo -n > $tmpfile`; # clear tmp file
select $tmpfh;
mk_duplicate_key_checker::main('-F', $cnf, qw(-d test --nosummary));
$output = `cat $tmpfile`;
select STDOUT;
is($output, '', 'No dupes on clean sandbox');

$sb->wipe_clean($dbh);
exit;
