---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mon/DuplicateKeyFinder.pm  100.0   82.5   84.4  100.0    0.0   58.4   92.4
DuplicateKeyFinder.t          100.0   50.0   33.3  100.0    n/a   41.6   98.6
Total                         100.0   81.7   80.0  100.0    0.0  100.0   94.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:50 2010
Finish:       Thu Jun 24 19:32:50 2010

Run:          DuplicateKeyFinder.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:52 2010
Finish:       Thu Jun 24 19:32:52 2010

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
18                                                    # DuplicateKeyFinder package $Revision: 5798 $
19                                                    # ###########################################################################
20                                                    package DuplicateKeyFinder;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                 11   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
25                                                    
26             1                    1             6   use List::Util qw(min);
               1                                  2   
               1                                 11   
27                                                    
28    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 22   
29                                                    
30                                                    sub new {
31    ***      1                    1      0      5      my ( $class, %args ) = @_;
32             1                                  4      my $self = {};
33             1                                 20      return bless $self, $class;
34                                                    }
35                                                    
36                                                    # %args should contain:
37                                                    #
38                                                    #  *  keys             (req) A hashref from TableParser::get_keys().
39                                                    #  *  clustered_key    The clustered key, if any; also from get_keys().
40                                                    #  *  tbl_info         { db, tbl, engine, ddl } hashref.
41                                                    #  *  callback         An anonymous subroutine, called for each dupe found.
42                                                    #  *  ignore_order     Order never matters for any type of index (generally
43                                                    #                      order matters except for FULLTEXT).
44                                                    #  *  ignore_structure Compare different index types as if they're the same.
45                                                    #  *  clustered        Perform duplication checks against the clustered  key.
46                                                    #
47                                                    # Returns an arrayref of duplicate key hashrefs.  Each contains
48                                                    #
49                                                    #  *  key               The name of the index that's a duplicate.
50                                                    #  *  cols              The columns in that key (arrayref).
51                                                    #  *  duplicate_of      The name of the index it duplicates.
52                                                    #  *  duplicate_of_cols The columns of the index it duplicates.
53                                                    #  *  reason            A human-readable description of why this is a duplicate.
54                                                    #  *  dupe_type         Either exact, prefix, fk, or clustered.
55                                                    #
56                                                    sub get_duplicate_keys {
57    ***     27                   27      0    255      my ( $self, $keys,  %args ) = @_;
58    ***     27     50                         177      die "I need a keys argument" unless $keys;
59            27                                246      my %keys = %$keys;  # Copy keys because we remove non-duplicates.
60            27                                101      my $primary_key;
61            27                                 82      my @unique_keys;
62            27                                 78      my @normal_keys;
63            27                                 80      my @fulltext_keys;
64            27                                 83      my @dupes;
65                                                    
66                                                       KEY:
67            27                                147      foreach my $key ( values %keys ) {
68                                                          # Save real columns before we potentially re-order them.  These are
69                                                          # columns we want to print if the key is a duplicate.
70            70                                231         $key->{real_cols} = [ @{$key->{cols}} ];
              70                                541   
71                                                    
72                                                          # We use column lengths to compare keys.
73            70                                416         $key->{len_cols}  = length $key->{colnames};
74                                                    
75                                                          # The primary key is treated specially.  It is effectively never a
76                                                          # duplicate, so it is never removed.  It is compared to all other
77                                                          # keys, and in any case of duplication, the primary is always kept
78                                                          # and the other key removed.  Usually the primary is the acutal
79                                                          # PRIMARY KEY, but for an InnoDB table without a PRIMARY KEY, the
80                                                          # effective primary key is the clustered key.
81            70    100    100                 1094         if ( $key->{name} eq 'PRIMARY'
                           100                        
82                                                               || ($args{clustered_key} && $key->{name} eq $args{clustered_key}) ) {
83            13                                 52            $primary_key = $key;
84            13                                 42            MKDEBUG && _d('primary key:', $key->{name});
85            13                                 70            next KEY;
86                                                          }
87                                                    
88                                                          # Key column order matters for all keys except FULLTEXT, so unless
89                                                          # ignore_order is specified we only sort FULLTEXT keys.
90            57    100                         356         my $is_fulltext = $key->{type} eq 'FULLTEXT' ? 1 : 0;
91            57    100    100                  634         if ( $args{ignore_order} || $is_fulltext  ) {
92            11                                 94            my $ordered_cols = join(',', sort(split(/,/, $key->{colnames})));
93            11                                 32            MKDEBUG && _d('Reordered', $key->{name}, 'cols from',
94                                                                $key->{colnames}, 'to', $ordered_cols); 
95            11                                 42            $key->{colnames} = $ordered_cols;
96                                                          }
97                                                    
98                                                          # Unless ignore_structure is specified, only keys of the same
99                                                          # structure (btree, fulltext, etc.) are compared to one another.
100                                                         # UNIQUE keys are kept separate to make comparisons easier.
101           57    100                         356         my $push_to = $key->{is_unique} ? \@unique_keys : \@normal_keys;
102           57    100                         339         if ( !$args{ignore_structure} ) {
103           55    100                         278            $push_to = \@fulltext_keys if $is_fulltext;
104                                                            # TODO:
105                                                            # $push_to = \@hash_keys     if $is_hash;
106                                                            # $push_to = \@spatial_keys  if $is_spatial;
107                                                         }
108           57                                297         push @$push_to, $key; 
109                                                      }
110                                                   
111                                                      # Redundantly constrained unique keys are treated as normal keys.
112           27                                224      push @normal_keys, $self->unconstrain_keys($primary_key, \@unique_keys);
113                                                   
114                                                      # Do not check the primary key against uniques before unconstraining
115                                                      # redundantly unique keys.  In cases like
116                                                      #    PRIMARY KEY (a, b)
117                                                      #    UNIQUE KEY  (a)
118                                                      # the unique key will be wrongly removed.  It is needed to keep
119                                                      # column a unique.  The process of unconstraining redundantly unique
120                                                      # keys marks single column unique keys so that they are never removed
121                                                      # (the mark is adding unique_col=>1 to the unique key's hash).
122           27    100                         142      if ( $primary_key ) {
123           13                                 36         MKDEBUG && _d('Comparing PRIMARY KEY to UNIQUE keys');
124           13                                148         push @dupes,
125                                                            $self->remove_prefix_duplicates([$primary_key], \@unique_keys, %args);
126                                                   
127           13                                 52         MKDEBUG && _d('Comparing PRIMARY KEY to normal keys');
128           13                                112         push @dupes,
129                                                            $self->remove_prefix_duplicates([$primary_key], \@normal_keys, %args);
130                                                      }
131                                                   
132           27                                 91      MKDEBUG && _d('Comparing UNIQUE keys to normal keys');
133           27                                209      push @dupes,
134                                                         $self->remove_prefix_duplicates(\@unique_keys, \@normal_keys, %args);
135                                                   
136           27                                 92      MKDEBUG && _d('Comparing normal keys');
137           27                                195      push @dupes,
138                                                         $self->remove_prefix_duplicates(\@normal_keys, \@normal_keys, %args);
139                                                   
140                                                      # If --allstruct, then these special struct keys (FULLTEXT, HASH, etc.)
141                                                      # will have already been put in and handled by @normal_keys.
142           27                                 83      MKDEBUG && _d('Comparing FULLTEXT keys');
143           27                                212      push @dupes,
144                                                         $self->remove_prefix_duplicates(\@fulltext_keys, \@fulltext_keys, %args, exact_duplicates => 1);
145                                                   
146                                                      # TODO: other structs
147                                                   
148                                                      # Remove clustered duplicates.
149           27    100                         174      my $clustered_key = $args{clustered_key} ? $keys{$args{clustered_key}}
150                                                                        : undef;
151           27                                 75      MKDEBUG && _d('clustered key:', $clustered_key->{name},
152                                                         $clustered_key->{colnames});
153           27    100    100                  379      if ( $clustered_key
      ***                   66                        
      ***                   66                        
154                                                           && $args{clustered}
155                                                           && $args{tbl_info}->{engine}
156                                                           && $args{tbl_info}->{engine} =~ m/InnoDB/i )
157                                                      {
158            4                                 12         MKDEBUG && _d('Removing UNIQUE dupes of clustered key');
159            4                                 40         push @dupes,
160                                                            $self->remove_clustered_duplicates($clustered_key, \@unique_keys, %args);
161                                                   
162            4                                 14         MKDEBUG && _d('Removing ordinary dupes of clustered key');
163            4                                 29         push @dupes,
164                                                            $self->remove_clustered_duplicates($clustered_key, \@normal_keys, %args);
165                                                      }
166                                                   
167           27                                201      return \@dupes;
168                                                   }
169                                                   
170                                                   sub get_duplicate_fks {
171   ***      3                    3      0    849      my ( $self, $fks, %args ) = @_;
172   ***      3     50                          20      die "I need a fks argument" unless $fks;
173            3                                 21      my @fks = values %$fks;
174            3                                 10      my @dupes;
175                                                   
176            3                                 27      foreach my $i ( 0..$#fks - 1 ) {
177   ***      3     50                          17         next unless $fks[$i];
178            3                                 19         foreach my $j ( $i+1..$#fks ) {
179   ***      3     50                          17            next unless $fks[$j];
180                                                   
181                                                            # A foreign key is a duplicate no matter what order the
182                                                            # columns are in, so re-order them alphabetically so they
183                                                            # can be compared.
184            3                                  9            my $i_cols  = join(',', sort @{$fks[$i]->{cols}} );
               3                                 31   
185            3                                 13            my $j_cols  = join(',', sort @{$fks[$j]->{cols}} );
               3                                 21   
186            3                                 16            my $i_pcols = join(',', sort @{$fks[$i]->{parent_cols}} );
               3                                 22   
187            3                                 10            my $j_pcols = join(',', sort @{$fks[$j]->{parent_cols}} );
               3                                 19   
188                                                   
189   ***      3    100     66                   68            if ( $fks[$i]->{parent_tbl} eq $fks[$j]->{parent_tbl}
      ***                   66                        
190                                                                 && $i_cols  eq $j_cols
191                                                                 && $i_pcols eq $j_pcols ) {
192            2                                 20               my $dupe = {
193                                                                  key               => $fks[$j]->{name},
194            2                                 82                  cols              => [ @{$fks[$j]->{cols}} ],
195                                                                  ddl               => $fks[$j]->{ddl},
196                                                                  duplicate_of      => $fks[$i]->{name},
197            2                                 12                  duplicate_of_cols => [ @{$fks[$i]->{cols}} ],
198                                                                  duplicate_of_ddl  => $fks[$i]->{ddl},
199                                                                  reason            =>
200                                                                       "FOREIGN KEY $fks[$j]->{name} ($fks[$j]->{colnames}) "
201                                                                     . "REFERENCES $fks[$j]->{parent_tbl} "
202                                                                     . "($fks[$j]->{parent_colnames}) "
203                                                                     . 'is a duplicate of '
204                                                                     . "FOREIGN KEY $fks[$i]->{name} ($fks[$i]->{colnames}) "
205                                                                     . "REFERENCES $fks[$i]->{parent_tbl} "
206                                                                     ."($fks[$i]->{parent_colnames})",
207                                                                  dupe_type         => 'fk',
208                                                               };
209            2                                 10               push @dupes, $dupe;
210            2                                 12               delete $fks[$j];
211   ***      2     50                          24               $args{callback}->($dupe, %args) if $args{callback};
212                                                            }
213                                                         }
214                                                      }
215            3                                 22      return \@dupes;
216                                                   }
217                                                   
218                                                   # Removes and returns prefix duplicate keys from right_keys.
219                                                   # Both left_keys and right_keys are arrayrefs.
220                                                   #
221                                                   # Prefix duplicates are the typical type of duplicate like:
222                                                   #    KEY x (a)
223                                                   #    KEY y (a, b)
224                                                   # Key x is a prefix duplicate of key y.  This also covers exact
225                                                   # duplicates like:
226                                                   #    KEY y (a, b)
227                                                   #    KEY z (a, b)
228                                                   # Key y and z are exact duplicates.
229                                                   #
230                                                   # Usually two separate lists of keys are compared: the left and right
231                                                   # keys.  When a duplicate is found, the Left key is Left alone and the
232                                                   # Right key is Removed. This is done because some keys are more important
233                                                   # than others.  For example, the PRIMARY KEY is always a left key because
234                                                   # it is never removed.  When comparing UNIQUE keys to normal (non-unique)
235                                                   # keys, the UNIQUE keys are Left (alone) and any duplicating normal
236                                                   # keys are Removed.
237                                                   #
238                                                   # A list of keys can be compared to itself in which case left and right
239                                                   # keys reference the same list but this sub doesn't know that so it just
240                                                   # removes dupes from the left as usual.
241                                                   #
242                                                   # Optional args are:
243                                                   #    * exact_duplicates  Keys are dupes only if they're exact duplicates
244                                                   #    * callback          Sub called for each dupe found
245                                                   # 
246                                                   # For a full technical explanation of how/why this sub works, read:
247                                                   # http://code.google.com/p/maatkit/wiki/DeterminingDuplicateKeys
248                                                   sub remove_prefix_duplicates {
249   ***    107                  107      0    820      my ( $self, $left_keys, $right_keys, %args ) = @_;
250          107                                410      my @dupes;
251          107                                299      my $right_offset;
252          107                                295      my $last_left_key;
253          107                                461      my $last_right_key = scalar(@$right_keys) - 1;
254                                                   
255                                                      # We use "scalar(@$arrayref) - 1" because the $# syntax is not
256                                                      # reliable with arrayrefs across Perl versions.  And we use index
257                                                      # into the arrays because we delete elements.
258                                                   
259          107    100                         535      if ( $right_keys != $left_keys ) {
260                                                         # Right and left keys are different lists.
261                                                   
262            1                                  8         @$left_keys = sort { $a->{colnames} cmp $b->{colnames} }
              33                                281   
263           53                                280                       grep { defined $_; }
264                                                                       @$left_keys;
265           44                                271         @$right_keys = sort { $a->{colnames} cmp $b->{colnames} }
              64                                300   
266           53                                281                        grep { defined $_; }
267                                                                       @$right_keys;
268                                                   
269                                                         # Last left key is its very last key.
270           53                                274         $last_left_key = scalar(@$left_keys) - 1;
271                                                   
272                                                         # No need to offset where we begin looping through the right keys.
273           53                                194         $right_offset = 0;
274                                                      }
275                                                      else {
276                                                         # Right and left keys are the same list.
277                                                   
278           24                                125         @$left_keys = reverse sort { $a->{colnames} cmp $b->{colnames} }
              44                                187   
279           54                                290                       grep { defined $_; }
280                                                                       @$left_keys;
281                                                         
282                                                         # Last left key is its second-to-last key.
283                                                         # The very last left key will be used as a right key.
284           54                                241         $last_left_key = scalar(@$left_keys) - 2;
285                                                   
286                                                         # Since we're looping through the same list in two different
287                                                         # positions, we must offset where we begin in the right keys
288                                                         # so that we stay ahead of where we are in the left keys.
289           54                                190         $right_offset = 1;
290                                                      }
291                                                   
292                                                      LEFT_KEY:
293          107                                524      foreach my $left_index ( 0..$last_left_key ) {
294           52    100                         318         next LEFT_KEY unless defined $left_keys->[$left_index];
295                                                   
296                                                         RIGHT_KEY:
297           51                                315         foreach my $right_index ( $left_index+$right_offset..$last_right_key ) {
298   ***     44     50                         266            next RIGHT_KEY unless defined $right_keys->[$right_index];
299                                                   
300           44                                241            my $left_name      = $left_keys->[$left_index]->{name};
301           44                                227            my $left_cols      = $left_keys->[$left_index]->{colnames};
302           44                                216            my $left_len_cols  = $left_keys->[$left_index]->{len_cols};
303           44                                220            my $right_name     = $right_keys->[$right_index]->{name};
304           44                                218            my $right_cols     = $right_keys->[$right_index]->{colnames};
305           44                                210            my $right_len_cols = $right_keys->[$right_index]->{len_cols};
306                                                   
307           44                                125            MKDEBUG && _d('Comparing left', $left_name, '(',$left_cols,')',
308                                                               'to right', $right_name, '(',$right_cols,')');
309                                                   
310                                                            # Compare the whole right key to the left key, not just
311                                                            # the their common minimum length prefix. This is correct.
312                                                            # Read http://code.google.com/p/maatkit/wiki/DeterminingDuplicateKeys.
313           44    100                         334            if (    substr($left_cols,  0, $right_len_cols)
314                                                                 eq substr($right_cols, 0, $right_len_cols) ) {
315                                                   
316                                                               # FULLTEXT keys, for example, are only duplicates if they
317                                                               # are exact duplicates.
318           18    100    100                  147               if ( $args{exact_duplicates} && ($right_len_cols<$left_len_cols) ) {
319            1                                  3                  MKDEBUG && _d($right_name, 'not exact duplicate of', $left_name);
320            1                                  6                  next RIGHT_KEY;
321                                                               }
322                                                   
323                                                               # Do not remove the unique key that is constraining a single
324                                                               # column to uniqueness. This prevents UNIQUE KEY (a) from being
325                                                               # removed by PRIMARY KEY (a, b).
326           17    100                         108               if ( exists $right_keys->[$right_index]->{unique_col} ) {
327            1                                  4                  MKDEBUG && _d('Cannot remove', $right_name,
328                                                                     'because is constrains col',
329                                                                     $right_keys->[$right_index]->{cols}->[0]);
330            1                                  7                  next RIGHT_KEY;
331                                                               }
332                                                   
333           16                                 43               MKDEBUG && _d('Remove', $right_name);
334           16                                 46               my $reason;
335           16    100                          99               if ( $right_keys->[$right_index]->{unconstrained} ) {
336            3                                 38                  $reason .= "Uniqueness of $right_name ignored because "
337                                                                     . $right_keys->[$right_index]->{constraining_key}->{name}
338                                                                     . " is a stronger constraint\n"; 
339                                                               }
340           16    100                          85               my $exact_dupe = $right_len_cols < $left_len_cols ? 0 : 1;
341           16    100                         118               $reason .= $right_name
342                                                                        . ($exact_dupe ? ' is a duplicate of '
343                                                                                       : ' is a left-prefix of ')
344                                                                        . $left_name;
345           16    100                         318               my $dupe = {
346                                                                  key               => $right_name,
347                                                                  cols              => $right_keys->[$right_index]->{real_cols},
348                                                                  ddl               => $right_keys->[$right_index]->{ddl},
349                                                                  duplicate_of      => $left_name,
350                                                                  duplicate_of_cols => $left_keys->[$left_index]->{real_cols},
351                                                                  duplicate_of_ddl  => $left_keys->[$left_index]->{ddl},
352                                                                  reason            => $reason,
353                                                                  dupe_type         => $exact_dupe ? 'exact' : 'prefix',
354                                                               };
355           16                                 64               push @dupes, $dupe;
356           16                                 64               delete $right_keys->[$right_index];
357                                                   
358   ***     16     50                         176               $args{callback}->($dupe, %args) if $args{callback};
359                                                            }
360                                                            else {
361           26                                 82               MKDEBUG && _d($right_name, 'not left-prefix of', $left_name);
362           26                                164               next LEFT_KEY;
363                                                            }
364                                                         } # RIGHT_KEY
365                                                      } # LEFT_KEY
366          107                                305      MKDEBUG && _d('No more keys');
367                                                   
368                                                      # Cleanup the lists: remove removed keys.
369          107                                470      @$left_keys  = grep { defined $_; } @$left_keys;
              67                                349   
370          107                                478      @$right_keys = grep { defined $_; } @$right_keys;
              96                                457   
371                                                   
372          107                                603      return @dupes;
373                                                   }
374                                                   
375                                                   # Removes and returns clustered duplicate keys from keys.
376                                                   # ck (clustered key) is hashref and keys is an arrayref.
377                                                   #
378                                                   # For engines with a clustered index, if a key ends with a prefix
379                                                   # of the primary key, it's a duplicate. Example:
380                                                   #    PRIMARY KEY (a)
381                                                   #    KEY foo (b, a)
382                                                   # Key foo is redundant to PRIMARY.
383                                                   #
384                                                   # Optional args are:
385                                                   #    * callback          Sub called for each dupe found
386                                                   #
387                                                   sub remove_clustered_duplicates {
388   ***      8                    8      0     79      my ( $self, $ck, $keys, %args ) = @_;
389   ***      8     50                          51      die "I need a ck argument"   unless $ck;
390   ***      8     50                          39      die "I need a keys argument" unless $keys;
391            8                                 36      my $ck_cols = $ck->{colnames};
392                                                   
393            8                                 23      my @dupes;
394                                                      KEY:
395            8                                 50      for my $i ( 0 .. @$keys - 1 ) {
396            9                                 55         my $key = $keys->[$i]->{colnames};
397            9    100                         171         if ( $key =~ m/$ck_cols$/ ) {
398            1                                  3            MKDEBUG && _d("clustered key dupe:", $keys->[$i]->{name},
399                                                               $keys->[$i]->{colnames});
400            2                                 12            my $dupe = {
401                                                               key               => $keys->[$i]->{name},
402                                                               cols              => $keys->[$i]->{real_cols},
403                                                               ddl               => $keys->[$i]->{ddl},
404                                                               duplicate_of      => $ck->{name},
405                                                               duplicate_of_cols => $ck->{real_cols},
406                                                               duplicate_of_ddl  => $ck->{ddl},
407                                                               reason            => "Key $keys->[$i]->{name} ends with a "
408                                                                                  . "prefix of the clustered index",
409                                                               dupe_type         => 'clustered',
410                                                               short_key         => $self->shorten_clustered_duplicate(
411                                                                                       $ck_cols,
412            1                                 10                                       join(',', map { "`$_`" }
413            1                                 16                                          @{$keys->[$i]->{real_cols}})
414                                                                                    ),
415                                                            };
416            1                                  8            push @dupes, $dupe;
417            1                                  4            delete $keys->[$i];
418   ***      1     50                          11            $args{callback}->($dupe, %args) if $args{callback};
419                                                         }
420                                                      }
421            8                                 24      MKDEBUG && _d('No more keys');
422                                                   
423                                                      # Cleanup the lists: remove removed keys.
424            8                                 38      @$keys = grep { defined $_; } @$keys;
               8                                 45   
425                                                   
426            8                                 50      return @dupes;
427                                                   }
428                                                   
429                                                   sub shorten_clustered_duplicate {
430   ***      4                    4      0     33      my ( $self, $ck_cols, $dupe_key_cols ) = @_;
431            4    100                          35      return $ck_cols if $ck_cols eq $dupe_key_cols;
432            3                                 58      $dupe_key_cols =~ s/$ck_cols$//;
433            3                                 16      $dupe_key_cols =~ s/,+$//;
434            3                                 33      return $dupe_key_cols;
435                                                   }
436                                                   
437                                                   # Given a primary key (can be undef) and an arrayref of unique keys,
438                                                   # removes and returns redundantly contrained unique keys from uniquie_keys.
439                                                   sub unconstrain_keys {
440   ***     27                   27      0    148      my ( $self, $primary_key, $unique_keys ) = @_;
441   ***     27     50                         143      die "I need a unique_keys argument" unless $unique_keys;
442           27                                 80      my %unique_cols;
443           27                                 82      my @unique_sets;
444           27                                 78      my %unconstrain;
445           27                                 86      my @unconstrained_keys;
446                                                   
447           27                                 91      MKDEBUG && _d('Unconstraining redundantly unique keys');
448                                                   
449                                                      # First determine which unique keys define unique columns
450                                                      # and which define unique sets.
451                                                      UNIQUE_KEY:
452           27                                138      foreach my $unique_key ( $primary_key, @$unique_keys ) {
453           39    100                         213         next unless $unique_key; # primary key may be undefined
454           25                                136         my $cols = $unique_key->{cols};
455           25    100                         145         if ( @$cols == 1 ) {
456           12                                 40            MKDEBUG && _d($unique_key->{name},'defines unique column:',$cols->[0]);
457                                                            # Save only the first unique key for the unique col. If there
458                                                            # are others, then they are exact duplicates and will be removed
459                                                            # later when unique keys are compared to unique keys.
460   ***     12     50                          91            if ( !exists $unique_cols{$cols->[0]} ) {
461           12                                 61               $unique_cols{$cols->[0]}  = $unique_key;
462           12                                 88               $unique_key->{unique_col} = 1;
463                                                            }
464                                                         }
465                                                         else {
466           13                                 68            local $LIST_SEPARATOR = '-';
467           13                                 44            MKDEBUG && _d($unique_key->{name}, 'defines unique set:', @$cols);
468           13                                135            push @unique_sets, { cols => $cols, key => $unique_key };
469                                                         }
470                                                      }
471                                                   
472                                                      # Second, find which unique sets can be unconstraind (i.e. those
473                                                      # which have which have at least one unique column).
474                                                      UNIQUE_SET:
475           27                                133      foreach my $unique_set ( @unique_sets ) {
476           13                                 56         my $n_unique_cols = 0;
477           13                                 83         COL:
478           13                                 49         foreach my $col ( @{$unique_set->{cols}} ) {
479           28    100                         209            if ( exists $unique_cols{$col} ) {
480            7                                 27               MKDEBUG && _d('Unique set', $unique_set->{key}->{name},
481                                                                  'has unique col', $col);
482   ***      7     50                          48               last COL if ++$n_unique_cols > 1;
483            7                                 54               $unique_set->{constraining_key} = $unique_cols{$col};
484                                                            }
485                                                         }
486           13    100    100                  190         if ( $n_unique_cols && $unique_set->{key}->{name} ne 'PRIMARY' ) {
487                                                            # Unique set is redundantly constrained.
488            6                                 33            MKDEBUG && _d('Will unconstrain unique set',
489                                                               $unique_set->{key}->{name},
490                                                               'because it is redundantly constrained by key',
491                                                               $unique_set->{constraining_key}->{name},
492                                                               '(',$unique_set->{constraining_key}->{colnames},')');
493            6                                 72            $unconstrain{$unique_set->{key}->{name}}
494                                                               = $unique_set->{constraining_key};
495                                                         }
496                                                      }
497                                                   
498                                                      # And finally, unconstrain the redudantly unique sets found above by
499                                                      # removing them from the list of unique keys and adding them to the
500                                                      # list of normal keys.
501           27                                420      for my $i ( 0..(scalar @$unique_keys-1) ) {
502           12    100                         140         if ( exists $unconstrain{$unique_keys->[$i]->{name}} ) {
503            6                                 20            MKDEBUG && _d('Unconstraining', $unique_keys->[$i]->{name});
504            6                                 41            $unique_keys->[$i]->{unconstrained} = 1;
505            6                                 49            $unique_keys->[$i]->{constraining_key}
506                                                               = $unconstrain{$unique_keys->[$i]->{name}};
507            6                                 31            push @unconstrained_keys, $unique_keys->[$i];
508            6                                 42            delete $unique_keys->[$i];
509                                                         }
510                                                      }
511                                                   
512           27                                 80      MKDEBUG && _d('No more keys');
513           27                                167      return @unconstrained_keys;
514                                                   }
515                                                   
516                                                   sub _d {
517            1                    1            13      my ($package, undef, $line) = caller 0;
518   ***      2     50                          15      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 13   
               2                                 19   
519            1                                  8           map { defined $_ ? $_ : 'undef' }
520                                                           @_;
521            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
522                                                   }
523                                                   
524                                                   1;
525                                                   # ###########################################################################
526                                                   # End DuplicateKeyFinder package
527                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
58    ***     50      0     27   unless $keys
81           100     13     57   if ($$key{'name'} eq 'PRIMARY' or $args{'clustered_key'} and $$key{'name'} eq $args{'clustered_key'})
90           100      9     48   $$key{'type'} eq 'FULLTEXT' ? :
91           100     11     46   if ($args{'ignore_order'} or $is_fulltext)
101          100     12     45   $$key{'is_unique'} ? :
102          100     55      2   if (not $args{'ignore_structure'})
103          100      8     47   if $is_fulltext
122          100     13     14   if ($primary_key)
149          100      6     21   $args{'clustered_key'} ? :
153          100      4     23   if ($clustered_key and $args{'clustered'} and $args{'tbl_info'}{'engine'} and $args{'tbl_info'}{'engine'} =~ /InnoDB/i)
172   ***     50      0      3   unless $fks
177   ***     50      0      3   unless $fks[$i]
179   ***     50      0      3   unless $fks[$j]
189          100      2      1   if ($fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols and $i_pcols eq $j_pcols)
211   ***     50      2      0   if $args{'callback'}
259          100     53     54   if ($right_keys != $left_keys) { }
294          100      1     51   unless defined $$left_keys[$left_index]
298   ***     50      0     44   unless defined $$right_keys[$right_index]
313          100     18     26   if (substr($left_cols, 0, $right_len_cols) eq substr($right_cols, 0, $right_len_cols)) { }
318          100      1     17   if ($args{'exact_duplicates'} and $right_len_cols < $left_len_cols)
326          100      1     16   if (exists $$right_keys[$right_index]{'unique_col'})
335          100      3     13   if ($$right_keys[$right_index]{'unconstrained'})
340          100      6     10   $right_len_cols < $left_len_cols ? :
341          100     10      6   $exact_dupe ? :
345          100     10      6   $exact_dupe ? :
358   ***     50     16      0   if $args{'callback'}
389   ***     50      0      8   unless $ck
390   ***     50      0      8   unless $keys
397          100      1      8   if ($key =~ /$ck_cols$/)
418   ***     50      1      0   if $args{'callback'}
431          100      1      3   if $ck_cols eq $dupe_key_cols
441   ***     50      0     27   unless $unique_keys
453          100     14     25   unless $unique_key
455          100     12     13   if (@$cols == 1) { }
460   ***     50     12      0   if (not exists $unique_cols{$$cols[0]})
479          100      7     21   if (exists $unique_cols{$col})
482   ***     50      0      7   if ++$n_unique_cols > 1
486          100      6      7   if ($n_unique_cols and $$unique_set{'key'}{'name'} ne 'PRIMARY')
502          100      6      6   if (exists $unconstrain{$$unique_keys[$i]{'name'}})
518   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
81           100     46     11      2   $args{'clustered_key'} and $$key{'name'} eq $args{'clustered_key'}
153          100     21      2      4   $clustered_key and $args{'clustered'}
      ***     66     23      0      4   $clustered_key and $args{'clustered'} and $args{'tbl_info'}{'engine'}
      ***     66     23      0      4   $clustered_key and $args{'clustered'} and $args{'tbl_info'}{'engine'} and $args{'tbl_info'}{'engine'} =~ /InnoDB/i
189   ***     66      0      1      2   $fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols
      ***     66      1      0      2   $fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols and $i_pcols eq $j_pcols
318          100     15      2      1   $args{'exact_duplicates'} and $right_len_cols < $left_len_cols
486          100      6      1      6   $n_unique_cols and $$unique_set{'key'}{'name'} ne 'PRIMARY'

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
28    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
81           100     11      2     57   $$key{'name'} eq 'PRIMARY' or $args{'clustered_key'} and $$key{'name'} eq $args{'clustered_key'}
91           100      2      9     46   $args{'ignore_order'} or $is_fulltext


Covered Subroutines
-------------------

Subroutine                  Count Pod Location                                                 
--------------------------- ----- --- ---------------------------------------------------------
BEGIN                           1     /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:22 
BEGIN                           1     /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:23 
BEGIN                           1     /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:24 
BEGIN                           1     /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:26 
BEGIN                           1     /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:28 
_d                              1     /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:517
get_duplicate_fks               3   0 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:171
get_duplicate_keys             27   0 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:57 
new                             1   0 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:31 
remove_clustered_duplicates     8   0 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:388
remove_prefix_duplicates      107   0 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:249
shorten_clustered_duplicate     4   0 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:430
unconstrain_keys               27   0 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:440


DuplicateKeyFinder.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1           155   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
11             1                    1            10   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1             9   use Test::More tests => 35;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use DuplicateKeyFinder;
               1                                  4   
               1                                 12   
15             1                    1            11   use Quoter;
               1                                  3   
               1                                  9   
16             1                    1            10   use TableParser;
               1                                  3   
               1                                 11   
17             1                    1            10   use MaatkitTest;
               1                                  6   
               1                                 35   
18                                                    
19             1                                  8   my $dk = new DuplicateKeyFinder();
20             1                                  7   my $q  = new Quoter();
21             1                                 24   my $tp = new TableParser(Quoter => $q);
22                                                    
23             1                                 37   my $sample = "common/t/samples/dupekeys/";
24             1                                 12   my $dupes;
25                                                    my $callback = sub {
26            19                   19           187      push @$dupes, $_[0];
27             1                                  7   };
28                                                    
29             1                                  5   my $opt = { version => '004001000' };
30             1                                  2   my $ddl;
31             1                                  3   my $tbl;
32                                                    
33             1                                  9   isa_ok($dk, 'DuplicateKeyFinder');
34                                                    
35             1                                 14   $ddl   = load_file('common/t/samples/one_key.sql');
36             1                                 20   $dupes = [];
37             1                                 14   my ($keys, $ck) = $tp->get_keys($ddl, $opt);
38             1                                227   $dk->get_duplicate_keys(
39                                                       $keys,
40                                                       clustered_key => $ck,
41                                                       callback => $callback);
42             1                                  9   is_deeply(
43                                                       $dupes,
44                                                       [
45                                                       ],
46                                                       'One key, no dupes'
47                                                    );
48                                                    
49             1                                 10   $ddl   = load_file('common/t/samples/dupe_key.sql');
50             1                                 26   $dupes = [];
51             1                                 17   ($keys, $ck) = $tp->get_keys($ddl, $opt);
52             1                                354   $dk->get_duplicate_keys(
53                                                       $keys,
54                                                       clustered_key => $ck,
55                                                       callback => $callback);
56             1                                 15   is_deeply(
57                                                       $dupes,
58                                                       [
59                                                          {
60                                                             'key'          => 'a',
61                                                             'cols'         => [qw(a)],
62                                                             ddl            => 'KEY `a` (`a`),',
63                                                             'duplicate_of' => 'a_2',
64                                                             'duplicate_of_cols' => [qw(a b)],
65                                                             duplicate_of_ddl    => 'KEY `a_2` (`a`,`b`)',
66                                                             'reason'       => 'a is a left-prefix of a_2',
67                                                             dupe_type      => 'prefix',
68                                                          }
69                                                       ],
70                                                       'Two dupe keys on table dupe_key'
71                                                    );
72                                                    
73             1                                 13   $ddl   = load_file('common/t/samples/dupe_key_reversed.sql');
74             1                                 19   $dupes = [];
75             1                                 16   ($keys, $ck) = $tp->get_keys($ddl, $opt);
76             1                                360   $dk->get_duplicate_keys(
77                                                       $keys,
78                                                       clustered_key => $ck,
79                                                       callback => $callback);
80             1                                 14   is_deeply(
81                                                       $dupes,
82                                                       [
83                                                          {
84                                                             'key'          => 'a',
85                                                             'cols'         => [qw(a)],
86                                                             ddl            => 'KEY `a` (`a`),',
87                                                             'duplicate_of' => 'a_2',
88                                                             'duplicate_of_cols' => [qw(a b)],
89                                                             duplicate_of_ddl    => 'KEY `a_2` (`a`,`b`),',
90                                                             'reason'       => 'a is a left-prefix of a_2',
91                                                             dupe_type      => 'prefix',
92                                                          }
93                                                       ],
94                                                       'Two dupe keys on table dupe_key in reverse'
95                                                    );
96                                                    
97                                                    # This test might fail if your system sorts a_3 before a_2, because the
98                                                    # keys are sorted by columns, not name. If this happens, then a_3 will
99                                                    # duplicate a_2.
100            1                                 14   $ddl   = load_file('common/t/samples/dupe_keys_thrice.sql');
101            1                                 17   $dupes = [];
102            1                                 17   ($keys, $ck) = $tp->get_keys($ddl, $opt);
103            1                                516   $dk->get_duplicate_keys(
104                                                      $keys,
105                                                      clustered_key => $ck,
106                                                      callback => $callback);
107            1                                 21   is_deeply(
108                                                      $dupes,
109                                                      [
110                                                         {
111                                                            'key'          => 'a_3',
112                                                            'cols'         => [qw(a b)],
113                                                            ddl            => 'KEY `a_3` (`a`,`b`)',
114                                                            'duplicate_of' => 'a_2',
115                                                            'duplicate_of_cols' => [qw(a b)],
116                                                            duplicate_of_ddl    => 'KEY `a_2` (`a`,`b`),',
117                                                            'reason'       => 'a_3 is a duplicate of a_2',
118                                                            dupe_type      => 'exact',
119                                                         },
120                                                         {
121                                                            'key'          => 'a',
122                                                            'cols'         => [qw(a)],
123                                                            ddl            => 'KEY `a` (`a`),',
124                                                            'duplicate_of' => 'a_2',
125                                                            'duplicate_of_cols' => [qw(a b)],
126                                                            duplicate_of_ddl    => 'KEY `a_2` (`a`,`b`),',
127                                                            'reason'       => 'a is a left-prefix of a_2',
128                                                            dupe_type      => 'prefix',
129                                                         },
130                                                      ],
131                                                      'Dupe keys only output once (may fail due to different sort order)'
132                                                   );
133                                                   
134            1                                 17   $ddl   = load_file('common/t/samples/nondupe_fulltext.sql');
135            1                                 18   $dupes = [];
136            1                                 19   ($keys, $ck) = $tp->get_keys($ddl, $opt);
137            1                                395   $dk->get_duplicate_keys(
138                                                      $keys,
139                                                      clustered_key => $ck,
140                                                      callback => $callback);
141            1                                  7   is_deeply(
142                                                      $dupes,
143                                                      [],
144                                                      'No dupe keys b/c of fulltext'
145                                                   );
146            1                                 10   $dupes = [];
147            1                                  7   ($keys, $ck) = $tp->get_keys($ddl, $opt);
148            1                                324   $dk->get_duplicate_keys(
149                                                      $keys,
150                                                      clustered_key => $ck,
151                                                      ignore_structure => 1,
152                                                      callback         => $callback);
153            1                                 16   is_deeply(
154                                                      $dupes,
155                                                      [
156                                                         {
157                                                            'key'          => 'a',
158                                                            'cols'         => [qw(a)],
159                                                            ddl            => 'KEY `a` (`a`),',
160                                                            'duplicate_of' => 'a_2',
161                                                            'duplicate_of_cols' => [qw(a b)],
162                                                            duplicate_of_ddl    => 'FULLTEXT KEY `a_2` (`a`,`b`),',
163                                                            'reason'       => 'a is a left-prefix of a_2',
164                                                            dupe_type      => 'prefix',
165                                                         },
166                                                      ],
167                                                      'Dupe keys when ignoring structure'
168                                                   );
169                                                   
170            1                                 14   $ddl   = load_file('common/t/samples/nondupe_fulltext_not_exact.sql');
171            1                                 19   $dupes = [];
172            1                                 18   ($keys, $ck) = $tp->get_keys($ddl, $opt);
173            1                                501   $dk->get_duplicate_keys(
174                                                      $keys,
175                                                      clustered_key => $ck,
176                                                      callback => $callback);
177            1                                  7   is_deeply(
178                                                      $dupes,
179                                                      [],
180                                                      'No dupe keys b/c fulltext requires exact match (issue 10)'
181                                                   );
182                                                   
183            1                                 11   $ddl   = load_file('common/t/samples/dupe_fulltext_exact.sql');
184            1                                 19   $dupes = [];
185            1                                 13   ($keys, $ck) = $tp->get_keys($ddl, $opt);
186            1                                420   $dk->get_duplicate_keys(
187                                                      $keys,
188                                                      clustered_key => $ck,
189                                                      callback => $callback);
190            1                                 16   is_deeply(
191                                                      $dupes,
192                                                      [
193                                                         {
194                                                            'key'          => 'ft_idx_a_b_2',
195                                                            'cols'         => [qw(a b)],
196                                                            ddl            => 'FULLTEXT KEY `ft_idx_a_b_2` (`a`,`b`)',
197                                                            'duplicate_of' => 'ft_idx_a_b_1',
198                                                            'duplicate_of_cols' => [qw(a b)],
199                                                            duplicate_of_ddl    => 'FULLTEXT KEY `ft_idx_a_b_1` (`a`,`b`),',
200                                                            'reason'       => 'ft_idx_a_b_2 is a duplicate of ft_idx_a_b_1',
201                                                            dupe_type      => 'exact',
202                                                         }
203                                                      ],
204                                                      'Dupe exact fulltext keys (issue 10)'
205                                                   );
206                                                   
207            1                                 15   $ddl   = load_file('common/t/samples/dupe_fulltext_reverse_order.sql');
208            1                                 18   $dupes = [];
209            1                                 18   ($keys, $ck) = $tp->get_keys($ddl, $opt);
210            1                                436   $dk->get_duplicate_keys(
211                                                      $keys,
212                                                      clustered_key => $ck,
213                                                      callback => $callback);
214            1                                 16   is_deeply(
215                                                      $dupes,
216                                                      [
217                                                         {
218                                                            'key'          => 'ft_idx_a_b',
219                                                            'cols'         => [qw(a b)],
220                                                            ddl            => 'FULLTEXT KEY `ft_idx_a_b` (`a`,`b`),',
221                                                            'duplicate_of' => 'ft_idx_b_a',
222                                                            'duplicate_of_cols' => [qw(b a)],
223                                                            duplicate_of_ddl    => 'FULLTEXT KEY `ft_idx_b_a` (`b`,`a`)',
224                                                            'reason'       => 'ft_idx_a_b is a duplicate of ft_idx_b_a',
225                                                            dupe_type      => 'exact',
226                                                         }
227                                                      ],
228                                                      'Dupe reverse order fulltext keys (issue 10)'
229                                                   );
230                                                   
231            1                                 14   $ddl   = load_file('common/t/samples/dupe_key_unordered.sql');
232            1                                 18   $dupes = [];
233            1                                 18   ($keys, $ck) = $tp->get_keys($ddl, $opt);
234            1                                382   $dk->get_duplicate_keys(
235                                                      $keys,
236                                                      clustered_key => $ck,
237                                                      callback => $callback);
238            1                                  6   is_deeply(
239                                                      $dupes,
240                                                      [],
241                                                      'No dupe keys because of order'
242                                                   );
243            1                                  9   $dupes = [];
244            1                                  8   ($keys, $ck) = $tp->get_keys($ddl, $opt);
245            1                                334   $dk->get_duplicate_keys(
246                                                      $keys,
247                                                      clustered_key => $ck,
248                                                      ignore_order => 1,
249                                                      callback     => $callback);
250            1                                 15   is_deeply(
251                                                      $dupes,
252                                                      [
253                                                         {
254                                                            'key'          => 'a',
255                                                            'cols'         => [qw(b a)],
256                                                            ddl            => 'KEY `a` (`b`,`a`),',
257                                                            'duplicate_of' => 'a_2',
258                                                            'duplicate_of_cols' => [qw(a b)],
259                                                            duplicate_of_ddl    => 'KEY `a_2` (`a`,`b`),',
260                                                            'reason'       => 'a is a duplicate of a_2',
261                                                            dupe_type      => 'exact',
262                                                         }
263                                                      ],
264                                                      'Two dupe keys when ignoring order'
265                                                   );
266                                                   
267                                                   # #############################################################################
268                                                   # Clustered key tests.
269                                                   # #############################################################################
270            1                                 14   $ddl   = load_file('common/t/samples/innodb_dupe.sql');
271            1                                 18   $dupes = [];
272            1                                 17   ($keys, $ck) = $tp->get_keys($ddl, $opt);
273            1                                389   $dk->get_duplicate_keys(
274                                                      $keys,
275                                                      clustered_key => $ck,
276                                                      callback => $callback);
277                                                   
278            1                                  6   is_deeply(
279                                                      $dupes,
280                                                      [],
281                                                      'No duplicate keys with ordinary options'
282                                                   );
283            1                                  9   $dupes = [];
284            1                                  8   ($keys, $ck) = $tp->get_keys($ddl, $opt);
285            1                                328   $dk->get_duplicate_keys(
286                                                      $keys,
287                                                      clustered_key => $ck,
288                                                      clustered => 1,
289                                                      tbl_info  => { engine => 'InnoDB', ddl => $ddl },
290                                                      callback  => $callback);
291            1                                 17   is_deeply(
292                                                      $dupes,
293                                                      [
294                                                         {
295                                                            'key'          => 'b',
296                                                            'cols'         => [qw(b a)],
297                                                            ddl            => 'KEY `b` (`b`,`a`)',
298                                                            'duplicate_of' => 'PRIMARY',
299                                                            'duplicate_of_cols' => [qw(a)],
300                                                            duplicate_of_ddl    => 'PRIMARY KEY  (`a`),',
301                                                            'reason'       => 'Key b ends with a prefix of the clustered index',
302                                                            dupe_type      => 'clustered',
303                                                            short_key      => '`b`',
304                                                         }
305                                                      ],
306                                                      'Duplicate keys with cluster option'
307                                                   );
308                                                   
309            1                                 17   $ddl = load_file('common/t/samples/dupe_if_it_were_innodb.sql');
310            1                                 19   $dupes = [];
311            1                                 18   ($keys, $ck) = $tp->get_keys($ddl, $opt);
312            1                                385   $dk->get_duplicate_keys(
313                                                      $keys,
314                                                      clustered_key => $ck,
315                                                      clustered => 1,
316                                                      tbl_info  => {engine    => 'MyISAM', ddl => $ddl},
317                                                      callback  => $callback);
318            1                                  7   is_deeply(
319                                                      $dupes,
320                                                      [],
321                                                      'No cluster-duplicate keys because not InnoDB'
322                                                   );
323                                                   
324                                                   # This table is a test case for an infinite loop I ran into while writing the
325                                                   # cluster stuff
326            1                                 11   $ddl = load_file('common/t/samples/mysql_db.sql');
327            1                                 18   $dupes = [];
328            1                                 12   ($keys, $ck) = $tp->get_keys($ddl, $opt);
329            1                                612   $dk->get_duplicate_keys(
330                                                      $keys,
331                                                      clustered_key => $ck,
332                                                      clustered => 1,
333                                                      tbl_info  => { engine    => 'InnoDB', ddl => $ddl },
334                                                      callback  => $callback);
335            1                                  7   is_deeply(
336                                                      $dupes,
337                                                      [],
338                                                      'No cluster-duplicate keys in mysql.db'
339                                                   );
340                                                   
341                                                   # #############################################################################
342                                                   # Duplicate FOREIGN KEY tests.
343                                                   # #############################################################################
344            1                                 11   $ddl   = load_file('common/t/samples/dupe_fk_one.sql');
345            1                                 17   $dupes = [];
346            1                                 25   $dk->get_duplicate_fks(
347                                                      $tp->get_fks($ddl, {database => 'test'}),
348                                                      callback => $callback);
349            1                                 18   is_deeply(
350                                                      $dupes,
351                                                      [
352                                                         {
353                                                            'key'               => 't1_ibfk_1',
354                                                            'cols'              => [qw(a b)],
355                                                            ddl                 => 'CONSTRAINT `t1_ibfk_1` FOREIGN KEY (`a`, `b`) REFERENCES `t2` (`a`, `b`)',
356                                                            'duplicate_of'      => 't1_ibfk_2',
357                                                            'duplicate_of_cols' => [qw(b a)],
358                                                            duplicate_of_ddl    => 'CONSTRAINT `t1_ibfk_2` FOREIGN KEY (`b`, `a`) REFERENCES `t2` (`b`, `a`)',
359                                                            'reason'            => 'FOREIGN KEY t1_ibfk_1 (`a`, `b`) REFERENCES `test`.`t2` (`a`, `b`) is a duplicate of FOREIGN KEY t1_ibfk_2 (`b`, `a`) REFERENCES `test`.`t2` (`b`, `a`)',
360                                                            dupe_type      => 'fk',
361                                                         }
362                                                      ],
363                                                      'Two duplicate foreign keys'
364                                                   );
365                                                   
366            1                                 15   $ddl   = load_file('common/t/samples/sakila_film.sql');
367            1                                 19   $dupes = [];
368            1                                 21   $dk->get_duplicate_fks(
369                                                      $tp->get_fks($ddl, {database => 'sakila'}),
370                                                      callback => $callback);
371            1                                 12   is_deeply(
372                                                      $dupes,
373                                                      [],
374                                                      'No duplicate foreign keys in sakila_film.sql'
375                                                   );
376                                                   
377                                                   # #############################################################################
378                                                   # Issue 9: mk-duplicate-key-checker should treat unique and FK indexes specially
379                                                   # #############################################################################
380                                                   
381            1                                 11   $ddl   = load_file('common/t/samples/issue_9-1.sql');
382            1                                 17   $dupes = [];
383            1                                 12   ($keys, $ck) = $tp->get_keys($ddl, $opt);
384            1                                398   $dk->get_duplicate_keys(
385                                                      $keys,
386                                                      clustered_key => $ck,
387                                                      callback => $callback);
388            1                                  6   is_deeply(
389                                                      $dupes,
390                                                      [],
391                                                      'Unique and non-unique keys with common prefix not dupes (issue 9)'
392                                                   );
393                                                   
394            1                                 11   $ddl   = load_file('common/t/samples/issue_9-2.sql');
395            1                                 20   $dupes = [];
396            1                                 13   ($keys, $ck) = $tp->get_keys($ddl, $opt);
397            1                                524   $dk->get_duplicate_keys(
398                                                      $keys,
399                                                      clustered_key => $ck,
400                                                      callback => $callback);
401            1                                 10   is_deeply(
402                                                      $dupes,
403                                                      [],
404                                                      'PRIMARY and non-unique keys with common prefix not dupes (issue 9)'
405                                                   );
406                                                   
407            1                                 16   $ddl   = load_file('common/t/samples/issue_9-3.sql');
408            1                                 19   $dupes = [];
409            1                                 12   ($keys, $ck) = $tp->get_keys($ddl, $opt);
410            1                                576   $dk->get_duplicate_keys(
411                                                      $keys,
412                                                      clustered_key => $ck,
413                                                      callback => $callback);
414            1                                 24   is_deeply(
415                                                      $dupes,
416                                                      [
417                                                         {
418                                                            'key'          => 'j',
419                                                            'cols'         => [qw(a b)],
420                                                            ddl            => 'KEY `j` (`a`,`b`)',
421                                                            'duplicate_of' => 'i',
422                                                            'duplicate_of_cols' => [qw(a b)],
423                                                            duplicate_of_ddl    => 'UNIQUE KEY `i` (`a`,`b`),',
424                                                            'reason'       => 'j is a duplicate of i',
425                                                            dupe_type      => 'exact',
426                                                         }
427                                                      ],
428                                                      'Non-unique key dupes unique key with same col cover (issue 9)'
429                                                   );
430                                                   
431            1                                 23   $ddl   = load_file('common/t/samples/issue_9-4.sql');
432            1                                 18   $dupes = [];
433            1                                 17   ($keys, $ck) = $tp->get_keys($ddl, $opt);
434            1                                569   $dk->get_duplicate_keys(
435                                                      $keys,
436                                                      clustered_key => $ck,
437                                                      callback => $callback);
438            1                                 24   is_deeply(
439                                                      $dupes,
440                                                      [
441                                                         {
442                                                            'key'          => 'j',
443                                                            'cols'         => [qw(a b)],
444                                                            ddl            => 'KEY `j` (`a`,`b`)',
445                                                            'duplicate_of' => 'PRIMARY',
446                                                            'duplicate_of_cols' => [qw(a b)],
447                                                            duplicate_of_ddl    => 'PRIMARY KEY  (`a`,`b`),',
448                                                            'reason'       => 'j is a duplicate of PRIMARY',
449                                                            dupe_type      => 'exact',
450                                                         }
451                                                      ],
452                                                      'Non-unique key dupes PRIMARY key same col cover (issue 9)'
453                                                   );
454                                                   
455            1                                 23   $ddl   = load_file('common/t/samples/issue_9-5.sql');
456            1                                 19   $dupes = [];
457            1                                 19   ($keys, $ck) = $tp->get_keys($ddl, $opt);
458            1                                546   $dk->get_duplicate_keys(
459                                                      $keys,
460                                                      clustered_key => $ck,
461                                                      callback => $callback);
462            1                                 10   is_deeply(
463                                                      $dupes,
464                                                      [],
465                                                      'Two unique keys with common prefix are not dupes'
466                                                   );
467                                                   
468            1                                 16   $ddl   = load_file('common/t/samples/uppercase_names.sql');
469            1                                 18   $dupes = [];
470            1                                 11   ($keys, $ck) = $tp->get_keys($ddl, $opt);
471            1                                570   $dk->get_duplicate_keys(
472                                                      $keys,
473                                                      clustered_key => $ck,
474                                                      callback => $callback);
475            1                                 23   is_deeply(
476                                                      $dupes,
477                                                      [
478                                                         {
479                                                            'key'               => 'A',
480                                                            'cols'              => [qw(A)],
481                                                            ddl                 => 'KEY `A` (`A`)',
482                                                            'duplicate_of'      => 'PRIMARY',
483                                                            'duplicate_of_cols' => [qw(A)],
484                                                            duplicate_of_ddl    => 'PRIMARY KEY  (`A`),',
485                                                            'reason'            => "A is a duplicate of PRIMARY",
486                                                            dupe_type      => 'exact',
487                                                         },
488                                                      ],
489                                                      'Finds duplicates OK on uppercase columns',
490                                                   );
491                                                   
492            1                                 22   $ddl   = load_file('common/t/samples/issue_9-7.sql');
493            1                                 18   $dupes = [];
494            1                                 16   ($keys, $ck) = $tp->get_keys($ddl, $opt);
495            1                                781   $dk->get_duplicate_keys(
496                                                      $keys,
497                                                      clustered_key => $ck,
498                                                      callback => $callback);
499            1                                 26   is_deeply(
500                                                      $dupes,
501                                                      [
502                                                         {
503                                                            'key'               => 'ua_b',
504                                                            'cols'              => [qw(a b)],
505                                                            ddl                 => 'UNIQUE KEY `ua_b` (`a`,`b`),',
506                                                            'duplicate_of'      => 'a_b_c',
507                                                            'duplicate_of_cols' => [qw(a b c)],
508                                                            duplicate_of_ddl    => 'KEY `a_b_c` (`a`,`b`,`c`)',
509                                                            'reason'            => "Uniqueness of ua_b ignored because PRIMARY is a stronger constraint\nua_b is a left-prefix of a_b_c",
510                                                            dupe_type      => 'prefix',
511                                                         },
512                                                      ],
513                                                      'Redundantly unique key dupes normal key after unconstraining'
514                                                   );
515                                                   
516            1                                 27   $ddl   = load_file('common/t/samples/issue_9-6.sql');
517            1                                 18   $dupes = [];
518            1                                 20   ($keys, $ck) = $tp->get_keys($ddl, $opt);
519            1                               2531   $dk->get_duplicate_keys(
520                                                      $keys,
521                                                      clustered_key => $ck,
522                                                      callback => $callback);
523            1                                337   is_deeply(
524                                                      $dupes,
525                                                      [
526                                                         {
527                                                          'duplicate_of' => 'PRIMARY',
528                                                          'reason' => 'a is a left-prefix of PRIMARY',
529                                                          dupe_type      => 'prefix',
530                                                          'duplicate_of_cols' => [qw(a b)],
531                                                          duplicate_of_ddl    => 'PRIMARY KEY  (`a`,`b`),',
532                                                          'cols' => [qw(a)],
533                                                          'key'  => 'a',
534                                                          ddl    => 'KEY `a` (`a`),',
535                                                         },
536                                                         {
537                                                          'duplicate_of' => 'PRIMARY',
538                                                          'reason' => 'a_b is a duplicate of PRIMARY',
539                                                          dupe_type      => 'exact',
540                                                          'duplicate_of_cols' => [qw(a b)],
541                                                          duplicate_of_ddl    => 'PRIMARY KEY  (`a`,`b`),',
542                                                          'cols' => [qw(a b)],
543                                                          'key'  => 'a_b',
544                                                          ddl    => 'KEY `a_b` (`a`,`b`),',
545                                                         },
546                                                         {
547                                                          'duplicate_of' => 'PRIMARY',
548                                                          'reason' => "Uniqueness of ua_b ignored because ua is a stronger constraint\nua_b is a duplicate of PRIMARY",
549                                                          dupe_type      => 'exact',
550                                                          'duplicate_of_cols' => [qw(a b)],
551                                                          duplicate_of_ddl    => 'PRIMARY KEY  (`a`,`b`),',
552                                                          'cols' => [qw(a b)],
553                                                          'key'  => 'ua_b',
554                                                          ddl    => 'UNIQUE KEY `ua_b` (`a`,`b`),',
555                                                         },
556                                                         {
557                                                          'duplicate_of' => 'PRIMARY',
558                                                          'reason' => "Uniqueness of ua_b2 ignored because ua is a stronger constraint\nua_b2 is a duplicate of PRIMARY",
559                                                          dupe_type      => 'exact',
560                                                          'duplicate_of_cols' => [qw(a b)],
561                                                          duplicate_of_ddl    => 'PRIMARY KEY  (`a`,`b`),',
562                                                          'cols' => [qw(a b)],
563                                                          'key'  => 'ua_b2',
564                                                          ddl    => 'UNIQUE KEY `ua_b2` (`a`,`b`),',
565                                                         }
566                                                      ],
567                                                      'Very pathological case',
568                                                   );
569                                                   
570                                                   # #############################################################################
571                                                   # Issue 269: mk-duplicate-key-checker: Wrongly suggesting removing index
572                                                   # #############################################################################
573            1                                 34   $ddl   = load_file('common/t/samples/issue_269-1.sql');
574            1                                 19   $dupes = [];
575            1                                 24   ($keys, $ck) = $tp->get_keys($ddl, $opt);
576            1                                604   $dk->get_duplicate_keys(
577                                                      $keys,
578                                                      clustered_key => $ck,
579                                                      callback => $callback);
580            1                                 10   is_deeply(
581                                                      $dupes,
582                                                      [
583                                                      ],
584                                                      'Keep stronger unique constraint that is prefix'
585                                                   );
586                                                   
587                                                   # #############################################################################
588                                                   # Issue 331: mk-duplicate-key-checker crashes when printing column types
589                                                   # #############################################################################
590            1                                 16   $ddl   = load_file('common/t/samples/issue_331.sql');
591            1                                 17   $dupes = [];
592            1                                 17   $dk->get_duplicate_fks(
593                                                      $tp->get_fks($ddl, {database => 'test'}),
594                                                      callback => $callback);
595            1                                 29   is_deeply(
596                                                      $dupes,
597                                                      [
598                                                         {
599                                                            'key'               => 'fk_1',
600                                                            'cols'              => [qw(id)],
601                                                            ddl                 => 'CONSTRAINT `fk_1` FOREIGN KEY (`id`) REFERENCES `issue_331_t1` (`t1_id`)',
602                                                            'duplicate_of'      => 'fk_2',
603                                                            'duplicate_of_cols' => [qw(id)],
604                                                            duplicate_of_ddl    => 'CONSTRAINT `fk_2` FOREIGN KEY (`id`) REFERENCES `issue_331_t1` (`t1_id`)',
605                                                            'reason'            => 'FOREIGN KEY fk_1 (`id`) REFERENCES `test`.`issue_331_t1` (`t1_id`) is a duplicate of FOREIGN KEY fk_2 (`id`) REFERENCES `test`.`issue_331_t1` (`t1_id`)',
606                                                            dupe_type      => 'fk',
607                                                         }
608                                                      ],
609                                                      'fk col not in referencing table (issue 331)'
610                                                   );
611                                                   
612                                                   # #############################################################################
613                                                   # Issue 295: Enhance rules for clustered keys in mk-duplicate-key-checker
614                                                   # #############################################################################
615            1                                 24   is(
616                                                      $dk->shorten_clustered_duplicate('`a`', '`b`,`a`'),
617                                                      '`b`',
618                                                      "shorten_clustered_duplicate('`a`', '`b`,`a`')"
619                                                   );
620                                                   
621            1                                 10   is(
622                                                      $dk->shorten_clustered_duplicate('`a`', '`a`'),
623                                                      '`a`',
624                                                      "shorten_clustered_duplicate('`a`', '`a`')"
625                                                   );
626                                                   
627            1                                 10   is(
628                                                      $dk->shorten_clustered_duplicate('`a`,`b`', '`c`,`a`,`b`'),
629                                                      '`c`',
630                                                      "shorten_clustered_duplicate('`a`,`b`', '`c`,`a`,`b`'),"
631                                                   );
632                                                   
633            1                                 10   $ddl   = load_file('common/t/samples/issue_295-1.sql');
634            1                                 28   $dupes = [];
635            1                                 30   ($keys, $ck) = $tp->get_keys($ddl, $opt);
636            1                                716   $dk->get_duplicate_keys(
637                                                      $keys,
638                                                      clustered_key => $ck,
639                                                      callback => $callback);
640            1                                 13   is_deeply(
641                                                      $dupes,
642                                                      [],
643                                                      'Do not remove clustered key acting as primary key'
644                                                   );
645                                                   
646                                                   # #############################################################################
647                                                   # Issue 904: Tables that confuse mk-duplicate-key-checker
648                                                   # #############################################################################
649            1                                 20   $ddl   = load_file("$sample/issue-904-1.txt");
650            1                                 30   $dupes = [];
651            1                                 17   ($keys, $ck) = $tp->get_keys($ddl, $opt);
652            1                               1285   $dk->get_duplicate_keys(
653                                                      $keys,
654                                                      clustered_key => $ck,
655                                                      clustered     => 1,
656                                                      tbl_info      => { engine => 'InnoDB', ddl => $ddl },
657                                                      callback      => $callback
658                                                   );
659                                                   
660            1                                 13   is_deeply(
661                                                      $dupes,
662                                                      [],
663                                                      'Clustered key with multiple columns (issue 904 1)'
664                                                   );
665                                                   
666            1                                 21   $ddl   = load_file("$sample/issue-904-2.txt");
667            1                                 20   $dupes = [];
668            1                                 14   ($keys, $ck) = $tp->get_keys($ddl, $opt);
669            1                               1325   $dk->get_duplicate_keys(
670                                                      $keys,
671                                                      clustered_key => $ck,
672                                                      clustered     => 1,
673                                                      tbl_info      => { engine => 'InnoDB', ddl => $ddl },
674                                                      callback      => $callback
675                                                   );
676                                                   
677            1                                 16   is_deeply(
678                                                      $dupes,
679                                                      [],
680                                                      'Clustered key with multiple columns (issue 904 2)'
681                                                   );
682                                                   
683                                                   # #############################################################################
684                                                   # Done.
685                                                   # #############################################################################
686            1                                 13   my $output = '';
687                                                   {
688            1                                  4      local *STDERR;
               1                                 11   
689            1                    1             3      open STDERR, '>', \$output;
               1                                537   
               1                                  4   
               1                                 12   
690            1                                 31      $dk->_d('Complete test coverage');
691                                                   }
692                                                   like(
693            1                                 34      $output,
694                                                      qr/Complete test coverage/,
695                                                      '_d() works'
696                                                   );
697            1                                  5   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location                
---------- ----- ------------------------
BEGIN          1 DuplicateKeyFinder.t:10 
BEGIN          1 DuplicateKeyFinder.t:11 
BEGIN          1 DuplicateKeyFinder.t:12 
BEGIN          1 DuplicateKeyFinder.t:14 
BEGIN          1 DuplicateKeyFinder.t:15 
BEGIN          1 DuplicateKeyFinder.t:16 
BEGIN          1 DuplicateKeyFinder.t:17 
BEGIN          1 DuplicateKeyFinder.t:4  
BEGIN          1 DuplicateKeyFinder.t:689
BEGIN          1 DuplicateKeyFinder.t:9  
__ANON__      19 DuplicateKeyFinder.t:26 


