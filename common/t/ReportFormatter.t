#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

require '../Transformers.pm';
require '../ReportFormatter.pm';

my $rf;

sub test_print {
   my $output = '';
   open my $fh, '>', \$output or die $OS_ERROR;
   select $fh;
   $rf->print();
   close $fh;
   select STDOUT;
   return $output;
}

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
   test_print(),
"# Checksum differences
# Query ID             db-1.foo.com 123.123.123.123
# ==================== ============ ===============
# 0x3A99CC42AEDCCFCD-1 ABC12345     ADD12345       
# 0x234DDDAC43820481-3 0007C99B     BB008171       
",
   'Basic report'
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
