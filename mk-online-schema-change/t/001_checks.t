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
require "$trunk/mk-online-schema-change/mk-online-schema-change";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 6;
}

my $vp      = new VersionParser();
my $q       = new Quoter();
my $tp      = new TableParser(Quoter => $q);
my $du      = new MySQLDump();
my $chunker = new TableChunker(Quoter => $q, MySQLDump => $du);
my $o       = new OptionParser();

$o->get_specs("$trunk/mk-online-schema-change/mk-online-schema-change");
$o->get_opts();
mk_online_schema_change::__set_quiet(1);

$sb->load_file('master', "mk-online-schema-change/t/samples/small_table.sql");
$dbh->do('use mkosc');

my $old_tbl_struct = $tp->parse($du->get_create_table($dbh, $q, 'mkosc', 'a'));

my %args = (
   dbh               => $dbh,
   old_table         => 'mkosc.a',
   old_table_renamed => 'mkosc.__old_a',
   old_tbl_struct    => $old_tbl_struct,
   new_table         => 'mkosc.__new_a',
   VersionParser     => $vp,
   Quoter            => $q,
   TableParser       => $tp,
   OptionParser      => $o,
   TableChunker      => $chunker,
);

my $chunk = mk_online_schema_change::checks(%args);
is_deeply(
   $chunk,
   {  column     => 'i',
      index      => 'PRIMARY',
      column_ddl => '  `i` int(11) NOT NULL ',
   },
   "checks() works"
);

throws_ok(
   sub { mk_online_schema_change::checks(
      %args,
      old_table => 'mkosc.does_not_exist'
   ) },
   qr/The old table does not exist/,
   "Old table must exist"
);

@ARGV = qw(--rename-tables);
$o->get_opts();
throws_ok(
   sub { mk_online_schema_change::checks(
      %args,
      old_table_renamed => 'mkosc.a',
   ) },
   qr/The old renamed table mkosc.a already exists/,
   "Old renamed table cannot already exist if --rename-tables"
);

throws_ok(
   sub { mk_online_schema_change::checks(
      %args,
      new_table => 'mkosc.a',
   ) },
   qr/The new table already exists/,
   "New table cannot already exist"
);

$dbh->do('CREATE TRIGGER foo AFTER DELETE ON mkosc.a FOR EACH ROW DELETE FROM mkosc.a WHERE 0');
throws_ok(
   sub { mk_online_schema_change::checks(%args) },
   qr/The old table has triggers/,
   "Old table cannot have triggers"
);
$dbh->do('DROP TRIGGER mkosc.foo');

$dbh->do('ALTER TABLE mkosc.a DROP COLUMN i');
my $tmp_struct = $tp->parse($du->get_create_table($dbh, $q, 'mkosc', 'a'));
throws_ok(
   sub { mk_online_schema_change::checks(
      %args,
      old_tbl_struct => $tmp_struct,
   ) },
   qr/The old table does not have a unique, single-column index/,
   "Old table must have a chunkable index"
);
$sb->load_file('master', "mk-online-schema-change/t/samples/small_table.sql");

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
