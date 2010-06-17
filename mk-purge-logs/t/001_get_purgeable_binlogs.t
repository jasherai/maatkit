#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 10;

use MaatkitTest;
require "$trunk/mk-purge-logs/mk-purge-logs";

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

my $slave_binlogs = [
   { slave => "12346",
     name  => "mysql-bin.000002",
   },
   { slave => "12347",
     name  => "mysql-bin.000002",
   },
];

my %args = (
   master_binlogs => $master_binlogs,
   slave_binlogs  => $slave_binlogs,
);

my $purge_to_binlog = '';

# #############################################################################
# Test purging unused binlogs.
# #############################################################################

$purge_to_binlog = mk_purge_logs::get_purge_to_binlog(
   %args,
   unused => 1,
);
is(
   $purge_to_binlog,
   "mysql-bin.000002",
   "Unused binlog, purge to first used"
);

$slave_binlogs->[0]->{name} = "mysql-bin.000001";

$purge_to_binlog = mk_purge_logs::get_purge_to_binlog(
   %args,
   unused => 1,
);
is(
   $purge_to_binlog,
   undef,
   "First binlog used, no purge"
);

$slave_binlogs->[0]->{name} = "mysql-bin.000003";
$slave_binlogs->[1]->{name} = "mysql-bin.000003";

$purge_to_binlog = mk_purge_logs::get_purge_to_binlog(
   %args,
   unused => 1,
);
is(
   $purge_to_binlog,
   "mysql-bin.000003",
   "All but latest binlog used, purge to latest"
);

# #############################################################################
# Test purging binlogs by size.
# #############################################################################

# Total size is 19_176.

$purge_to_binlog = mk_purge_logs::get_purge_to_binlog(
   %args,
   total_size => 20_000,
);
is(
   $purge_to_binlog,
   undef,
   "Total size < max size, no purge"
);

# Purging just the first binlog will remove 12_345 from the total size,
# satisfying the 10k max size (remaining 2 binlogs would = 6_831 in size).
$purge_to_binlog = mk_purge_logs::get_purge_to_binlog(
   %args,
   total_size => 10_000,
);
is(
   $purge_to_binlog,
   "mysql-bin.000002",
   "Total size > max size, purge first binlog"
);

$purge_to_binlog = mk_purge_logs::get_purge_to_binlog(
   %args,
   total_size => 19_176,
);
is(
   $purge_to_binlog,
   undef,
   "Total size = max size, purge first binlog"
);

# All binlogs would have to be purged to meet max size.  But since all
# binlogs cannot be purged, purging to the last binlog should be suggested.
$purge_to_binlog = mk_purge_logs::get_purge_to_binlog(
   %args,
   total_size => 1,
);
is(
   $purge_to_binlog,
   "mysql-bin.000003",
   "Small max size, purge all but latest binlog"
);

# #############################################################################
# Test purging by unused+size.
# #############################################################################

# Slave binlogs are currently:
# $slave_binlogs->[0]->{name} = "mysql-bin.000003";
# $slave_binlogs->[1]->{name} = "mysql-bin.000003";

# This should purge to mysql-bin.000002 because mysql-bin.000001 is
# unused and purging it will satisfy size.
$purge_to_binlog = mk_purge_logs::get_purge_to_binlog(
   %args,
   unused     => 1,
   total_size => 10_000,
);
is(
   $purge_to_binlog,
   "mysql-bin.000002",
   "Purge unused with max size < total size"
);

# Repeat same test but this change will prevent anything from being
# purged because even though purging to mysql-bin.000002 satisfies
# size, mysql-bin.000001 is used.
$slave_binlogs->[0]->{name} = "mysql-bin.000001";
$purge_to_binlog = mk_purge_logs::get_purge_to_binlog(
   %args,
   unused     => 1,
   total_size => 10_000,
);
is(
   $purge_to_binlog,
   undef,
   "Binglog for max size is used, no purge"
);

# Repeat same test but reverse the conditions: unused logs but
# there's still enough space.
$slave_binlogs->[0]->{name} = "mysql-bin.000003";
$purge_to_binlog = mk_purge_logs::get_purge_to_binlog(
   %args,
   unused     => 1,
   total_size => 100_000,
);
is(
   $purge_to_binlog,
   undef,
   "Unused binlogs don't exceed max size, no purge"
);

# #############################################################################
# Done.
# #############################################################################
exit;
