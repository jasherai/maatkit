#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use List::Util qw(max);

use SchemaIterator;
use Quoter;
use DSNParser;
use Sandbox;
use OptionParser;
use MaatkitTest;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $q   = new Quoter();
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => "Cannot connect to sandbox master";
}
else {
   plan tests => 34;
}


$dbh->{FetchHashKeyName} = 'NAME_lc';

my $si = new SchemaIterator(
   Quoter        => $q,
);
isa_ok($si, 'SchemaIterator');

sub get_all {
   my ( $itr ) = @_;
   my @objs;
   while ( my $obj = $itr->() ) {
      MKDEBUG && SchemaIterator::_d('Iterator returned', Dumper($obj));
      push @objs, $obj;
   }
   @objs = sort @objs;
   return \@objs;
}

sub get_all_db_tbls {
   my ( $dbh, $si ) = @_;
   my @db_tbls;
   my $next_db = $si->get_db_itr(dbh=>$dbh);
   while ( my $db = $next_db->() ) {
      my $next_tbl = $si->get_tbl_itr(
         dbh   => $dbh,
         db    => $db,
         views => 0,
      );
      while ( my $tbl = $next_tbl->() ) {
         push @db_tbls, "$db.$tbl";
      }
   }
   return \@db_tbls;
}

# ###########################################################################
# Test simple, unfiltered get_db_itr().
# ###########################################################################

$sb->load_file('master', 'common/t/samples/SchemaIterator.sql');
my @dbs = sort grep { $_ !~ m/information_schema|lost\+found/; } map { $_->[0] } @{ $dbh->selectall_arrayref('show databases') };

my $next_db = $si->get_db_itr(dbh=>$dbh);
is(
   ref $next_db,
   'CODE',
   'get_db_iter() returns a subref'
);

is_deeply(
   get_all($next_db),
   \@dbs,
   'get_db_iter() found the databases'
);

# ###########################################################################
# Test simple, unfiltered get_tbl_itr().
# ###########################################################################

my $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is(
   ref $next_tbl,
   'CODE',
   'get_tbl_iter() returns a subref'
);

is_deeply(
   get_all($next_tbl),
   [qw(t1 t2 t3)],
   'get_tbl_itr() found the db1 tables'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d2');
is_deeply(
   get_all($next_tbl),
   [qw(t1)],
   'get_tbl_itr() found the db2 table'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d3');
is_deeply(
   get_all($next_tbl),
   [],
   'get_tbl_itr() found no db3 tables'
);


# #############################################################################
# Test make_filter().
# #############################################################################
my $o = new OptionParser(
   description => 'SchemaIterator'
);
$o->get_specs("$trunk/mk-parallel-dump/mk-parallel-dump");
$o->get_opts();

my $filter = $si->make_filter($o);
is(
   ref $filter,
   'CODE',
   'make_filter() returns a coderef'
);

$si->set_filter($filter);

$next_db = $si->get_db_itr(dbh=>$dbh);
is_deeply(
   get_all($next_db),
   \@dbs,
   'Database not filtered',
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   [qw(t1 t2 t3)],
   'Tables not filtered'
);

# Filter by --databases (-d).
@ARGV=qw(--d d1);
$o->get_opts();
$si->set_filter($si->make_filter($o));

$next_db = $si->get_db_itr(dbh=>$dbh);
is_deeply(
   get_all($next_db),
   ['d1'],
   '--databases'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   [qw(t1 t2 t3)],
   '--database filter does not affect tables'
);

# Filter by --databases (-d) and --tables (-t).
@ARGV=qw(-d d1 -t t2);
$o->get_opts();
$si->set_filter($si->make_filter($o));

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   ['t2'],
   '--databases and --tables'
);

# Ignore some dbs and tbls.
@ARGV=('--ignore-databases', 'mysql,sakila,d1,d3');
$o->get_opts();
$si->set_filter($si->make_filter($o));

$next_db = $si->get_db_itr(dbh=>$dbh);
is_deeply(
   get_all($next_db),
   ['d2'],
   '--ignore-databases'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d2');
is_deeply(
   get_all($next_tbl),
   ['t1'],
   '--ignore-databases filter does not affect tables'
);

@ARGV=('--ignore-databases', 'mysql,sakila,d2,d3',
       '--ignore-tables', 't1,t2');
$o->get_opts();
$si->set_filter($si->make_filter($o));

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   ['t3'],
   '--ignore-databases and --ignore-tables'
);

# Select some dbs but ignore some tables.
@ARGV=('-d', 'd1', '--ignore-tables', 't1,t3');
$o->get_opts();
$si->set_filter($si->make_filter($o));

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   ['t2'],
   '--databases and --ignore-tables'
);

# Filter by engines, which requires extra work: SHOW TABLE STATUS.
@ARGV=qw(--engines InnoDB);
$o->get_opts();
$si->set_filter($si->make_filter($o));

$next_db = $si->get_db_itr(dbh=>$dbh);
is_deeply(
   get_all($next_db),
   \@dbs,
   '--engines does not affect databases'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   ['t2'],
   '--engines'
);

@ARGV=qw(--ignore-engines MEMORY);
$o->get_opts();
$si->set_filter($si->make_filter($o));

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   [qw(t1 t2)],
   '--ignore-engines'
);

# ###########################################################################
# Filter views.
# ###########################################################################
SKIP: {
   skip 'Sandbox master does not have the sakila database', 2
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   my @sakila_tbls = map { $_->[0] } grep { $_->[1] eq 'BASE TABLE' } @{ $dbh->selectall_arrayref('show /*!50002 FULL*/ tables from sakila') };

   my @all_sakila_tbls = map { $_->[0] } @{ $dbh->selectall_arrayref('show /*!50002 FULL*/ tables from sakila') };

   @ARGV=();
   $o->get_opts();
   $si->set_filter($si->make_filter($o));

   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'sakila');
   is_deeply(
      get_all($next_tbl),
      \@sakila_tbls,
      'Table itr does not return views by default'
   );

   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'sakila', views=>1);
   is_deeply(
      get_all($next_tbl),
      \@all_sakila_tbls,
      'Table itr returns views if specified'
   );
};

# ###########################################################################
# Make sure --engine filter is case-insensitive.
# ###########################################################################

# In MySQL 5.0 it's "MRG_MyISAM" but in 5.1 it's "MRG_MYISAM".  SiLlY.

@ARGV=qw(--engines InNoDb);
$o->get_opts();
$si->set_filter($si->make_filter($o));
$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   ['t2'],
   '--engines is case-insensitive'
);

@ARGV=qw(--ignore-engines InNoDb);
$o->get_opts();
$si->set_filter($si->make_filter($o));
$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   ['t1','t3'],
   '--ignore-engines is case-insensitive'
);

# ###########################################################################
# Filter by regex.
# ###########################################################################
@ARGV=qw(--databases-regex d[13] --tables-regex t[^3]);
$o->get_opts();
$si->set_filter($si->make_filter($o));

$next_db = $si->get_db_itr(dbh=>$dbh);
is_deeply(
   get_all($next_db),
   [qw(d1 d3)],
   '--databases-regex'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   ['t1','t2'],
   '--tables-regex'
);

# ignore patterns
@ARGV=qw{--ignore-databases-regex (?:^d[23]|mysql|info|sakila) --ignore-tables-regex t[^23]};
$o->get_opts();
$si->set_filter($si->make_filter($o));

$next_db = $si->get_db_itr(dbh=>$dbh);
is_deeply(
   get_all($next_db),
   ['d1'],
   '--ignore-databases-regex'
);

$next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
is_deeply(
   get_all($next_tbl),
   [qw(t2 t3)],
   '--ignore-tables-regex'
);


# #############################################################################
# Issue 806: mk-table-sync --tables does not honor schema qualier
# #############################################################################

# Filter by db-qualified table.  There is t1 in both d1 and d2.
# We want only d1.t1.
@ARGV=qw(-t d1.t1);
$o->get_opts();
$si->set_filter($si->make_filter($o));

is_deeply(
   get_all_db_tbls($dbh, $si),
   [qw(d1.t1)],
   '-t d1.t1 (issue 806)'
);

@ARGV=qw(-d d1 -t d1.t1);
$o->get_opts();
$si->set_filter($si->make_filter($o));

is_deeply(
   get_all_db_tbls($dbh, $si),
   [qw(d1.t1)],
   '-d d1 -t d1.t1 (issue 806)'
);

@ARGV=qw(-d d2 -t d1.t1);
$o->get_opts();
$si->set_filter($si->make_filter($o));

is_deeply(
   get_all_db_tbls($dbh, $si),
   [],
   '-d d2 -t d1.t1 (issue 806)'
);

@ARGV=('-t','d1.t1,d1.t3');
$o->get_opts();
$si->set_filter($si->make_filter($o));

is_deeply(
   get_all_db_tbls($dbh, $si),
   [qw(d1.t1 d1.t3)],
   '-t d1.t1,d1.t3 (issue 806)'
);

@ARGV=('--ignore-databases', 'mysql,sakila', '--ignore-tables', 'd1.t2');
$o->get_opts();
$si->set_filter($si->make_filter($o));

is_deeply(
   get_all_db_tbls($dbh, $si),
   [qw(d1.t1 d1.t3 d2.t1)],
   '--ignore-tables d1.t2 (issue 806)'
);

@ARGV=('-t','d1.t3,d2.t1');
$o->get_opts();
$si->set_filter($si->make_filter($o));

is_deeply(
   get_all_db_tbls($dbh, $si),
   [qw(d1.t3 d2.t1)],
   '-t d1.t3,d2.t1 (issue 806)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
