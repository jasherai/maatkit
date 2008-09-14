#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 17;

my $output = `perl ../mk-parallel-restore mk_parallel_restore_foo --test`;
like(
   $output,
   qr{mysql mk_parallel_restore_foo < '.*?foo/bar.sql'},
   'Found the file',
);
like(
   $output,
   qr{1 tables,\s+1 files,\s+1 successes},
   'Counted the work to be done',
);

$output = `perl ../mk-parallel-restore -n bar mk_parallel_restore_foo --test`;
unlike( $output, qr/bar/, '--ignoretbl filtered out bar');

$output = `perl ../mk-parallel-restore -n mk_parallel_restore_foo.bar mk_parallel_restore_foo --test`;
unlike( $output, qr/bar/, '--ignoretbl filtered out bar again');

# Actually load the file, and make sure it succeeds.
`mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_foo'`;
`mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_bar'`;
$output = `perl ../mk-parallel-restore --createdb mk_parallel_restore_foo`;
$output = `mysql -N -e 'select count(*) from mk_parallel_restore_foo.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_foo.bar');

# Test that the --database parameter doesn't specify the database to use for the
# connection, and that --createdb creates the database for it (bug #1870415).
`mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_foo'`;
`mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_bar'`;
$output = `perl ../mk-parallel-restore --database mk_parallel_restore_bar --createdb mk_parallel_restore_foo`;
$output = `mysql -N -e 'select count(*) from mk_parallel_restore_bar.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_bar.bar');

# Test that the --defaults-file parameter works (bug #1886866).
$output = `perl ../mk-parallel-restore --createdb --defaults-file=~/.my.cnf mk_parallel_restore_foo`;
like($output, qr/1 files,     1 successes,  0 failures/, 'restored');
$output = `mysql -N -e 'select count(*) from mk_parallel_restore_bar.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_bar.bar');

# Clean up.
`mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_foo'`;
`mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_bar'`;

$output = `mysql -e 'show databases'`;
SKIP: {
   skip 'Sakila is not installed', 6 unless $output =~ m/sakila/;

   $output = `perl ../../mk-parallel-dump/mk-parallel-dump --basedir /tmp -d sakila -t film,film_actor,payment,rental`;
   like($output, qr/0 failures/, 'Dumped sakila tables');

   $output = `MKDEBUG=1 perl ../mk-parallel-restore -D test /tmp/default/ 2>&1 | grep -A 6 ' got ' | grep 'Z => ' | awk '{print \$3}' | cut -f1 -d',' | sort --numeric-sort --check --reverse 2>&1`;
   unlike($output, qr/disorder/, 'Tables restored biggest-first by default');   

   `mysql -e 'DROP TABLE test.film_actor, test.film, test.payment, test.rental'`;

   # Do it all again with > 1 arg in order to test that it does NOT
   # sort by biggest-first, as explained by Baron in issue 31 comment 1.
   $output = `MKDEBUG=1 perl ../mk-parallel-restore -D test /tmp/default/sakila/payment.000000.sql.gz /tmp/default/sakila/film.000000.sql.gz /tmp/default/sakila/rental.000000.sql.gz /tmp/default/sakila/film_actor.000000.sql.gz 2>&1 | grep -A 6 ' got ' | grep 'N => ' | awk '{print \$3}' | cut -f1 -d',' 2>&1`;
   like($output, qr/'payment'\n'film'\n'rental'\n'film_actor'/, 'Tables restored in given order');

   `mysql -e 'DROP TABLE test.film_actor, test.film, test.payment, test.rental'`;

   # And yet again, but this time test that a given order of tables is
   # ignored if --biggestfirst is explicitly given
   $output = `MKDEBUG=1 perl ../mk-parallel-restore -D test --biggestfirst /tmp/default/sakila/payment.000000.sql.gz /tmp/default/sakila/film.000000.sql.gz /tmp/default/sakila/rental.000000.sql.gz /tmp/default/sakila/film_actor.000000.sql.gz 2>&1 | grep -A 6 ' got ' |  grep 'Z => ' | awk '{print \$3}' | cut -f1 -d',' | sort --numeric-sort --check --reverse 2>&1`;
   unlike($output, qr/disorder/, 'Explicit --biggestfirst overrides given table order');

   `mysql -e 'DROP TABLE test.film_actor, test.film, test.payment, test.rental'`;

   # And again, because I've yet to better optimize these tests...
   # This time we're just making sure reporting progress by bytes.
   # This is kind of a contrived test, but it's better than nothing.
   $output = `../mk-parallel-restore --progress --test /tmp/default/`;
   like($output, qr/done: [\d\.]+[Mk]\/[\d\.]+[Mk]/, 'Reporting progress by bytes');

}

# #############################################################################
# Issue 30: Add resume functionality to mk-parallel-restore
# #############################################################################
`mysql < samples/issue_30.sql`;
`rm -rf /tmp/default`;
`../../mk-parallel-dump/mk-parallel-dump --basedir /tmp -d test -t issue_30 -C 25`;
# The above makes the following chunks:
#
# #   WHERE                         SIZE  FILE
# --------------------------------------------------------------
# 0:  `id` < 254                    790   issue_30.000000.sql.gz
# 1:  `id` >= 254 AND `id` < 502    619   issue_30.000001.sql.gz
# 2:  `id` >= 502 AND `id` < 750    661   issue_30.000002.sql.gz
# 3:  `id` >= 750                   601   issue_30.000003.sql.gz
#
# Now we fake like a resume operation died on an edge case:
# after restoring the first row of chunk 2. We should resume
# from chunk 1 to be sure that all of 2 is restored.
`mysql -D test -e 'SELECT * FROM issue_30' > /tmp/mkpr_i30`;
`mysql -D test -e 'DELETE FROM issue_30 WHERE id > 502'`;
$output = `MKDEBUG=1 ../mk-parallel-restore -D test /tmp/default/test/ | grep 'Resuming'`;
like($output, qr/Resuming restore of test.issue_30 from chunk 2 \(140\d{1,2} bytes/, 'Reports resume from chunk 2 (issue 30)');

$output = 'foo';
$output = `mysql -e 'SELECT * FROM test.issue_30' | diff /tmp/mkpr_i30 -`;
ok(!$output, 'Resume restored all 100 rows exactly (issue 30)');

`rm -rf /tmp/mkpr_i30`;
`rm -rf /tmp/default`;

# Test that resume doesn't do anything on a tab dump because there's
# no chunks file
`../../mk-parallel-dump/mk-parallel-dump --basedir /tmp -d test -t issue_30 --tab`;
$output = `MKDEBUG=1 ../mk-parallel-restore -D test --local --tab /tmp/default/test/`;
like($output, qr/Cannot resume restore: no chunks file/, 'Does not resume --tab dump (issue 30)');

`rm -rf /tmp/default/`;

# Test that resume doesn't do anything on non-chunked dump because
# there's only 1 chunk: where 1=1
`../../mk-parallel-dump/mk-parallel-dump --basedir /tmp -d test -t issue_30 -C 10000`;
$output = `MKDEBUG=1 ../mk-parallel-restore -D test /tmp/default/test/`;
like($output, qr/Cannot resume restore: only 1 chunk \(1=1\)/, 'Does not resume single chunk where 1=1 (issue 30)');

`rm -rf /tmp/default`;
`mysql -e 'DROP TABLE test.issue_30'`;
exit;
