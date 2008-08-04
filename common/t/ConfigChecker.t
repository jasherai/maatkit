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

use Test::More tests => 3;
use English qw(-no_match_vars);

use DBI;

require '../ConfigChecker.pm';
require '../MySQLInstance.pm';
require '../DSNParser.pm';

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

# #############################################################################
# First, setup a MySQLInstance... 
# #############################################################################
my $cmd_01 = '/usr/sbin/mysqld --defaults-file=/tmp/5126/my.sandbox.cnf --basedir=/usr --datadir=/tmp/5126/data --pid-file=/tmp/5126/data/mysql_sandbox5126.pid --skip-external-locking --port=5126 --socket=/tmp/5126/mysql_sandbox5126.sock --long-query-time=3';
my $myi = new MySQLInstance($cmd_01);
$myi->load_default_sys_vars();
my $dsn = $myi->get_DSN();
$dsn->{u} = 'msandbox';
$dsn->{p} = 'msandbox';
my $dbh;
my $dp = new DSNParser();
eval {
   $dbh = $dp->get_dbh($dp->get_cxn_params($dsn));
};
if ( $EVAL_ERROR ) {
   chomp $EVAL_ERROR;
   print "Cannot connect to " . $dp->as_string($dsn)
         . ": $EVAL_ERROR\n\n";
}
$myi->load_online_sys_vars(\$dbh);

# #############################################################################
# Now, begin checking ConfigChecker
# #############################################################################
my $cc = new ConfigChecker();
isa_ok($cc, 'ConfigChecker');

my @problems = $cc->run_all_checks($myi->{online_sys_vars});
is(
   $problems[0],
   'innodb_flush_method != O_DIRECT',
   'innodb_flush_method != O_DIRECT'
);
cmp_ok(@problems, '>=', 4, 'First 4 problems');

# print Dumper(\@problems);

$dbh->disconnect() if defined $dbh;

exit;
