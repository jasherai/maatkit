#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 1;

my $output = `../mk-duplicate-key-checker -d mysql -t columns_priv -v`;
like($output, qr/mysql\s+columns_priv\s+MyISAM/, 'Finds mysql.columns_priv PK');

