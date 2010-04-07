#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use MaatkitTest;
require "$trunk/mk-config-diff/mk-config-diff";

my $sample        = "$trunk/mk-config-diff/t/samples/";
my $common_sample = "$trunk/common/t/samples/configs/";

is(
   mk_config_diff::determine_config_type("$sample/showvars001.txt"),
   'show_variables',
   'SHOW VARIABLES vertical'
);

is(
   mk_config_diff::determine_config_type("$sample/showvars002.txt"),
   'show_variables',
   'SHOW VARIABLES horizontal'
);

is(
   mk_config_diff::determine_config_type("$common_sample/myprintdef001.txt"),
   'my_print_defaults',
   'my_print_defaults'
);

is(
   mk_config_diff::determine_config_type("$common_sample/mysqldhelp001.txt"),
   'mysqld',
   'mysqld'
);

# #############################################################################
# Done.
# #############################################################################
exit;
