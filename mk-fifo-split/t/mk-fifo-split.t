#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

unlink('/tmp/mk-fifo-split');

my $output = `perl ../mk-fifo-split --help`;
like($output, qr/Options and values/, 'It lives');

my $cmd = 'perl ../mk-fifo-split --lines 10000 ../mk-fifo-split > /dev/null 2>&1 < /dev/null';
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
