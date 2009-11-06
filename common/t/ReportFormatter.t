#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

require '../Transformers.pm';
require '../ReportFormatter.pm';

my $rf;

$rf = new ReportFormatter();

isa_ok($rf, 'ReportFormatter');

$rf->set_title('Checksum differences');

$rf->set_columns(
   {
      name        => 'Query ID',
      fixed_width => length '0x234DDDAC43820481-3',
   },
   {
      name => 'db-1.foo.com',
   },
   {
      name => '123.123.123.123',
   },
);

$rf->add_line(qw(0x3A99CC42AEDCCFCD-1  ABC12345  ADD12345));
$rf->add_line(qw(0x234DDDAC43820481-3  0007C99B  BB008171));

is(
   $rf->get_report(),
"# Checksum differences
# Query ID             db-1.foo.com 123.123.123.123
# ==================== ============ ===============
# 0x3A99CC42AEDCCFCD-1 ABC12345     ADD12345
# 0x234DDDAC43820481-3 0007C99B     BB008171
",
   'Basic report'
);

$rf = new ReportFormatter();
$rf->set_title('Truncate underline');
$rf->set_columns(
   { name => 'col1' },
   { name => 'col2' },
);
$rf->add_line('short', 'long long long long long long long long long long long long long long long long long long');

is(
   $rf->get_report(),
"# Truncate underline
# col1  col2
# ===== ======================================================================
# short long long long long long long long long long long long long long long long long long long
",
   'Truncate header underlining to line width'
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $rf->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
