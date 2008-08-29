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

<<<<<<< .mine
use Test::More tests => 19;
=======
use Test::More tests => 18;
>>>>>>> .r2246
use English qw(-no_match_vars);

use DBI;

require '../MySQLInstance.pm';
require '../DSNParser.pm';

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;


sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

print `../../sandbox/simple/make_sandbox 5126`;
my $cmd = '/usr/sbin/mysqld --defaults-file=/tmp/5126/my.sandbox.cnf --basedir=/usr --datadir=/tmp/5126/data --pid-file=/tmp/5126/data/mysql_sandbox5126.pid --skip-external-locking --port=5126 --socket=/tmp/5126/mysql_sandbox5126.sock --long-query-time=3';

my %ops = (
   pid_file              => '/tmp/5126/data/mysql_sandbox5126.pid',
   defaults_file         => '/tmp/5126/my.sandbox.cnf',
   datadir               => '/tmp/5126/data',
   port                  => '5126',
   'socket'              => '/tmp/5126/mysql_sandbox5126.sock',
   basedir               => '/usr',
   skip_external_locking => 'ON',
   long_query_time       => '3',
);

is(
   '/usr/sbin/mysqld',
   MySQLInstance::find_mysqld_binary_unix($cmd),
   'Found mysqld binary',
);

is(MySQLInstance::get_register_size(
   q{/bin/ls: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), for }),
   64,
   'Got 64-bit size',
);

is(MySQLInstance::get_register_size(
   q{/bin/ls: ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), }),
   32,
   'Got 32-bit size',
);

my $myi = new MySQLInstance($cmd);
isa_ok($myi, 'MySQLInstance');
is(
   $myi->{mysqld_binary},
   '/usr/sbin/mysqld',
   'mysqld_binary parsed'
);
$myi = new MySQLInstance(q{mysql    16420 20249 99 Aug27 ?        2-21:38:12 /usr/libexec/mysqld --defaults-file=/etc/my.cnf --basedir=/usr --datadir=/db/mysql --user=mysql --pid-file=/var/run/mysqld/mysqld.pid --skip-locking --socket=/db/mysql/mysql.sock});
is(
   $myi->{mysqld_binary},
   '/usr/libexec/mysqld',
   'mysqld_binary parsed again'
);

eval {
   new MySQLInstance(q{root      0.0  1096   4452 /bin/sh /usr/bin/mysqld_safe }
      . q{--defaults-file=/etc/my.cnf --pid-file=/var/run/mysqld/mysqld.pid }
      . q{--log-error=/var/log/mysqld.log});
};
like($EVAL_ERROR, qr/No mysqld binary found/,
   'Error when no mysqld binary found');

is(
   MySQLInstance::find_mysqld_binary_unix(
      q{root      0.0  1096   4452 /bin/sh /usr/bin/mysqld_safe }
      . q{--defaults-file=/etc/my.cnf --pid-file=/var/run/mysqld/mysqld.pid }
      . q{--log-error=/var/log/mysqld.log}),
   '', 'No mysqld binary found'
);

is(
   MySQLInstance::find_mysqld_binary_unix('/usr/libexec/mysqld'),
   '/usr/libexec/mysqld', 'Found mysqld binary at end of string'
);

$myi = new MySQLInstance($cmd);

is_deeply(
   \%{ $myi->{cmd_line_ops} },
   \%ops,
   'cmd_line_ops parsed'
);

my $expect_dsn_01 = {
   P => 5126,
   S => '/tmp/5126/mysql_sandbox5126.sock',
   h => '127.0.0.1',
};

is_deeply(
   $myi->get_DSN(S => 'foo'),
   {
      P => 5126,
      S => 'foo',
      h => 'localhost',
   },
   'It keeps localhost when socket given',
);

my $dsn = $myi->get_DSN();
is_deeply(
   $dsn,
   $expect_dsn_01,
   'DSN returned'
);

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
$myi->load_sys_vars($dbh);
# Sample of stable/predictable vars to make sure load_online_sys_vars()
# actually did something, otherwise $myi->{online_sys_vars} will be empty
my %expect_online_sys_vars_01 = (
   basedir     => '/usr/',
   datadir     => '/tmp/5126/data/',
   'log'       => 'OFF',
   'log_bin'   => 'ON',
   'port'      => 5126,
);
# The call to keys here and a few lines below is guaranteed to return in the
# same order the var names from %expect_online_sys_vars_01
my @expect_online_sys_vars
   = @expect_online_sys_vars_01{ keys %expect_online_sys_vars_01 };
# I can't get a hash slice like:
# @myi->{online_sys_vars}->{ keys %expect_online_sys_vars_01 }
# because @myi isn't valid and @$myi makes Perl think I want an array ref
# That's why I copy the whole hash:
my %online_sys_vars = %{ $myi->{online_sys_vars} };
my @online_sys_vars
   = @online_sys_vars{ keys %expect_online_sys_vars_01 };
is_deeply(
   \@online_sys_vars,
   \@expect_online_sys_vars,
   'Online sys vars'
);

my @expect_duplicate_vars_01 = qw(max_connections long_query_time);
my $duplicate_vars = $myi->duplicate_sys_vars();
is_deeply(
   $duplicate_vars,
   \@expect_duplicate_vars_01,
   'Duplicate vars'
);

my %expect_overriden_vars_01 = (
   long_query_time => [ '3', '1' ],
);
my $overriden_vars = $myi->overriden_sys_vars();
is_deeply(
   $overriden_vars,
   \%expect_overriden_vars_01,
   'Overriden sys vars'
);

my $oos = $myi->out_of_sync_sys_vars();
my @expect_oos_long_query_time = (3, 1);
is_deeply(
   \@{$oos->{long_query_time}},
   \@expect_oos_long_query_time,
   'out of sync sys vars: long_query_time online=3 conf=1'
);

$myi->load_status_vals($dbh);
ok(exists $myi->{status_vals}->{Aborted_clients},
   'status vals: Aborted_clients');
ok(exists $myi->{status_vals}->{Uptime},
   'status vals: Uptime');

$dbh->disconnect() if defined $dbh;

# #############################################################################
# Issue 49: mk-audit doesn't parse server binary right
# #############################################################################
my $ps = load_file('samples/ps_01_issue_49.txt');
my $mysqld_procs_ref = MySQLInstance::mysqld_processes($ps);
#is_deeply(
#   $mysqld_procs_ref,
#   ...
#   'Parses ps (issue 49)'
#);
%ops = (
   basedir               => '/usr',
   datadir               => '/mnt/data/mysql',
   user                  => 'mysql',
   pid_file              => '/var/run/mysqld/mysqld.pid',
   skip_external_locking => 'ON',
   socket                => '/mnt/data/mysql/mysql.sock',
);
$myi = new MySQLInstance($mysqld_procs_ref->[0]->{cmd});
is($myi->{mysqld_binary}, '/usr/libexec/mysqld', 'mysqld binary parsed (issue 49)');
is_deeply(
   \%{ $myi->{cmd_line_ops} },
   \%ops,
   'cmd line ops parsed (issue 49)'
);


exit;
