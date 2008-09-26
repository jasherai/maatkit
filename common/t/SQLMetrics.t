#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;
use English qw(-no_match_vars);

require '../QueryRewriter.pm';
require '../SQLMetrics.pm';

use Data::Dumper;
$Data::Dumper::Indent = 1;

my $handlers = {
   SQLMetrics::make_handler_for('Query_time', 'number'),
   SQLMetrics::make_handler_for('user', 'string'),
};

my $m  = new SQLMetrics(
   key_metric      => 'arg',
   fingerprint     => \&QueryRewriter::fingerprint,
   handlers        => $handlers,
   buffer_n_events => -1,
);

isa_ok($m, 'SQLMetrics');

my $events = [
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      arg           => "SELECT id FROM users WHERE name='baouong'",
      Query_time    => '0.000652',
      Lock_time     => '0.000109',
      Rows_sent     => 1,
      Rows_examined => 1,
      NR            => 5,
   },
   {  ts   => '071015 21:43:52',
      cmd  => 'Query',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg  => "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
      Query_time    => '0.001943',
      Lock_time     => '0.000145',
      Rows_sent     => 0,
      Rows_examined => 0,
      NR            => 8,
   },
];

foreach my $event ( @$events ) {
   $m->record_event($event);
}
$m->calc_metrics();

print Dumper($m);

exit;
