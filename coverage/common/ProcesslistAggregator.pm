---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../ProcesslistAggregator.pm   85.0   87.5   80.0   85.7    n/a  100.0   85.3
Total                          85.0   87.5   80.0   85.7    n/a  100.0   85.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          ProcesslistAggregator.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:26 2009
Finish:       Sat Aug 29 15:03:26 2009

/home/daniel/dev/maatkit/common/ProcesslistAggregator.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2009 Percona Inc.
2                                                     # Feedback and improvements are welcome.
3                                                     #
4                                                     # THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
5                                                     # WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
6                                                     # MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
7                                                     #
8                                                     # This program is free software; you can redistribute it and/or modify it under
9                                                     # the terms of the GNU General Public License as published by the Free Software
10                                                    # Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
11                                                    # systems, you can issue `man perlgpl' or `man perlartistic' to read these
12                                                    # licenses.
13                                                    #
14                                                    # You should have received a copy of the GNU General Public License along with
15                                                    # this program; if not, write to the Free Software Foundation, Inc., 59 Temple
16                                                    # Place, Suite 330, Boston, MA  02111-1307  USA.
17                                                    # ###########################################################################
18                                                    # ProcesslistAggregator package $Revision: 4175 $
19                                                    # ###########################################################################
20                                                    package ProcesslistAggregator;
21                                                    
22             1                    1             8   use strict;
               1                                  3   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  6   
               1                                  9   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
25                                                    
26             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
27                                                    
28                                                    sub new {
29             1                    1            13      my ( $class, %args ) = @_;
30    ***      1            50                   13      my $self = {
31                                                          undef_val => $args{undef_val} || 'NULL',
32                                                       };
33             1                                 11      return bless $self, $class;
34                                                    }
35                                                    
36                                                    # Given an arrayref of processes ($proclist), returns an hashref of
37                                                    # time and counts aggregates for User, Host, db, Command and State.
38                                                    # See t/ProcesslistAggregator.t for examples.
39                                                    # The $proclist arg is usually the return val of:
40                                                    #    $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} } );
41                                                    sub aggregate {
42             3                    3            29      my ( $self, $proclist ) = @_;
43             3                                 11      my $aggregate = {};
44             3                                  9      foreach my $proc ( @{$proclist} ) {
               3                                 13   
45           165                                417         foreach my $field ( keys %{ $proc } ) {
             165                                830   
46                                                             # Don't aggregate these fields.
47          1320    100                        5282            next if $field eq 'Id';
48          1155    100                        4076            next if $field eq 'Info';
49           990    100                        3622            next if $field eq 'Time';
50                                                    
51                                                             # Format the field's value a little.
52           825                               2580            my $val  = $proc->{ $field };
53           825    100                        2939               $val  = $self->{undef_val} if !defined $val;
54           825    100    100                 7025               $val  = lc $val if ( $field eq 'Command' || $field eq 'State' );
55           825    100                        3166               $val  =~ s/:.*// if $field eq 'Host';
56                                                    
57           825                               2534            my $time = $proc->{Time};
58           825    100                        2946               $time = 0 if $time eq 'NULL';
59                                                    
60                                                             # Do this last or else $proc->{$field} won't match.
61           825                               2442            $field = lc $field;
62                                                    
63           825                               4469            $aggregate->{ $field }->{ $val }->{time}  += $time;
64           825                               3900            $aggregate->{ $field }->{ $val }->{count} += 1;
65                                                          }
66                                                       }
67             3                                 29      return $aggregate;
68                                                    }
69                                                    
70                                                    sub _d {
71    ***      0                    0                    my ($package, undef, $line) = caller 0;
72    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
73    ***      0                                              map { defined $_ ? $_ : 'undef' }
74                                                            @_;
75    ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
76                                                    }
77                                                    
78                                                    1;
79                                                    
80                                                    # ###########################################################################
81                                                    # End ProcesslistAggregator package
82                                                    # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
47           100    165   1155   if $field eq 'Id'
48           100    165    990   if $field eq 'Info'
49           100    165    825   if $field eq 'Time'
53           100     23    802   if not defined $val
54           100    330    495   if $field eq 'Command' or $field eq 'State'
55           100    165    660   if $field eq 'Host'
58           100      5    820   if $time eq 'NULL'
72    ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
30    ***     50      0      1   $args{'undef_val'} || 'NULL'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
54           100    165    165    495   $field eq 'Command' or $field eq 'State'


Covered Subroutines
-------------------

Subroutine Count Location                                                   
---------- ----- -----------------------------------------------------------
BEGIN          1 /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:22
BEGIN          1 /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:23
BEGIN          1 /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:24
BEGIN          1 /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:26
aggregate      3 /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:42
new            1 /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:29

Uncovered Subroutines
---------------------

Subroutine Count Location                                                   
---------- ----- -----------------------------------------------------------
_d             0 /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:71


