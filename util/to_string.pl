#!/usr/bin/perl
require '../common/MySQLProtocolParser.pm';
my $str = shift @ARGV;
$str =~ s/\s+//g;
my $str = MySQLProtocolParser::to_string($str);
print "$str\n";
exit;
