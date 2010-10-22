#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 32;

use Transformers;
use QueryReportFormatter;
use EventAggregator;
use QueryRewriter;
use QueryParser;
use Quoter;
use ReportFormatter;
use OptionParser;
use DSNParser;
use ReportFormatter;
use Sandbox;
use MaatkitTest;

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

my ($result, $events, $expected);

my $q   = new Quoter();
my $qp  = new QueryParser();
my $qr  = new QueryRewriter(QueryParser=>$qp);
my $o   = new OptionParser(description=>'qrf');

$o->get_specs("$trunk/mk-query-digest/mk-query-digest");

my $qrf = new QueryReportFormatter(
   OptionParser  => $o,
   QueryRewriter => $qr,
   QueryParser   => $qp,
   Quoter        => $q, 
);

my $ea  = new EventAggregator(
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

isa_ok($qrf, 'QueryReportFormatter');

$result = $qrf->rusage();
like(
   $result,
   qr/^# \S+ user time, \S+ system time, \S+ rss, \S+ vsz/s,
   'rusage report',
);

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
# Attribute          total     min     max     avg     95%  stddev  median
# =========        ======= ======= ======= ======= ======= ======= =======
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
$ea->calculate_statistical_metrics(apdex_t=>1);
$result = $qrf->header(
   ea      => $ea,
   select  => [ qw(Query_time Lock_time Rows_sent Rows_examined ts) ],
   orderby => 'Query_time',
);

is($result, $expected, 'Global (header) report');

$expected = <<EOF;
# Query 1: 2 QPS, 9.00x concurrency, ID 0x82860EDA9A88FCC5 at byte 1 _____
# Scores: Apdex = 0.50 [1.0]*, V/M = 5.4
# This item is included in the report because it matches --limit.
# Attribute    pct   total     min     max     avg     95%  stddev  median
# ========= ====== ======= ======= ======= ======= ======= ======= =======
# Count         66       2
# Exec time     89      9s      1s      8s      5s      8s      5s      5s
# Lock time     68   310us   109us   201us   155us   201us    65us   155us
# Rows sent    100       2       1       1       1       1       0       1
# Rows exam    100       3       1       2    1.50       2    0.71    1.50
# Users                  2 bob (1/50%), root (1/50%)
# Databases              2 test1 (1/50%), test3 (1/50%)
# Time range 2007-10-15 21:43:52 to 2007-10-15 21:43:53
EOF

$result = $qrf->event_report(
   ea => $ea,
   # "users" is here to try to cause a failure
   select => [ qw(Query_time Lock_time Rows_sent Rows_examined ts db user users) ],
   item    => 'select id from users where name=?',
   rank    => 1,
   orderby => 'Query_time',
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
   ea     => $ea,
   attrib => 'Query_time',
   item   => 'select id from users where name=?',
);

is($result, $expected, 'Query_time distro');

SKIP: {
   skip 'Wider labels not used, not tested', 1;
$qrf = new QueryReportFormatter(label_width => 15);
$expected = <<EOF;
# Query 1: 2 QPS, 9.00x concurrency, ID 0x82860EDA9A88FCC5 at byte 1 ___________
# This item is included in the report because it matches --limit.
# Attribute          pct   total     min     max     avg     95%  stddev  median
# =============== ====== ======= ======= ======= ======= ======= ======= =======
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
};

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
$ea->calculate_statistical_metrics(apdex_t=>1);
$expected = <<EOF;
# Overall: 1 total, 1 unique, 0 QPS, 0x concurrency ______________________
# Attribute          total     min     max     avg     95%  stddev  median
# =========        ======= ======= ======= ======= ======= ======= =======
# Exec time              0       0       0       0       0       0       0
# Time range        2009-04-12 11:00:13.118191 to 2009-04-12 11:00:13.118191
EOF

$result = $qrf->header(
   ea      => $ea,
   select  => [ qw(Query_time Lock_time Rows_sent Rows_examined ts) ],
   orderby => 'Query_time',
);

is($result, $expected, 'Global report with all zeroes');

$expected = <<EOF;
# Query 1: 0 QPS, 0x concurrency, ID 0x5D51E5F01B88B79E at byte 0 ________
# Scores: Apdex = 1.00 [1.0]*, V/M = 0.0
# This item is included in the report because it matches --limit.
# Attribute    pct   total     min     max     avg     95%  stddev  median
# ========= ====== ======= ======= ======= ======= ======= ======= =======
# Count        100       1
# Exec time      0       0       0       0       0       0       0       0
# Users                  1 msandbox
# Databases              1   mysql
# Time range 2009-04-12 11:00:13.118191 to 2009-04-12 11:00:13.118191
EOF

$result = $qrf->event_report(
   ea     => $ea,
   select => [ qw(Query_time Lock_time Rows_sent Rows_examined ts db user users) ],
   item    => 'administrator command: Connect',
   rank    => 1,
   orderby => 'Query_time',
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
   ea     => $ea,
   attrib => 'Query_time',
   item   => 'administrator command: Connect',
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
# Attribute          total     min     max     avg     95%  stddev  median
# =========        ======= ======= ======= ======= ======= ======= =======
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
$ea->calculate_statistical_metrics();
$result = $qrf->header(
   ea      => $ea,
   # select  => [ $ea->get_attributes() ],
   orderby => 'Query_time',
);

is($result, $expected, 'Bool (Yes/No) pretty printer');

# #############################################################################
# Test attrib sorting.
# #############################################################################

# This test uses the $ea from the Bool pretty printer test above.
is_deeply(
   [ $qrf->sorted_attribs($ea->get_attributes(), $ea) ],
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
   'sorted_attribs()'
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
# Attribute          total     min     max     avg     95%  stddev  median
# =========        ======= ======= ======= ======= ======= ======= =======
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
$ea->calculate_statistical_metrics();
$result = $qrf->header(
   ea        => $ea,
   # select    => [ $ea->get_attributes() ],
   orderby   => 'Query_time',
   zero_bool => 0,
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
      open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
      my %args = (
         next_event => sub { return <$fh>;      },
         tell       => sub { return tell($fh);  },
      );
      while ( my $e = $p->parse_event(%args) ) {
         $_->($e) for @callbacks;
      }
      close $fh;
   };
   die $EVAL_ERROR if $EVAL_ERROR;
   $ea2->calculate_statistical_metrics();
   my %top_spec = (
      attrib  => 'Query_time',
      orderby => 'sum',
      total   => 100,
      count   => 100,
   );
   my ($worst, $other) = $ea2->top_events(%top_spec);
   my $top_n = scalar @$worst;
   my $report = '';
   foreach my $rank ( 1 .. $top_n ) {
      $report .= $qrf->event_report(
         ea      => $ea2,
         # select  => [ $ea2->get_attributes() ],
         item    => $worst->[$rank - 1]->[0],
         rank    => $rank,
         orderby => 'Query_time',
         reason  => '',
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
# Scores: Apdex = NS [0.0]*, V/M = 0.0
# This item is included in the report because it matches --limit.
# Attribute    pct   total     min     max     avg     95%  stddev  median
# ========= ====== ======= ======= ======= ======= ======= ======= =======
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
$ea->calculate_statistical_metrics();
$result = $qrf->event_report(
   ea      => $ea,
   select  => [ qw(Query_time foo) ],
   item    => 'select id from users where name=?',
   rank    => 1,
   orderby => 'Query_time',
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
# Scores: Apdex = NS [0.0]*, V/M = 0.3
# This item is included in the report because it matches --limit.
# Attribute    pct   total     min     max     avg     95%  stddev  median
# ========= ====== ======= ======= ======= ======= ======= ======= =======
# Count        100       2
# Exec time    100      3s      1s      2s      2s      2s   707ms      2s
# foo                    2 Hi.  I'm a... (1/50%), Me too! I'... (1/50%)
EOF

foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}
$ea->calculate_statistical_metrics();
$result = $qrf->event_report(
   ea      => $ea,
   select  => [ qw(Query_time foo) ],
   item    => 'select id from users where name=?',
   rank    => 1,
   orderby => 'Query_time',
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
# Scores: Apdex = NS [0.0]*, V/M = 0.3
# This item is included in the report because it matches --limit.
# Attribute    pct   total     min     max     avg     95%  stddev  median
# ========= ====== ======= ======= ======= ======= ======= ======= =======
# Count        100       3
# Exec time    100      6s      1s      3s      2s      3s   780ms      2s
# foo                    3 Hi.  I'm a... (1/33%), Me too! I'... (1/33%)... 1 more
EOF

foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}
$ea->calculate_statistical_metrics();
$result = $qrf->event_report(
   ea      => $ea,
   select  => [ qw(Query_time foo) ],
   item    => 'select id from users where name=?',
   rank    => 1,
   orderby => 'Query_time',
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
# Attribute          total     min     max     avg     95%  stddev  median
# =========        ======= ======= ======= ======= ======= ======= =======
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
$ea->calculate_statistical_metrics();
$result = $qrf->header(
   ea      => $ea,
   select  => $ea->get_attributes(),
   orderby => 'Query_time',
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
# Scores: Apdex = NS [0.0]*, V/M = 0.0
# Attribute    pct   total     min     max     avg     95%  stddev  median
# ========= ====== ======= ======= ======= ======= ======= ======= =======
# Count        100       2
# Exec time    100     16s      8s      8s      8s      8s       0      8s
# Hosts                  2 123.123.123.456 (1/50%)... 1 more
EOF

$ea  = new EventAggregator(
   groupby => 'arg',
   worst   => 'Query_time',
   ignore_attributes => [qw(arg cmd)],
);
foreach my $event (@$events) {
   $ea->aggregate($event);
}
$ea->calculate_statistical_metrics();
$result = $qrf->event_report(
   ea      => $ea,
   select  => [ qw(Query_time host) ],
   item    => 'foo',
   rank    => 1,
   orderby => 'Query_time',
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
$ea->calculate_statistical_metrics();
$result = $qrf->event_report(
   ea      => $ea,
   select  => [ qw(Query_time host) ],
   item    => 'foo',
   rank    => 1,
   orderby => 'Query_time',
);

$expected = <<EOF;
# Item 1: 0 QPS, 0x concurrency, ID 0xEDEF654FCCC4A4D8 at byte 0 _________
# Scores: Apdex = NS [0.0]*, V/M = 0.0
# Attribute    pct   total     min     max     avg     95%  stddev  median
# ========= ====== ======= ======= ======= ======= ======= ======= =======
# Count        100       3
# Exec time    100     24s      8s      8s      8s      8s       0      8s
# Hosts                  3 123.123.123.456 (1/33%)... 2 more
EOF
is($result, $expected, "IPs not shortened with more");

# Test show_all.
@ARGV = qw(--show-all host);
$o->get_opts();
$result = $qrf->event_report(
   ea       => $ea,
   select   => [ qw(Query_time host) ],
   item     => 'foo',
   rank     => 1,
   orderby  => 'Query_time',
);

$expected = <<EOF;
# Item 1: 0 QPS, 0x concurrency, ID 0xEDEF654FCCC4A4D8 at byte 0 _________
# Scores: Apdex = NS [0.0]*, V/M = 0.0
# Attribute    pct   total     min     max     avg     95%  stddev  median
# ========= ====== ======= ======= ======= ======= ======= ======= =======
# Count        100       3
# Exec time    100     24s      8s      8s      8s      8s       0      8s
# Hosts                  3 123.123.123.456 (1/33%), 123.123.123.789 (1/33%), 123.123.123.999 (1/33%)
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
# Scores: Apdex = NS [0.0]*, V/M = 0.0
# Attribute    pct   total     min     max     avg     95%  stddev  median
# ========= ====== ======= ======= ======= ======= ======= ======= =======
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
$ea->calculate_statistical_metrics();
$result = $qrf->event_report(
   ea      => $ea,
   select  => [ qw(Query_time InnoDB_rec_lock_wait InnoDB_IO_r_wait InnoDB_queue_wait) ],
   item    => 'foo',
   rank    => 1,
   orderby => 'Query_time',
);

is($result, $expected, "_wait attribs treated as times (issue 948)");


# #############################################################################
# print_reports()
# #############################################################################
$events = [
   {
      cmd         => 'Query',
      arg         => "select col from tbl where id=42",
      fingerprint => "select col from tbl where id=?",
      Query_time  => '1.000652',
      Lock_time   => '0.001292',
      ts          => '071015 21:43:52',
      pos_in_log  => 123,
      db          => 'foodb',
   },
];
$ea = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
);
foreach my $event ( @$events ) {
   $ea->aggregate($event);
}
$ea->calculate_statistical_metrics();

# Reset opts in case anything above left something set.
@ARGV = qw();
$o->get_opts();

# Normally, the report subs will make their own ReportFormatter but
# that package isn't visible to QueryReportFormatter right now so we
# make ReportFormatters and pass them in.  Since ReporFormatters can't
# be shared, we can only test one subreport at a time, else the
# prepared statements subreport will reuse/reprint stuff from the
# profile subreport.
my $report = new ReportFormatter(line_width=>74);

ok(
   no_diff(
      sub { $qrf->print_reports(
         reports => [qw(header query_report profile)],
         ea      => $ea,
         worst   => [['select col from tbl where id=?','top',1]],
         other   => [],
         orderby => 'Query_time',
         groupby => 'fingerprint',
         ReportFormatter => $report,
      ); },
      "common/t/samples/QueryReportFormatter/reports001.txt",
   ),
   "print_reports(header, query_report, profile)"
);

$report = new ReportFormatter(line_width=>74);

ok(
   no_diff(
      sub { $qrf->print_reports(
         reports => [qw(profile query_report header)],
         ea      => $ea,
         worst   => [['select col from tbl where id=?','top',1]],
         orderby => 'Query_time',
         groupby => 'fingerprint',
         ReportFormatter => $report,
      ); },
      "common/t/samples/QueryReportFormatter/reports003.txt",
   ),
   "print_reports(profile, query_report, header)",
);

$events = [
   {
      Query_time    => '0.000286',
      Warning_count => 0,
      arg           => 'PREPARE SELECT i FROM d.t WHERE i=?',
      fingerprint   => 'prepare select i from d.t where i=?',
      bytes         => 35,
      cmd           => 'Query',
      db            => undef,
      pos_in_log    => 0,
      ts            => '091208 09:23:49.637394',
      Statement_id  => 2,
   },
   {
      Query_time    => '0.030281',
      Warning_count => 0,
      arg           => 'EXECUTE SELECT i FROM d.t WHERE i="3"',
      fingerprint   => 'execute select i from d.t where i=?',
      bytes         => 37,
      cmd           => 'Query',
      db            => undef,
      pos_in_log    => 1106,
      ts            => '091208 09:23:49.637892',
      Statement_id  => 2,
   },
];
$ea = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
);
foreach my $event ( @$events ) {
   $ea->aggregate($event);
}
$ea->calculate_statistical_metrics();
$report = new ReportFormatter(
   line_width   => 74,
   extend_right => 1,
);
ok(
   no_diff(
      sub {
         $qrf->print_reports(
            reports => ['query_report','prepared'],
            ea      => $ea,
            worst   => [
               ['execute select i from d.t where i=?', 'top',1],
               ['prepare select i from d.t where i=?', 'top',2],
            ],
            orderby => 'Query_time',
            groupby => 'fingerprint',
            ReportFormatter => $report,
         );
      },
      "common/t/samples/QueryReportFormatter/reports002.txt",
   ),
   "print_reports(query_report, prepared)"
);


push @$events,
   {
      Query_time    => '1.030281',
      arg           => 'update foo set col=1 where 1',
      fingerprint   => 'update foo set col=? where ?',
      bytes         => 37,
      cmd           => 'Query',
      pos_in_log    => 100,
      ts            => '091208 09:23:49.637892',
   },
$ea = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
);
foreach my $event ( @$events ) {
   $ea->aggregate($event);
}
$ea->calculate_statistical_metrics();
$report = new ReportFormatter(
   line_width   => 74,
   extend_right => 1,
);
ok(
   no_diff(
      sub {
         $qrf->print_reports(
            reports => ['profile'],
            ea      => $ea,
            worst   => [
               ['update foo set col=? where ?', 'top',1]
            ],
            other => [
               ['execute select i from d.t where i=?','misc',2],
               ['prepare select i from d.t where i=?','misc',3],
            ],
            orderby => 'Query_time',
            groupby => 'fingerprint',
            ReportFormatter => $report,
         );
      },
      "common/t/samples/QueryReportFormatter/reports004.txt",
   ),
   "MISC items in profile"
);

# #############################################################################
# EXPLAIN report
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox master', 1 unless $dbh;
   $sb->load_file('master', "common/t/samples/QueryReportFormatter/table.sql");

   # Normally dbh would be passed to QueryReportFormatter::new().  If it's
   # set earlier then previous tests cause EXPLAIN failures due to their
   # fake dbs.
   $qrf->{dbh} = $dbh;

   my $explain =
"# *************************** 1. row ***************************
#            id: 1
#   select_type: SIMPLE
#         table: t
"
. (($sandbox_version || '') ge '5.1' ? "#    partitions: NULL\n" : '') .
"#          type: const
# possible_keys: PRIMARY
#           key: PRIMARY
#       key_len: 4
#           ref: const
#          rows: 1
#         Extra: 
";

   is(
      $qrf->explain_report("select * from qrf.t where i=2", 'qrf'),
      $explain,
      "explain_report()"
   );

   $sb->wipe_clean($dbh);
   $dbh->disconnect();
}


# #############################################################################
# files and date reports.
# #############################################################################
like(
   $qrf->date(),
   qr/# Current date: .+?\d+:\d+:\d+/,
   "date report"
);

is(
   $qrf->files(files=>[qw(foo bar)]),
   "# Files: foo, bar\n",
   "files report"
);

like(
   $qrf->hostname(),
   qr/# Hostname: .+?/,
   "hostname report"
);

# #############################################################################
# Test report grouping.
# #############################################################################
$events = [
   {
      cmd         => 'Query',
      arg         => "select col from tbl where id=42",
      fingerprint => "select col from tbl where id=?",
      Query_time  => '1.000652',
      Lock_time   => '0.001292',
      ts          => '071015 21:43:52',
      pos_in_log  => 123,
      db          => 'foodb',
   },
];
$ea = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
);
foreach my $event ( @$events ) {
   $ea->aggregate($event);
}
$ea->calculate_statistical_metrics();
@ARGV = qw();
$o->get_opts();
$report = new ReportFormatter(line_width=>74);
$qrf    = new QueryReportFormatter(
   OptionParser  => $o,
   QueryRewriter => $qr,
   QueryParser   => $qp,
   Quoter        => $q, 
);
my $output = output(
   sub { $qrf->print_reports(
      reports => [qw(rusage date files header query_report profile)],
      ea      => $ea,
      worst   => [['select col from tbl where id=?','top',1]],
      orderby => 'Query_time',
      groupby => 'fingerprint',
      files   => [qw(foo bar)],
      group   => {map {$_=>1} qw(rusage date files header)},
      ReportFormatter => $report,
   ); }
);
like(
   $output,
   qr/
^#\s.+?\suser time.+?vsz$
^#\sCurrent date:.+?$
^#\sFiles:\sfoo,\sbar$
   /mx,
   "grouped reports"
);

# #############################################################################
# Issue 1124: Make mk-query-digest profile include variance-to-mean ratio
# #############################################################################

$events = [
   {
      Query_time    => "1.000000",
      arg           => "select c from t where id=1",
      fingerprint   => "select c from t where id=?",
      cmd           => 'Query',
      pos_in_log    => 0,
   },
   {
      Query_time    => "5.500000",
      arg           => "select c from t where id=2",
      fingerprint   => "select c from t where id=?",
      cmd           => 'Query',
      pos_in_log    => 0,
   },
   {
      Query_time    => "2.000000",
      arg           => "select c from t where id=3",
      fingerprint   => "select c from t where id=?",
      cmd           => 'Query',
      pos_in_log    => 0,
   },
   {
      Query_time    => "9.000000",
      arg           => "select c from t where id=4",
      fingerprint   => "select c from t where id=?",
      cmd           => 'Query',
      pos_in_log    => 0,
   },
];
$ea = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
);
foreach my $event ( @$events ) {
   $ea->aggregate($event);
}
$ea->calculate_statistical_metrics();
$report = new ReportFormatter(
   line_width   => 74,
   extend_right => 1,
);
ok(
   no_diff(
      sub {
         $qrf->print_reports(
            reports => ['profile'],
            ea      => $ea,
            worst   => [
               ['select c from t where id=?', 'top',1],
            ],
            orderby => 'Query_time',
            groupby => 'fingerprint',
            ReportFormatter => $report,
         );
      },
      "common/t/samples/QueryReportFormatter/reports005.txt",
   ),
   "Variance-to-mean ration (issue 1124)"
);

# #############################################################################
# Done.
# #############################################################################
$output = '';
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
