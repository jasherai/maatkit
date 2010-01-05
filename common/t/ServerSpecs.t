#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

$ENV{PATH} = "./samples/:$ENV{PATH}";

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 11;

use ServerSpecs;
use MaatkitTest;

my $server = ServerSpecs::server_specs();

ok($server->{os}->{name} ne '', 'Has OS name');
ok($server->{os}->{version} ne '', 'Has OS version');
ok($server->{os}->{regsize} ne '', 'Has OS regsize');
ok($server->{os}->{swappiness} ne '', 'Has OS swappiness');

my %vars = ServerSpecs::parse_sysctl_conf('samples/sysctl.conf_01');
is_deeply(
   \%vars,
   {
      ip_forward         => '0',
      tcp_syncookies     => '1',
      tcp_synack_retries => '2',
   },
   'Parses sysctl.conf (issue 56)'
);

my @mem = ServerSpecs::_memory_slots();
ok(!scalar @mem, 'Cannot exec dmidecode so no memory slot info');

ok(!ServerSpecs::_can_run('/tmp/blahblah'), 'Cannot exec non-existent app');

unlike(
   $server->{storage}->{raid}->{aacraid},
   qr/unable to check/,
   'Dummy aacraid info'
);
unlike(
   $server->{storage}->{raid}->{'LSI Logic SAS based MegaRAID'},
   qr/unable to check/,
   'Dummy MegaRAID info'
);
unlike(
   $server->{storage}->{raid}->{'3ware 9000 Storage Controller'},
   qr/unable to check/,
   'Dummy 3ware RAID info'
);

ok($server->{storage}->{vgs} ne 'No LVM2', 'Gets dummy LVM (vgs) info');

exit;
