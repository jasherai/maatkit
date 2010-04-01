#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 22;

use Transformers;
use QueryReportFormatter;
use EventAggregator;
use QueryRewriter;
use MaatkitTest;

my ( $qrf, $result, $events, $expected, $qr, $ea );

$qr  = new QueryRewriter();
$qrf = new QueryReportFormatter();
$ea  = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
   attributes => {
      Query_time    => [qw(Query_time)],
      Lock_time     => [qw(Lock_time)],
      user          => [qw(user)],
      ts            => [qw(ts)],
      Rows_sent     => [qw(Rows_sent)],
      Rows_examined => [qw(Rows_examined)],
      db            => [qw(db)],
   },
);

isa_ok( $qrf, 'QueryReportFormatter' );

$result = $qrf->header();
like($result,
   qr/^# \S+ user time, \S+ system time, \S+ rss, \S+ vsz/s,
   'Header looks ok');

$events = [
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      arg           => "SELECT id FROM users WHERE name='foo'",
      Query_time    => '8.000652',
      Lock_time     => '0.000109',
      Rows_sent     => 1,
      Rows_examined => 1,
      pos_in_log    => 1,
      db            => 'test3',
   },
   {  ts   => '071015 21:43:52',
      cmd  => 'Query',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg =>
         "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
      Query_time    => '1.001943',
      Lock_time     => '0.000145',
      Rows_sent     => 0,
      Rows_examined => 0,
      pos_in_log    => 2,
      db            => 'test1',
   },
   {  ts            => '071015 21:43:53',
      cmd           => 'Query',
      user          => 'bob',
      host          => 'localhost',
      ip            => '',
      arg           => "SELECT id FROM users WHERE name='bar'",
      Query_time    => '1.000682',
      Lock_time     => '0.000201',
      Rows_sent     => 1,
      Rows_examined => 2,
      pos_in_log    => 5,
      db            => 'test1',
   }
];

# Here's the breakdown of values for those three events:
# 
# ATTRIBUTE     VALUE     BUCKET  VALUE        RANGE
# Query_time => 8.000652  326     7.700558026  range [7.700558026, 8.085585927)
# Query_time => 1.001943  284     0.992136979  range [0.992136979, 1.041743827)
# Query_time => 1.000682  284     0.992136979  range [0.992136979, 1.041743827)
#               --------          -----------
#               10.003277         9.684831984
#
# Lock_time  => 0.000109  97      0.000108186  range [0.000108186, 0.000113596)
# Lock_time  => 0.000145  103     0.000144980  range [0.000144980, 0.000152229)
# Lock_time  => 0.000201  109     0.000194287  range [0.000194287, 0.000204002)
#               --------          -----------
#               0.000455          0.000447453
#
# Rows_sent  => 1         284     0.992136979  range [0.992136979, 1.041743827)
# Rows_sent  => 0         0       0
# Rows_sent  => 1         284     0.992136979  range [0.992136979, 1.041743827)
#               --------          -----------
#               2                 1.984273958
#
# Rows_exam  => 1         284     0.992136979  range [0.992136979, 1.041743827)
# Rows_exam  => 0         0       0 
# Rows_exam  => 2         298     1.964363355, range [1.964363355, 2.062581523) 
#               --------          -----------
#               3                 2.956500334

# I hand-checked these values with my TI-83 calculator.
# They are, without a doubt, correct.
$expected = <<EOF;
# Overall: 3 total, 2 unique, 3 QPS, 10.00x concurrency __________________
#                    total     min     max     avg     95%  stddev  median
# Exec time            10s      1s      8s      3s      8s      3s   992ms
# Lock time          455us   109us   201us   151us   194us    35us   144us
# Rows sent              2       0       1    0.67    0.99    0.47    0.99
# Rows exam              3       0       2       1    1.96    0.80    0.99
# Time range        2007-10-15 21:43:52 to 2007-10-15 21:43:53
EOF

foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}

$result = $qrf->global_report(
   $ea,
   select  => [ qw(Query_time Lock_time Rows_sent Rows_examined ts) ],
   worst   => 'Query_time',
);

is($result, $expected, 'Global report');

$expected = <<EOF;
# Query 1: 2 QPS, 9.00x concurrency, ID 0x82860EDA9A88FCC5 at byte 1 _____
# This item is included in the report because it matches --limit.
#              pct   total     min     max     avg     95%  stddev  median
# Count         66       2
# Exec time     89      9s      1s      8s      5s      8s      5s      5s
# Lock time     68   310us   109us   201us   155us   201us    65us   155us
# Rows sent    100       2       1       1       1       1       0       1
# Rows exam    100       3       1       2    1.50       2    0.71    1.50
# Users                  2 bob (1), root (1)
# Databases              2 test1 (1), test3 (1)
# Time range 2007-10-15 21:43:52 to 2007-10-15 21:43:53
EOF

$result = $qrf->event_report(
   $ea,
   # "users" is here to try to cause a failure
   select => [ qw(Query_time Lock_time Rows_sent Rows_examined ts db user users) ],
   where   => 'select id from users where name=?',
   rank    => 1,
   worst   => 'Query_time',
   reason  => 'top',
);

is($result, $expected, 'Event report');

$expected = <<EOF;
# Query_time distribution
#   1us
#  10us
# 100us
#   1ms
#  10ms
# 100ms
#    1s  ################################################################
#  10s+
EOF

$result = $qrf->chart_distro(
   $ea,
   attribute => 'Query_time',
   where     => 'select id from users where name=?',
);

is($result, $expected, 'Query_time distro');

$qrf = new QueryReportFormatter(label_width => 15);
$expected = <<EOF;
# Query 1: 2 QPS, 9.00x concurrency, ID 0x82860EDA9A88FCC5 at byte 1 ___________
# This item is included in the report because it matches --limit.
#                    pct   total     min     max     avg     95%  stddev  median
# Count               66       2
# Exec time           89      9s      1s      8s      5s      8s      5s      5s
# Lock time           68   310us   109us   201us   155us   201us    65us   155us
# Rows sent          100       2       1       1       1       1       0       1
# Rows examined      100       3       1       2    1.50       2    0.71    1.50
# Users                        2 bob (1), root (1)
# Databases                    2 test1 (1), test3 (1)
# Time range      2007-10-15 21:43:52 to 2007-10-15 21:43:53
EOF

$result = $qrf->event_report(
   $ea,
   # "users" is here to try to cause a failure
   select => [ qw(Query_time Lock_time Rows_sent Rows_examined ts db user users) ],
   where   => 'select id from users where name=?',
   rank    => 1,
   worst   => 'Query_time',
   reason  => 'top',
);

is($result, $expected, 'Event report with wider label');

$qrf = new QueryReportFormatter;

# ########################################################################
# This one is all about an event that's all zeroes.
# ########################################################################
$ea  = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
   attributes => {
      Query_time    => [qw(Query_time)],
      Lock_time     => [qw(Lock_time)],
      user          => [qw(user)],
      ts            => [qw(ts)],
      Rows_sent     => [qw(Rows_sent)],
      Rows_examined => [qw(Rows_examined)],
      db            => [qw(db)],
   },
);

$events = [
   {  bytes              => 30,
      db                 => 'mysql',
      ip                 => '127.0.0.1',
      arg                => 'administrator command: Connect',
      fingerprint        => 'administrator command: Connect',
      Rows_affected      => 0,
      user               => 'msandbox',
      Warning_count      => 0,
      cmd                => 'Admin',
      No_good_index_used => 'No',
      ts                 => '090412 11:00:13.118191',
      No_index_used      => 'No',
      port               => '57890',
      host               => '127.0.0.1',
      Thread_id          => 8,
      pos_in_log         => '0',
      Query_time         => '0',
      Error_no           => 0
   },
];

foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}

$expected = <<EOF;
# Overall: 1 total, 1 unique, 0 QPS, 0x concurrency ______________________
#                    total     min     max     avg     95%  stddev  median
# Exec time              0       0       0       0       0       0       0
# Time range        2009-04-12 11:00:13.118191 to 2009-04-12 11:00:13.118191
EOF

$result = $qrf->global_report(
   $ea,
   select  => [ qw(Query_time Lock_time Rows_sent Rows_examined ts) ],
   worst   => 'Query_time',
);

is($result, $expected, 'Global report with all zeroes');

$expected = <<EOF;
# Query 1: 0 QPS, 0x concurrency, ID 0x5D51E5F01B88B79E at byte 0 ________
# This item is included in the report because it matches --limit.
#              pct   total     min     max     avg     95%  stddev  median
# Count        100       1
# Exec time      0       0       0       0       0       0       0       0
# Users                  1 msandbox
# Databases              1   mysql
# Time range 2009-04-12 11:00:13.118191 to 2009-04-12 11:00:13.118191
EOF

$result = $qrf->event_report(
   $ea,
   select => [ qw(Query_time Lock_time Rows_sent Rows_examined ts db user users) ],
   where   => 'administrator command: Connect',
   rank    => 1,
   worst   => 'Query_time',
   reason  => 'top',
);

is($result, $expected, 'Event report with all zeroes');

$expected = <<EOF;
# Query_time distribution
#   1us
#  10us
# 100us
#   1ms
#  10ms
# 100ms
#    1s
#  10s+
EOF

# This used to cause illegal division by zero in some cases.
$result = $qrf->chart_distro(
   $ea,
   attribute => 'Query_time',
   where     => 'administrator command: Connect',
);

is($result, $expected, 'Chart distro with all zeroes');

# #############################################################################
# Test bool (Yes/No) pretty printing.
# #############################################################################
$events = [
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      arg           => "SELECT id FROM users WHERE name='foo'",
      Query_time    => '8.000652',
      Lock_time     => '0.002300',
      QC_Hit        => 'No',
      Filesort      => 'Yes',
      InnoDB_IO_r_bytes     => 2,
      InnoDB_pages_distinct => 20,
   },
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      arg           => "SELECT id FROM users WHERE name='foo'",
      Query_time    => '1.001943',
      Lock_time     => '0.002320',
      QC_Hit        => 'Yes',
      Filesort      => 'Yes',
      InnoDB_IO_r_bytes     => 2,
      InnoDB_pages_distinct => 18,
   },
   {  ts            => '071015 21:43:53',
      cmd           => 'Query',
      arg           => "SELECT id FROM users WHERE name='bar'",
      Query_time    => '1.000682',
      Lock_time     => '0.003301',
      QC_Hit        => 'Yes',
      Filesort      => 'Yes',
      InnoDB_IO_r_bytes     => 3,
      InnoDB_pages_distinct => 11,
   }
];
$expected = <<EOF;
# Overall: 3 total, 1 unique, 3 QPS, 10.00x concurrency __________________
#                    total     min     max     avg     95%  stddev  median
# Exec time            10s      1s      8s      3s      8s      3s   992ms
# Lock time            8ms     2ms     3ms     3ms     3ms   500us     2ms
# Time range        2007-10-15 21:43:52 to 2007-10-15 21:43:53
# IDB IO rb              7       2       3    2.33    2.90    0.44    1.96
# IDB pages             49      11      20   16.33   19.46    3.71   17.65
# 100% (3)    Filesort
#  66% (2)    QC_Hit
EOF

$ea  = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
   ignore_attributes => [qw(arg cmd)],
);
foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}

$result = $qrf->global_report(
   $ea,
   select  => [ $ea->get_attributes() ],
   worst   => 'Query_time',
);

is($result, $expected, 'Bool (Yes/No) pretty printer');

# #############################################################################
# Test attrib sorting.
# #############################################################################

# This test uses the $ea from the Bool pretty printer test above.
is_deeply(
   [ QueryReportFormatter::sort_attribs($ea, $ea->get_attributes()) ],
   [qw(
      Query_time
      Lock_time
      ts
      InnoDB_IO_r_bytes
      InnoDB_pages_distinct
      Filesort
      QC_Hit
      )
   ],
   'sort_attribs()'
);

# ############################################################################
# Test that --[no]zero-bool removes 0% vals.
# ############################################################################
$events = [
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      arg           => "SELECT id FROM users WHERE name='foo'",
      Query_time    => '8.000652',
      Lock_time     => '0.002300',
      QC_Hit        => 'No',
      Filesort      => 'No',
   },
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      arg           => "SELECT id FROM users WHERE name='foo'",
      Query_time    => '1.001943',
      Lock_time     => '0.002320',
      QC_Hit        => 'Yes',
      Filesort      => 'No',
   },
   {  ts            => '071015 21:43:53',
      cmd           => 'Query',
      arg           => "SELECT id FROM users WHERE name='bar'",
      Query_time    => '1.000682',
      Lock_time     => '0.003301',
      QC_Hit        => 'Yes',
      Filesort      => 'No',
   }
];
$expected = <<EOF;
# Overall: 3 total, 1 unique, 3 QPS, 10.00x concurrency __________________
#                    total     min     max     avg     95%  stddev  median
# Exec time            10s      1s      8s      3s      8s      3s   992ms
# Lock time            8ms     2ms     3ms     3ms     3ms   500us     2ms
# Time range        2007-10-15 21:43:52 to 2007-10-15 21:43:53
#  66% (2)    QC_Hit
EOF

$ea  = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
   ignore_attributes => [qw(arg cmd)],
);
foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}
$result = $qrf->global_report(
   $ea,
   select  => [ $ea->get_attributes() ],
   worst   => 'Query_time',
   no_zero_bool => 1,
);

is($result, $expected, 'No zero bool vals');

# #############################################################################
# Issue 458: mk-query-digest Use of uninitialized value in division (/) at
# line 3805
# #############################################################################
use SlowLogParser;
my $p = new SlowLogParser();

sub report_from_file {
   my $ea2 = new EventAggregator(
      groupby => 'fingerprint',
      worst   => 'Query_time',
   );
   my ( $file ) = @_;
   $file = "$trunk/$file";
   my @e;
   my @callbacks;
   push @callbacks, sub {
      my ( $event ) = @_;
      my $group_by_val = $event->{arg};
      return 0 unless defined $group_by_val;
      $event->{fingerprint} = $qr->fingerprint($group_by_val);
      return $event;
   };
   push @callbacks, sub {
      $ea2->aggregate(@_);
   };
   eval {
      open my $fh, "<", $file or BAIL_OUT($OS_ERROR);
      1 while $p->parse_event($fh, undef, @callbacks);
      close $fh;
   };
   my %top_spec = (
      attrib  => 'Query_time',
      orderby => 'sum',
      total   => 100,
      count   => 100,
   );
   my @worst  = $ea2->top_events(%top_spec);
   my $report = '';
   foreach my $rank ( 1 .. @worst ) {
      $report .= $qrf->event_report(
         $ea2,
         select => [ $ea2->get_attributes() ],
         where  => $worst[$rank - 1]->[0],
         rank   => $rank,
         worst  => 'Query_time',
         reason => '',
      );
   }
   return $report;
}

# The real bug is in QueryReportFormatter, and there's nothing particularly
# interesting about this sample, but we just want to make sure that the
# timestamp prop shows up only in the one event.  The bug is that it appears
eval {
   report_from_file('common/t/samples/slow029.txt');
};
is(
   $EVAL_ERROR,
   '',
   'event_report() does not die on empty attributes (issue 458)'
);

# #############################################################################
# Test that format_string_list() truncates long strings.
# #############################################################################

$events = [
   {  ts   => '071015 21:43:52',
      cmd  => 'Query',
      arg  => "SELECT id FROM users WHERE name='foo'",
      Query_time => 1,
      foo  => "Hi.  I'm a very long string.  I'm way over the 78 column width that we try to keep lines limited to so text wrapping doesn't make things look all funky and stuff.",
   },
];

$expected = <<EOF;
# Query 1: 0 QPS, 0x concurrency, ID 0x82860EDA9A88FCC5 at byte 0 ________
# This item is included in the report because it matches --limit.
#              pct   total     min     max     avg     95%  stddev  median
# Count        100       1
# Exec time    100      1s      1s      1s      1s      1s       0      1s
# foo                    1 Hi.  I'm a very long string.  I'm way over t...
EOF

$ea  = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
   ignore_attributes => [qw(arg cmd)],
);
foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}

$result = $qrf->event_report(
   $ea,
   select => [ qw(Query_time foo) ],
   where   => 'select id from users where name=?',
   rank    => 1,
   worst   => 'Query_time',
   reason  => 'top',
);

is(
   $result,
   $expected,
   'Truncate one long string'
);

$ea->reset_aggregated_data();
push @$events,
   {  ts   => '071015 21:43:55',
      cmd  => 'Query',
      arg  => "SELECT id FROM users WHERE name='foo'",
      Query_time => 2,
      foo  => "Me too! I'm a very long string yay!  I'm also over the 78 column width that we try to keep lines limited to."
   };

$expected = <<EOF;
# Query 1: 0.67 QPS, 1x concurrency, ID 0x82860EDA9A88FCC5 at byte 0 _____
# This item is included in the report because it matches --limit.
#              pct   total     min     max     avg     95%  stddev  median
# Count        100       2
# Exec time    100      3s      1s      2s      2s      2s   707ms      2s
# foo                    2 Hi.  I'm a... (1), Me too! I'... (1)
EOF

foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}

$result = $qrf->event_report(
   $ea,
   select => [ qw(Query_time foo) ],
   where   => 'select id from users where name=?',
   rank    => 1,
   worst   => 'Query_time',
   reason  => 'top',
);

is(
   $result,
   $expected, 'Truncate multiple long strings'
);

$ea->reset_aggregated_data();
push @$events,
   {  ts   => '071015 21:43:55',
      cmd  => 'Query',
      arg  => "SELECT id FROM users WHERE name='foo'",
      Query_time => 3,
      foo  => 'Number 3 long string, but I\'ll exceed the line length so I\'ll only show up as "more" :-('
   };

$expected = <<EOF;
# Query 1: 1 QPS, 2x concurrency, ID 0x82860EDA9A88FCC5 at byte 0 ________
# This item is included in the report because it matches --limit.
#              pct   total     min     max     avg     95%  stddev  median
# Count        100       3
# Exec time    100      6s      1s      3s      2s      3s   780ms      2s
# foo                    3 Hi.  I'm a... (1), Me too! I'... (1)... 1 more
EOF

foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}

$result = $qrf->event_report(
   $ea,
   select => [ qw(Query_time foo) ],
   where   => 'select id from users where name=?',
   rank    => 1,
   worst   => 'Query_time',
   reason  => 'top',
);

is(
   $result,
   $expected, 'Truncate multiple strings longer than whole line'
);

# #############################################################################
# Issue 478: mk-query-digest doesn't count errors and hosts right
# #############################################################################

# We decided that string attribs shouldn't be listed in the global header.
$events = [
   {
      cmd           => 'Query',
      arg           => "SELECT id FROM users WHERE name='foo'",
      Query_time    => '8.000652',
      user          => 'bob',
   },
   {
      cmd           => 'Query',
      arg           => "SELECT id FROM users WHERE name='foo'",
      Query_time    => '1.001943',
      user          => 'bob',
   },
   {
      cmd           => 'Query',
      arg           => "SELECT id FROM users WHERE name='bar'",
      Query_time    => '1.000682',
      user          => 'bob',
   }
];
$expected = <<EOF;
# Overall: 3 total, 1 unique, 0 QPS, 0x concurrency ______________________
#                    total     min     max     avg     95%  stddev  median
# Exec time            10s      1s      8s      3s      8s      3s   992ms
EOF

$ea  = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
   ignore_attributes => [qw(arg cmd)],
);
foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}
$result = $qrf->global_report(
   $ea,
   select  => [ $ea->get_attributes() ],
   worst   => 'Query_time',
);

is($result, $expected, 'No string attribs in global report (issue 478)');

# #############################################################################
# Issue 744: Option to show all Hosts
# #############################################################################

# Don't shorten IP addresses.
$events = [
   {
      cmd        => 'Query',
      arg        => "foo",
      Query_time => '8.000652',
      host       => '123.123.123.456',
   },
   {
      cmd        => 'Query',
      arg        => "foo",
      Query_time => '8.000652',
      host       => '123.123.123.789',
   },
];
$expected = <<EOF;
# Item 1: 0 QPS, 0x concurrency, ID 0xEDEF654FCCC4A4D8 at byte 0 _________
#              pct   total     min     max     avg     95%  stddev  median
# Count        100       2
# Exec time    100     16s      8s      8s      8s      8s       0      8s
# Hosts                  2 123.123.123.456 (1), 123.123.123.789 (1)
EOF

$ea  = new EventAggregator(
   groupby => 'arg',
   worst   => 'Query_time',
   ignore_attributes => [qw(arg cmd)],
);
foreach my $event (@$events) {
   $ea->aggregate($event);
}
$result = $qrf->event_report(
   $ea,
   select => [ qw(Query_time host) ],
   where   => 'foo',
   rank    => 1,
   worst   => 'Query_time',
);

is($result, $expected, "IPs not shortened");

# Add another event so we get "... N more" to make sure that IPs
# are still not shortened.
push @$events, 
   {
      cmd        => 'Query',
      arg        => "foo",
      Query_time => '8.000652',
      host       => '123.123.123.999',
   };
$ea->aggregate($events->[-1]);
$result = $qrf->event_report(
   $ea,
   select => [ qw(Query_time host) ],
   where   => 'foo',
   rank    => 1,
   worst   => 'Query_time',
);

$expected = <<EOF;
# Item 1: 0 QPS, 0x concurrency, ID 0xEDEF654FCCC4A4D8 at byte 0 _________
#              pct   total     min     max     avg     95%  stddev  median
# Count        100       3
# Exec time    100     24s      8s      8s      8s      8s       0      8s
# Hosts                  3 123.123.123.456 (1), 123.123.123.789 (1)... 1 more
EOF
is($result, $expected, "IPs not shortened with more");

# Test show_all.
$result = $qrf->event_report(
   $ea,
   select   => [ qw(Query_time host) ],
   where    => 'foo',
   rank     => 1,
   worst    => 'Query_time',
   show_all => { host=>1 },
);

$expected = <<EOF;
# Item 1: 0 QPS, 0x concurrency, ID 0xEDEF654FCCC4A4D8 at byte 0 _________
#              pct   total     min     max     avg     95%  stddev  median
# Count        100       3
# Exec time    100     24s      8s      8s      8s      8s       0      8s
# Hosts                  3 123.123.123.456 (1), 123.123.123.789 (1), 123.123.123.999 (1)
EOF
is($result, $expected, "Show all hosts");

# #############################################################################
# Issue 948: mk-query-digest treats InnoDB_rec_lock_wait value as number
# instead of time
# #############################################################################

$events = [
   {
      cmd        => 'Query',
      arg        => "foo",
      Query_time => '8.000652',
      InnoDB_rec_lock_wait => 0.001,
      InnoDB_IO_r_wait     => 0.002,
      InnoDB_queue_wait    => 0.003,
   },
];
$expected = <<EOF;
# Item 1: 0 QPS, 0x concurrency, ID 0xEDEF654FCCC4A4D8 at byte 0 _________
#              pct   total     min     max     avg     95%  stddev  median
# Count        100       1
# Exec time    100      8s      8s      8s      8s      8s       0      8s
# IDB IO rw    100     2ms     2ms     2ms     2ms     2ms       0     2ms
# IDB queue    100     3ms     3ms     3ms     3ms     3ms       0     3ms
# IDB rec l    100     1ms     1ms     1ms     1ms     1ms       0     1ms
EOF

$ea  = new EventAggregator(
   groupby => 'arg',
   worst   => 'Query_time',
   ignore_attributes => [qw(arg cmd)],
);
foreach my $event (@$events) {
   $ea->aggregate($event);
}
$result = $qrf->event_report(
   $ea,
   select => [ qw(Query_time InnoDB_rec_lock_wait InnoDB_IO_r_wait InnoDB_queue_wait) ],
   where   => 'foo',
   rank    => 1,
   worst   => 'Query_time',
);

is($result, $expected, "_wait attribs treated as times (issue 948)");

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $qrf->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
