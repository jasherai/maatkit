#!/usr/bin/perl
require '../MySQLProtocolParser.pm';
my $num = MySQLProtocolParser::to_num(@ARGV);
print "$num\n";
exit;
