---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/QueryParser.pm   92.2   63.6   50.0   90.9    n/a  100.0   85.3
Total                          92.2   63.6   50.0   90.9    n/a  100.0   85.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:10 2009
Finish:       Fri Jul 31 18:53:10 2009

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
18                                                    # QueryParser package $Revision: 4280 $
19                                                    # ###########################################################################
20                                                    package QueryParser;
21                                                    
22             1                    1             8   use strict;
               1                                  3   
               1                                  6   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  4   
25                                                    
26             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  8   
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
51                                                    # http://dev.mysql.com/doc/refman/5.1/en/sql-syntax-data-definition.html
52                                                    # We treat TRUNCATE as a dds but really it's a data manipulation statement.
53                                                    our $data_def_stmts = qr/(?:CREATE|ALTER|TRUNCATE|DROP|RENAME)/i;
54                                                    
55                                                    sub new {
56             1                    1             8      my ( $class ) = @_;
57             1                                  9      bless {}, $class;
58                                                    }
59                                                    
60                                                    # Returns a list of table names found in the query text.
61                                                    sub get_tables {
62            52                   52           247      my ( $self, $query ) = @_;
63    ***     52     50                         187      return unless $query;
64            52                                112      MKDEBUG && _d('Getting tables for', $query);
65                                                    
66                                                       # Handle CREATE, ALTER, TRUNCATE and DROP TABLE.
67            52                                398      my ( $ddl_stmt ) = $query =~ /^\s*($data_def_stmts)\b/i;
68            52    100                         188      if ( $ddl_stmt ) {
69             8                                 17         MKDEBUG && _d('Special table type:', $ddl_stmt);
70             8                                 28         $query =~ s/IF NOT EXISTS//i;
71             8    100                          79         if ( $query =~ m/$ddl_stmt DATABASE\b/i ) {
72                                                             # Handles CREATE DATABASE, not to be confused with CREATE TABLE.
73             1                                  3            MKDEBUG && _d('Query alters a database, not a table');
74             1                                  6            return ();
75                                                          }
76             7                                 86         my ($tbl) = $query =~ m/TABLE\s+($tbl_ident)(\s+.*)?/i;
77             7                                 18         MKDEBUG && _d('Matches table:', $tbl);
78             7                                 46         return ($tbl);
79                                                       }
80                                                    
81                                                       # These keywords may appear between UPDATE or SELECT and the table refs.
82                                                       # They need to be removed so that they are not mistaken for tables.
83            44                                261      $query =~ s/ (?:LOW_PRIORITY|IGNORE|STRAIGHT_JOIN)//ig;
84                                                    
85            44                                129      $query =~ s/\\["']//g;                # quoted strings
86            44                                131      $query =~ s/".*?"/?/sg;               # quoted strings
87            44                                127      $query =~ s/'.*?'/?/sg;               # quoted strings
88                                                    
89            44                                 99      my @tables;
90            44                                779      foreach my $tbls ( $query =~ m/$tbl_regex/gio ) {
91            60                                127         MKDEBUG && _d('Match tables:', $tbls);
92            60                                801         foreach my $tbl ( split(',', $tbls) ) {
93                                                             # Remove implicit or explicit (AS) alias.
94            74                                659            $tbl =~ s/\s*($tbl_ident)(\s+.*)?/$1/gio;
95            74                                383            push @tables, $tbl;
96                                                          }
97                                                       }
98            44                                332      return @tables;
99                                                    }
100                                                   
101                                                   # Returns true if it sees what looks like a "derived table", e.g. a subquery in
102                                                   # the FROM clause.
103                                                   sub has_derived_table {
104            5                    5            21      my ( $self, $query ) = @_;
105                                                      # See the $tbl_regex regex above.
106            5                                 44      my $match = $query =~ m/$has_derived/;
107            5                                 12      MKDEBUG && _d($query, 'has ' . ($match ? 'a' : 'no') . ' derived table');
108            5                                 27      return $match;
109                                                   }
110                                                   
111                                                   # Return a list of tables/databases and the name they're aliased to.
112                                                   sub get_aliases {
113           39                   39           161      my ( $self, $query ) = @_;
114   ***     39     50                         143      return unless $query;
115           39                                 83      my $aliases;
116                                                   
117                                                      # These keywords may appear between UPDATE or SELECT and the table refs.
118                                                      # They need to be removed so that they are not mistaken for tables.
119           39                                231      $query =~ s/ (?:LOW_PRIORITY|IGNORE|STRAIGHT_JOIN)//ig;
120                                                   
121                                                      # These keywords may appear before JOIN. They need to be removed so
122                                                      # that they are not mistaken for implicit aliases of the preceding table.
123           39                                188      $query =~ s/ (?:INNER|OUTER|CROSS|LEFT|RIGHT|NATURAL)//ig;
124                                                   
125                                                      # Get the table references clause and the keyword that starts the clause.
126                                                      # See the comments below for why we need the starting keyword.
127           39                                528      my ($tbl_refs, $from) = $query =~ m{
128                                                         (
129                                                            (FROM|INTO|UPDATE)\b\s*   # Keyword before table refs
130                                                            .+?                       # Table refs
131                                                         )
132                                                         (?:\s+|\z)                   # If the query does not end with the table
133                                                                                      # refs then there must be at least 1 space
134                                                                                      # between the last tbl ref and the next
135                                                                                      # keyword
136                                                         (?:WHERE|ORDER|LIMIT|HAVING|SET|VALUES|\z) # Keyword after table refs
137                                                      }ix;
138                                                   
139                                                      # This shouldn't happen, often at least.
140   ***     39     50     33                  335      die "Failed to parse table references from $query"
141                                                         unless $tbl_refs && $from;
142                                                   
143           39                                 88      MKDEBUG && _d('tbl refs:', $tbl_refs);
144                                                   
145                                                      # These keywords precede a table ref. They signal the start of a table
146                                                      # ref, but to know where the table ref ends we need the after tbl ref
147                                                      # keywords below.
148           39                                406      my $before_tbl = qr/(?:,|JOIN|\s|$from)+/i;
149                                                   
150                                                      # These keywords signal the end of a table ref and either 1) the start
151                                                      # of another table ref, or 2) the start of an ON|USING part of a JOIN
152                                                      # clause (which we want to skip over), or 3) the end of the string (\z).
153                                                      # We need these after tbl ref keywords so that they are not mistaken
154                                                      # for implicit aliases of the preceding table.
155           39                                131      my $after_tbl  = qr/(?:,|JOIN|ON|USING|\z)/i;
156                                                   
157                                                      # This is required for cases like:
158                                                      #    FROM t1 JOIN t2 ON t1.col1=t2.col2 JOIN t3 ON t2.col3 = t3.col4
159                                                      # Because spaces may precede a tbl and a tbl may end with \z, then
160                                                      # t3.col4 will match as a table. However, t2.col3=t3.col4 will not match.
161           39                                148      $tbl_refs =~ s/ = /=/g;
162                                                   
163           39                                540      while (
164                                                         $tbl_refs =~ m{
165                                                            $before_tbl\b\s*
166                                                               ( ($tbl_ident) (?:\s+ (?:AS\s+)? (\w+))? )
167                                                            \s*$after_tbl
168                                                         }xgio )
169                                                      {
170           65                                334         my ( $tbl_ref, $db_tbl, $alias ) = ($1, $2, $3);
171           65                                138         MKDEBUG && _d('Match table:', $tbl_ref);
172                                                   
173                                                         # Handle subqueries.
174           65    100                         251         if ( $tbl_ref =~ m/^AS\s+\w+/i ) {
175                                                            # According the the manual
176                                                            # http://dev.mysql.com/doc/refman/5.0/en/unnamed-views.html:
177                                                            # "The [AS] name  clause is mandatory, because every table in a
178                                                            # FROM clause must have a name."
179                                                            # So if the tbl ref begins with 'AS', then we probably have a
180                                                            # subquery.
181            1                                  3            MKDEBUG && _d('Subquery', $tbl_ref);
182            1                                  4            $aliases->{$alias} = undef;
183            1                                  6            next;
184                                                         }
185                                                   
186           64                                329         my ( $db, $tbl ) = $db_tbl =~ m/^(?:(.*?)\.)?(.*)/;
187   ***     64            66                  420         $aliases->{$alias || $tbl} = $tbl;
188           64    100                         653         $aliases->{DATABASE}->{$tbl} = $db if $db;
189                                                      }
190           39                                343      return $aliases;
191                                                   }
192                                                   
193                                                   # Splits a compound statement and returns an array with each sub-statement.
194                                                   # Example:
195                                                   #    INSERT INTO ... SELECT ...
196                                                   # is split into two statements: "INSERT INTO ..." and "SELECT ...".
197                                                   sub split {
198            8                    8            51      my ( $self, $query ) = @_;
199   ***      8     50                          30      return unless $query;
200            8                                 26      $query = remove_comments($query);
201            8                                 30      $query =~ s/^\s+//;      # Remove leading spaces.
202            8                                 44      $query =~ s/\s{2,}/ /g;  # Remove extra spaces.
203            8                                 16      MKDEBUG && _d('Splitting', $query);
204                                                   
205            8                                 40      my $verbs = qr{SELECT|INSERT|UPDATE|DELETE|REPLACE|UNION|CREATE}i;
206                                                   
207                                                      # This splits a statement on the above verbs which means that the verb
208                                                      # gets chopped out.  Capturing the verb (e.g. ($verb)) will retain it,
209                                                      # but then it's disjointed from its statement.  Example: for this query,
210                                                      #   INSERT INTO ... SELECT ...
211                                                      # split returns ('INSERT', 'INTO ...', 'SELECT', '...').  Therefore,
212                                                      # we must re-attach each verb to its statement; we do this later...
213            8                                146      my @split_statements = grep { $_ } split(m/\b($verbs\b(?!(?:\s*\()))/io, $query);
              32                                106   
214                                                   
215            8                                 24      my @statements;
216   ***      8     50                          30      if ( @split_statements == 1 ) {
217                                                         # This happens if the query has no verbs, so it's probably a single
218                                                         # statement.
219   ***      0                                  0         push @statements, $query;
220                                                      }
221                                                      else {
222                                                         # ...Re-attach verbs to their statements.
223                                                         for ( my $i = 0; $i <= $#split_statements; $i += 2 ) {
224           12                                 90            push @statements, $split_statements[$i].$split_statements[$i+1];
225            8                                 22         }
226                                                      }
227                                                   
228                                                      # Wrap stmts in <> to make it more clear where each one begins/ends.
229            8                                 17      MKDEBUG && _d('statements:', map { $_ ? "<$_>" : 'none' } @statements);
230            8                                 80      return @statements;
231                                                   }
232                                                   
233                                                   sub remove_comments {
234            8                    8            30      my ( $query ) = @_;
235   ***      8     50                          26      return unless $query;
236            8                                 29      $query =~ s!/\*.*?\*/! !g;
237            8                                 28      return $query;
238                                                   }
239                                                   
240                                                   sub _d {
241   ***      0                    0                    my ($package, undef, $line) = caller 0;
242   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
243   ***      0                                              map { defined $_ ? $_ : 'undef' }
244                                                           @_;
245   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
246                                                   }
247                                                   
248                                                   1;
249                                                   
250                                                   # ###########################################################################
251                                                   # End QueryParser package
252                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
63    ***     50      0     52   unless $query
68           100      8     44   if ($ddl_stmt)
71           100      1      7   if ($query =~ /$ddl_stmt DATABASE\b/i)
114   ***     50      0     39   unless $query
140   ***     50      0     39   unless $tbl_refs and $from
174          100      1     64   if ($tbl_ref =~ /^AS\s+\w+/i)
188          100      7     57   if $db
199   ***     50      0      8   unless $query
216   ***     50      0      8   if (@split_statements == 1) { }
235   ***     50      0      8   unless $query
242   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
140   ***     33      0      0     39   $tbl_refs and $from

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
187   ***     66     37     27      0   $alias or $tbl


Covered Subroutines
-------------------

Subroutine        Count Location                                          
----------------- ----- --------------------------------------------------
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:22 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:23 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:24 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:26 
get_aliases          39 /home/daniel/dev/maatkit/common/QueryParser.pm:113
get_tables           52 /home/daniel/dev/maatkit/common/QueryParser.pm:62 
has_derived_table     5 /home/daniel/dev/maatkit/common/QueryParser.pm:104
new                   1 /home/daniel/dev/maatkit/common/QueryParser.pm:56 
remove_comments       8 /home/daniel/dev/maatkit/common/QueryParser.pm:234
split                 8 /home/daniel/dev/maatkit/common/QueryParser.pm:198

Uncovered Subroutines
---------------------

Subroutine        Count Location                                          
----------------- ----- --------------------------------------------------
_d                    0 /home/daniel/dev/maatkit/common/QueryParser.pm:241


