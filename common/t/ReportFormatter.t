#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use Transformers;
use ReportFormatter;
use MaatkitTest;

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

$rf = new ReportFormatter(
   long_last_column => 1,
);
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
# short long long long long long long long long long long long long long lo...
",
   'Truncate header underlining to line width'
);


# Make sure header labels are always left justified.
$rf = new ReportFormatter(
   long_last_column => 1,
);
$rf->set_columns(
   { name => 'Rank',          right_justify => 1, },
   { name => 'Query ID',                          },
   { name => 'Response time', right_justify => 1, },
   { name => 'Calls',         right_justify => 1, },
   { name => 'R/Call',        right_justify => 1, },
   { name => 'Item',                              },
);
$rf->add_line(
   '123456789', '0x31DA25F95494CA95', '0.1494 99.9%', '1', '0.1494', 'SHOW');

is(
   $rf->get_report(),
"# Rank      Query ID           Response time Calls R/Call Item
# ========= ================== ============= ===== ====== ====
# 123456789 0x31DA25F95494CA95  0.1494 99.9%     1 0.1494 SHOW
",
   'Header labels are always left justified'
);

# #############################################################################
# Respect line width.
# #############################################################################
$rf = new ReportFormatter(long_last_column=>1);
$rf->set_title('Respect line width');
$rf->set_columns(
   { name => 'col1' },
   { name => 'col2' },
   { name => 'col3' },
);
$rf->add_line(
   'short',
   'longer',
   'long long long long long long long long long long long long long long long long long long'
);
$rf->add_line(
   'a',
   'b',
   'c',
);

is(
   $rf->get_report(),
"# Respect line width
# col1  col2   col3
# ===== ====== ===============================================================
# short longer long long long long long long long long long long long long ...
# a     b      c
",
   'Respects line length'
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
