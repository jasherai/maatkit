#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

use SchemaDiscover;
use DSNParser;
use MySQLDump;
use Quoter;
use TableParser;
use VersionParser;
use DSNParser;
use Sandbox;
use MaatkitTest;

my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $du = new MySQLDump();
my $q  = new Quoter();
my $tp = new TableParser(Quoter => $q);
my $vp = new VersionParser();

my $sd = new SchemaDiscover(
   du => $du,
   q  => $q,
   tp => $tp,
   vp => $vp,
);
isa_ok($sd, 'SchemaDiscover');

SKIP: {
   skip 'Sandbox master does not have the sakila database', 4
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   my $schema = $sd->discover($dbh);

   ok(exists $schema->{dbs}->{sakila},   'sakila db exists'    );
   ok(exists $schema->{dbs}->{mysql},    'mysql db exists'     );
   ok(exists $schema->{counts}->{TOTAL}, 'TOTAL counts exists' );

   is_deeply(
      $schema->{stored_code},
      [
         'sakila del_trg 1',
         'sakila ins_trg 4',
         'sakila upd_trg 1',
         'sakila func 3',
         'sakila proc 3',
      ],
      'stored code objects'
   );

   $dbh->disconnect() if defined $dbh;
};

exit;
