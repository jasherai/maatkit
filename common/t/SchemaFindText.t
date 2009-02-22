#!/usr/bin/perl

# This program is copyright (c) 2008 Baron Schwartz.
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

use Test::More tests => 6;
use English qw(-no_match_vars);

require "../SchemaFindText.pm";

open my $fh, "<", "samples/schema-dump.sql" or die $OS_ERROR;

my $sft = new SchemaFindText(fh => $fh);

is($sft->next_db(), 'mysql', 'got mysql DB');
is($sft->next_tbl(), 'columns_priv', 'got columns_priv table');
like($sft->last_tbl_ddl(), qr/CREATE TABLE `columns_priv`/, 'got columns_priv ddl');
is($sft->next_db(), 'sakila', 'got sakila DB');
$sft->next_tbl();
is($sft->next_tbl(), 'address', 'got address table');
like($sft->last_tbl_ddl(), qr/CREATE TABLE `address`/, 'got address ddl');
