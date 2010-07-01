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

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to MySQL';
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'sakila db not loaded';
}
else {
   plan tests => 8;
}

my $cnf  = '/tmp/12345/my.sandbox.cnf';

my $basedir1 = '/tmp/dump1/';
my $basedir2 = '/tmp/dump2/';
diag(`rm -rf $basedir1 $basedir2`);

# ###########################################################################
# Test --compress
# ###########################################################################

# Dump first without compression.
mk_parallel_dump::main(qw(--no-gzip --quiet --base-dir), $basedir1,
   qw(-d sakila -t), 'actor,country,customer', '-F', $cnf);

is(
   `ls -1 $basedir1/sakila/`,
"00_actor.sql
00_country.sql
00_customer.sql
actor.000000.sql
country.000000.sql
customer.000000.sql
",
   'Non-compressed files'
);

# Dump with compression.
mk_parallel_dump::main(qw(--quiet --base-dir), $basedir2,
   qw(-d sakila -t), 'actor,country,customer', '-F', $cnf);

is(
   `ls -1 $basedir2/sakila/`,
"00_actor.sql
00_country.sql
00_customer.sql
actor.000000.sql.gz
country.000000.sql.gz
customer.000000.sql.gz
",
   'Compressed files'
);

# Verify that compressed file is exactly the same as the uncompressed file.
diag(`gzip -d $basedir2/sakila/*.gz`);
my @files = qw(
   00_actor.sql
   00_country.sql
   00_customer.sql
   actor.000000.sql
   country.000000.sql
   customer.000000.sql
);
foreach my $file ( @files ) {
   is(
      `diff $basedir1/sakila/$file $basedir2/sakila/$file`,
      '',
      "$file"
   );
}

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir1 $basedir2`);
exit;
