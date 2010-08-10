#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use VersionParser;
use MaatkitTest;

my $vp = new VersionParser;

is(
   $vp->parse('5.0.38-Ubuntu_0ubuntu1.1-log'),
   '005000038',
   'Parser works on ordinary version',
);

# Open a connection to MySQL, or skip the rest of the tests.
use DSNParser;
use Sandbox;
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');
SKIP: {
   skip 'Cannot connect to MySQL', 2 unless $dbh;
   ok($vp->version_ge($dbh, '3.23.00'), 'Version is > 3.23');

   unlike(
      $vp->innodb_version($dbh),
      qr/DISABLED/,
      "InnoDB version"
   );
}

# #############################################################################
# Done.
# #############################################################################
exit;
