#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 10;

use MaatkitTest;
require "$trunk/mk-query-advisor/mk-query-advisor";

my @args = qw(--print-all --report-format full --query);


# #############################################################################
# Literals.
# #############################################################################

ok(
   no_diff(sub { mk_query_advisor::main(@args,
         'SELECT ip FROM tbl WHERE ip="127.0.0.1"') },
      'mk-query-advisor/t/samples/lit-001.txt',
   ),
   'LIT.001 "IP"'
);

ok(
   no_diff(sub { mk_query_advisor::main(@args,
         'SELECT c FROM tbl WHERE c < 2010-02-15') },
      'mk-query-advisor/t/samples/lit-002-01.txt',
   ),
   'LIT.002 YYYY-MM-DD'
);

ok(
   no_diff(sub { mk_query_advisor::main(@args,
         'SELECT c FROM tbl WHERE c=20100215') },
      'mk-query-advisor/t/samples/lit-002-02.txt',
   ),
   'LIT.002 YYYYMMDD'
);

# #############################################################################
# Table list.
# #############################################################################

ok(
   no_diff(sub { mk_query_advisor::main(@args,
         'SELECT * FROM tbl WHERE id=1') },
      'mk-query-advisor/t/samples/tbl-001-01.txt',
   ),
   'TBL.001 *'
);

ok(
   no_diff(sub { mk_query_advisor::main(@args,
         'SELECT tbl.* FROM tbl WHERE id=2') },
      'mk-query-advisor/t/samples/tbl-001-02.txt',
   ),
   'TBL.001 tbl.*'
);

ok(
   no_diff(sub { mk_query_advisor::main(@args,
         'SELECT tbl.* foo, bar FROM tbl WHERE id=1') },
      'mk-query-advisor/t/samples/tbl-002-01.txt',
   ),
   'TBL.002 tbl.* foo'
);

ok(
   no_diff(sub { mk_query_advisor::main(@args,
         'SELECT tbl.* AS foo, bar FROM tbl WHERE id=2') },
      'mk-query-advisor/t/samples/tbl-002-02.txt',
   ),
   'TBL.002 tbl.* AS foo'
);

# #############################################################################
# Query.
# #############################################################################

ok(
   no_diff(sub { mk_query_advisor::main(@args,
         'insert into foo values ("bar")') },
      'mk-query-advisor/t/samples/qry-001-01.txt',
   ),
   'QRY.001 INSERT'
);

ok(
   no_diff(sub { mk_query_advisor::main(@args,
         'replace into foo values ("bar")') },
      'mk-query-advisor/t/samples/qry-001-02.txt',
   ),
   'QRY.001 REPLACE'
);

# #############################################################################
# Subqueries.
# #############################################################################

ok(
   no_diff(sub { mk_query_advisor::main(@args,
         'select t from w where i=1 or i in (select * from j)') },
      'mk-query-advisor/t/samples/sub-001-01.txt',
   ),
   'SUB.001'
);

# #############################################################################
# Done.
# #############################################################################
exit;
