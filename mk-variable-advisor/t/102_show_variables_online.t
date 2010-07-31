#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
shift @INC;  # These shifts are required for tools that use base and derived
shift @INC;  # classes.  See mk-query-digest/t/101_slowlog_analyses.t
shift @INC;
require "$trunk/mk-variable-advisor/mk-variable-advisor";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => "Cannot connect to sandbox master";
}
else {
   plan tests => 1;
}

# #############################################################################
# SHOW VARIABLES from the sandbox server.
# #############################################################################
my @args   = qw(F=/tmp/12345/my.sandbox.cnf);
my $output = "";

$output = output(
   sub { mk_variable_advisor::main(@args) },
);
like(
   $output,
   qr/port The server is listening on a non-default port/,
   "Get variables from host"
);

# #############################################################################
# Done.
# #############################################################################
exit;
