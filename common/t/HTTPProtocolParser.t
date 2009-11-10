#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

require '../TcpdumpParser.pm';
require '../ProtocolParser.pm';
require '../HTTPProtocolParser.pm';

use Data::Dumper;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Indent    = 1;

my $tcpdump  = new TcpdumpParser();
my $protocol; # Create a new HTTPProtocolParser for each test.

sub load_data {
   my ( $file ) = @_;
   open my $fh, '<', $file or BAIL_OUT("Cannot open $file: $OS_ERROR");
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   (my $data = join('', $contents =~ m/(.*)/g)) =~ s/\s+//g;
   return $data;
}

sub run_test {
   my ( $def ) = @_;
   map     { die "What is $_ for?" }
      grep { $_ !~ m/^(?:misc|file|result|num_events|desc)$/ }
      keys %$def;
   my @e;
   my $num_events = 0;

   my @callbacks;
   push @callbacks, sub {
      my ( $packet ) = @_;
      return $protocol->parse_packet($packet, undef);
   };
   push @callbacks, sub {
      push @e, @_;
   };

   eval {
      open my $fh, "<", $def->{file}
         or BAIL_OUT("Cannot open $def->{file}: $OS_ERROR");
      $num_events++ while $tcpdump->parse_event($fh, undef, @callbacks);
      close $fh;
   };
   is($EVAL_ERROR, '', "No error on $def->{file}");
   if ( defined $def->{result} ) {
      is_deeply(
         \@e,
         $def->{result},
         $def->{file} . ($def->{desc} ? ": $def->{desc}" : '')
      ) or print "Got: ", Dumper(\@e);
   }
   if ( defined $def->{num_events} ) {
      is($num_events, $def->{num_events}, "$def->{file} num_events");
   }

   # Uncomment this if you're hacking the unknown.
   # print "Events for $def->{file}: ", Dumper(\@e);

   return;
}

# GET a very simple page.
$protocol = new HTTPProtocolParser();
run_test({
   file   => 'samples/http_tcpdump001.txt',
   result => [
      { ts           => '2009-11-09 11:31:52.341907',
        bytes        => '715',
        host         => '10.112.2.144',
        pos_in_log   => 0,
        request      => 'get',
        domain       => 'hackmysql.com',
        page         => '/contact',
        response     => '200',
        Query_time   => '0.651419',
      },
   ],
});

# Get http://www.percona.com/about-us.html
$protocol = new HTTPProtocolParser();
run_test({
   file   => 'samples/http_tcpdump002.txt',
   result => [
     { ts            => '2009-11-09 15:31:09.074855',
       Query_time    => '0.070097',
       bytes         => '3832',
       host          => '10.112.2.144',
       page          => '/about-us.html',
       pos_in_log    => 1411,
       request       => 'get',
       response      => '200', 
     },
     { ts            => '2009-11-09 15:31:09.157215',
       Query_time    => '0.068558',
       bytes         => '9921',
       host          => '10.112.2.144',
       page          => '/js/jquery.js',
       pos_in_log    => 17567,
       request       => 'get',
       response      => '200', 
     },
     { ts            => '2009-11-09 15:31:09.346763',
       Query_time    => '0.066506',
       bytes         => '344',
       host          => '10.112.2.144',
       page          => '/images/menu_team.gif',
       pos_in_log    => 54305,
       request       => 'get',
       response      => '200', 
     },
     { ts            => '2009-11-09 15:31:09.373800',
       Query_time    => '0.045442',
       bytes         => '35',
       host          => '10.112.2.144',
       page          => '/__utm.gif?utmwv=1.3&utmn=1710381507&utmcs=UTF-8&utmsr=1280x800&utmsc=24-bit&utmul=en-us&utmje=1&utmfl=10.0%20r22&utmdt=About%20Percona&utmhn=www.percona.com&utmhid=1947703805&utmr=0&utmp=/about-us.html&utmac=UA-343802-3&utmcc=__utma%3D154442809.1969570579.1256593671.1256825719.1257805869.3%3B%2B__utmz%3D154442809.1256593671.1.1.utmccn%3D(direct)%7Cutmcsr%3D(direct)%7Cutmcmd%3D(none)%3B%2B',
       pos_in_log    => 57147,
       request       => 'get',
       response      => '200', 
     },
     { ts            => '2009-11-09 15:31:09.411349',
       Query_time    => '0.073882',
       bytes         => '414',
       host          => '10.112.2.144',
       page          => '/images/menu_our-vision.gif',
       pos_in_log    => 60418,
       request       => 'get',
       response      => '200', 
     },
     { ts            => '2009-11-09 15:31:09.420996',
       Query_time    => '0.067345',
       bytes         => '20017',
       host          => '10.112.2.144',
       page          => '/images/handshake.jpg',
       pos_in_log    => 69161,
       request       => 'get',
       response      => '200', 
     },
     { ts            => '2009-11-09 15:31:09.420851',
       Query_time    => '0.067669',
       bytes         => '170',
       host          => '10.112.2.144',
       page          => '/images/bg-gray-corner-top.gif',
       pos_in_log    => 66849,
       request       => 'get',
       response      => '200', 
     },
     { ts            => '2009-11-09 15:31:14.536149',
       Query_time    => '0.061528',
       bytes         => '4009',
       host          => '10.112.2.144',
       page          => '/clickaider.js',
       pos_in_log    => 148652,
       request       => 'get',
       response      => '200', 
     },
     { ts            => '2009-11-09 15:31:14.678713',
       Query_time    => '0.060436',
       bytes         => '43',
       host          => '10.112.2.144',
       page          => '/pv?lng=140&&lnks=&t=About%20Percona&c=73a41b95-2926&r=http%3A%2F%2Fwww.percona.com%2F&tz=-420&loc=http%3A%2F%2Fwww.percona.com%2Fabout-us.html&rnd=3688',
       pos_in_log    => 168450,
       request       => 'get',
       response      => '200', 
     },
     { ts            => '2009-11-09 15:31:14.737890',
       Query_time    => '0.061937',
       bytes         => '822',
       host          => '10.112.2.144',
       page          => '/s/forms.js',
       pos_in_log    => 171322,
       request       => 'get',
       response      => '200', 
     },
   ],
});

# #############################################################################
# Done.
# #############################################################################
exit;
