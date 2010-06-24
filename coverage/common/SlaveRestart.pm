---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/SlaveRestart.pm   86.8   57.1   45.5   88.9    0.0   85.6   75.3
SlaveRestart.t                 95.7   50.0   33.3  100.0    n/a   14.4   87.1
Total                          91.0   54.2   42.9   94.7    0.0  100.0   80.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:39 2010
Finish:       Thu Jun 24 19:36:39 2010

Run:          SlaveRestart.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:41 2010
Finish:       Thu Jun 24 19:37:16 2010

/home/daniel/dev/maatkit/common/SlaveRestart.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # ###########################################################################
2                                                     # SlaveRestart package $Revision: 0000 $
3                                                     # ###########################################################################
4                                                     
5                                                     package SlaveRestart;
6                                                     
7              1                    1             4   use strict;
               1                                  2   
               1                                  7   
8              1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
9              1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
10                                                    
11    ***      1            50      1             9   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 19   
12                                                    
13                                                    # Arguments:
14                                                    #   * dbh                dbh: contains the original slave info.
15                                                    #   * connect_to_slave   coderef: tries to connect to the slave.
16                                                    #   * onfail             scalar: whether it will attempt to reconnect or not.
17                                                    #   * retries            scalar: number of reconnect attempts.
18                                                    #   * delay              coderef: returns the amount of time between each reconnect
19                                                    
20                                                    sub new {
21    ***      1                    1      0     11      my ($class, %args) = @_;
22             1                                  6      foreach my $arg ( qw(dbh connect_to_slave) ) {
23    ***      2     50                          12         die "I need a $arg argument" unless $args{$arg};
24                                                       }
25                                                    
26                                                       my $self = {
27                                                          show_slave_status => sub {
28             7                    7            39            my ($dbh) = @_;
29             7                                 21            return $dbh->selectrow_hashref("SHOW SLAVE STATUS");
30                                                          },
31             1                                 12         retries           => 3,
32                                                          delay             => 5,
33                                                    
34                                                          # Override defaults
35                                                          %args,
36                                                       };
37             1                                 17      return bless $self, $class;
38                                                    }
39                                                    
40                                                    sub reconnect {
41    ***      2                    2      0     40      my ($self) = @_;
42             2                                 21      my $reconnect_attempt = 1;
43             2                                 23      my ($slave, $status);
44                                                      
45    ***      2     50     33                  396      return if $self->{dbh} && $self->{dbh}->ping;
46             2                                126      warn "Attempting to reconnect to the slave.\n";
47    ***      2            66                   76      while ( !$status->{master_host} && $reconnect_attempt <= $self->{retries} ) {
48             6                                 48         my $sleep_time = $self->{delay};
49             6                                 22         MKDEBUG && _d("Reconnect attempt: ", $reconnect_attempt);
50             6                                 29         MKDEBUG && _d("Reconnect time: ", $sleep_time);
51                                                          
52             6                                 47         eval {
53             6                                 29            $slave  = ${ $self->{connect_to_slave} }->();
               6                                107   
54                                                          };
55                                                    
56    ***      6     50                        1539         if ( $EVAL_ERROR ) {
57    ***      0                                  0            MKDEBUG && _d($EVAL_ERROR);
58                                                          }
59             6                                 65         $status = $self->_check_slave_status( dbh => $slave );
60                                                    
61    ***      6     50     33                   82         MKDEBUG && _d("Successfully reconnected to the slave.")
62                                                             if ( $status->{master_host} && $reconnect_attempt <= $self->{retries} );
63                                                    
64             6                             30001180         sleep $sleep_time;
65             6                                254         $reconnect_attempt++;
66                                                       }
67             2                                 75      return $slave;
68                                                    };
69                                                    
70                                                    sub _check_slave_status {
71             7                    7            87      my ($self, %args) = @_;
72             7                                 41      my $dbh = $args{dbh};
73             7                                 39      my $show_slave_status = $self->{show_slave_status};
74             7                                 29      my $status;
75                                                    
76             7                                 35      eval{
77             7                                 47         $status = $show_slave_status->($dbh);
78                                                       };
79                                                    
80             7    100                          68      if ( $EVAL_ERROR ) {
81             4                                 17         MKDEBUG && _d($EVAL_ERROR);
82                                                       }
83             7    100                         498      return $EVAL_ERROR ? undef : $status;
84                                                    }
85                                                    
86                                                    sub _d {
87    ***      0                    0                    my ($package, undef, $line) = caller 0;
88    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
89    ***      0                                              map { defined $_ ? $_ : 'undef' }
90                                                            @_;
91    ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
92                                                    }
93                                                    
94                                                    1;
95                                                    
96                                                    # ###########################################################################
97                                                    # End SlaveRestart package
98                                                    # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
23    ***     50      0      2   unless $args{$arg}
45    ***     50      0      2   if $$self{'dbh'} and $$self{'dbh'}->ping
56    ***     50      0      6   if ($EVAL_ERROR)
61    ***     50      0      6   if $$status{'master_host'} and $reconnect_attempt <= $$self{'retries'}
80           100      4      3   if ($EVAL_ERROR)
83           100      4      3   $EVAL_ERROR ? :
88    ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
45    ***     33      0      2      0   $$self{'dbh'} and $$self{'dbh'}->ping
47    ***     66      0      2      6   not $$status{'master_host'} and $reconnect_attempt <= $$self{'retries'}
61    ***     33      6      0      0   $$status{'master_host'} and $reconnect_attempt <= $$self{'retries'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
11    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine          Count Pod Location                                          
------------------- ----- --- --------------------------------------------------
BEGIN                   1     /home/daniel/dev/maatkit/common/SlaveRestart.pm:11
BEGIN                   1     /home/daniel/dev/maatkit/common/SlaveRestart.pm:7 
BEGIN                   1     /home/daniel/dev/maatkit/common/SlaveRestart.pm:8 
BEGIN                   1     /home/daniel/dev/maatkit/common/SlaveRestart.pm:9 
__ANON__                7     /home/daniel/dev/maatkit/common/SlaveRestart.pm:28
_check_slave_status     7     /home/daniel/dev/maatkit/common/SlaveRestart.pm:71
new                     1   0 /home/daniel/dev/maatkit/common/SlaveRestart.pm:21
reconnect               2   0 /home/daniel/dev/maatkit/common/SlaveRestart.pm:41

Uncovered Subroutines
---------------------

Subroutine          Count Pod Location                                          
------------------- ----- --- --------------------------------------------------
_d                      0     /home/daniel/dev/maatkit/common/SlaveRestart.pm:87


SlaveRestart.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/env perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.
5                                                     com/p/maatkit/wiki/Testing"
6                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
7              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
8                                                     
9                                                     };
10                                                    
11             1                    1            11   use strict;
               1                                  3   
               1                                  5   
12             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
13             1                    1            11   use English qw( -no_match_vars );
               1                                  3   
               1                                  7   
14             1                    1            10   use Test::More;
               1                                  3   
               1                                 10   
15                                                    
16             1                    1            17   use DSNParser;
               1                                  3   
               1                                 13   
17             1                    1            13   use SlaveRestart;
               1                                  3   
               1                                 13   
18             1                    1            12   use MaatkitTest; 
               1                                  4   
               1                                 39   
19             1                    1            13   use Sandbox;
               1                                  3   
               1                                 24   
20                                                    
21             1                                 13   my $dp  = new DSNParser ( opts => $dsn_opts );
22             1                                227   my $sb  = new Sandbox ( basedir => '/tmp', DSNParser => $dp );
23             1                                 52   my $dbh = $sb->get_dbh_for( 'slave1' );
24             1                                367   my $status;
25                                                    
26    ***      1     50                           6   if ( !$dbh ) {
      ***      1     50                           2   
27    ***      0                                  0      plan skip_all => 'Cannot connect to MySQL slave.';
28                                                    }
29                                                    elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
30    ***      0                                  0      plan skip_all => 'sakila db not loaded';
31                                                    }
32                                                    else {
33             1                                407      plan tests => 4;
34                                                    }
35                                                    
36                                                    my $restart = new SlaveRestart(
37                                                       dbh              => $dbh,
38             6                    6           115      connect_to_slave => \sub { $sb->get_dbh_for( 'slave1' ) }, 
39             1                                507      onfail           => 1,    # Simulate that the reconnect option is used.
40                                                       retries          => 3,
41                                                       delay            => 5,
42                                                    );
43                                                    
44             1                                 10   isa_ok( $restart, 'SlaveRestart' );
45                                                    
46                                                    # ###########################################################################
47                                                    # Test checking the status of the slave database. 
48                                                    # ###########################################################################
49             1                               1036   my ($rows) = $restart->_check_slave_status( dbh => $dbh );
50             1                                  8   ok( $rows->{Master_Port} == '12345', 'Check and show slave status correctly.' );
51                                                    
52                                                    # ###########################################################################
53                                                    # Test to see if it cannot connect to a slave database.
54                                                    # ###########################################################################
55    ***      1     50                      5022465   die( 'Cannot stop MySQL slave.' ) if system( '/tmp/12346/stop && sleep 2' );
56             1                                 78   ($dbh)  = $restart->reconnect();
57             1                                 33   ok( $dbh == 0, 'Unable to connect to slave.' );
58                                                    
59                                                    # ###########################################################################
60                                                    # Test reconnecting to a slave database.
61                                                    # ###########################################################################
62    ***      1     50                       10165   die( 'Cannot start MySQL slave.' ) if system( 'sleep 1 && /tmp/12346/start &' );
63             1                                 79   ($dbh)  = $restart->reconnect();
64             1                                  6   $status = $dbh->selectrow_hashref("SHOW SLAVE STATUS"); 
65             1                                 43   ok( $status->{Master_Port} == '12345', 'Reconnect to lost slave db.' );


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
26    ***     50      0      1   if (not $dbh) { }
      ***     50      0      1   elsif (not @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"');}) { }
55    ***     50      0      1   if system '/tmp/12346/stop && sleep 2'
62    ***     50      0      1   if system 'sleep 1 && /tmp/12346/start &'


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location         
---------- ----- -----------------
BEGIN          1 SlaveRestart.t:11
BEGIN          1 SlaveRestart.t:12
BEGIN          1 SlaveRestart.t:13
BEGIN          1 SlaveRestart.t:14
BEGIN          1 SlaveRestart.t:16
BEGIN          1 SlaveRestart.t:17
BEGIN          1 SlaveRestart.t:18
BEGIN          1 SlaveRestart.t:19
BEGIN          1 SlaveRestart.t:4 
__ANON__       6 SlaveRestart.t:38


