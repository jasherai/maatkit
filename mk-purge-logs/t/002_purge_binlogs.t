#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 7;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-purge-logs/mk-purge-logs";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

my $master_binlogs = [
   { name => "mysql-bin.000001",
     size => 12345,
   },
   { name => "mysql-bin.000002",
     size => 6789,
   },
   { name => "mysql-bin.000003",
     size => 42,
   },
];

my %args = (
   dbh            => 1,
   master_binlogs => $master_binlogs,
   print          => 1,
   purge          => 0,
);

my $output = '';
my ($n_purged, $size_purged) = (0, 0);

$output = output(
   sub { ($n_purged, $size_purged) = mk_purge_logs::purge_binlogs(%args,
      purge_to => 'mysql-bin.000002',
      print    => 1,
   ) },
);
is(
   $output,
"mysql-bin.000001 12345
",
   "Prints purgeable binlogs"
);

is(
   $n_purged,
   0,
   "Reports zero purged binlogs with just print"
);

is(
   $size_purged,
   0,
   "Reports zero size purged with just print"
);


# #############################################################################
# Actually purge binlogs.
# #############################################################################
SKIP: {
   skip "Cannot connect to sandbox master", 2 unless $master_dbh;
   skip "Cannot connect to sandbox slave", 2  unless $slave_dbh;

   # A reset and flush should result in the master having 2 binlogs and
   # its slave using the 2nd.
   diag(`$trunk/sandbox/mk-test-env reset`);
   $master_dbh->do('flush logs');
   sleep 1;

   my $mbinlogs = $master_dbh->selectall_arrayref('show binary logs');
   skip "Failed to reset and flush master binary logs", 2
      unless @$mbinlogs == 2;

   my $ss = $slave_dbh->selectrow_hashref('show slave status');
   skip "Slave did not reset to second master binary log ", 2
      unless $ss->{Master_Log_File} eq $mbinlogs->[1]->[0];

   $master_binlogs = [ mk_purge_logs::get_master_binlogs(dbh=>$master_dbh) ];

   $args{dbh}            = $master_dbh;
   $args{purge_to}       = $master_binlogs->[1]->{name};
   $args{master_binlogs} = $master_binlogs;
   $args{print}          = 1;
   $args{purge}          = 1;

   $output = output(
      sub { ($n_purged, $size_purged) = mk_purge_logs::purge_binlogs(%args,
         purge_to => 'mysql-bin.000002',
         print    => 1,
      ) },
   );
   is(
      $output,
"$master_binlogs->[0]->{name} $master_binlogs->[0]->{size}
",
      "Prints purged binlog"
   );

   is(
      $n_purged,
      1,
      "Reports 1 purged binlog"
   );

   is(
      $size_purged,
      $master_binlogs->[0]->{size},
      "Reports purged size"
   );

   $master_binlogs = [ mk_purge_logs::get_master_binlogs(dbh=>$master_dbh) ];
   is_deeply(
      $master_binlogs,
      [
         { name => $mbinlogs->[1]->[0],
           size => $mbinlogs->[1]->[1],
         },
      ],
      "Purged the binglog"
   );

   $sb->wipe_clean($master_dbh);
   $master_dbh->disconnect();
   $slave_dbh->disconnect();
}

# #############################################################################
# Done.
# #############################################################################
exit;
