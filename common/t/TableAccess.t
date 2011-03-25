#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use MaatkitTest;
use QueryParser;
use SQLParser;
use TableAccess;

my $qp = new QueryParser();
my $sp = new SQLParser();
my $ta = new TableAccess(QueryParser => $qp, SQLParser => $sp);
isa_ok($ta, 'TableAccess');

my $query = "DELETE FROM d.t WHERE type != 'D' OR type IS NULL";
is_deeply(
   $ta->get_table_access(query=>$query),
   [
      { table   => 'd.t',
        context => 'DELETE',
        access  => 'write',
      },
      { table   => 'd.t',
        context => 'DELETE',
        access  => 'read',
      },
   ],
   "Simple DELETE"
);

$query = "SELECT * FROM zn.edp
  INNER JOIN zn.edp_input_key edpik     ON edp = edp.id
  INNER JOIN `zn`.`key`       input_key ON edpik.input_key = input_key.id
  WHERE edp.id = 296";
is_deeply(
   $ta->get_table_access(query=>$query),
   [
      { context => 'SELECT',
        access  => 'read',
        table   => 'zn.edp',
      },
      { context => 'JOIN',
        access  => 'read',
        table   => 'zn.edp_input_key',
      },
      { context => 'JOIN',
        access  => 'read',
        table   => 'zn.key',
      },
      { context => 'WHERE',
        access  => 'read',
        table   => 'edp',
      },
   ],
   "SELECT with 2 JOIN and WHERE"
);

$query = "REPLACE INTO db.tblA (dt, ncpc)
  SELECT dates.dt, scraped.total_r FROM tblB AS dates
  LEFT JOIN dbF.tblC AS scraped
    ON dates.dt = scraped.dt AND dates.version = scraped.version";
is_deeply(
   $ta->get_table_access(query=>$query),
   [
      { context => 'INSERT',
        access  => 'write',
        table   => 'db.tblA',
      },
      { context => 'INSERT',
        access  => 'read',
        table   => 'tblB',
      },
      { context => 'INSERT',
        access  => 'read',
        table   => 'dbF.tblC',
      },
      { context => 'JOIN',
        access  => 'read',
        table   => 'dbF.tblC',
      },
   ],
   "REPLACE SELECT JOIN"
);

$query = "ALTER TABLE tt.ks ADD PRIMARY KEY(`d`,`v`)";
is_deeply(
   $ta->get_table_access(query=>$query),
   [
      { context => 'ALTER',
        access  => 'write',
        table   => 'tt.ks',
      },
   ],
   "ALTER TABLE"
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $ta->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
