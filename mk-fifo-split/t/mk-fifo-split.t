#!/usr/bin/perl

# This program is copyright (c) 2007 Baron Schwartz.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
use strict;
use warnings FATAL => 'all';

use Test::More tests => 3;
use English qw(-no_match_vars);

unlink('/tmp/mk-fifo-split');

my $output = `perl ../mk-fifo-split --help`;
like($output, qr/Options and values/, 'It lives');

my $cmd = 'perl ../mk-fifo-split ../mk-fifo-split > /dev/null 2>&1 < /dev/null';
system("($cmd)&");
sleep(1);

open my $fh, '<', '/tmp/mk-fifo-split' or die $OS_ERROR;
my $contents = do { local $INPUT_RECORD_SEPARATOR; <$fh>; };
close $fh;

open my $fh2, '<', '../mk-fifo-split' or die $OS_ERROR;
my $contents2 = do { local $INPUT_RECORD_SEPARATOR; <$fh2>; };
close $fh2;

ok($contents eq $contents2, 'I read the file');

$cmd = 'perl ../mk-fifo-split file_with_lines --offset 2 > /dev/null 2>&1 < /dev/null';
system("($cmd)&");
sleep(1);

open $fh, '<', '/tmp/mk-fifo-split' or die $OS_ERROR;
$contents = do { local $INPUT_RECORD_SEPARATOR; <$fh>; };
close $fh;

is($contents, <<EOF
     2	hi
     3	there
     4	b
     5	c
     6	d
EOF
, 'Offset works');
