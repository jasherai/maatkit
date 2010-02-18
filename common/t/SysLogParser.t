#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use SysLogParser;
use MaatkitTest;

my $p = new SysLogParser;

# The final line is broken across two lines in the actual log, but it's one
# logical event.
test_log_parser(
   parser => $p,
   file   => 'common/t/samples/pg-syslog-005.txt',
   result => [
      '2010-02-10 09:03:26.918 EST c=4b72bcae.d01,u=[unknown],D=[unknown] LOG:  connection received: host=[local]',
      '2010-02-10 09:03:26.922 EST c=4b72bcae.d01,u=fred,D=fred LOG:  connection authorized: user=fred database=fred',
      '2010-02-10 09:03:36.645 EST c=4b72bcae.d01,u=fred,D=fred LOG:  duration: 0.627 ms  statement: select 1;',
      '2010-02-10 09:03:39.075 EST c=4b72bcae.d01,u=fred,D=fred LOG:  disconnection: session time: 0:00:12.159 user=fred database=fred host=[local]',
   ],
);

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
