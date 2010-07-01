#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use MaatkitTest;
require "$trunk/mk-config-diff/mk-config-diff";

my $parser = new TextResultSetParser();
my %args   = (TextResultSetParser => $parser);

my $sample        = "$trunk/mk-config-diff/t/samples/";
my $common_sample = "$trunk/common/t/samples/configs/";


# #############################################################################
# Parse and load just online config from file.
# #############################################################################

my $config = new MySQLConfig();
mk_config_diff::parse_config_from_file(
   file        => "$sample/showvars001.txt",
   MySQLConfig => $config,
   %args
);

isa_ok(
   $config,
   "MySQLConfig",
   "Returns MySQLConfig obj"
);

is(
   $config->get('back_log'),
   50,
   'Set online config'
);

is(
   $config->get('back_log', offline=>1),
   undef,
   'Did not set offline config'
);

# #############################################################################
# Parse and load just offline config from file.
# #############################################################################

$config = new MySQLConfig();
mk_config_diff::parse_config_from_file(
   file        => "$common_sample/mysqldhelp001.txt",
   MySQLConfig => $config,
   %args
);

is(
   $config->get('port', offline=>1),
   12345,
   'Set offline config'
);

is(
   $config->get('port'),
   undef,
   'Did not set online config'
);

# #############################################################################
# Parse and load online config with already loaded offline config.
# #############################################################################

mk_config_diff::parse_config_from_file(
   file        => "$sample/showvars001.txt",
   MySQLConfig => $config,
   %args
);

is(
   $config->get('port'),
   12345,
   'Set online config after setting offline config'
);

# #############################################################################
# Done.
# #############################################################################
exit;
