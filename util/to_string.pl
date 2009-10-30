#!/usr/bin/perl
require '../common/MySQLProtocolParser.pm';
my $str = MySQLProtocolParser::to_string(@ARGV);
print "$str\n";
exit;
