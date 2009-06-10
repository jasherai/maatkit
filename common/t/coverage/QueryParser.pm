---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/QueryParser.pm   90.0   58.3   50.0   88.9    n/a  100.0   82.8
Total                          90.0   58.3   50.0   88.9    n/a  100.0   82.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:46 2009
Finish:       Wed Jun 10 17:20:46 2009

/home/daniel/dev/maatkit/common/QueryParser.pm

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
18                                                    # QueryParser package $Revision: 3637 $
19                                                    # ###########################################################################
20                                                    package QueryParser;
21                                                    
22             1                    1             7   use strict;
               1                                  3   
               1                                  5   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25                                                    
26             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
27                                                    our $tbl_ident = qr/(?:`[^`]+`|\w+)(?:\.(?:`[^`]+`|\w+))?/;
28                                                    # This regex finds things that look like database.table identifiers, based on
29                                                    # their proximity to keywords.  (?<!KEY\s) is a workaround for ON DUPLICATE KEY
30                                                    # UPDATE, which is usually followed by a column name.
31                                                    our $tbl_regex = qr{
32                                                             \b(?:FROM|JOIN|(?<!KEY\s)UPDATE|INTO) # Words that precede table names
33                                                             \b\s*
34                                                             # Capture the identifier and any number of comma-join identifiers that
35                                                             # follow it, optionally with aliases with or without the AS keyword
36                                                             ($tbl_ident
37                                                                (?: (?:\s+ (?:AS\s+)? \w+)?, \s*$tbl_ident )*
38                                                             )
39                                                          }xio;
40                                                    # This regex is meant to match "derived table" queries, of the form
41                                                    # .. from ( select ...
42                                                    # .. join ( select ...
43                                                    # .. bar join foo, ( select ...
44                                                    # Unfortunately it'll also match this:
45                                                    # select a, b, (select ...
46                                                    our $has_derived = qr{
47                                                          \b(?:FROM|JOIN|,)
48                                                          \s*\(\s*SELECT
49                                                       }xi;
50                                                    
51                                                    sub new {
52             1                    1             9      my ( $class ) = @_;
53             1                                 11      bless {}, $class;
54                                                    }
55                                                    
56                                                    # Returns a list of table names found in the query text.
57                                                    sub get_tables {
58            44                   44           228      my ( $self, $query ) = @_;
59    ***     44     50                         168      return unless $query;
60            44                                100      MKDEBUG && _d('Getting tables for', $query);
61                                                    
62                                                       # These keywords may appear between UPDATE or SELECT and the table refs.
63                                                       # They need to be removed so that they are not mistaken for tables.
64            44                                307      $query =~ s/ (?:LOW_PRIORITY|IGNORE|STRAIGHT_JOIN)//ig;
65                                                    
66            44                                141      $query =~ s/\\["']//g;                # quoted strings
67            44                                136      $query =~ s/".*?"/?/sg;               # quoted strings
68            44                                191      $query =~ s/'.*?'/?/sg;               # quoted strings
69                                                    
70            44                                110      my @tables;
71            44                                844      foreach my $tbls ( $query =~ m/$tbl_regex/gio ) {
72            60                                128         MKDEBUG && _d('Match tables:', $tbls);
73            60                                264         foreach my $tbl ( split(',', $tbls) ) {
74                                                             # Remove implicit or explicit (AS) alias.
75            74                                737            $tbl =~ s/\s*($tbl_ident)(\s+.*)?/$1/gio;
76            74                                399            push @tables, $tbl;
77                                                          }
78                                                       }
79            44                                351      return @tables;
80                                                    }
81                                                    
82                                                    # Returns true if it sees what looks like a "derived table", e.g. a subquery in
83                                                    # the FROM clause.
84                                                    sub has_derived_table {
85             5                    5            31      my ( $self, $query ) = @_;
86                                                       # See the $tbl_regex regex above.
87             5                                 45      my $match = $query =~ m/$has_derived/;
88             5                                 13      MKDEBUG && _d($query, 'has ' . ($match ? 'a' : 'no') . ' derived table');
89             5                                 29      return $match;
90                                                    }
91                                                    
92                                                    # Return a list of tables/databases and the name they're aliased to.
93                                                    sub get_aliases {
94            39                   39           185      my ( $self, $query ) = @_;
95    ***     39     50                         149      return unless $query;
96            39                                 89      my $aliases;
97                                                    
98                                                       # These keywords may appear between UPDATE or SELECT and the table refs.
99                                                       # They need to be removed so that they are not mistaken for tables.
100           39                                268      $query =~ s/ (?:LOW_PRIORITY|IGNORE|STRAIGHT_JOIN)//ig;
101                                                   
102                                                      # These keywords may appear before JOIN. They need to be removed so
103                                                      # that they are not mistaken for implicit aliases of the preceding table.
104           39                                202      $query =~ s/ (?:INNER|OUTER|CROSS|LEFT|RIGHT|NATURAL)//ig;
105                                                   
106                                                      # Get the table references clause and the keyword that starts the clause.
107                                                      # See the comments below for why we need the starting keyword.
108           39                                572      my ($tbl_refs, $from) = $query =~ m{
109                                                         (
110                                                            (FROM|INTO|UPDATE)\b\s*   # Keyword before table refs
111                                                            .+?                       # Table refs
112                                                         )
113                                                         (?:\s+|\z)                   # If the query does not end with the table
114                                                                                      # refs then there must be at least 1 space
115                                                                                      # between the last tbl ref and the next
116                                                                                      # keyword
117                                                         (?:WHERE|ORDER|LIMIT|HAVING|SET|VALUES|\z) # Keyword after table refs
118                                                      }ix;
119                                                   
120                                                      # This shouldn't happen, often at least.
121   ***     39     50     33                  347      die "Failed to parse table references from $query"
122                                                         unless $tbl_refs && $from;
123                                                   
124           39                                 82      MKDEBUG && _d('tbl refs:', $tbl_refs);
125                                                   
126                                                      # These keywords precede a table ref. They signal the start of a table
127                                                      # ref, but to know where the table ref ends we need the after tbl ref
128                                                      # keywords below.
129           39                                492      my $before_tbl = qr/(?:,|JOIN|\s|$from)+/i;
130                                                   
131                                                      # These keywords signal the end of a table ref and either 1) the start
132                                                      # of another table ref, or 2) the start of an ON|USING part of a JOIN
133                                                      # clause (which we want to skip over), or 3) the end of the string (\z).
134                                                      # We need these after tbl ref keywords so that they are not mistaken
135                                                      # for implicit aliases of the preceding table.
136           39                                145      my $after_tbl  = qr/(?:,|JOIN|ON|USING|\z)/i;
137                                                   
138                                                      # This is required for cases like:
139                                                      #    FROM t1 JOIN t2 ON t1.col1=t2.col2 JOIN t3 ON t2.col3 = t3.col4
140                                                      # Because spaces may precede a tbl and a tbl may end with \z, then
141                                                      # t3.col4 will match as a table. However, t2.col3=t3.col4 will not match.
142           39                                149      $tbl_refs =~ s/ = /=/g;
143                                                   
144           39                                590      while (
145                                                         $tbl_refs =~ m{
146                                                            $before_tbl\b\s*
147                                                               ( ($tbl_ident) (?:\s+ (?:AS\s+)? (\w+))? )
148                                                            \s*$after_tbl
149                                                         }xgio )
150                                                      {
151           65                                370         my ( $tbl_ref, $db_tbl, $alias ) = ($1, $2, $3);
152           65                                145         MKDEBUG && _d('Match table:', $tbl_ref);
153                                                   
154                                                         # Handle subqueries.
155           65    100                         260         if ( $tbl_ref =~ m/^AS\s+\w+/i ) {
156                                                            # According the the manual
157                                                            # http://dev.mysql.com/doc/refman/5.0/en/unnamed-views.html:
158                                                            # "The [AS] name  clause is mandatory, because every table in a
159                                                            # FROM clause must have a name."
160                                                            # So if the tbl ref begins with 'AS', then we probably have a
161                                                            # subquery.
162            1                                  3            MKDEBUG && _d('Subquery', $tbl_ref);
163            1                                  4            $aliases->{$alias} = undef;
164            1                                  8            next;
165                                                         }
166                                                   
167           64                                350         my ( $db, $tbl ) = $db_tbl =~ m/^(?:(.*?)\.)?(.*)/;
168   ***     64            66                  423         $aliases->{$alias || $tbl} = $tbl;
169           64    100                         632         $aliases->{DATABASE}->{$tbl} = $db if $db;
170                                                      }
171           39                                419      return $aliases;
172                                                   }
173                                                   
174                                                   sub _d {
175   ***      0                    0                    my ($package, undef, $line) = caller 0;
176   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
177   ***      0                                              map { defined $_ ? $_ : 'undef' }
178                                                           @_;
179   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
180                                                   }
181                                                   
182                                                   1;
183                                                   
184                                                   # ###########################################################################
185                                                   # End QueryParser package
186                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
59    ***     50      0     44   unless $query
95    ***     50      0     39   unless $query
121   ***     50      0     39   unless $tbl_refs and $from
155          100      1     64   if ($tbl_ref =~ /^AS\s+\w+/i)
169          100      7     57   if $db
176   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
121   ***     33      0      0     39   $tbl_refs and $from

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
168   ***     66     37     27      0   $alias or $tbl


Covered Subroutines
-------------------

Subroutine        Count Location                                          
----------------- ----- --------------------------------------------------
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:22 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:23 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:24 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:26 
get_aliases          39 /home/daniel/dev/maatkit/common/QueryParser.pm:94 
get_tables           44 /home/daniel/dev/maatkit/common/QueryParser.pm:58 
has_derived_table     5 /home/daniel/dev/maatkit/common/QueryParser.pm:85 
new                   1 /home/daniel/dev/maatkit/common/QueryParser.pm:52 

Uncovered Subroutines
---------------------

Subroutine        Count Location                                          
----------------- ----- --------------------------------------------------
_d                    0 /home/daniel/dev/maatkit/common/QueryParser.pm:175


