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

use Test::More tests => 10;
use English qw(-no_match_vars);

use DBI;

require '../MySQLAdvisor.pm';
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
# Now, begin checking MySQLAdvisor 
# #############################################################################
my $ma = new MySQLAdvisor();
isa_ok($ma, 'MySQLAdvisor');

my %problems = $ma->run_all_checks($myi->{online_sys_vars}, $myi->{status_vals});
ok( exists $problems{innodb_flush_method}, 'check innodb_flush_method fails' );
ok( exists $problems{max_connections},     'check max_connections fails'     );
ok( exists $problems{log_slow_queries},    'check log_slow_queries fails'    );
ok( exists $problems{thread_cache_size},   'check thread_cache_size fails'   );
ok(!exists $problems{'socket'},            'check socket passes'             );
ok( exists $problems{query_cache},         'check query_cache fails'         );

%problems = $ma->run_check($myi->{online_sys_vars}, $myi->{status_vals}, 'foo');
ok(exists $problems{ERROR}, 'check foo does not exist');

%problems = $ma->run_check($myi->{online_sys_vars}, $myi->{status_vals}, 'Innodb_buffer_pool_pages_free');
ok(!exists $problems{ERROR}, 'check Innodb_buffer_pool_pages_free does exist');
ok(!exists $problems{Innodb_buffer_pool_pages_free}, 'check Innodb_buffer_pool_pages_free fails');

$dbh->disconnect() if defined $dbh;

exit;
