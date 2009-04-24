#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 41;

require '../MySQLInstance.pm';
require '../OptionParser.pm';
require '../DSNParser.pm';
require '../Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

my $o = new OptionParser(
   description => 'for MySQLInstance.t',
   dp          => $dp,
);
$o->get_specs('../../mk-audit/mk-audit');

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

# We must get the basedir to the mysqld bin because this path will
# differ from my machine to yours. For example, on my machine it is:
# /home/daniel/mysql/5.0.51
# I doubt, though, that that path is valid on your machine.
my $msandbox_basedir = $ENV{MSANDBOX_BASEDIR};
if ( !defined $msandbox_basedir || !-d $msandbox_basedir ) {
   BAIL_OUT("The MSANDBOX_BASEDIR environment variable is not set or valid.");
}

# This should be the exact cmd line op with which the sandbox started mysqld.
# This comes from the start script of a sandbox (e.g. /tmp/12345/start).  If
# this differs, tests below will fail.
my $cmd = "$msandbox_basedir/bin/mysqld --defaults-file=/tmp/12345/my.sandbox.cnf --basedir=/usr --datadir=/tmp/12345/data --pid-file=/tmp/12345/data/mysql_sandbox12345.pid --skip-external-locking --port=12345 --socket=/tmp/12345/mysql_sandbox12345.sock --long-query-time=3";
my %ops = (
   pid_file              => '/tmp/12345/data/mysql_sandbox12345.pid',
   defaults_file         => '/tmp/12345/my.sandbox.cnf',
   datadir               => '/tmp/12345/data',
   port                  => '12345',
   'socket'              => '/tmp/12345/mysql_sandbox12345.sock',
   basedir               => '/usr',
   skip_external_locking => 'ON',
   long_query_time       => '3',
);
is(
   "$msandbox_basedir/bin/mysqld",
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

my $mi = new MySQLInstance($cmd);
isa_ok($mi, 'MySQLInstance');
is(
   $mi->{mysqld_binary},
   "$msandbox_basedir/bin/mysqld",
   'mysqld_binary parsed'
);

$mi = new MySQLInstance(q{mysql    16420 20249 99 Aug27 ?        2-21:38:12 /usr/libexec/mysqld --defaults-file=/etc/my.cnf --basedir=/usr --datadir=/db/mysql --user=mysql --pid-file=/var/run/mysqld/mysqld.pid --skip-locking --socket=/db/mysql/mysql.sock});
is(
   $mi->{mysqld_binary},
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

$mi = new MySQLInstance($cmd);
is_deeply(
   \%{ $mi->{cmd_line_ops} },
   \%ops,
   'cmd_line_ops parsed'
);

@ARGV = qw(-S foo);
$o->get_opts();
is_deeply(
   $mi->get_DSN($o),
   {
      P => 12345,
      S => 'foo',
      h => 'localhost',
   },
   'It keeps localhost when socket given',
);

$mi->load_sys_vars($dbh);
# Sample of stable/predictable vars to make sure load_online_sys_vars()
# actually did something, otherwise $mi->{online_sys_vars} will be empty
is($mi->{online_sys_vars}->{datadir}, '/tmp/12345/data/', 'Loads online sys vars (1/3)');
is($mi->{online_sys_vars}->{log_bin}, 'ON', 'Loads online sys var (2/3)');
is($mi->{online_sys_vars}->{port}, '12345', 'Loads online sys var (3/3)');

my $ret = $mi->duplicate_sys_vars();
is_deeply(
   $ret,
   [qw(max_connections long_query_time)],
   'Duplicate vars'
);

$ret = $mi->overriden_sys_vars();
is_deeply(
   $ret,
   { long_query_time => [ '3', '1' ], },
   'Overriden sys vars'
);

$ret = $mi->out_of_sync_sys_vars();
is_deeply(
   $ret->{long_query_time},
   {online=>3, config=>1},
   'out of sync sys var}: long_query_time online=3 conf=1'
);

$mi->load_status_vals($dbh);
ok(exists $mi->{status_vals}->{Aborted_clients},
   'status vals: Aborted_clients');
ok(exists $mi->{status_vals}->{Uptime},
   'status vals: Uptime');

my $eq = MySQLInstance::get_eq_for('query_cache_type');
is(
   $eq->('1', 'ON'),
   '1',
   'eq_for query_cache_type true for 1 and ON'
);
$eq = MySQLInstance::get_eq_for('ft_stopword_file');
is(
   $eq->('', '(built-in)'),
   '1',
   "eq_for ft_stopword_file true for '' and (built-in)"
);
$eq = MySQLInstance::get_eq_for('language');
is(
   $eq->('/usr/share/mysql/english', '/usr/share/mysql/english/'),
   '1',
   'eq_for language true for /path and /path/ (issue 102)');
$eq = MySQLInstance::get_eq_for('log_bin');
is(
   $eq->('mysql-bin', 'ON'),
   '1',
   'eq_for mysql-bin true for mysql-bin and ON'
);
$eq = MySQLInstance::get_eq_for('open_files_limit');
is(
   $eq->('', '/tmp/'),
   '1',
   'eq_for open_files_limit true for undef and /tmp/ (issue 138)'
);

# Check that missing my_print_defaults causes the obj to die
eval {
   $mi->_vars_from_defaults_file('', 'my_print_defaults_foozed');
};
like($EVAL_ERROR, qr/Cannot execute my_print_defaults command/, 'Dies if my_print_defaults cannot be executed');

# Handle pathological oos cases like 2.2 and 2.200000 for long_query_time.
$mi->{conf_sys_vars}   = {};
$mi->{online_sys_vars} = {};
# sql_mode has an eq_for calling _veq()
$mi->{conf_sys_vars}->{long_query_time}   = '2.2';
$mi->{online_sys_vars}->{long_query_time} = '2.200000';
$ret = $mi->out_of_sync_sys_vars();
ok(scalar keys %$ret == 0, 'long_query_time 2.2 is not oos with 2.200000');

# !!! REMEMBER !!!
# I just destroyed parts of $mi in the test above. Therefore, if you
# add tests below here, you may want to make a new MySQLInstance obj.

# #############################################################################
# Issue 49: mk-audit doesn't parse server binary right
# #############################################################################
my $ps = load_file('samples/ps_01_issue_49.txt');
my $mysqld_procs_ref = MySQLInstance::mysqld_processes($ps);

is_deeply(
   $mysqld_procs_ref,
   [
      {
         cmd => '/usr/libexec/mysqld --basedir=/usr --datadir=/mnt/data/mysql --user=mysql --pid-file=/var/run/mysqld/mysqld.pid --skip-external-locking --socket=/mnt/data/mysql/mysql.sock',
         pcpu => '0.4',
         syslog => 'No',
         user => 'mysql',
         rss => '65032',
         '64bit' => 'No',
         vsz => '626604'
      },
   ],
   'Parses ps (issue 49)'
);

%ops = (
   basedir               => '/usr',
   datadir               => '/mnt/data/mysql',
   user                  => 'mysql',
   pid_file              => '/var/run/mysqld/mysqld.pid',
   skip_external_locking => 'ON',
   socket                => '/mnt/data/mysql/mysql.sock',
   defaults_file         => '',
);
$mi = new MySQLInstance($mysqld_procs_ref->[0]->{cmd});
is($mi->{mysqld_binary}, '/usr/libexec/mysqld', 'mysqld binary parsed (issue 49)');
is_deeply(
   \%{ $mi->{cmd_line_ops} },
   \%ops,
   'cmd line ops parsed (issue 49)'
);

# #############################################################################
# Issue 58: mk-audit warns about bogus differences between online values
# and my.cnf values
# #############################################################################
my $mysqld_output = load_file('samples/mysqld_01_issue_58.txt');
$mi->_load_default_defaults_files($mysqld_output),
is_deeply(
   $mi->{default_defaults_files},
   [
      '/etc/my.cnf',
      '~/.my.cnf'
   ],
   'Parses default defaults files and removes duplicates (issue 58)'
);
# Break ourselves:
@{ $mi->{default_defaults_files} } = ();
eval { $mi->_vars_from_defaults_file(); };
like($EVAL_ERROR, qr/MySQL instance has no valid defaults files/, 'Dies if no valid defaults files');

# #############################################################################
# Issue 135: mk-audit dies if running mysqld --help --verbose dies      
# #############################################################################
$mi = new MySQLInstance($cmd);
SKIP: {
   skip 'segfault.c is not compiled', 1
      unless -f 'samples/segfault';
   $mi->{mysqld_binary} = 'samples/segfault';
   {
      local $SIG{__WARN__}
         = sub { $EVAL_ERROR = $_[0]; }; # suppress warn output
      $mi->load_sys_vars($dbh);
   };
   like($EVAL_ERROR, qr/Cannot execute $mi->{mysqld_binary}/, "Warns if mysqld fails to execute");
};

$mi->{mysqld_binary} = 'true';
{
   local $SIG{__WARN__} = sub { $EVAL_ERROR = $_[0]; }; # suppress warn output
   $mi->load_sys_vars($dbh);
};
like($EVAL_ERROR, qr/MySQL returned no information/, "Warns if mysqld returns nothing");

# #############################################################################
# Issue 42: mk-audit doesn't separate instances correctly
# #############################################################################
$ps = load_file('samples/ps_02.txt');
$mysqld_procs_ref = MySQLInstance::mysqld_processes($ps);
is_deeply(
   $mysqld_procs_ref,
   [
   {
      cmd => '/usr/sbin/mysqld --basedir=/usr --datadir=/var/lib/mysql --user=mysql --pid-file=/var/run/mysqld/mysqld.pid --skip-external-locking --port=3306 --socket=/var/run/mysqld/mysqld.sock',
      pcpu => '0.0',
      syslog => 'Yes',
      user => 'mysql',
      rss => '16292',
      '64bit' => 'Yes',
      vsz => '127196'
   },
   {
      cmd => '/usr/sbin/mysqld --defaults-file=/tmp/12345/my.sandbox.cnf --basedir=/usr --datadir=/tmp/12345/data --pid-file=/tmp/12345/data/mysql_sandbox12345.pid --skip-external-locking --port=12345 --socket=/tmp/12345/mysql_sandbox12345.sock --long-query-time=3',
      pcpu => '0.1',
      syslog => 'Yes',
      user => 'baron',
      rss => '18816',
      '64bit' => 'Yes',
      vsz => '125400'
   },
   {
      cmd => '/usr/sbin/mysqld --defaults-file=/tmp/12346/my.sandbox.cnf --basedir=/usr --datadir=/tmp/12346/data --pid-file=/tmp/12346/data/mysql_sandbox12346.pid --skip-external-locking --port=12346 --socket=/tmp/12346/mysql_sandbox12346.sock --long-query-time=3',
      pcpu => '0.1',
      syslog => 'Yes',
      user => 'baron',
      rss => '19024',
      '64bit' => 'Yes',
      vsz => '125528'
   },
   {
      cmd => '/usr/sbin/mysqld --defaults-file=/tmp/12347/my.sandbox.cnf --basedir=/usr --datadir=/tmp/12347/data --pid-file=/tmp/12347/data/mysql_sandbox12347.pid --skip-external-locking --port=12347 --socket=/tmp/12347/mysql_sandbox12347.sock --long-query-time=3',
      pcpu => '0.1',
      syslog => 'Yes',
      user => 'baron',
      rss => '18796',
      '64bit' => 'Yes',
      vsz => '126396'
   },
   {
      cmd => '/usr/sbin/mysqld --defaults-file=/tmp/12348/my.sandbox.cnf --basedir=/usr --datadir=/tmp/12348/data --pid-file=/tmp/12348/data/mysql_sandbox12348.pid --skip-external-locking --port=12348 --socket=/tmp/12348/mysql_sandbox12348.sock --long-query-time=3',
      pcpu => '0.1',
      syslog => 'Yes',
      user => 'baron',
      rss => '18792',
      '64bit' => 'Yes',
      vsz => '126396'
   },
   ],
   'Parses Baron\'s ps (issue 42)'
);
my @dsns = (
   {
      P => 3306,
      S => '/var/run/mysqld/mysqld.sock',
      h => 'localhost',
   },
   {
      P => 12345,
      S => '/tmp/12345/mysql_sandbox12345.sock',
      h => '127.0.0.1',
   },
   {
      P => 12346,
      S => '/tmp/12346/mysql_sandbox12346.sock',
      h => '127.0.0.1',
   },
   {
      P => 12347,
      S => '/tmp/12347/mysql_sandbox12347.sock',
      h => '127.0.0.1',
   },
   {
      P => 12348,
      S => '/tmp/12348/mysql_sandbox12348.sock',
      h => '127.0.0.1',
   },
);
@ARGV = ();
$o->get_opts();
my $i = 0;
foreach my $m ( @$mysqld_procs_ref ) {
   $mi     = new MySQLInstance($m->{cmd});
   my $dsn = $mi->get_DSN($o);
   is_deeply(
      $dsn,
      $dsns[$i++],
      "DSN for Baron\'s mysqld instance $i"
   );
}

# #############################################################################
# Issue 139: mk-audit out-of-sync false-positive for sql_mode
# NO_UNSIGNED_SUBTRACTION
# #############################################################################

# This issue actually affects any var that has an eq_for calling _veq().
# _veq() returns false even if the var values are the same (and this is
# correct for _veq()). The real problem is that the eq_for subs should only
# be called after a standard eq comparison fails.
$mi->{conf_sys_vars}   = {};
$mi->{online_sys_vars} = {};
# sql_mode has an eq_for calling _veq()
$mi->{conf_sys_vars}->{sql_mode}   = 'foo';
$mi->{online_sys_vars}->{sql_mode} = 'foo';
$ret = $mi->out_of_sync_sys_vars();
ok(scalar keys %$ret == 0, 'Var with _veq eq_for and same vals (issue 139)');

# #############################################################################
# Issue 115: mk-audit false-positive duplicate system variables
# #############################################################################
# According to
# http://dev.mysql.com/doc/refman/5.0/en/replication-options-slave.html
# these vars can be given multiple times.
my @dupes = (
   ['replicate_wild_do_table',''],
   ['replicate_wild_ignore_table',''],
   ['replicate_rewrite_db',''],
   ['replicate_ignore_table',''],
   ['replicate_ignore_db',''],
   ['replicate_do_table',''],
   ['replicate_do_db',''],
);
$mi->{defaults_file_sys_vars} = [];
push @{$mi->{defaults_file_sys_vars}}, @dupes, @dupes;
$ret = $mi->duplicate_sys_vars();
ok(scalar @$ret == 0, 'Exceptions to duplicate sys vars like replicate-do-db (issue 115)');

# #############################################################################
# For issue 248, getting --host to work with mk-audit will require
# significant changes.
# #############################################################################
# TODO

$sb->wipe_clean($dbh);
exit;
