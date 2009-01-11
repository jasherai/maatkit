#!/usr/bin/perl
# This program is copyright 2008 Percona Inc.
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

use Test::More tests => 5;
use English qw(-no_match_vars);
use DBI;

require '../DSNParser.pm';
require '../Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

require '../SchemaDiscover.pm';
require '../DSNParser.pm';
require '../MySQLDump.pm';
require '../Quoter.pm';
require '../TableParser.pm';

my $d = new MySQLDump();
my $q = new Quoter();
my $t = new TableParser();
my $params = { dbh         => $dbh,
               MySQLDump   => $d,
               Quoter      => $q,
               TableParser => $t,
             };

my $sd = new SchemaDiscover($params);
isa_ok($sd, 'SchemaDiscover');

SKIP: {
   skip 'Sandbox master does not have the sakila database', 4
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   ok(exists $sd->{dbs}->{sakila},   'sakila db exists'    );
   ok(exists $sd->{dbs}->{mysql},    'mysql db exists'     );
   ok(exists $sd->{counts}->{TOTAL}, 'TOTAL counts exists' );

   $sd->discover_triggers_routines_events();
   is_deeply(
      \@{ $sd->{trigs_routines_events} },
      [
         'sakila del_trg 1',
         'sakila ins_trg 4',
         'sakila upd_trg 1',
         'sakila func 3',
         'sakila proc 3',
      ],
      'discover_triggers_routines_events'
   );

   $dbh->disconnect() if defined $dbh;
};

exit;
