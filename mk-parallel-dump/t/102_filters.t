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
require "$trunk/mk-parallel-dump/mk-parallel-dump";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'sakila db not loaded';
}
else {
   plan tests => 5;
}

my $output;
my $basedir = '/tmp/dump/';
my $cnf     = "/tmp/12345/my.sandbox.cnf";
my $cmd     = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf -h 127.1";

use File::Find;
sub get_files {
   my ( $dir ) = @_;
   my @files;
   find sub {
      return if -d;
      push @files, $File::Find::name;
   }, $dir;
   @files = sort @files;
   return \@files;
}

$sb->wipe_clean($dbh);
$sb->load_file('master', 'mk-table-sync/t/samples/filter_tables.sql');

$output    = `$cmd -v -t issue_806_1.t2 --dry-run`;
my @output = split(/\n/, $output);
is_deeply(
   \@output,
   [
      'CHUNK  TIME  EXIT  SKIPPED DATABASE.TABLE ',
      "/*!40103 SET TIME_ZONE='+00:00' */;",
      'SELECT /*chunk 0*/ `i` FROM `issue_806_1`.`t2` WHERE  1=1;',
      '  tbl  0.01     0        0 issue_806_1.t2 ',
      '   db  0.01     0        0 issue_806_1    ',
      '  all  0.01     0        0 -              ',
   ],
   "db-qualified --tables (issue 806)"
);

# #########################################################################
# Issue 573: 'mk-parallel-dump --progress --ignore-engine MyISAM' Reports
# progress incorrectly
# #########################################################################
# For this issue we'll also test the filters in general, specially
# the engine filters as they were previously treated specially.
# sakila is mostly InnoDB tables so load some MyISAM tables.
diag(`/tmp/12345/use < $trunk/mk-table-sync/t/samples/issue_560.sql`);
diag(`/tmp/12345/use < $trunk/mk-table-sync/t/samples/issue_375.sql`);
diag(`rm -rf $basedir`);

# film_text is the only non-InnoDB table (it's MyISAM).
$output = `$cmd --base-dir $basedir -d sakila --ignore-engines InnoDB --progress`;
like(
   $output,
   qr/1 databases, 1 tables, 1 chunks/,
   '--ignore-engines InnoDB'
);

# Make very sure that it dumped only film_text.
is_deeply(
   get_files($basedir),
   [
      "${basedir}00_master_data.sql",
      "${basedir}sakila/00_film_text.sql",
      "${basedir}sakila/film_text.000000.sql.gz",
   ],
   '--ignore-engines InnoDB dumped files'
);

diag(`rm -rf $basedir`);

$output = `$cmd --base-dir $basedir -d sakila --ignore-engines InnoDB --tab --progress`;
like(
   $output,
   qr/1 databases, 1 tables, 1 chunks/,
   '--ignore-engines InnoDB --tab'
);
is_deeply(
   get_files($basedir),
   [
      "${basedir}00_master_data.sql",
      "${basedir}sakila/00_film_text.sql",
      "${basedir}sakila/film_text.000000.txt",
   ],
   '--ignore-engines InnoDB --tab dumped files'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
