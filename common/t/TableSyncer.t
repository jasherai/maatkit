#!/usr/bin/perl

# This program is copyright (c) 2007 Baron Schwartz.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
use strict;
use warnings FATAL => 'all';

use Test::More;
use English qw(-no_match_vars);
use DBI;

# Open a connection to MySQL, or skip the rest of the tests.
my ($src_dbh, $dst_dbh);
eval {
   $src_dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 });
   $dst_dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 });
};
if ( $src_dbh ) {
   plan tests => 16;
}
else {
   plan skip_all => 'Cannot connect to MySQL';
}

require "../ChangeHandler.pm";
require "../MySQLDump.pm";
require "../Quoter.pm";
require "../RowDiff.pm";
require "../TableChecksum.pm";
require "../TableChunker.pm";
require "../TableNibbler.pm";
require "../TableParser.pm";
require "../TableSyncChunk.pm";
require "../TableSyncer.pm";
require "../TableSyncStream.pm";
require "../VersionParser.pm";

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like( $EVAL_ERROR, $pat, $msg );
}

`mysql < samples/before-TableSyncChunk.sql`;

my $ts = new TableSyncer();
my $tp = new TableParser();
my $du = new MySQLDump();
my $q  = new Quoter();
my $vp = new VersionParser();
my $ddl        = $du->get_create_table($src_dbh, $q, 'test', 'test1');
my $tbl_struct = $tp->parse($ddl);
my $chunker    = new TableChunker();
my $checksum   = new TableChecksum();
my $nibbler    = new TableNibbler();

my $algo = $ts->best_algorithm(
   struct => $tbl_struct,
   nibbler => $nibbler,
   chunker => $chunker,
);

ok ($algo, 'Found an algorithm');

$ts->sync_table(
   algorithm => $algo,
   buffer    => 0,
   checksum  => $checksum,
   chunker   => $chunker,
   chunksize => 2,
   dst_dbh   => $dst_dbh,
   dst_db    => 'test',
   dst_tbl   => 'test2',
   execute   => 1,
   lock      => 1,
   misc_dbh  => $src_dbh,
   print     => 1,
   quoter    => $q,
   replicate => 0,
   src_dbh   => $src_dbh,
   src_db    => 'test',
   src_tbl   => 'test1',
   tbl_struct => $tbl_struct,
   timeoutok  => 0,
   versionparser => $vp,
   wait      => 0,
   where     => '',
);
