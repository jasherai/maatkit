#!/usr/bin/perl
require '../common/ProtocolParser.pm';
print "@ARGV\n";
print ProtocolParser::timestamp_diff(undef, @ARGV), "\n";
exit;
