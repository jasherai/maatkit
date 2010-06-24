---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/ReportFormatter.pm   94.6   76.2   82.1   94.7    0.0   95.6   87.2
ReportFormatter.t             100.0   50.0   33.3  100.0    n/a    4.4   97.6
Total                          96.5   75.6   78.6   96.4    0.0  100.0   89.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:18 2010
Finish:       Thu Jun 24 19:36:18 2010

Run:          ReportFormatter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:20 2010
Finish:       Thu Jun 24 19:36:20 2010

/home/daniel/dev/maatkit/common/ReportFormatter.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
18                                                    # ReportFormatter package $Revision: 6190 $
19                                                    # ###########################################################################
20                                                    package ReportFormatter;
21                                                    
22                                                    # This package produces formatted, columnized reports given variable-width
23                                                    # lines of data.  It does the hard work of resizing and truncating data
24                                                    # to fit the line width.  Unless all data fits the line (which doesn't happen
25                                                    # often), columns widths have to be adjusted to maximize line "real estate".
26                                                    # This involves the following magic.
27                                                    #
28                                                    # Internally, all column widths are *first* treated as percentages of the
29                                                    # line width. Even if a column is specified with width=>N where N is some
30                                                    # length of characters, this is converted to a percent/line width (rounded up).
31                                                    # 
32                                                    # Columns specified with width=>N or width_pct=>P (where P is some percent
33                                                    # of *total* line width, not remaining line width when used with other width=>N
34                                                    # columns) are fixed.  You get exactly what you specify even if this results
35                                                    # in the column header/name or values being truncated to fit.  Otherwise,
36                                                    # the column is "auto-width" and you get whatever the package gives you.
37                                                    #
38                                                    # add_line() keeps track of min and max column values.  When get_report() is
39                                                    # called, it calls _calculate_column_widths() which begins the magic.  It
40                                                    # converts each column's percentage width to characters, called the print width.
41                                                    # So width_pct=>50 == print_width=>39 (characters).  If the column is fixed
42                                                    # (i.e. *not* auto-width) then print width is fixed.  Otherwise, the print
43                                                    # width is adjusted as follows.
44                                                    #
45                                                    # The print width is set to the min val if, for some reason, it's less than
46                                                    # the min val.  This is so the column is at least wide enough to print the
47                                                    # minimum value.  Else, if there's a max val and the print val is wider than
48                                                    # it, then the print val is set to the max val.  This reclaims "extra space"
49                                                    # from auto-width cols.
50                                                    #
51                                                    # Extra space is distributed evenly among auto-width cols with print widths
52                                                    # less than the column's max val or header/name.  This widens auto-width cols
53                                                    # to either show longer values or truncate the column header/name less.
54                                                    # 
55                                                    # After these adjustments, get_report() calls _truncate_headers() and
56                                                    # _truncate_line_values().  These truncate output to the columns' final,
57                                                    # calculated widths.
58                                                    
59             1                    1             5   use strict;
               1                                  3   
               1                                  5   
60             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
61             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
62             1                    1             6   use List::Util qw(min max);
               1                                  6   
               1                                 11   
63             1                    1             9   use POSIX qw(ceil);
               1                                  3   
               1                                  7   
64                                                    
65                                                    eval { require Term::ReadKey };
66                                                    my $have_term = $EVAL_ERROR ? 0 : 1;
67                                                    
68    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 17   
69                                                    
70                                                    # Arguments:
71                                                    #  * underline_header     bool: underline headers with =
72                                                    #  * line_prefix          scalar: prefix every line with this string
73                                                    #  * line_width           scalar: line width in characters or 'auto'
74                                                    #  * column_spacing       scalar: string between columns (default one space)
75                                                    #  * extend_right         bool: allow right-most column to extend beyond
76                                                    #                               line width (default: no)
77                                                    #  * column_errors        scalar: die or warn on column errors (default warn)
78                                                    #  * truncate_header_side scalar: left or right (default left)
79                                                    sub new {
80    ***     14                   14      0     71      my ( $class, %args ) = @_;
81            14                                 45      my @required_args = qw();
82            14                                 55      foreach my $arg ( @required_args ) {
83    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
84                                                       }
85            14                                167      my $self = {
86                                                          underline_header     => 1,
87                                                          line_prefix          => '# ',
88                                                          line_width           => 78,
89                                                          column_spacing       => ' ',
90                                                          extend_right         => 0,
91                                                          truncate_line_mark   => '...',
92                                                          column_errors        => 'warn',
93                                                          truncate_header_side => 'left',
94                                                          %args,              # args above can be overriden, args below cannot
95                                                          n_cols              => 0,
96                                                       };
97                                                    
98                                                       # This is not tested or currently used, but I like the idea and
99                                                       # think one day it will be very handy in mk-config-diff.
100   ***     14     50     50                  104      if ( ($self->{line_width} || '') eq 'auto' ) {
101   ***      0      0                           0         die "Cannot auto-detect line width because the Term::ReadKey module "
102                                                            . "is not installed" unless $have_term;
103   ***      0                                  0         ($self->{line_width}) = GetTerminalSize();
104                                                      }
105           14                                 29      MKDEBUG && _d('Line width:', $self->{line_width});
106                                                   
107           14                                 95      return bless $self, $class;
108                                                   }
109                                                   
110                                                   sub set_title {
111   ***      9                    9      0     38      my ( $self, $title ) = @_;
112            9                                 36      $self->{title} = $title;
113            9                                 27      return;
114                                                   }
115                                                   
116                                                   # @cols is an array of hashrefs.  Each hashref describes a column and can
117                                                   # have the following keys:
118                                                   # Required args:
119                                                   #   * name           column's name
120                                                   # Optional args:
121                                                   #   * width              fixed column width in characters
122                                                   #   * width_pct          relative column width as percentage of line width
123                                                   #   * truncate           can truncate column (default yes)
124                                                   #   * truncate_mark      append string to truncate col vals (default ...)
125                                                   #   * truncate_side      truncate left or right side of value (default right)
126                                                   #   * truncate_callback  coderef to do truncation; overrides other truncate_*
127                                                   #   * undef_value        string for undef values (default '')
128                                                   sub set_columns {
129   ***     14                   14      0     62      my ( $self, @cols ) = @_;
130           14                                 41      my $min_hdr_wid = 0;  # check that header fits on line
131           14                                 35      my $used_width  = 0;
132           14                                 33      my @auto_width_cols;
133                                                   
134           14                                 79      for my $i ( 0..$#cols ) {
135           41                                119         my $col      = $cols[$i];
136           41                                130         my $col_name = $col->{name};
137           41                                105         my $col_len  = length $col_name;
138   ***     41     50                         147         die "Column does not have a name" unless defined $col_name;
139                                                   
140           41    100                         152         if ( $col->{width} ) {
141            2                                 41            $col->{width_pct} = ceil(($col->{width} * 100) / $self->{line_width});
142            2                                  5            MKDEBUG && _d('col:', $col_name, 'width:', $col->{width}, 'chars =',
143                                                               $col->{width_pct}, '%');
144                                                         }
145                                                   
146           41    100                         153         if ( $col->{width_pct} ) {
147           12                                 46            $used_width += $col->{width_pct};
148                                                         }
149                                                         else {
150                                                            # Auto-width columns get an equal share of whatever amount
151                                                            # of line width remains.  Later, they can be adjusted again.
152           29                                 61            MKDEBUG && _d('Auto width col:', $col_name);
153           29                                 93            $col->{auto_width} = 1;
154           29                                 84            push @auto_width_cols, $i;
155                                                         }
156                                                   
157                                                         # Set defaults if another value wasn't given.
158   ***     41     50                         196         $col->{truncate}        = 1 unless defined $col->{truncate};
159   ***     41     50                         208         $col->{truncate_mark}   = '...' unless defined $col->{truncate_mark};
160   ***     41            50                  176         $col->{truncate_side} ||= 'right';
161   ***     41     50                         204         $col->{undef_value}     = '' unless defined $col->{undef_value};
162                                                   
163                                                         # These values will be computed/updated as lines are added.
164           41                                123         $col->{min_val} = 0;
165           41                                118         $col->{max_val} = 0;
166                                                   
167                                                         # Calculate if the minimum possible header width will exceed the line.
168           41                                108         $min_hdr_wid        += $col_len;
169           41                                140         $col->{header_width} = $col_len;
170                                                   
171                                                         # Used with extend_right.
172           41    100                         185         $col->{right_most} = 1 if $i == $#cols;
173                                                   
174           41                                106         push @{$self->{cols}}, $col;
              41                                195   
175                                                      }
176                                                   
177           14                                 53      $self->{n_cols} = scalar @cols;
178                                                   
179   ***     14     50    100                  105      if ( ($used_width || 0) > 100 ) {
180   ***      0                                  0         die "Total width_pct for all columns is >100%";
181                                                      }
182                                                   
183                                                      # Divide remain line width (in %) among auto-width columns.
184           14    100                          52      if ( @auto_width_cols ) {
185           10                                 44         my $wid_per_col = int((100 - $used_width) / scalar @auto_width_cols);
186           10                                 24         MKDEBUG && _d('Line width left:', (100-$used_width), '%;',
187                                                            'each auto width col:', $wid_per_col, '%');
188           10                                 29         map { $self->{cols}->[$_]->{width_pct} = $wid_per_col } @auto_width_cols;
              29                                141   
189                                                      }
190                                                   
191                                                      # Add to the minimum possible header width the spacing between columns.
192           14                                 74      $min_hdr_wid += ($self->{n_cols} - 1) * length $self->{column_spacing};
193           14                                 31      MKDEBUG && _d('min header width:', $min_hdr_wid);
194           14    100                          63      if ( $min_hdr_wid > $self->{line_width} ) {
195            2                                  4         MKDEBUG && _d('Will truncate headers because min header width',
196                                                            $min_hdr_wid, '> line width', $self->{line_width});
197            2                                  7         $self->{truncate_headers} = 1;
198                                                      }
199                                                   
200           14                                 56      return;
201                                                   }
202                                                   
203                                                   # Add a line to the report.  Does not print the line or the report.
204                                                   # @vals is an array of values for each column.  There should be as
205                                                   # many vals as columns.  Use undef for columns that have no values.
206                                                   sub add_line {
207   ***     20                   20      0    101      my ( $self, @vals ) = @_;
208           20                                 57      my $n_vals = scalar @vals;
209   ***     20     50                          85      if ( $n_vals != $self->{n_cols} ) {
210   ***      0                                  0         $self->_column_error("Number of values $n_vals does not match "
211                                                            . "number of columns $self->{n_cols}");
212                                                      }
213           20                                 77      for my $i ( 0..($n_vals-1) ) {
214           62                                206         my $col   = $self->{cols}->[$i];
215           62    100                         249         my $val   = defined $vals[$i] ? $vals[$i] : $col->{undef_value};
216           62                                159         my $width = length $val;
217           62           100                  454         $col->{min_val} = min($width, ($col->{min_val} || $width));
218           62           100                  475         $col->{max_val} = max($width, ($col->{max_val} || $width));
219                                                      }
220           20                                 55      push @{$self->{lines}}, \@vals;
              20                                 89   
221           20                                 74      return;
222                                                   }
223                                                   
224                                                   # Returns the formatted report for the columns and lines added earlier.
225                                                   sub get_report {
226   ***     14                   14      0     47      my ( $self ) = @_;
227                                                   
228           14                                 54      $self->_calculate_column_widths();
229           14    100                          64      $self->_truncate_headers() if $self->{truncate_headers};
230           14                                 54      $self->_truncate_line_values();
231                                                   
232           14                                 59      my @col_fmts = $self->_make_column_formats();
233   ***     14            50                  102      my $fmt      = ($self->{line_prefix} || '')
234                                                                   . join($self->{column_spacing}, @col_fmts);
235           14                                 33      MKDEBUG && _d('Format:', $fmt);
236                                                   
237                                                      # Make the printf line format for the header and ensure that its labels
238                                                      # are always left justified.
239           14                                102      (my $hdr_fmt = $fmt) =~ s/%([^-])/%-$1/g;
240                                                   
241                                                      # Build the report line by line, starting with the title and header lines.
242           14                                 33      my @lines;
243           14    100                          95      push @lines, sprintf "$self->{line_prefix}$self->{title}" if $self->{title};
244           41                                201      push @lines, $self->_truncate_line(
245           14                                 45            sprintf($hdr_fmt, map { $_->{name} } @{$self->{cols}}),
              14                                 56   
246                                                            strip => 1,
247                                                            mark  => '',
248                                                      );
249                                                   
250   ***     14     50                          68      if ( $self->{underline_header} ) {
251           14                                 36         my @underlines = map { '=' x $_->{print_width} } @{$self->{cols}};
              41                                194   
              14                                 52   
252           14                                126         push @lines, $self->_truncate_line(
253                                                            sprintf($fmt, @underlines),
254                                                            mark  => '',
255                                                         );
256                                                      }
257                                                   
258           20                                 54      push @lines, map {
259           14                                 52         my $vals = $_;
260           20                                 46         my $i    = 0;
261           62    100                         266         my @vals = map {
262           20                                 61               defined $_ ? $_ : $self->{cols}->[$i++]->{undef_value}
263                                                         } @$vals;
264           20                                 88         my $line = sprintf($fmt, @vals);
265           20    100                          77         if ( $self->{extend_right} ) {
266            2                                  8            $line;
267                                                         }
268                                                         else {
269           18                                 58            $self->_truncate_line($line);
270                                                         }
271           14                                 37      } @{$self->{lines}};
272                                                   
273           14                                117      return join("\n", @lines) . "\n";
274                                                   }
275                                                   
276                                                   sub truncate_value {
277   ***     15                   15      0     73      my ( $self, $col, $val, $width, $side ) = @_;
278           15    100                          80      return $val if length $val <= $width;
279           13    100    100                   92      return $val if $col->{right_most} && $self->{extend_right};
280           12           100                   49      $side  ||= $col->{truncate_side};
281           12                                 38      my $mark = $col->{truncate_mark};
282           12    100                          50      if ( $side eq 'right' ) {
      ***            50                               
283            7                                 28         $val  = substr($val, 0, $width - length $mark);
284            7                                 21         $val .= $mark;
285                                                      }
286                                                      elsif ( $side eq 'left') {
287            5                                 25         $val = $mark . substr($val, -1 * $width + length $mark);
288                                                      }
289                                                      else {
290   ***      0                                  0         MKDEBUG && _d("I don't know how to", $side, "truncate values");
291                                                      }
292           12                                 52      return $val;
293                                                   }
294                                                   
295                                                   sub _calculate_column_widths {
296           14                   14            46      my ( $self ) = @_;
297                                                   
298           14                                 39      my $extra_space = 0;
299           14                                 36      foreach my $col ( @{$self->{cols}} ) {
              14                                 59   
300           41                                190         my $print_width = int($self->{line_width} * ($col->{width_pct} / 100));
301                                                   
302           41                                 85         MKDEBUG && _d('col:', $col->{name}, 'width pct:', $col->{width_pct},
303                                                            'char width:', $print_width,
304                                                            'min val:', $col->{min_val}, 'max val:', $col->{max_val});
305                                                   
306           41    100                         166         if ( $col->{auto_width} ) {
307           29    100    100                  328            if ( $col->{min_val} && $print_width < $col->{min_val} ) {
                    100    100                        
308            2                                  5               MKDEBUG && _d('Increased to min val width:', $col->{min_val});
309            2                                  6               $print_width = $col->{min_val};
310                                                            }
311                                                            elsif ( $col->{max_val} &&  $print_width > $col->{max_val} ) {
312           15                                 31               MKDEBUG && _d('Reduced to max val width:', $col->{max_val});
313           15                                 52               $extra_space += $print_width - $col->{max_val};
314           15                                 47               $print_width  = $col->{max_val};
315                                                            }
316                                                         }
317                                                   
318           41                                130         $col->{print_width} = $print_width;
319           41                                116         MKDEBUG && _d('print width:', $col->{print_width});
320                                                      }
321                                                   
322           14                                 33      MKDEBUG && _d('Extra space:', $extra_space);
323           14                                 58      while ( $extra_space-- ) {
324          251                                579         foreach my $col ( @{$self->{cols}} ) {
             251                                894   
325          803    100    100                 9881            if (    $col->{auto_width}
      ***                   66                        
326                                                                 && (    $col->{print_width} < $col->{max_val}
327                                                                      || $col->{print_width} < $col->{header_width})
328                                                            ) {
329                                                               # MKDEBUG && _d('Increased', $col->{name}, 'width');
330          136                                685               $col->{print_width}++;
331                                                            }
332                                                         }
333                                                      }
334                                                   
335           14                                 37      return;
336                                                   }
337                                                   
338                                                   sub _truncate_headers {
339            2                    2             8      my ( $self, $col ) = @_;
340            2                                  7      my $side = $self->{truncate_header_side};
341            2                                  6      foreach my $col ( @{$self->{cols}} ) {
               2                                  8   
342            4                                 13         my $col_name    = $col->{name};
343            4                                 13         my $print_width = $col->{print_width};
344   ***      4     50                          15         next if length $col_name <= $print_width;
345            4                                 16         $col->{name}  = $self->truncate_value($col, $col_name, $print_width, $side);
346            4                                 12         MKDEBUG && _d('Truncated hdr', $col_name, 'to', $col->{name},
347                                                            'max width:', $print_width);
348                                                      }
349            2                                  6      return;
350                                                   }
351                                                   
352                                                   sub _truncate_line_values {
353           14                   14            46      my ( $self ) = @_;
354           14                                 53      my $n_vals = $self->{n_cols} - 1;
355           14                                 34      foreach my $vals ( @{$self->{lines}} ) {
              14                                 63   
356           20                                 68         for my $i ( 0..$n_vals ) {
357           62                                232            my $col   = $self->{cols}->[$i];
358           62    100                         266            my $val   = defined $vals->[$i] ? $vals->[$i] : $col->{undef_value};
359           62                                161            my $width = length $val;
360                                                   
361   ***     62    100     66                  557            if ( $col->{print_width} && $width > $col->{print_width} ) {
362   ***      7     50                          28               if ( !$col->{truncate} ) {
363   ***      0                                  0                  $self->_column_error("Value '$val' is too wide for column "
364                                                                     . $col->{name});
365                                                               }
366                                                   
367                                                               # If _column_error() dies then we never get here.  If it warns
368                                                               # then we truncate the value despite $col->{truncate} being
369                                                               # false so the user gets something rather than nothing.
370            7                                 21               my $callback  = $self->{truncate_callback};
371            7                                 21               my $print_width = $col->{print_width};
372   ***      7     50                          37               $val = $callback ? $callback->($col, $val, $print_width)
373                                                                    :             $self->truncate_value($col, $val, $print_width);
374            7                                 17               MKDEBUG && _d('Truncated val', $vals->[$i], 'to', $val,
375                                                                  '; max width:', $print_width);
376            7                                 33               $vals->[$i] = $val;
377                                                            }
378                                                         }
379                                                      }
380           14                                 39      return;
381                                                   }
382                                                   
383                                                   # Make the printf line format for each row given the columns' settings.
384                                                   sub _make_column_formats {
385           14                   14            50      my ( $self ) = @_;
386           14                                 32      my @col_fmts;
387           14                                 49      my $n_cols = $self->{n_cols} - 1;
388           14                                 49      for my $i ( 0..$n_cols ) {
389           41                                144         my $col = $self->{cols}->[$i];
390                                                   
391                                                         # Normally right-most col has no width so it can potentially
392                                                         # extend_right.  But if it's right-justified, it requires a width.
393   ***     41    100     66                  271         my $width = $col->{right_most} && !$col->{right_justify} ? ''
394                                                                   : $col->{print_width};
395                                                   
396           41    100                         188         my $col_fmt  = '%' . ($col->{right_justify} ? '' : '-') . $width . 's';
397           41                                157         push @col_fmts, $col_fmt;
398                                                      }
399           14                                 98      return @col_fmts;
400                                                   }
401                                                   
402                                                   sub _truncate_line {
403           46                   46           235      my ( $self, $line, %args ) = @_;
404           46    100                         234      my $mark = defined $args{mark} ? $args{mark} : $self->{truncate_line_mark};
405   ***     46     50                         155      if ( $line ) {
406           46    100                         231         $line =~ s/\s+$// if $args{strip};
407           46                                123         my $len  = length($line);
408           46    100                         203         if ( $len > $self->{line_width} ) {
409           17                                 76            $line  = substr($line, 0, $self->{line_width} - length $mark);
410           17    100                          65            $line .= $mark if $mark;
411                                                         }
412                                                      }
413           46                                209      return $line;
414                                                   }
415                                                   
416                                                   sub _column_error {
417   ***      0                    0             0      my ( $self, $err ) = @_;
418   ***      0                                  0      my $msg = "Column error: $err";
419   ***      0      0                           0      $self->{column_errors} eq 'die' ? die $msg : warn $msg;
420   ***      0                                  0      return;
421                                                   }
422                                                   
423                                                   sub _d {
424            1                    1             8      my ($package, undef, $line) = caller 0;
425   ***      2     50                          10      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  7   
               2                                 11   
426            1                                  6           map { defined $_ ? $_ : 'undef' }
427                                                           @_;
428            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
429                                                   }
430                                                   
431                                                   1;
432                                                   
433                                                   # ###########################################################################
434                                                   # End ReportFormatter package
435                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
83    ***      0      0      0   unless $args{$arg}
100   ***     50      0     14   if (($$self{'line_width'} || '') eq 'auto')
101   ***      0      0      0   unless $have_term
138   ***     50      0     41   unless defined $col_name
140          100      2     39   if ($$col{'width'})
146          100     12     29   if ($$col{'width_pct'}) { }
158   ***     50     41      0   unless defined $$col{'truncate'}
159   ***     50     41      0   unless defined $$col{'truncate_mark'}
161   ***     50     41      0   unless defined $$col{'undef_value'}
172          100     14     27   if $i == $#cols
179   ***     50      0     14   if (($used_width || 0) > 100)
184          100     10      4   if (@auto_width_cols)
194          100      2     12   if ($min_hdr_wid > $$self{'line_width'})
209   ***     50      0     20   if ($n_vals != $$self{'n_cols'})
215          100     59      3   defined $vals[$i] ? :
229          100      2     12   if $$self{'truncate_headers'}
243          100      9      5   if $$self{'title'}
250   ***     50     14      0   if ($$self{'underline_header'})
261          100     59      3   defined $_ ? :
265          100      2     18   if ($$self{'extend_right'}) { }
278          100      2     13   if length $val <= $width
279          100      1     12   if $$col{'right_most'} and $$self{'extend_right'}
282          100      7      5   if ($side eq 'right') { }
      ***     50      5      0   elsif ($side eq 'left') { }
306          100     29     12   if ($$col{'auto_width'})
307          100      2     27   if ($$col{'min_val'} and $print_width < $$col{'min_val'}) { }
             100     15     12   elsif ($$col{'max_val'} and $print_width > $$col{'max_val'}) { }
325          100    136    667   if ($$col{'auto_width'} and $$col{'print_width'} < $$col{'max_val'} || $$col{'print_width'} < $$col{'header_width'})
344   ***     50      0      4   if length $col_name <= $print_width
358          100     59      3   defined $$vals[$i] ? :
361          100      7     55   if ($$col{'print_width'} and $width > $$col{'print_width'})
362   ***     50      0      7   if (not $$col{'truncate'})
372   ***     50      0      7   $callback ? :
393          100     14     27   $$col{'right_most'} && !$$col{'right_justify'} ? :
396          100      4     37   $$col{'right_justify'} ? :
404          100     28     18   defined $args{'mark'} ? :
405   ***     50     46      0   if ($line)
406          100     14     32   if $args{'strip'}
408          100     17     29   if ($len > $$self{'line_width'})
410          100      4     13   if $mark
419   ***      0      0      0   $$self{'column_errors'} eq 'die' ? :
425   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
279          100      7      5      1   $$col{'right_most'} and $$self{'extend_right'}
307          100      9     18      2   $$col{'min_val'} and $print_width < $$col{'min_val'}
             100      9      3     15   $$col{'max_val'} and $print_width > $$col{'max_val'}
325   ***     66      0    667    136   $$col{'auto_width'} and $$col{'print_width'} < $$col{'max_val'} || $$col{'print_width'} < $$col{'header_width'}
361   ***     66      0     55      7   $$col{'print_width'} and $width > $$col{'print_width'}
393   ***     66     27      0     14   $$col{'right_most'} && !$$col{'right_justify'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
68    ***     50      0      1   $ENV{'MKDEBUG'} || 0
100   ***     50     14      0   $$self{'line_width'} || ''
160   ***     50      0     41   $$col{'truncate_side'} ||= 'right'
179          100      5      9   $used_width || 0
233   ***     50     14      0   $$self{'line_prefix'} || ''
280          100      4      8   $side ||= $$col{'truncate_side'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
217          100     24     29      9   $$col{'min_val'} || $width
218          100     24     29      9   $$col{'max_val'} || $width
325          100     78     58    667   $$col{'print_width'} < $$col{'max_val'} || $$col{'print_width'} < $$col{'header_width'}


Covered Subroutines
-------------------

Subroutine               Count Pod Location                                              
------------------------ ----- --- ------------------------------------------------------
BEGIN                        1     /home/daniel/dev/maatkit/common/ReportFormatter.pm:59 
BEGIN                        1     /home/daniel/dev/maatkit/common/ReportFormatter.pm:60 
BEGIN                        1     /home/daniel/dev/maatkit/common/ReportFormatter.pm:61 
BEGIN                        1     /home/daniel/dev/maatkit/common/ReportFormatter.pm:62 
BEGIN                        1     /home/daniel/dev/maatkit/common/ReportFormatter.pm:63 
BEGIN                        1     /home/daniel/dev/maatkit/common/ReportFormatter.pm:68 
_calculate_column_widths    14     /home/daniel/dev/maatkit/common/ReportFormatter.pm:296
_d                           1     /home/daniel/dev/maatkit/common/ReportFormatter.pm:424
_make_column_formats        14     /home/daniel/dev/maatkit/common/ReportFormatter.pm:385
_truncate_headers            2     /home/daniel/dev/maatkit/common/ReportFormatter.pm:339
_truncate_line              46     /home/daniel/dev/maatkit/common/ReportFormatter.pm:403
_truncate_line_values       14     /home/daniel/dev/maatkit/common/ReportFormatter.pm:353
add_line                    20   0 /home/daniel/dev/maatkit/common/ReportFormatter.pm:207
get_report                  14   0 /home/daniel/dev/maatkit/common/ReportFormatter.pm:226
new                         14   0 /home/daniel/dev/maatkit/common/ReportFormatter.pm:80 
set_columns                 14   0 /home/daniel/dev/maatkit/common/ReportFormatter.pm:129
set_title                    9   0 /home/daniel/dev/maatkit/common/ReportFormatter.pm:111
truncate_value              15   0 /home/daniel/dev/maatkit/common/ReportFormatter.pm:277

Uncovered Subroutines
---------------------

Subroutine               Count Pod Location                                              
------------------------ ----- --- ------------------------------------------------------
_column_error                0     /home/daniel/dev/maatkit/common/ReportFormatter.pm:417


ReportFormatter.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1             9   use Test::More tests => 20;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use Transformers;
               1                                  2   
               1                                 11   
15             1                    1            10   use ReportFormatter;
               1                                  4   
               1                                 10   
16             1                    1            12   use MaatkitTest;
               1                                  6   
               1                                 39   
17                                                    
18             1                                  4   my $rf;
19                                                    
20             1                                  7   $rf = new ReportFormatter();
21                                                    
22             1                                  8   isa_ok($rf, 'ReportFormatter');
23                                                    
24                                                    # #############################################################################
25                                                    # truncate_value()
26                                                    # #############################################################################
27             1                                 15   is(
28                                                       $rf->truncate_value(
29                                                          {truncate_mark=>'...', truncate_side=>'right'},
30                                                          "hello world",
31                                                          7,
32                                                       ),
33                                                       "hell...",
34                                                       "truncate_value(), right side"
35                                                    );
36                                                    
37             1                                 15   is(
38                                                       $rf->truncate_value(
39                                                          {truncate_mark=>'...', truncate_side=>'left'},
40                                                          "hello world",
41                                                          7,
42                                                       ),
43                                                       "...orld",
44                                                       "truncate_value(), left side"
45                                                    );
46                                                    
47             1                                 16   is(
48                                                       $rf->truncate_value(
49                                                          {truncate_mark=>'...', truncate_side=>'left'},
50                                                          "hello world",
51                                                          11,
52                                                       ),
53                                                       "hello world",
54                                                       "truncate_value(), max width == val width"
55                                                    );
56                                                    
57             1                                 12   is(
58                                                       $rf->truncate_value(
59                                                          {truncate_mark=>'...', truncate_side=>'left'},
60                                                          "hello world",
61                                                          100,
62                                                       ),
63                                                       "hello world",
64                                                       "truncate_value(), max width > val width"
65                                                    );
66                                                    
67                                                    # #############################################################################
68                                                    # Basic report.
69                                                    # #############################################################################
70             1                                  8   $rf->set_title('Checksum differences');
71             1                                 17   $rf->set_columns(
72                                                       {
73                                                          name        => 'Query ID',
74                                                          width_fixed => length '0x234DDDAC43820481-3',
75                                                       },
76                                                       {
77                                                          name => 'db-1.foo.com',
78                                                       },
79                                                       {
80                                                          name => '123.123.123.123',
81                                                       },
82                                                    );
83                                                    
84             1                                  8   $rf->add_line(qw(0x3A99CC42AEDCCFCD-1  ABC12345  ADD12345));
85             1                                  5   $rf->add_line(qw(0x234DDDAC43820481-3  0007C99B  BB008171));
86                                                    
87             1                                  6   is(
88                                                       $rf->get_report(),
89                                                    "# Checksum differences
90                                                    # Query ID             db-1.foo.com 123.123.123.123
91                                                    # ==================== ============ ===============
92                                                    # 0x3A99CC42AEDCCFCD-1 ABC12345     ADD12345
93                                                    # 0x234DDDAC43820481-3 0007C99B     BB008171
94                                                    ",
95                                                       'Basic report'
96                                                    );
97                                                    
98                                                    # #############################################################################
99                                                    # Header that's too wide.
100                                                   # #############################################################################
101            1                                  7   $rf = new ReportFormatter();
102            1                                 20   $rf->set_columns(
103                                                      { name => 'We are very long header columns that are going to cause', },
104                                                      { name => 'this sub to die because together we cannot fit on one line' },
105                                                   );
106            1                                  6   is(
107                                                      $rf->get_report(),
108                                                   "# ...ader columns that are going to cause ...e together we cannot fit on one l
109                                                   # ======================================= ====================================
110                                                   ",
111                                                      "Full auto-fit columns to line"
112                                                   );
113                                                   
114            1                                  7   $rf = new ReportFormatter();
115            1                                 16   $rf->set_columns(
116                                                      {
117                                                         name      => 'We are very long header columns that are going to cause',
118                                                         width_pct => 40,
119                                                      },
120                                                      {
121                                                         name      => 'this sub to die because together we cannot fit on one line',
122                                                         width_pct => 60,
123                                                      },
124                                                   );
125                                                   
126            1                                  5   is(
127                                                      $rf->get_report(),
128                                                   "# ...umns that are going to cause ... because together we cannot fit on one li
129                                                   # =============================== ============================================
130                                                   ",
131                                                      "Two fixed percentage-width columsn"
132                                                   );
133                                                   
134            1                                  6   $rf = new ReportFormatter();
135            1                                 16   $rf->set_columns(
136                                                      {
137                                                         name  => 'header1',
138                                                         width => 7,
139                                                      },
140                                                      { name => 'this long line should take up the rest of the line.......!', },
141                                                   );
142                                                   
143            1                                  5   is(
144                                                      $rf->get_report(),
145                                                   "# header1 this long line should take up the rest of the line.......!
146                                                   # ======= ====================================================================
147                                                   ",
148                                                      "One fixed char-width column and one auto-width column"
149                                                   );
150                                                   
151                                                   # #############################################################################
152                                                   # Test that header underline respects line width.
153                                                   # #############################################################################
154            1                                  6   $rf = new ReportFormatter();
155            1                                 17   $rf->set_columns(
156                                                      { name => 'col1' },
157                                                      { name => 'col2' },
158                                                   );
159            1                                  7   $rf->add_line('short', 'long long long long long long long long long long long long long long long long long long');
160                                                   
161            1                                  5   is(
162                                                      $rf->get_report(),
163                                                   "# col1  col2
164                                                   # ===== ======================================================================
165                                                   # short long long long long long long long long long long long long long lo...
166                                                   ",
167                                                      'Truncate header underlining to line width'
168                                                   );
169                                                   
170                                                   # #############################################################################
171                                                   # Test taht header labels are always left justified.
172                                                   # #############################################################################
173            1                                  6   $rf = new ReportFormatter();
174            1                                 22   $rf->set_columns(
175                                                      { name => 'Rank',          right_justify => 1, },
176                                                      { name => 'Query ID',                          },
177                                                      { name => 'Response time', right_justify => 1, },
178                                                      { name => 'Calls',         right_justify => 1, },
179                                                      { name => 'R/Call',        right_justify => 1, },
180                                                      { name => 'Item',                              },
181                                                   );
182            1                                  7   $rf->add_line(
183                                                      '123456789', '0x31DA25F95494CA95', '0.1494 99.9%', '1', '0.1494', 'SHOW');
184                                                   
185            1                                  4   is(
186                                                      $rf->get_report(),
187                                                   "# Rank      Query ID           Response time Calls R/Call Item
188                                                   # ========= ================== ============= ===== ====== ====
189                                                   # 123456789 0x31DA25F95494CA95  0.1494 99.9%     1 0.1494 SHOW
190                                                   ",
191                                                      'Header labels are always left justified'
192                                                   );
193                                                   
194                                                   # #############################################################################
195                                                   # Respect line width.
196                                                   # #############################################################################
197            1                                 19   $rf = new ReportFormatter();
198            1                                 19   $rf->set_title('Respect line width');
199            1                                  8   $rf->set_columns(
200                                                      { name => 'col1' },
201                                                      { name => 'col2' },
202                                                      { name => 'col3' },
203                                                   );
204            1                                  5   $rf->add_line(
205                                                      'short',
206                                                      'longer',
207                                                      'long long long long long long long long long long long long long long long long long long'
208                                                   );
209            1                                  5   $rf->add_line(
210                                                      'a',
211                                                      'b',
212                                                      'c',
213                                                   );
214                                                   
215            1                                  5   is(
216                                                      $rf->get_report(),
217                                                   "# Respect line width
218                                                   # col1  col2   col3
219                                                   # ===== ====== ===============================================================
220                                                   # short longer long long long long long long long long long long long long ...
221                                                   # a     b      c
222                                                   ",
223                                                      'Respects line length'
224                                                   );
225                                                   
226                                                   # #############################################################################
227                                                   # extend_right
228                                                   # #############################################################################
229            1                                  7   $rf = new ReportFormatter(extend_right=>1);
230            1                                 17   $rf->set_title('extend_right');
231            1                                  8   $rf->set_columns(
232                                                      { name => 'col1' },
233                                                      { name => 'col2' },
234                                                      { name => 'col3' },
235                                                   );
236            1                                  5   $rf->add_line(
237                                                      'short',
238                                                      'longer',
239                                                      'long long long long long long long long long long long long long long long long long long'
240                                                   );
241            1                                  5   $rf->add_line(
242                                                      'a',
243                                                      'b',
244                                                      'c',
245                                                   );
246                                                   
247            1                                  5   is(
248                                                      $rf->get_report(),
249                                                   "# extend_right
250                                                   # col1  col2   col3
251                                                   # ===== ====== ===============================================================
252                                                   # short longer long long long long long long long long long long long long long long long long long long
253                                                   # a     b      c
254                                                   ",
255                                                      "Allow right-most column to extend beyond line width"
256                                                   );
257                                                   
258                                                   # #############################################################################
259                                                   # Relvative column widths.
260                                                   # #############################################################################
261            1                                  6   $rf = new ReportFormatter();
262            1                                 17   $rf->set_title('Relative col widths');
263            1                                 10   $rf->set_columns(
264                                                      { name => 'col1', width_pct=>'20', },
265                                                      { name => 'col2', width_pct=>'40', },
266                                                      { name => 'col3', width_pct=>'40',  },
267                                                   );
268            1                                  5   $rf->add_line(
269                                                      'shortest',
270                                                      'a b c d e f g h i j k l m n o p',
271                                                      'seoncd longest line',
272                                                   );
273            1                                  4   $rf->add_line(
274                                                      'x',
275                                                      'y',
276                                                      'z',
277                                                   );
278                                                   
279            1                                  5   is(
280                                                      $rf->get_report(),
281                                                   "# Relative col widths
282                                                   # col1            col2                            col3
283                                                   # =============== =============================== ============================
284                                                   # shortest        a b c d e f g h i j k l m n o p seoncd longest line
285                                                   # x               y                               z
286                                                   ",
287                                                      "Relative col widths that fit"
288                                                   );
289                                                   
290            1                                  7   $rf = new ReportFormatter();
291            1                                 17   $rf->set_title('Relative col widths');
292            1                                 10   $rf->set_columns(
293                                                      { name => 'col1', width_pct=>'20', },
294                                                      { name => 'col2', width_pct=>'40', },
295                                                      { name => 'col3', width_pct=>'40',  },
296                                                   );
297            1                                  6   $rf->add_line(
298                                                      'shortest',
299                                                      'a b c d e f g h i j k l m n o p',
300                                                      'seoncd longest line',
301                                                   );
302            1                                  5   $rf->add_line(
303                                                      'x',
304                                                      'y',
305                                                      'z',
306                                                   );
307            1                                  5   $rf->add_line(
308                                                      'this line is going to have to be truncated because it is too long',
309                                                      'this line is ok',
310                                                      'and this line will have to be truncated, too',
311                                                   );
312                                                   
313            1                                  5   is(
314                                                      $rf->get_report(),
315                                                   "# Relative col widths
316                                                   # col1            col2                            col3
317                                                   # =============== =============================== ============================
318                                                   # shortest        a b c d e f g h i j k l m n o p seoncd longest line
319                                                   # x               y                               z
320                                                   # this line is... this line is ok                 and this line will have t...
321                                                   ",
322                                                      "Relative columns made smaller to fit"
323                                                   );
324                                                   
325            1                                 11   $rf = new ReportFormatter();
326            1                                 15   $rf->set_title('Relative col widths');
327            1                                 10   $rf->set_columns(
328                                                      { name => 'col1', width    =>'25', },
329                                                      { name => 'col2', width_pct=>'33', },
330                                                      { name => 'col3', width_pct=>'33', },
331                                                   );
332            1                                  5   $rf->add_line(
333                                                      'shortest',
334                                                      'a b c d e f g h i j k l m n o p',
335                                                      'seoncd longest line',
336                                                   );
337            1                                  5   $rf->add_line(
338                                                      'x',
339                                                      'y',
340                                                      'z',
341                                                   );
342            1                                  5   $rf->add_line(
343                                                      '1234567890123456789012345xxxxxx',
344                                                      'this line is ok',
345                                                      'and this line will have to be truncated, too',
346                                                   );
347                                                   
348            1                                  4   is(
349                                                      $rf->get_report(),
350                                                   "# Relative col widths
351                                                   # col1                      col2                      col3
352                                                   # ========================= ========================= ========================
353                                                   # shortest                  a b c d e f g h i j k ... seoncd longest line
354                                                   # x                         y                         z
355                                                   # 1234567890123456789012... this line is ok           and this line will ha...
356                                                   ",
357                                                      "Fixed and relative columns"
358                                                   );
359                                                   
360                                                   
361            1                                  6   $rf = new ReportFormatter();
362            1                                 15   $rf->set_title('Short cols');
363            1                                  8   $rf->set_columns(
364                                                      { name => 'I am column1', },
365                                                      { name => 'I am column2', },
366                                                      { name => "I don't know who I am", },
367                                                   );
368            1                                  5   $rf->add_line(
369                                                      '',
370                                                      '',
371                                                      '',
372                                                   );
373                                                   
374            1                                  4   is(
375                                                      $rf->get_report(),
376                                                   "# Short cols
377                                                   # I am column1              I am column2              I don't know who I am
378                                                   # ========================= ========================= ========================
379                                                   #                                                     
380                                                   ",
381                                                      "Short columsn, blank data"
382                                                   );
383                                                   
384            1                                  7   $rf = new ReportFormatter();
385            1                                 13   $rf->set_title('Short cols');
386            1                                  8   $rf->set_columns(
387                                                      { name => 'I am column1', },
388                                                      { name => 'I am column2', },
389                                                      { name => "I don't know who I am", },
390                                                   );
391            1                                  5   $rf->add_line(undef,undef,undef);
392                                                   
393            1                                  5   is(
394                                                      $rf->get_report(),
395                                                   "# Short cols
396                                                   # I am column1              I am column2              I don't know who I am
397                                                   # ========================= ========================= ========================
398                                                   #                                                     
399                                                   ",
400                                                      "Short columsn, undef data"
401                                                   );
402                                                   
403            1                                  7   $rf = new ReportFormatter();
404            1                                 18   $rf->set_title('Short cols');
405            1                                  8   $rf->set_columns(
406                                                      { name => 'I am column1', },
407                                                      { name => 'I am column2', },
408                                                      { name => "I don't know who I am", },
409                                                   );
410            1                                  6   $rf->add_line('','','');
411            1                                  5   $rf->add_line(qw(a b c));
412                                                   
413            1                                  5   is(
414                                                      $rf->get_report(),
415                                                   "# Short cols
416                                                   # I am column1 I am column2 I don't know who I am
417                                                   # ============ ============ =====================
418                                                   #                           
419                                                   # a            b            c
420                                                   ",
421                                                      "Short columsn, blank and short data"
422                                                   );
423                                                   
424                                                   # #############################################################################
425                                                   # Done.
426                                                   # #############################################################################
427            1                                  4   my $output = '';
428                                                   {
429            1                                  3      local *STDERR;
               1                                  8   
430            1                    1             2      open STDERR, '>', \$output;
               1                                302   
               1                                  2   
               1                                  7   
431            1                                 16      $rf->_d('Complete test coverage');
432                                                   }
433                                                   like(
434            1                                 24      $output,
435                                                      qr/Complete test coverage/,
436                                                      '_d() works'
437                                                   );
438            1                                  3   exit;


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
---------- ----- ---------------------
BEGIN          1 ReportFormatter.t:10 
BEGIN          1 ReportFormatter.t:11 
BEGIN          1 ReportFormatter.t:12 
BEGIN          1 ReportFormatter.t:14 
BEGIN          1 ReportFormatter.t:15 
BEGIN          1 ReportFormatter.t:16 
BEGIN          1 ReportFormatter.t:4  
BEGIN          1 ReportFormatter.t:430
BEGIN          1 ReportFormatter.t:9  


