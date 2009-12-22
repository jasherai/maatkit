#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 9;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

require '../../common/MaatkitTest.pm';

MaatkitTest->import(qw(no_diff));

my $run_with = '../mk-query-digest --report-format=query_report --limit 10 ../../common/t/samples/';
my $run_notop = '../mk-query-digest --report-format=query_report ../../common/t/samples/';

# #############################################################################
# Issue 154: Add --since and --until options to mk-query-digest
# #############################################################################

# --since
ok(
   no_diff($run_with.'slow033.txt --since 2009-07-28', 'samples/slow033-since-yyyy-mm-dd.txt'),
   '--since 2009-07-28'
);

ok(
   no_diff($run_with.'slow033.txt --since 090727', 'samples/slow033-since-yymmdd.txt'),
   '--since 090727'
);

# This test will fail come July 2014.
ok(
   no_diff($run_with.'slow033.txt --since 1825d', 'samples/slow033-since-Nd.txt'),
   '--since 1825d (5 years ago)'
);

# --until
ok(
   no_diff($run_with.'slow033.txt --until 2009-07-27', 'samples/slow033-until-date.txt'),
   '--until 2009-07-27'
);

ok(
   no_diff($run_with.'slow033.txt --until 090727', 'samples/slow033-until-date.txt'),
   '--until 090727'
);

# The result file is correct: it's the one that has all quries from slow033.txt.
ok(
   no_diff($run_with.'slow033.txt --until 1d', 'samples/slow033-since-Nd.txt'),
   '--until 1d'
);

# And one very precise --since --until.
ok(
   no_diff($run_with.'slow033.txt --since "2009-07-26 11:19:28" --until "090727 11:30:00"', 'samples/slow033-precise-since-until.txt'),
   '--since "2009-07-26 11:19:28" --until "090727 11:30:00"'
);

SKIP: {
   skip 'Cannot connect to sandbox master', 2 unless $dbh;

   # The result file is correct: it's the one that has all quries from
   # slow033.txt.
   ok(
      no_diff($run_with.'slow033.txt --aux-dsn h=127.1,P=12345,u=msandbox,p=msandbox --since "\'2009-07-08\' - INTERVAL 7 DAY"', 'samples/slow033-since-Nd.txt'),
      '--since "\'2009-07-08\' - INTERVAL 7 DAY"',
   );

   ok(
      no_diff($run_with.'slow033.txt --aux-dsn h=127.1,P=12345,u=msandbox,p=msandbox --until "\'2009-07-28\' - INTERVAL 1 DAY"', 'samples/slow033-until-date.txt'),
      '--until "\'2009-07-28\' - INTERVAL 1 DAY"',
   );

   $sb->wipe_clean($dbh);
};

# #############################################################################
# Done.
# #############################################################################
exit;
