#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 12;

my $output;

$output = `mysql -e 'show databases'`;
SKIP: {
   skip 'Sakila is not installed', 6 unless $output =~ m/sakila/;

   $output = `perl ../mk-parallel-dump --C 100 --basedir /tmp -T --d sakila --t film`;
   my ($tbl, $chunk) = $output =~ m/default:\s+(\d+) tables,\s+(\d+) chunks,\s+\2 successes/;
   is($tbl, 1, 'One table dumped');
   ok($chunk >= 5 && $chunk <= 15, 'Got some chunks');
   ok(-s '/tmp/default/sakila/film.005.txt.gz', 'chunk 5 exists');
   ok(-s '/tmp/default/00_master_data.sql', 'master_data exists');
   `rm -rf /tmp/default`;

   # Fixes bug #1851461.
   `mysql -e 'drop database if exists foo'`;
   `mysql -e 'create database foo'`;
   `mysql -e 'create table foo.bar(a int) engine=myisam'`;
   `mysql -e 'create table foo.mrg(a int) engine=merge union=(foo.bar)'`;
   $output = `perl ../mk-parallel-dump -C 100 --basedir /tmp -T --d foo`;
   ok(!-f '/tmp/default/foo/mrg.000.sql.gz', 'Merge table was not dumped');
   `mysql -e 'drop database if exists foo'`;
   `rm -rf /tmp/default`;

   # Fixes bug #1850998 (workaround for MySQL bug #29408)
   `mysql < bug_29408.sql`;
   $output = `perl ../mk-parallel-dump -E foo -C 100 --basedir /tmp -T --d mk_parallel_dump_foo 2>&1`;
   unlike($output, qr/No database selected/, 'Bug did not affect it');
   `mysql -e 'drop database if exists mk_parallel_dump_foo'`;
   `rm -rf /tmp/default`;

   # Make sure subsequent chunks don't have DROP/CREATE in them (fixes bug
   # #1863949).
   $output = `perl ../mk-parallel-dump -C 100 --no-gzip --basedir /tmp -d sakila -t film 2>&1`;
   ok(-f '/tmp/default/sakila/film.000.sql', 'first chunk file exists');
   ok(-f '/tmp/default/sakila/film.001.sql', 'second chunk file exists');
   $output = `grep -i 'DROP TABLE' /tmp/default/sakila/film.000.sql`;
   like($output, qr/DROP TABLE/i, 'first chunk has DROP TABLE');
   $output = `grep -i 'DROP TABLE' /tmp/default/sakila/film.001.sql`;
   unlike($output, qr/DROP TABLE/i, 'second chunk has no DROP TABLE');
   $output = `grep -i 'CREATE TABLE' /tmp/default/sakila/film.000.sql`;
   like($output, qr/CREATE TABLE/i, 'first chunk has CREATE TABLE');
   $output = `grep -i 'CREATE TABLE' /tmp/default/sakila/film.001.sql`;
   unlike($output, qr/CREATE TABLE/i, 'second chunk has no CREATE TABLE');
   `rm -rf /tmp/default`;

}
