#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 23;

use SchemaFindText;
use MaatkitTest;

open my $fh, "<", "$trunk/common/t/samples/schemas/schema-dump.sql"
   or die $OS_ERROR;

my $sft = new SchemaFindText(fh => $fh);

is($sft->next_db(), 'mysql', 'got mysql DB');
is($sft->next_tbl(), 'columns_priv', 'got columns_priv table');
like($sft->last_tbl_ddl(), qr/CREATE TABLE `columns_priv`/, 'got columns_priv ddl');

# At the "end" of the db, we should get undef for next_tbl()
foreach my $tbl (
   qw( db func help_category help_keyword help_relation help_topic
      host proc procs_priv tables_priv time_zone time_zone_leap_second
      time_zone_name time_zone_transition time_zone_transition_type user)
) {
   is($sft->next_tbl(), $tbl, $tbl);
}
is($sft->next_tbl(), undef, 'end of mysql schema');

is($sft->next_db(), 'sakila', 'got sakila DB');
$sft->next_tbl();
is($sft->next_tbl(), 'address', 'got address table');
like($sft->last_tbl_ddl(), qr/CREATE TABLE `address`/, 'got address ddl');


# #############################################################################
# Done.
# #############################################################################
exit;
