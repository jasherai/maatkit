#!/usr/bin/perl

# This program is copyright 
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

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

require '../MySQLInstance.pm';

my $cmd_01 = '/home/daniel/mysql/5.1.26/bin/mysqld --defaults-file=/home/daniel/sandboxes/msb_5_1_26/my.sandbox.cnf --basedir=/home/daniel/mysql/5.1.26 --datadir=/home/daniel/sandboxes/msb_5_1_26/data --log-error=/home/daniel/sandboxes/msb_5_1_26/data/virgil.err --pid-file=/home/daniel/sandboxes/msb_5_1_26/data/mysql_sandbox5126.pid --socket=/tmp/mysql_sandbox5126.sock --port=5126';

my %cmd_line_ops_01 = (
   pid_file => '/home/daniel/sandboxes/msb_5_1_26/data/mysql_sandbox5126.pid',
   defaults_file => '/home/daniel/sandboxes/msb_5_1_26/my.sandbox.cnf',
   log_error     => '/home/daniel/sandboxes/msb_5_1_26/data/virgil.err',
   datadir       => '/home/daniel/sandboxes/msb_5_1_26/data',
   port          => '5126',
   socket        => '/tmp/mysql_sandbox5126.sock',
   basedir       => '/home/daniel/mysql/5.1.26',
);

my $myi = new MySQLInstance($cmd_01);
$myi->load_default_sys_vars();

isa_ok($myi, 'MySQLInstance');

is(
   $myi->{mysqld_binary},
   '/home/daniel/mysql/5.1.26/bin/mysqld',
   'mysqld_binary parsed'
);

is_deeply(
   \%{ $myi->{cmd_line_ops} },
   \%cmd_line_ops_01,
   'cmd_line_ops parsed'
);

exit;
