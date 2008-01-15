#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 6;

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

# Clean up.
`mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_foo'`;
`mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_bar'`;
