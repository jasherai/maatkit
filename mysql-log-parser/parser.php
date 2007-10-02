#!/usr/bin/php
<?php

/**
 * MyProfi is mysql profiler and anlyzer, which outputs statistics of mostly
 * used queries by reading query log file.
 *
 * Copyright (C) 2006 camka at camka@users.sourceforge.net
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * @author camka
 * @package MyProfi
 */


/**
 * Normalize query: remove variable data and replace it with {}
 *
 * @param string $q
 * @return string
 */
function normalize($q)
{
	$query = $q;
	$query = preg_replace("/\\/\\*.*\\*\\//sU", '', $query);                       // remove multiline comments
	$query = preg_replace("/([\"'])(?:\\\\.|\\1\\1|.)*\\1/sU", "{}", $query);      // remove quoted strings
	$query = preg_replace("/(\\W)(?:-?\\d+(?:\\.\\d+)?)/", "\\1{}", $query);       // remove numbers
	$query = preg_replace("/(\\W)null(?:\\Wnull)*(\\W|\$)/i", "\\1{}\\2", $query); // remove nulls
	$query = str_replace (array("\\n", "\\t", "\\0"), ' ', $query);                // replace escaped linebreaks
	$query = preg_replace("/\\s+/", ' ', $query);                                  // remove multiple spaces
	$query = preg_replace("/ (\\W)/","\\1", $query);                               // remove spaces bordering with non-characters
	$query = preg_replace("/(\\W) /","\\1", $query);                               // --,--
	$query = preg_replace("/\\{\\}(?:,?\\{\\})+/", "{}", $query);                   // repetitive {},{} to single {}
	$query = preg_replace("/\\(\\{\\}\\)(?:,\\(\\{\\}\\))+/", "({})", $query);     // repetitive ({}),({}) to single ({})
	$query = strtolower(trim($query," \t\n)("));                                     // trim spaces and strolower
	return $query;
}

/**
 * Output program usage doc and die
 *
 * @param string $msg - describing message
 */
function doc($msg = null)
{
	file_put_contents('php://stderr', (!is_null($msg) ? ($msg."\n\n") : '').

'MyProfi: mysql log profiler and analyzer

Usage: php parser.php [OPTIONS] INPUTFILE

Options:
-top N
	Output only N top queries
-type "query types"
	Ouput only statistics for the queries of given query types.
	Query types are comma separated words that queries may begin with
-sample
	Output one sample query per each query pattern to be able to use it
	with EXPLAIN query to analyze its performance
-csv
	Consideres an input file to be in csv format
	Note, that if the input file extension is .csv, it is also considered as csv
-slow
	Treats an input file as a slow query log
-sort CRITERIA
	Sort output statistics by given CRITERIA.
	Works only for slow query log format.
	Possible values of CRITERIA: qt_total | qt_avg | qt_max | lt_total | lt_avg | lt_max | rs_total
	 rs_avg | rs_max | re_total | re_avg | re_max,
	 where two-letter prefix stands for "Query time", "Lock time", "Rows sent", "Rows executed"
	 values taken from data provided by sloq query log respectively.
	 Suffix after _ character tells MyProfi to take total, maximum or average
	 calculated values.

Example:
	php parser.php -csv -top 10 -type "select, update" general_log.csv
');
	exit;
}

/**
 * Interface for all query fetchers
 *
 */
interface query_fetcher
{
	/**
	 * Get next query in the flow
	 *
	 */
	public function get_query();
}

/**
 * General filereader class
 *
 */
abstract class filereader
{
	/**
	 * File pointer
	 *
	 * @var resource
	 */
	public $fp;

	/**
	 * Attempts to open a file
	 * Dies on failure
	 *
	 * @param string $filename
	 */
	public function __construct($filename)
	{
		if (false === ($this->fp = @fopen($filename, "rb")))
		{
			doc('Error: cannot open input file '.$filename);
		}
	}

	/**
	 * Close file on exit
	 *
	 */
	public function __destruct()
	{
		if ($this->fp)
			fclose($this->fp);
	}
}

/**
 * Extracts normalized queries from mysql query log one by one
 *
 */
class extractor extends filereader implements query_fetcher
{
	/**
	 * Fetch the next query pattern from stream
	 *
	 * @return string
	 */
	public function get_query()
	{
		static $newline;

		$return = $newline;
		$newline = null;

		$fp = $this->fp;

		while(($line = fgets($fp)))
		{
			$line = rtrim($line,"\r\n");

			// skip server start log lines
			if (substr($line, -13) == "started with:")
			{
				fgets($fp); // skip TCP Port: 3306, Named Pipe: (null)
				fgets($fp); // skip Time                 Id Command    Argument
				continue;
			}

			$matches = array();
			if(preg_match("/^(?:\\d{6} {1,2}\\d{1,2}:\\d{2}:\\d{2}|\t)\t +\\d+ (\\w+)/", $line, $matches))
			{
				// if log line
				$type = $matches[1];
				switch($type)
				{
					case 'Query':
						if($return)
						{
							$newline = ltrim(substr($line, strpos($line, "Q") + 5)," \t");
							break 2;
						}
						else
						{
							$return = ltrim(substr($line, strpos($line, "Q") + 5)," \t");
							break;
						}
					case 'Execute':
						if($return)
						{
							$newline = ltrim(substr($line, strpos($line, ']') + 1), " \t");
							break 2;
						}
						else
						{
							$return = ltrim(substr($line, strpos($line, ']') + 1), " \t");
							break;
						}
					default:
						if ($return)
							break 2;
						else
							break;
				}
			}
			else
			{
				$return .= $line;
			}
		}

		return ($return === '' || is_null($return)? false : $return);
	}
}

/**
 * Extracts normalized queries from mysql slow query log one by one
 *
 */
class slow_extractor extends filereader implements query_fetcher
{
	protected $stat = array();

	/**
	 * Fetch the next query pattern from stream
	 *
	 * @return string
	 */
	public function get_query()
	{
		$currstatement = '';

		$fp = $this->fp;

		while(($line = fgets($fp)))
		{
			$line = rtrim($line,"\r\n");

			if (($smth = $this->is_separator($line, $fp)))
			{
				if (is_array($smth))
					$this->stat = $smth;

				if ($currstatement !== '')
				{
					return array_merge($this->stat, array($currstatement));
				}
			}
			else
			{
				$currstatement .= $line;
			}
		}

		if ($currstatement !== '')
			return array_merge($this->stat, array($currstatement));
		else
			return false;
	}

	protected function is_separator(&$line, $fp)
	{
		// skip server start log lines
		/*
		/usr/sbin/mysqld, Version: 5.0.26-log. started with:
		Tcp port: 3306  Unix socket: /var/lib/mysql/mysqldb/mysql.sock
		Time                 Id Command    Argument
		*/
		if (substr($line, -13) == "started with:")
		{
			fgets($fp); // skip TCP Port: 3306, Named Pipe: (null)
			fgets($fp); // skip Time                 Id Command    Argument
			return true;
		}

		// skip command information
		# Time: 070103 16:53:22
		# User@Host: photo[photo] @ dopey [192.168.16.70]
		# Query_time: 14  Lock_time: 0  Rows_sent: 93  Rows_examined: 3891399

		$linestart = substr($line, 0, 14);

		if (!strncmp($linestart, '# Time: ', 8)
			|| !strncmp($line, '# User@Host: ', 13))
			return true;

		if (!strncmp($line, '# Query_time: ', 14))
		{
			$matches = array();

			// floating point numbers matching is needed for
			// www.mysqlperformanceblog.com slow query patch
			preg_match('/Query_time: +(\\d*(?:\\.d+)?) +Lock_time: +(\\d*(?:\\.d+)?) +Rows_sent: +(\\d*(?:\\.d+)?) +Rows_examined: +(\\d*(?:\\.d+)?)/', $line, $matches);

			// shift the whole matched string element
			// leaving only numbers we need
			array_shift($matches);
			$arr = array(
				'qt'=>array_shift($matches),
				'lt'=>array_shift($matches),
				'rs'=>array_shift($matches),
				're'=>array_shift($matches),
				);
			return $arr;
		}

		if (preg_match('/(?:^use [^ ]+;$)|(?:^SET timestamp=\\d+;$)/', $line))
			return true;

		return false;
	}
}

/**
 * Read mysql query log in csv format (as of mysql 5.1 it by default)
 *
 */
class csvreader extends filereader implements query_fetcher
{
	/**
	 * Fetch next query from csv file
	 *
	 * @return string - or FALSE on file end
	 */
	public function get_query()
	{
		while (false !== ($data = fgetcsv($this->fp)))
		{
			if ((!isset($data[4])) || (($data[4] !== "Query") && ($data[4] !== "Execute")) || (!$data[5]))
				continue;

			// cut statement id from prefix of prepared statement
			$d5 = $data[5];
			$query = ('Execute' == $data[4] ? substr($d5, strpos($d5,']')+1) : $d5 );

			return str_replace(array("\\\\",'\\"'), array("\\",'"'), $query);
		}
		return false;
	}
}

/**
 * Read mysql slow query log in csv format (as of mysql 5.1 it by default)
 *
 */
class slow_csvreader extends filereader implements query_fetcher
{
	/**
	 * Fetch next query from csv file
	 *
	 * @return string - or FALSE on file end
	 */
	public function get_query()
	{
		while (false !== ($data = fgetcsv($this->fp)))
		{
			if (!isset($data[10]))
				continue;

			$query_time    = self::time_to_int($data[2]);
			$lock_time     = self::time_to_int($data[3]);
			$rows_sent     = $data[4];
			$rows_examined = $data[5];

			$statement     = str_replace(array("\\\\",'\\"'), array("\\",'"'), $data[10]);

			// cut statement id from prefix of prepared statement

			return array('qt'=>$query_time, 'lt'=>$lock_time, 'rs'=>$rows_sent, 're'=>$rows_examined, $statement);
		}
		return false;
	}

	/**
	 * Converts time value in format H:i:s into integer
	 * representation of number of total seconds
	 *
	 * @param string $time
	 * @return integer
	 */
	protected static function time_to_int($time)
	{
		list($h, $m, $s) = explode(':', $time);
		return ($h*3600 + $m*60 + $s);
	}
}

/**
 * Main statistics gathering class
 *
 */
class myprofi
{
	/**
	 * Query fetcher class
	 *
	 * @var mixed
	 */
	protected $fetcher;

	/**
	 * Top number of queries to output in stats
	 *
	 * @var integer
	 */
	protected $top = null;

	/**
	 * Only queries of these types to calculate
	 *
	 * @var array
	 */
	protected $types = null;

	/**
	 * Will the input file be treated as CSV formatted
	 *
	 * @var boolean
	 */
	protected $csv = false;

	/**
	 * Will the input file be treated as slow query log
	 *
	 * @var boolean
	 */
	protected $slow = false;

	/**
	 * Will the statistics include a sample query for each
	 * pattern
	 *
	 * @var boolean
	 */
	protected $sample = false;

	/**
	 * Field name to sort by
	 *
	 * @var string
	 */
	protected $sort;

	/**
	 * Input filename
	 */
	protected $filename;

	protected $_queries = array();
	protected $_nums    = array();
	protected $_types   = array();
	protected $_samples = array();
	protected $_stats = array();

	protected $total    = 0;

	/**
	 * Set the object that can fetch queries one by one from
	 * some storage
	 *
	 * @param query_fetcher $prov
	 */
	protected function set_data_provider(query_fetcher $prov)
	{
		$this->fetcher = $prov;
	}

	/**
	 * Set maximum number of queries
	 *
	 * @param integer $top
	 */
	public function top($top)
	{
		$this->top = $top;
	}

	/**
	 * Set array of query types to calculate
	 *
	 * @param string $types - comma separated list of types
	 */
	public function types($types)
	{
		$types = explode(',', $types);
		$types = array_map('trim', $types);
		$types = array_map('strtolower', $types);
		$types = array_flip($types);

		$this->types = $types;
	}

	/**
	 * Set the csv format of an input file
	 *
	 * @param boolean $csv
	 */
	public function csv($csv)
	{
		$this->csv = $csv;
	}

	/**
	 * Set the csv format of an input file
	 *
	 * @param boolean $csv
	 */
	public function slow($slow = null)
	{
		if (is_null($slow))
			return $this->slow;

		$this->slow = $slow;
	}

	/**
	 * Keep one sample query for each pattern
	 *
	 * @param boolean $sample
	 */
	public function sample($sample)
	{
		$this->sample = $sample;
	}

	/**
	 * Set input file
	 *
	 * @param string $filename
	 */
	public function set_input_file($filename)
	{
		if (!$this->csv && (strcasecmp(".csv", substr($filename, -4)) === 0))
			$this->csv(true);

		$this->filename = $filename;
	}

	public function sortby($sort)
	{
		$this->sort = $sort;
	}

	/**
	 * The main routine so count statistics
	 *
	 */
	public function process_queries()
	{
		if ($this->csv)
		{
			if ($this->slow)
				$this->set_data_provider(new slow_csvreader($this->filename));
			else
				$this->set_data_provider(new csvreader($this->filename));
		}
		elseif ($this->slow)
			$this->set_data_provider(new slow_extractor($this->filename));
		else
			$this->set_data_provider(new extractor($this->filename));

		// counters
		$i = 0;

		// stats arrays
		$queries = array();
		$nums    = array();
		$types   = array();
		$samples = array();
		$stats   = array();

		// temporary assigned properties
		$prefx   = $this->types;
		$ex      = $this->fetcher;

		// group queries by type and pattern
		while(($line = $ex->get_query()))
		{
			$stat = false;

			if (is_array($line))
			{
				$stat = $line;
				$line = array_pop($stat); // extract statement, it's always the last element of array
			}

			// keep query sample
			$smpl = $line;

			if ('' == ($line = normalize($line))) continue;

			// extract first word to determine query type
			$t = preg_split("/[\\W]/", $line, 2);
			$type = $t[0];

			if (!is_null($prefx) && !isset($prefx[$type]))
				continue;

			$hash = md5($line);

			// calculate query by type
			if (!array_key_exists($type, $types))
				$types[$type] = 1;
			else
				$types[$type]++;

			// calculate query by pattern
			if (!array_key_exists($hash, $queries))
			{
				$queries[$hash] = $line;   // patterns
				$nums[$hash]    = 1;       // pattern counts
				$stats[$hash]   = array(); // slow query statistics

				if ($this->sample)
					$samples[$hash] = $smpl;   // patterns samples
			}
			else
			{
				$nums[$hash]++;
			}

			// calculating statistics
			if ($stat)
			{
				foreach($stat as $k=>$v)
				{
					if (isset($stats[$hash][$k]))
					{
						// sum with total
						$stats[$hash][$k]['t'] += $v;

						if ($v > $stats[$hash][$k]['m'])
						{
							// increase maximum, if the current value is bigger
							$stats[$hash][$k]['m'] = $v;
						}
					}
					else
					{
						// set total and maximum values
						$stats[$hash][$k] = array('t'=>$v,'m'=>$v);
					}
				}
			}

			$i++;
		}

		$stats2 = array();
		if ($this->slow)
		{
			foreach($stats as $hash => $col)
			{
				foreach ($col as $k => $v)
				{
					$stats2[$hash][$k.'_total'] = $v['t'];
					$stats2[$hash][$k.'_avg']   = $v['t'] / $nums[$hash];
					$stats2[$hash][$k.'_max']   = $v['m'];
				}
			}
		}

		$stats = $stats2;

		if ($this->sort)
			uasort($stats, array($this, 'cmp'));
		else
			arsort($nums);

		arsort($types);

		if (!is_null($this->top))
		{
			if($this->sort)
				$stats = array_slice($stats, 0, $this->top);
			else
				$nums = array_slice($nums, 0, $this->top);

		}

		$this->_queries = $queries;
		$this->_nums    = $nums;
		$this->_types   = $types;
		$this->_samples = $samples;
		$this->_stats   = $stats;

		$this->total    = $i;
	}

	public function get_types_stat()
	{
		return new ArrayIterator($this->_types);
	}

	protected function cmp($a, $b)
	{
		$f = $a[$this->sort];
		$s = $b[$this->sort];

		return ($f < $s ) ? 1 : ($f > $s ? -1 : 0);
	}

	public function get_pattern_stats()
	{
		$stat = array();

		if ($this->sort)
			$tmp =& $this->_stats;
		else
			$tmp =& $this->_nums;

		if (list($h,$n) = each ($tmp))
		{
			if ($this->sort)
			{
				$stat = $n;
				$n = $this->_nums[$h];
			}

			if ($this->sample)
				return array($n, $this->_queries[$h], $this->_samples[$h], $stat);
			else
				return array($n, $this->_queries[$h], false, $stat);
		}
		else
			return false;
	}

	public function total()
	{
		return $this->total;
	}
}

// for debug purposes
if (!isset($argv))
{
	$argv = array(
		__FILE__,
//		'-slow',
		'-sort',
		'qt_total',
		'-top',
		'10',
		'queries.log',
	);
}

$fields = array(
	'qt_total',
	'qt_avg',
	'qt_max',
	'lt_total',
	'lt_avg',
	'lt_max',
	'rs_total',
	'rs_avg',
	'rs_max',
	're_total',
	're_avg',
	're_max',
);

// the last argument always must be an input filename
if (isset($argv[1]))
	$file = array_pop($argv);
else
{
	doc('Error: no input file specified');
}

// get rid of program filename ($argvs[0])
array_shift($argv);

// initialize an object
$myprofi = new myprofi();

$sample = false;

$sort = false;

// iterating through command line options
while(null !== ($com = array_shift($argv)))
{
	switch ($com)
	{
		case '-top':
			if (is_null($top = array_shift($argv)))
				doc('Error: must specify the number of top queries to output');

			if (!($top = (int)$top))
				doc('Error: top number must be integer value');
			$myprofi->top($top);
			break;

		case '-type':
			if (is_null($prefx = array_shift($argv)))
				doc('Error: must specify coma separated list of query types to output');
			$myprofi->types($prefx);
			break;

		case '-sample':
			$myprofi->sample(true);
			$sample = true;
			break;

		case '-csv':
			$myprofi->csv(true);
			break;

		case '-slow':
			$myprofi->slow(true);
			break;

		case '-sort':
			if (is_null($sort = array_shift($argv)))
				doc('Error: must specify criteria to sort by');
			elseif(false === array_search($sort, $fields))
				doc('Unknown sorting field "'.$sort.'"');
			$myprofi->sortby($sort);
			break;
	}
}
if (!$myprofi->slow() && $sort)
{
	$sort = false;
	$myprofi->sortby(false);
}

$myprofi->set_input_file($file);
$myprofi->process_queries();

$i = $myprofi->total();
$j = 1;
printf("Queries by type:\n================\n");
foreach($myprofi->get_types_stat() as $type => $num)
{
	printf("% -20s % -10s [%5s%%] \n", $type, number_format($num, 0, '', ' '), number_format(100*$num/$i,2));
}
printf("---------------\nTotal: ".number_format($i, 0, '', ' ')." queries\n\n\n");
printf("Queries by pattern:\n===================\n");

while(list($num, $query, $smpl, $stats) = $myprofi->get_pattern_stats())
{
	if ($sort)
	{
		$n = $stats[$sort];
		printf("%d.\t% -10s [%10s] - %s\n", $j, number_format($num, 0, '', ' '), number_format($n, 2), $query);
	}
	else
	{
		printf("%d.\t% -10s [% 5s%%] - %s\n", $j, number_format($num, 0, '', ' '), number_format(100*$num/$i,2), $query);
	}
	if ($smpl) printf("%s\n\n", $smpl);

	$j++;
}
printf("---------------\nTotal: ".number_format(--$j, 0, '', ' ')." patterns");
?>