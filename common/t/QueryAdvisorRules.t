#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 46;

use MaatkitTest;
use PodParser;
use QueryAdvisorRules;
use QueryAdvisor;
use SQLParser;

# This test should just test that the QueryAdvisor module conforms to the
# expected interface:
#   - It has a get_rules() method that returns a list of hashrefs:
#     ({ID => 'ID', code => $code}, {ID => ..... }, .... )
#   - It has a load_rule_info() method that accepts a list of hashrefs, which
#     we'll use to load rule info from POD.  Our built-in rule module won't
#     store its own rule info.  But plugins supplied by users should.
#   - It has a get_rule_info() method that accepts an ID and returns a hashref:
#     {ID => 'ID', Severity => 'NOTE|WARN|CRIT', Description => '......'}
my $p   = new PodParser();
my $qar = new QueryAdvisorRules(PodParser => $p);

my @rules = $qar->get_rules();
ok(
   scalar @rules,
   'Returns array of rules'
);

my $rules_ok = 1;
foreach my $rule ( @rules ) {
   if (    !$rule->{id}
        || !$rule->{code}
        || (ref $rule->{code} ne 'CODE') )
   {
      $rules_ok = 0;
      last;
   }
}
ok(
   $rules_ok,
   'All rules are proper'
);

# QueryAdvisorRules.pm has more rules than mqa-rule-LIT.001.pod so to avoid
# "There is no info" errors we remove all but LIT.001.
@rules = grep { $_->{id} eq 'LIT.001' } @rules;

# Test that we can load rule info from POD.  Make a sample POD file that has a
# single sample rule definition for LIT.001 or something.
$qar->load_rule_info(
   rules    => \@rules,
   file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
   section  => 'CHECKS',
);

# We shouldn't be able to load the same rule info twice.
throws_ok(
   sub {
      $qar->load_rule_info(
         rules    => \@rules,
         file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
         section  => 'CHECKS',
      );
   },
   qr/Info for rule \S+ already exists and cannot be redefined/,
   'Duplicate rule info is caught',
);

# Test that we can now get a hashref as described above.
is_deeply(
   $qar->get_rule_info('LIT.001'),
   {  id          => 'LIT.001',
      severity    => 'NOTE',
      description => "IP address used as string. The string literal looks like an IP address but is not used inside INET_ATON(). WHERE ip='127.0.0.1' is better as ip=INET_ATON('127.0.0.1') if the column is numeric.",
   },
   'get_rule_info(LIT.001) works',
);

# Test getting a nonexistent rule.
is(
   $qar->get_rule_info('BAR.002'),
   undef,
   "get_rule_info() nonexistent rule"
);

is(
   $qar->get_rule_info(),
   undef,
   "get_rule_info(undef)"
);

# Add a rule for which there is no POD info and test that it's not allowed.
push @rules, {
   id   => 'FOO.001',
   code => sub { return },
};
$qar->_reset_rule_info();  # else we'll get "cannot redefine rule" error
throws_ok (
   sub {
      $qar->load_rule_info(
         rules    => \@rules,
         file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
         section  => 'CHECKS',
      );
   },
   qr/There is no info for rule FOO.001/,
   "Doesn't allow rules without info",
);

# ###########################################################################
# Test cases for the rules themselves.
# ###########################################################################
my @cases = (
   {  name   => 'IP address not inside INET_ATON, plus SELECT * is used',
      query  => 'SELECT * FROM tbl WHERE ip="127.0.0.1"',
      advice => [qw(LIT.001 COL.001)],
   },
   {  name   => 'Date literal not quoted',
      query  => 'SELECT col FROM tbl WHERE col < 2001-01-01',
      advice => [qw(LIT.002)],
   },
   {  name   => 'Aliases without AS keyword',
      query  => 'SELECT a b FROM tbl',
      advice => [qw(ALI.001 CLA.001)],
   },
   {  name   => 'tbl.* alias',
      query  => 'SELECT tbl.* foo FROM bar WHERE id=1',
      advice => [qw(ALI.001 ALI.002 COL.001)],
   },
   {  name   => 'tbl as tbl',
      query  => 'SELECT col FROM tbl AS tbl WHERE id',
      advice => [qw(ALI.003)],
   },
   {  name   => 'col as col',
      query  => 'SELECT col AS col FROM tbl AS `my tbl` WHERE id',
      advice => [qw(ALI.003)],
   },
   {  name   => 'Blind INSERT',
      query  => 'INSERT INTO tbl VALUES(1),(2)',
      advice => [qw(COL.002)],
   },
   {  name   => 'Blind INSERT',
      query  => 'INSERT tbl VALUE (1)',
      advice => [qw(COL.002)],
   },
   {  name   => 'SQL_CALC_FOUND_ROWS',
      query  => 'SELECT SQL_CALC_FOUND_ROWS col FROM tbl AS alias WHERE id=1',
      advice => [qw(KWR.001)],
   },
   {  name   => 'All comma joins ok',
      query  => 'SELECT col FROM tbl1, tbl2 WHERE tbl1.id=tbl2.id',
      advice => [],
   },
   {  name   => 'All ANSI joins ok',
      query  => 'SELECT col FROM tbl1 JOIN tbl2 USING(id) WHERE tbl1.id>10',
      advice => [],
   },
   {  name   => 'Mix comman/ANSI joins',
      query  => 'SELECT col FROM tbl, tbl1 JOIN tbl2 USING(id) WHERE tbl.d>10',
      advice => [qw(JOI.001)],
   },
   {  name   => 'Non-deterministic GROUP BY',
      query  => 'select a, b, c from tbl where foo group by a',
      advice => [qw(RES.001)],
   },
   {  name   => 'Non-deterministic LIMIT w/o ORDER BY',
      query  => 'select a, b from tbl where foo limit 10 group by a, b',
      advice => [qw(RES.002)],
   },
   {  name   => 'ORDER BY RAND()',
      query  => 'select a from t where id order by rand()',
      advice => [qw(CLA.002)],
   },
   {  name   => 'ORDER BY RAND(N)',
      query  => 'select a from t where id order by rand(123)',
      advice => [qw(CLA.002)],
   },
   {  name   => 'LIMIT w/ OFFSET does not scale',
      query  => 'select a from t where i limit 10, 10 order by a',
      advice => [qw(CLA.003)],
   },
   {  name   => 'LIMIT w/ OFFSET does not scale',
      query  => 'select a from t where i limit 10 OFFSET 10 order by a',
      advice => [qw(CLA.003)],
   },
   {  name   => 'Leading %wildcard',
      query  => 'select a from t where i="%hm"',
      advice => [qw(ARG.001)],
   },
   {  name   => 'Leading _wildcard',
      query  => 'select a from t where i="_hm"',
      advice => [qw(ARG.001)],
   },
   {  name   => 'Leading "% wildcard"',
      query  => 'select a from t where i="% eh "',
      advice => [qw(ARG.001)],
   },
   {  name   => 'Leading "_ wildcard"',
      query  => 'select a from t where i="_ eh "',
      advice => [qw(ARG.001)],
   },
   {  name   => 'GROUP BY number',
      query  => 'select a from t where i group by 1',
      advice => [qw(CLA.004)],
   },
   {  name   => '!= instead of <>',
      query  => 'select a from t where i != 2',
      advice => [qw(STA.001)],
   },
   {  name   => "LIT.002 doesn't match",
      query  => "update foo.bar set biz = '91848182522'",
      advice => [],
   },
   {  name   => "LIT.002 doesn't match",
      query  => "update db2.tuningdetail_21_265507 inner join db1.gonzo using(g) set n.c1 = a.c1, n.w3 = a.w3",
      advice => [],
   },
   {  name   => "LIT.002 doesn't match",
      query  => "UPDATE db4.vab3concept1upload
                 SET    vab3concept1id = '91848182522'
                 WHERE  vab3concept1upload='6994465'",
      advice => [],
   },
   {  name   => "LIT.002 at end of query",
      query  => "select c from t where d=2006-10-10",
      advice => [qw(LIT.002)],
   },
   {  name   => "LIT.002 5 digits doesn't match",
      query  => "select c from t where d=12345",
      advice => [],
   },
   {  name   => "LIT.002 7 digits doesn't match",
      query  => "select c from t where d=1234567",
      advice => [],
   },
   {  name   => "SELECT var LIMIT",
      query  => "select \@\@version_comment limit 1 ",
      advice => [],
   },
   {  name   => "Date with time",
      query  => "select c from t where d > 2010-03-15 09:09:09",
      advice => [qw(LIT.002)],
   },
   {  name   => "Date with time and subseconds",
      query  => "select c from t where d > 2010-03-15 09:09:09.123456",
      advice => [qw(LIT.002)],
   },
   {  name   => "Date with time doesn't match",
      query  => "select c from t where d > '2010-03-15 09:09:09'",
      advice => [qw()],
   },
   {  name   => "Date with time and subseconds doesn't match",
      query  => "select c from t where d > '2010-03-15 09:09:09.123456'",
      advice => [qw()],
   },
   {  name   => "LIKE without wildcard",
      query  => "select c from t where i like 'lamp'",
      advice => [qw(ARG.002)],
   },
   {  name   => "LIKE with wildcard %",
      query  => "select c from t where i like 'lamp%'",
      advice => [qw()],
   },
   {  name   => "LIKE with wildcard _",
      query  => "select c from t where i like 'lamp_'",
      advice => [qw()],
   },
);

# Run the test cases.
$qar = new QueryAdvisorRules(PodParser => $p);
$qar->load_rule_info(
   rules   => [ $qar->get_rules() ],
   file    => "$trunk/mk-query-advisor/mk-query-advisor",
   section => 'RULES',
);

my $qa = new QueryAdvisor();
$qa->load_rules($qar);
$qa->load_rule_info($qar);

my $sp = new SQLParser();

foreach my $test ( @cases ) {
   my $query_struct = $sp->parse($test->{query});
   my $event = {
      arg          => $test->{query},
      query_struct => $query_struct,
   };
   is_deeply(
      [ $qa->run_rules($event) ],
      [ sort @{$test->{advice}} ],
      $test->{name},
   );
}

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $p->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
