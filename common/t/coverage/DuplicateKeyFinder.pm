---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mon/DuplicateKeyFinder.pm   96.3   76.2   90.5   90.9    n/a  100.0   90.9
Total                          96.3   76.2   90.5   90.9    n/a  100.0   90.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          DuplicateKeyFinder.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:42:44 2009
Finish:       Wed Jun 10 17:42:45 2009

/home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009 Percona Inc.
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
18                                                    # DuplicateKeyFinder package $Revision: 3288 $
19                                                    # ###########################################################################
20                                                    package DuplicateKeyFinder;
21                                                    
22             1                    1           122   use strict;
               1                                  3   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
25                                                    
26             1                    1             6   use List::Util qw(min);
               1                                  2   
               1                                 11   
27                                                    
28             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 11   
29                                                    
30                                                    sub new {
31             1                    1            20      my ( $class ) = @_;
32             1                                  7      my $self = {
33                                                          # These are used in case you want to look back and see more
34                                                          # details about what happened inside get_duplicate_keys().
35                                                          keys        => undef,  # copy of last keys that we worked on
36                                                          unique_cols => undef,  # unique cols for those last keys (hashref)
37                                                          unique_sets => undef,  # unique sets for those last keys (arrayref) 
38                                                       };
39             1                                 15      return bless $self, $class;
40                                                    }
41                                                    
42                                                    # %args should contain:
43                                                    #
44                                                    #  *  keys           (req) A hashref from TableParser::get_keys().
45                                                    #  *  tbl_info       (req) { db, tbl, engine, ddl } hashref.
46                                                    #  *  callback       (req) An anonymous subroutine, called for each dupe found.
47                                                    #  *  ignore_order   Order never matters for any type of index (generally order
48                                                    #                    matters except for FULLTEXT).
49                                                    #  *  ignore_type    Compare indexes of different types as if they're the same.
50                                                    #  *  clustered      Perform duplication checks against the clustered  key.
51                                                    #
52                                                    # Returns an arrayref of duplicate key hashrefs.  Each contains
53                                                    #
54                                                    #  *  key               The name of the index that's a duplicate.
55                                                    #  *  cols              The columns in that key (arrayref).
56                                                    #  *  duplicate_of      The name of the index it duplicates.
57                                                    #  *  duplicate_of_cols The columns of the index it duplicates.
58                                                    #  *  reason            A human-readable description of why this is a duplicate.
59                                                    sub get_duplicate_keys {
60            24                   24           138      my ( $self, %args ) = @_;
61    ***     24     50                         118      die "I need a keys argument" unless $args{keys};
62            24                                 63      my %all_keys  = %{$args{keys}}; # copy keys because we change stuff
              24                                142   
63            24                                103      $self->{keys} = \%all_keys;
64            24                                152      my $primary_key;
65            24                                 54      my @unique_keys;
66            24                                 59      my @normal_keys;
67            24                                 52      my @fulltext_keys;
68            24                                 99      my %pass_args = %args;
69            24                                 80      delete $pass_args{keys};
70                                                    
71                                                       ALL_KEYS:
72            24                                 91      foreach my $key ( values %all_keys ) {
73            59                                232         $key->{real_cols} = $key->{colnames}; 
74            59                                220         $key->{len_cols}  = length $key->{colnames};
75                                                    
76                                                          # The PRIMARY KEY is treated specially. It is effectively never a
77                                                          # duplicate, so it is never removed. It is compared to all other
78                                                          # keys, and in any case of duplication, the PRIMARY is always kept
79                                                          # and the other key removed.
80            59    100                         250         if ( $key->{name} eq 'PRIMARY' ) {
81            10                                 25            $primary_key = $key;
82            10                                 34            next ALL_KEYS;
83                                                          }
84                                                    
85            49    100                         200         my $is_fulltext = $key->{type} eq 'FULLTEXT' ? 1 : 0;
86                                                    
87                                                          # Key column order matters for all keys except FULLTEXT, so we only
88                                                          # sort if --ignoreorder or FULLTEXT. 
89            49    100    100                  362         if ( $args{ignore_order} || $is_fulltext  ) {
90            11                                 80            my $ordered_cols = join(',', sort(split(/,/, $key->{colnames})));
91            11                                 26            MKDEBUG && _d('Reordered', $key->{name}, 'cols from',
92                                                                $key->{colnames}, 'to', $ordered_cols); 
93            11                                 36            $key->{colnames} = $ordered_cols;
94                                                          }
95                                                    
96                                                          # By default --allstruct is false, so keys of different structs
97                                                          # (BTREE, HASH, FULLTEXT, SPATIAL) are kept and compared separately.
98                                                          # UNIQUE keys are also separated just to make comparisons easier.
99            49    100                         227         my $push_to = $key->{is_unique} ? \@unique_keys : \@normal_keys;
100           49    100                         199         if ( !$args{ignore_type} ) {
101           47    100                         164            $push_to = \@fulltext_keys if $is_fulltext;
102                                                            # TODO:
103                                                            # $push_to = \@hash_keys     if $is_hash;
104                                                            # $push_to = \@spatial_keys  if $is_spatial;
105                                                         }
106           49                                188         push @$push_to, $key; 
107                                                      }
108                                                   
109           24                                 63      my @dupes;
110                                                   
111           24                                 51      MKDEBUG && _d('Start unconstraining redundantly unique keys');
112                                                      # See http://code.google.com/p/maatkit/wiki/DeterminingDuplicateKeys
113                                                      # First, determine which unique keys define unique columns and which
114                                                      # define unique sets.
115           24                                 56      my %unique_cols;
116           24                                 54      my @unique_sets;
117           24                                 59      my %unconstrain;   # unique keys to unconstrain
118                                                      UNIQUE_KEY:
119           24                                 74      foreach my $unique_key ( $primary_key, @unique_keys ) {
120           36    100                         138         next unless $unique_key; # primary key may be undefined
121           22                                 65         my $cols = $unique_key->{cols};
122           22    100                          77         if ( @$cols == 1 ) {
123           11                                 24            MKDEBUG && _d($unique_key->{name},'defines unique column:',$cols->[0]);
124                                                            # Save only the first unique key for the unique col. If there
125                                                            # are others, then they are exact duplicates and will be removed
126                                                            # later when unique keys are compared to unique keys.
127   ***     11     50                          51            if ( !exists $unique_cols{$cols->[0]} ) {
128           11                                 42               $unique_cols{$cols->[0]}  = $unique_key;
129           11                                 53               $unique_key->{unique_col} = 1;
130                                                            }
131                                                         }
132                                                         else {
133           11                                 35            local $LIST_SEPARATOR = '-';
134           11                                 27            MKDEBUG && _d($unique_key->{name}, 'defines unique set:', @$cols);
135           11                                 62            push @unique_sets, { cols => $cols, key => $unique_key };
136                                                         }
137                                                      }
138                                                   
139                                                      # Second, find which unique sets can be unconstraind (i.e. those
140                                                      # which have which have at least one unique column).
141                                                      UNIQUE_SET:
142           24                                 85      foreach my $unique_set ( @unique_sets ) {
143           11                                 29         my $n_unique_cols = 0;
144           11                                 42         COL:
145           11                                 28         foreach my $col ( @{$unique_set->{cols}} ) {
146           24    100                         115            if ( exists $unique_cols{$col} ) {
147            7                                 15               MKDEBUG && _d('Unique set', $unique_set->{key}->{name},
148                                                                  'has unique col', $col);
149   ***      7     50                          28               last COL if ++$n_unique_cols > 1;
150            7                                 27               $unique_set->{constraining_key} = $unique_cols{$col};
151                                                            }
152                                                         }
153           11    100    100                   90         if ( $n_unique_cols && $unique_set->{key}->{name} ne 'PRIMARY' ) {
154                                                            # Unique set is redundantly constrained.
155            6                                 15            MKDEBUG && _d('Will unconstrain unique set',
156                                                               $unique_set->{key}->{name},
157                                                               'because it is redundantly constrained by key',
158                                                               $unique_set->{constraining_key}->{name},
159                                                               '(',$unique_set->{constraining_key}->{colnames},')');
160            6                                 39            $unconstrain{$unique_set->{key}->{name}}
161                                                               = $unique_set->{constraining_key};
162                                                         }
163                                                      }
164                                                   
165                                                      # And finally, unconstrain the redudantly unique sets found above by
166                                                      # removing them from the list of unique keys and adding them to the
167                                                      # list of normal keys.
168           24                                136      for my $i ( 0..$#unique_keys ) {
169           12    100                         518         if ( exists $unconstrain{$unique_keys[$i]->{name}} ) {
170            6                                 16            MKDEBUG && _d('Normalizing', $unique_keys[$i]->{name});
171            6                                 27            $unique_keys[$i]->{unconstrained} = 1;
172            6                                 29            $unique_keys[$i]->{constraining_key}
173                                                               = $unconstrain{$unique_keys[$i]->{name}};
174            6                                 35            push @normal_keys, $unique_keys[$i];
175            6                                 26            delete $unique_keys[$i];
176                                                         }
177                                                      }
178           24                                107      $self->{unique_cols} = \%unique_cols;
179           24                                106      $self->{unique_sets} = \@unique_sets;
180           24                                 97      MKDEBUG && _d('No more keys');
181                                                   
182                                                      # If you're tempted to check the primary key against uniques before
183                                                      # unconstraining redundantly unique keys: don't. In cases like
184                                                      #    PRIMARY KEY (a, b)
185                                                      #    UNIQUE KEY  (a)
186                                                      # the unique key will be wrongly removed. It is needed to keep
187                                                      # column a unique. The process of unconstraining redundantly unique
188                                                      # keys marks single column unique keys so that they are never removed
189                                                      # (the mark is adding unique_col=>1 to the unique key's hash).
190           24    100                          99      if ( $primary_key ) {
191           10                                 24         MKDEBUG && _d('Start comparing PRIMARY KEY to UNIQUE keys');
192           10                                 76         $self->remove_prefix_duplicates(
193                                                               keys           => [$primary_key],
194                                                               remove_keys    => \@unique_keys,
195                                                               duplicate_keys => \@dupes,
196                                                               %pass_args);
197                                                   
198           10                                 28         MKDEBUG && _d('Start comparing PRIMARY KEY to normal keys');
199           10                                 62         $self->remove_prefix_duplicates(
200                                                               keys           => [$primary_key],
201                                                               remove_keys    => \@normal_keys,
202                                                               duplicate_keys => \@dupes,
203                                                               %pass_args);
204                                                      }
205                                                   
206           24                                 57      MKDEBUG && _d('Start comparing UNIQUE keys to normal keys');
207           24                                156      $self->remove_prefix_duplicates(
208                                                            keys           => \@unique_keys,
209                                                            remove_keys    => \@normal_keys,
210                                                            duplicate_keys => \@dupes,
211                                                            %pass_args);
212                                                   
213           24                                 54      MKDEBUG && _d('Start comparing normal keys');
214           24                                133      $self->remove_prefix_duplicates(
215                                                            keys           => \@normal_keys,
216                                                            duplicate_keys => \@dupes,
217                                                            %pass_args);
218                                                   
219                                                      # If --allstruct, then these special struct keys (FULLTEXT, HASH, etc.)
220                                                      # will have already been put in and handled by @normal_keys.
221           24                                 58      MKDEBUG && _d('Start comparing FULLTEXT keys');
222           24                                117      $self->remove_prefix_duplicates(
223                                                            keys             => \@fulltext_keys,
224                                                            exact_duplicates => 1,
225                                                            %pass_args);
226                                                   
227                                                      # TODO: other structs
228                                                   
229                                                      # For engines with a clustered index, if a key ends with a prefix
230                                                      # of the primary key, it's a duplicate. Example:
231                                                      #    PRIMARY KEY (a)
232                                                      #    KEY foo (b, a)
233                                                      # Key foo is redundant to PRIMARY.
234           24    100    100                  221      if ( $primary_key
                           100                        
235                                                           && $args{clustered}
236                                                           && $args{tbl_info}->{engine} =~ m/^(?:InnoDB|solidDB)$/ ) {
237                                                   
238            2                                  5         MKDEBUG && _d('Start removing UNIQUE dupes of clustered key');
239            2                                 13         $self->remove_clustered_duplicates(
240                                                               primary_key => $primary_key,
241                                                               keys        => \@unique_keys,
242                                                               %pass_args);
243                                                   
244            2                                  6         MKDEBUG && _d('Start removing ordinary dupes of clustered key');
245            2                                 10         $self->remove_clustered_duplicates(
246                                                               primary_key => $primary_key,
247                                                               keys        => \@normal_keys,
248                                                               %pass_args);
249                                                      }
250                                                   
251           24                                149      return \@dupes;
252                                                   }
253                                                   
254                                                   sub get_duplicate_fks {
255            3                    3            18      my ( $self, %args ) = @_;
256   ***      3     50                          16      die "I need a keys argument" unless $args{keys};
257            3                                  9      my @fks = values %{$args{keys}};
               3                                 15   
258            3                                  9      my @dupes;
259            3                                 26      foreach my $i ( 0..$#fks - 1 ) {
260   ***      3     50                          13         next unless $fks[$i];
261            3                                 16         foreach my $j ( $i+1..$#fks ) {
262   ***      3     50                          11            next unless $fks[$j];
263                                                   
264                                                            # A foreign key is a duplicate no matter what order the
265                                                            # columns are in, so re-order them alphabetically so they
266                                                            # can be compared.
267            3                                  9            my $i_cols  = join(',', sort @{$fks[$i]->{cols}} );
               3                                 25   
268            3                                 10            my $j_cols  = join(',', sort @{$fks[$j]->{cols}} );
               3                                 16   
269            3                                 10            my $i_pcols = join(',', sort @{$fks[$i]->{parent_cols}} );
               3                                 15   
270            3                                 10            my $j_pcols = join(',', sort @{$fks[$j]->{parent_cols}} );
               3                                 16   
271                                                   
272   ***      3    100     66                   58            if ( $fks[$i]->{parent_tbl} eq $fks[$j]->{parent_tbl}
      ***                   66                        
273                                                                 && $i_cols  eq $j_cols
274                                                                 && $i_pcols eq $j_pcols ) {
275            2                                 54               my $dupe = {
276                                                                  key               => $fks[$j]->{name},
277                                                                  cols              => $fks[$j]->{colnames},
278                                                                  duplicate_of      => $fks[$i]->{name},
279                                                                  duplicate_of_cols => $fks[$i]->{colnames},
280                                                                  reason       =>
281                                                                       "FOREIGN KEY $fks[$j]->{name} ($fks[$j]->{colnames}) "
282                                                                     . "REFERENCES $fks[$j]->{parent_tbl} "
283                                                                     . "($fks[$j]->{parent_colnames}) "
284                                                                     . 'is a duplicate of '
285                                                                     . "FOREIGN KEY $fks[$i]->{name} ($fks[$i]->{colnames}) "
286                                                                     . "REFERENCES $fks[$i]->{parent_tbl} "
287                                                                     ."($fks[$i]->{parent_colnames})"
288                                                               };
289            2                                  7               push @dupes, $dupe;
290            2                                  7               delete $fks[$j];
291   ***      2     50                          17               $args{callback}->($dupe, %args) if $args{callback};
292                                                            }
293                                                         }
294                                                      }
295            3                                 33      return \@dupes;
296                                                   }
297                                                   
298                                                   # TODO: Document this subroutine.
299                                                   # %args should contain the same things passed to get_duplicate_keys(), plus:
300                                                   #  *  remove_keys       ????
301                                                   #  *  duplicate_keys    ????
302                                                   #  *  exact_duplicates  ????
303                                                   sub remove_prefix_duplicates {
304           92                   92           511      my ( $self, %args ) = @_;
305           92                                268      my $keys;
306           92                                194      my $remove_keys;
307           92                                202      my @dupes;
308           92                                203      my $keep_index;
309           92                                199      my $remove_index;
310           92                                194      my $last_key;
311           92                                196      my $remove_key_offset;
312                                                   
313           92                                267      $keys  = $args{keys};
314           18                                 66      @$keys = sort { $a->{colnames} cmp $b->{colnames} }
              63                                254   
315           92                                366               grep { defined $_; }
316                                                               @$keys;
317                                                   
318           92    100                         354      if ( $args{remove_keys} ) {
319           44                                128         $remove_keys  = $args{remove_keys};
320           31                                123         @$remove_keys = sort { $a->{colnames} cmp $b->{colnames} }
              48                                162   
321           44                                163                         grep { defined $_; }
322                                                                         @$remove_keys;
323                                                   
324           44                                136         $remove_index      = 1;
325           44                                114         $keep_index        = 0;
326           44                                127         $last_key          = scalar(@$keys) - 1;
327           44                                123         $remove_key_offset = 0;
328                                                      }
329                                                      else {
330           48                                120         $remove_keys       = $keys;
331           48                                118         $remove_index      = 0;
332           48                                119         $keep_index        = 1;
333           48                                844         $last_key          = scalar(@$keys) - 2;
334           48                                127         $remove_key_offset = 1;
335                                                      }
336           92                                277      my $last_remove_key = scalar(@$remove_keys) - 1;
337                                                   
338                                                      I_KEY:
339           92                                329      foreach my $i ( 0..$last_key ) {
340   ***     41     50                         168         next I_KEY unless defined $keys->[$i];
341                                                   
342                                                         J_KEY:
343           41                                166         foreach my $j ( $i+$remove_key_offset..$last_remove_key ) {
344   ***     37     50                         150            next J_KEY unless defined $remove_keys->[$j];
345                                                   
346           37                                116            my $keep = ($i, $j)[$keep_index];
347           37                                116            my $rm   = ($i, $j)[$remove_index];
348                                                   
349           37                                137            my $keep_name     = $keys->[$keep]->{name};
350           37                                132            my $keep_cols     = $keys->[$keep]->{colnames};
351           37                                121            my $keep_len_cols = $keys->[$keep]->{len_cols};
352           37                                134            my $rm_name       = $remove_keys->[$rm]->{name};
353           37                                121            my $rm_cols       = $remove_keys->[$rm]->{colnames};
354           37                                118            my $rm_len_cols   = $remove_keys->[$rm]->{len_cols};
355                                                   
356           37                                 79            MKDEBUG && _d('Comparing [keep]', $keep_name, '(',$keep_cols,')',
357                                                               'to [remove if dupe]', $rm_name, '(',$rm_cols,')');
358                                                   
359                                                            # Compare the whole remove key to the keep key, not just
360                                                            # the their common minimum length prefix. This is correct
361                                                            # because it enables magick that I should document. :-)
362           37    100                         174            if (    substr($rm_cols, 0, $rm_len_cols)
363                                                                 eq substr($keep_cols, 0, $rm_len_cols) ) {
364                                                   
365                                                               # FULLTEXT keys, for example, are only duplicates if they
366                                                               # are exact duplicates.
367           18    100    100                  105               if ( $args{exact_duplicates} && ($rm_len_cols < $keep_len_cols) ) {
368            1                                  2                  MKDEBUG && _d($rm_name, 'not exact duplicate of', $keep_name);
369            1                                  4                  next J_KEY;
370                                                               }
371                                                   
372                                                               # Do not remove the unique key that is constraining a single
373                                                               # column to uniqueness. This prevents UNIQUE KEY (a) from being
374                                                               # removed by PRIMARY KEY (a, b).
375           17    100                          74               if ( exists $remove_keys->[$rm]->{unique_col} ) {
376            1                                  5                  MKDEBUG && _d('Cannot remove', $rm_name,
377                                                                     'because is constrains col',
378                                                                     $remove_keys->[$rm]->{cols}->[0]);
379            1                                  5                  next J_KEY;
380                                                               }
381                                                   
382           16                                 35               MKDEBUG && _d('Remove', $remove_keys->[$rm]->{name});
383           16                                 36               my $reason;
384           16    100                          73               if ( $remove_keys->[$rm]->{unconstrained} ) {
385            3                                 22                  $reason .= "Uniqueness of $rm_name ignored because "
386                                                                           . $remove_keys->[$rm]->{constraining_key}->{name}
387                                                                           . " is a stronger constraint\n"; 
388                                                               }
389           16    100                          78               $reason .= $rm_name
390                                                                        . ($rm_len_cols < $keep_len_cols ? ' is a left-prefix of '
391                                                                                                         : ' is a duplicate of ')
392                                                                        . $keep_name;
393           16                                143               my $dupe = {
394                                                                  key               => $rm_name,
395                                                                  cols              => $remove_keys->[$rm]->{real_cols},
396                                                                  duplicate_of      => $keep_name,
397                                                                  duplicate_of_cols => $keys->[$keep]->{real_cols},
398                                                                  reason            => $reason,
399                                                               };
400           16                                 48               push @dupes, $dupe;
401           16                                 49               delete $remove_keys->[$rm];
402                                                   
403   ***     16     50                         120               $args{callback}->($dupe, %args) if $args{callback};
404                                                   
405           16    100                         155               next I_KEY if $remove_index == 0;
406   ***      7     50                          41               next J_KEY if $remove_index == 1;
407                                                            }
408                                                            else {
409           19                                 41               MKDEBUG && _d($rm_name, 'not left-prefix of', $keep_name);
410           19                                 75               next I_KEY;
411                                                            }
412                                                         }
413                                                      }
414           92                                200      MKDEBUG && _d('No more keys');
415                                                   
416           92                                303      @$keys        = grep { defined $_; } @$keys;
              62                                238   
417           92    100                         404      @$remove_keys = grep { defined $_; } @$remove_keys if $args{remove_keys};
              45                                151   
418   ***     92     50                         343      push @{$args{duplicate_keys}}, @dupes if $args{duplice_keys};
      ***      0                                  0   
419                                                   
420           92                                343      return;
421                                                   }
422                                                   
423                                                   sub remove_clustered_duplicates {
424            4                    4            23      my ( $self, %args ) = @_;
425   ***      4     50                          20      die "I need a primary_key argument" unless $args{primary_key};
426   ***      4     50                          15      die "I need a keys argument"        unless $args{keys};
427            4                                 15      my $pkcols = $args{primary_key}->{colnames};
428            4                                 16      my $keys   = $args{keys};
429            4                                 10      my @dupes;
430                                                      # TODO: this can be done more easily now that each key has
431                                                      # its cols in an array, so we just have to look at cols[-1].
432                                                      KEY:
433            4                                 18      for my $i ( 0 .. @$keys - 1 ) {
434            2                                  9         my $suffix = $keys->[$i]->{colnames};
435                                                         SUFFIX:
436            2                                 15         while ( $suffix =~ s/`[^`]+`,// ) {
437            1                                 12            my $len = min(length($pkcols), length($suffix));
438   ***      1     50                           6            if ( substr($suffix, 0, $len) eq substr($pkcols, 0, $len) ) {
439            1                                 14               my $dupe = {
440                                                                  key               => $keys->[$i]->{name},
441                                                                  cols              => $keys->[$i]->{real_cols},
442                                                                  duplicate_of      => $args{primary_key}->{name},
443                                                                  duplicate_of_cols => $args{primary_key}->{real_cols},
444                                                                  reason            => "Key $keys->[$i]->{name} "
445                                                                                       . "ends with a prefix of the clustered "
446                                                                                       . "index",
447                                                               };
448            1                                  3               push @dupes, $dupe;
449            1                                  4               delete $keys->[$i];
450   ***      1     50                           9               $args{callback}->($dupe, %args) if $args{callback};
451            1                                 10               last SUFFIX;
452                                                            }
453                                                         }
454                                                      }
455            4                                  9      MKDEBUG && _d('No more keys');
456                                                   
457            4                                 14      @$keys = grep { defined $_; } @$keys;
               1                                  5   
458   ***      4     50                          21      push @{$args{duplicate_keys}}, @dupes if $args{duplice_keys};
      ***      0                                  0   
459                                                   
460            4                                 15      return;
461                                                   }
462                                                   
463                                                   sub _d {
464   ***      0                    0                    my ($package, undef, $line) = caller 0;
465   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
466   ***      0                                              map { defined $_ ? $_ : 'undef' }
467                                                           @_;
468   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
469                                                   }
470                                                   
471                                                   1;
472                                                   # ###########################################################################
473                                                   # End DuplicateKeyFinder package
474                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
61    ***     50      0     24   unless $args{'keys'}
80           100     10     49   if ($$key{'name'} eq 'PRIMARY')
85           100      9     40   $$key{'type'} eq 'FULLTEXT' ? :
89           100     11     38   if ($args{'ignore_order'} or $is_fulltext)
99           100     12     37   $$key{'is_unique'} ? :
100          100     47      2   if (not $args{'ignore_type'})
101          100      8     39   if $is_fulltext
120          100     14     22   unless $unique_key
122          100     11     11   if (@$cols == 1) { }
127   ***     50     11      0   if (not exists $unique_cols{$$cols[0]})
146          100      7     17   if (exists $unique_cols{$col})
149   ***     50      0      7   if ++$n_unique_cols > 1
153          100      6      5   if ($n_unique_cols and $$unique_set{'key'}{'name'} ne 'PRIMARY')
169          100      6      6   if (exists $unconstrain{$unique_keys[$i]{'name'}})
190          100     10     14   if ($primary_key)
234          100      2     22   if ($primary_key and $args{'clustered'} and $args{'tbl_info'}{'engine'} =~ /^(?:InnoDB|solidDB)$/)
256   ***     50      0      3   unless $args{'keys'}
260   ***     50      0      3   unless $fks[$i]
262   ***     50      0      3   unless $fks[$j]
272          100      2      1   if ($fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols and $i_pcols eq $j_pcols)
291   ***     50      2      0   if $args{'callback'}
318          100     44     48   if ($args{'remove_keys'}) { }
340   ***     50      0     41   unless defined $$keys[$i]
344   ***     50      0     37   unless defined $$remove_keys[$j]
362          100     18     19   if (substr($rm_cols, 0, $rm_len_cols) eq substr($keep_cols, 0, $rm_len_cols)) { }
367          100      1     17   if ($args{'exact_duplicates'} and $rm_len_cols < $keep_len_cols)
375          100      1     16   if (exists $$remove_keys[$rm]{'unique_col'})
384          100      3     13   if ($$remove_keys[$rm]{'unconstrained'})
389          100      6     10   $rm_len_cols < $keep_len_cols ? :
403   ***     50     16      0   if $args{'callback'}
405          100      9      7   if $remove_index == 0
406   ***     50      7      0   if $remove_index == 1
417          100     44     48   if $args{'remove_keys'}
418   ***     50      0     92   if $args{'duplice_keys'}
425   ***     50      0      4   unless $args{'primary_key'}
426   ***     50      0      4   unless $args{'keys'}
438   ***     50      1      0   if (substr($suffix, 0, $len) eq substr($pkcols, 0, $len))
450   ***     50      1      0   if $args{'callback'}
458   ***     50      0      4   if $args{'duplice_keys'}
465   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
153          100      4      1      6   $n_unique_cols and $$unique_set{'key'}{'name'} ne 'PRIMARY'
234          100     14      7      3   $primary_key and $args{'clustered'}
             100     21      1      2   $primary_key and $args{'clustered'} and $args{'tbl_info'}{'engine'} =~ /^(?:InnoDB|solidDB)$/
272   ***     66      0      1      2   $fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols
      ***     66      1      0      2   $fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols and $i_pcols eq $j_pcols
367          100     15      2      1   $args{'exact_duplicates'} and $rm_len_cols < $keep_len_cols

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
89           100      2      9     38   $args{'ignore_order'} or $is_fulltext


Covered Subroutines
-------------------

Subroutine                  Count Location                                                 
--------------------------- ----- ---------------------------------------------------------
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:22 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:23 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:24 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:26 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:28 
get_duplicate_fks               3 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:255
get_duplicate_keys             24 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:60 
new                             1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:31 
remove_clustered_duplicates     4 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:424
remove_prefix_duplicates       92 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:304

Uncovered Subroutines
---------------------

Subroutine                  Count Location                                                 
--------------------------- ----- ---------------------------------------------------------
_d                              0 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:464


