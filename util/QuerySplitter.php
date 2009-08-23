<?php
/**
 * Break down a mysql query statement to different parts, which can be altered and joined again.
 * Supported types: SELECT, INSERT, REPLACE, UPDATE, DELETE, TRUNCATE.
 *
 * SELECT ... UNION syntax is *not* supported.
 * DELETE ... USING syntax is *not* supported.
 * Invalid query statements might give unexpected results. 
 * 
 * All methods of this class are static.
 * 
 * @package    DB
 * @subpackage DB_MySQL
 *   
 * {@internal
 *   This class highly depends on complicated PCRE regular expressions. So if your not really really really good at reading/writing these, don't touch this class.
 *   To prevent a regex getting in some crazy (or catastrophic) backtracking loop, use regexbuddy (http://www.regexbuddy.com) or some other step-by-step regex debugger.
 *   The performance of each function is really important, since these functions will be called a lot in 1 page and should be concidered abstraction overhead. The focus is on performance not readability of the code.
 * 
 *   Expression REGEX_VALUES matches all quoted strings, all backquoted identifiers and all words and all non-word chars upto the next keyword.
 *   It uses atomic groups to look for the next keyword after each quoted string and complete word, not after each char. Atomic groups are also neccesary to prevent catastrophic backtracking when the regex should fail.
 * 
 *   Expressions like '/\w+\s*(abc)?\s*\w+z/' should be prevented. If this regex would try to match "ef    ghi", the regex will first take all 3 spaces for the first \s*. When the regex fails it retries taking the
 *     first 2 spaces for the first \s* and the 3rd space for the second \s*, etc, etc. This causes the matching to take more than 3 times as long as '/\w+\s*(abc\s*)?\w+z/' would.
 *   This is the reason why trailing spaces are included with REGEX_VALUES and not automaticly trimmed.
 * }}
 * 
 * @todo It might be possible to use recursion instead of extracting subqueries, using \((?>SELECT\b)(?R)\). For query other that select, I should do (?:^\s++UPDATE ...|(?<!^)\s++SELECT ...) to match SELECT and not UPDATE statement in recursion.
 * @todo BUG: addCriteria using column index for column with alias, puts alias in WHERE. (+ make a testcase) 
 */
class DB_MySQL_QuerySplitter /*implements DB_QuerySplitter*/
{
	const REGEX_VALUES = '(?:\w++|`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|\s++|[^`"\'\w\s])*?';
	const REGEX_IDENTIFIER = '(?:(?:\w++|`[^`]*+`)(?:\.(?:\w++|`[^`]*+`)){0,2})';

	//------------- Basics -----------------------
	
	/**
	 * Quote a value so it can be savely used in a query.
	 * 
	 * @param mixed  $value
	 * @param string $empty  Return $empty if $value is null
	 * @return string
	 */
	public static function quote($value, $empty='NULL')
	{
		if (is_null($value)) return $empty;
		if (is_bool($value)) return $value ? 'TRUE' : 'FALSE';
		if (is_int($value) || is_float($value)) return $value;
		if (is_array($value)) return join(', ', array_map(array(__CLASS__, __FUNCTION__), $value));
		return '"' . strtr($value, array('\\'=>'\\\\', "\0"=>'\\0', "\r"=>'\\r', "\n"=>'\\n', '"'=>'\\"')) . '"';
	}
	
	/**
	 * Quotes a string so it can be safely used as a table or column name.
	 * Dots are seen as seperator and are kept out of quotes.
	 * 
	 * Return NULL if $identifier is not valid.
	 *
	 * @param string $identifier
	 * @return string
	 */
	public static function quoteIdentifier($identifier)
	{
		if (strpos($identifier, '.') === false && strpos($identifier, '`') === false) return "`$identifier`";
		
		$identifier = preg_replace('/(`?)(.+?)\1(\.|$)/', '`\2`\3', trim($identifier));
		if (!preg_match('/^(?:`[^`]*`(\.|$))+$/', $identifier)) throw new DB_Exception("Unable to quote invalid identifier: $identifier");
		return $identifier;
	}
    
	/**
	 * Check if a identifier is valid as field name or table name
	 *
	 * @param string  $name
	 * @param boolean $withtable  TRUE: group.name, FALSE: name, NULL: both
	 * @param boolean $withalias  Allow an alias (AS alias)
	 * @return boolean
	 */
	public static function validIdentifier($name, $withgroup=null, $withalias=false)
	{	
		return preg_match('/^' . ($withgroup !== false ? '((?:`(?>[^`]*)`|(?>\d*[A-Za-z_]\w*))\.)' . ($withgroup ? '+' : '*') : '') . '(`(?>[^`]*)`|(?>\d*[A-Za-z_]\w*))' . ($withalias ? '(?:\s*(?:\bAS\b\s*)?(`(?>[^`]*)`|(?>\d*[A-Za-z_]\w*)))?' : '') . '$/', trim($name));
	}
    
	/**
	 * Split a column name in table, column and alias OR table name in db, table and alias.
	 * Returns array(table, fieldname, alias) / array(db, table, alias)
	 *
	 * @param string $fieldname  Full fieldname
	 * @return array
	 */
	public static function splitIdentifier($name)
	{
		$matches = null;
		if (preg_match('/^(?:((?:`(?>[^`]*)`|(?>\d*[A-Za-z_]\w*))(?:\.(?:`(?>[^`]*)`|(?>\d*[A-Za-z_]\w*)))*)\.)(`(?>[^`]*)`|(?>\d*[A-Za-z_]\w*))(?:\s+AS\s+(`(?>[^`]*)`|(?>\d*[A-Za-z_]\w*)))?$/', trim($name), $matches)) return array(str_replace('`', '', $matches[1]), trim($matches[2], '`'), isset($matches[3]) ? trim($matches[3], '`') : null);
		return array(null, trim($name, '`'), null);
	}
	
	/**
	 * Create a full field name OR create a full table name.
	 *
	 * @param string $group  Table name / DB name
	 * @param string $name   Field name / Table name
	 * @param string $alias
	 * @return boolean
	 */
	public static function makeIdentifier($group, $name, $alias=null)
	{
		return (!empty($group) && self::validIdentifier($name, false) ? self::quoteIdentifier($group) . '.' . self::quoteIdentifier($name) : $name) . (!empty($alias) ? ' AS ' . self::quoteIdentifier($alias) : '');
	}
	
	/**
	 * Parse arguments into a statement.
	 *
	 * @param mixed $statement  Query string or DB::Statement object
	 * @param array $args       Arguments to parse into statement on ?
	 * @return mixed
	 */
	public static function parse($statement, $args)
	{
        if (empty($args)) return $statement;
        
		if (is_object($statement)) {
		    $source = $statement;
		    $statement = $statement->getStatement();
		}
        
		$i = 0;
		$statement = preg_replace('/`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(\?\!?)|:(\!)?(\w++)/e', $args === false ? "'$1$3' ? NULL : str_replace('\\\"', '\"', '\$0')" : "'\$3' && array_key_exists('\$3', \$args) ? ('\$2' ? \$args['\$3'] : Q\DB_MySQL_QuerySplitter::quote(\$args['\$3'])) : ('\$1' ? ('\$1' === '?!' ? \$args[\$i++] : Q\DB_MySQL_QuerySplitter::quote(\$args[\$i++])) : str_replace('\\\"', '\"', '\$0'))", $statement);
		
		if (isset($source)) {
		    $class = get_class($source);
		    return new $class($source, $statement);
		}
		
		return $statement;
	}
	
	/**
	 * Count the number of (unnamed) placeholders in a statement.
	 *
	 * @param string $statement
	 * @return int
	 */
	public static function countPlaceholders($statement)
	{
		if (is_object($statement)) $statement = $statement->getStatement();
		
		$matches = null;
		preg_match_all('/`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(\?)/', $statement, $matches, PREG_PATTERN_ORDER);
		return count($matches[1]);
	}
		
	
	//------------- Split / Build query -----------------------

	/**
	 * Return the type of the query.
	 *
	 * @param string $sql  SQL query statement (or an array with parts)
	 * @return string
	 */
	public static function getQueryType($sql)
	{
		$matches = null;
		if (is_array($sql)) $sql = $sql[0];
		return preg_match('/^\s*(SELECT|INSERT|REPLACE|UPDATE|DELETE|TRUNCATE|ALTER|CREATE|DROP|RENAME|DESCRIBE|SET|SHOW)\b/i', $sql, $matches) ? strtoupper($matches[1]) : null;
	}

	/**
	 * Convert a query statement to another type.
	 *
	 * @todo Currently only works for SELECT to DELETE and vise versa
	 * 
	 * @param string $sql   SQL query statement (or an array with parts)
	 * @param string $type  New query type
	 * @return string
	 */
	public static function convertStatement($sql, $type)
	{
		$type = strtoupper($type);
		if ($type !== 'SELECT' && $type !== 'DELETE') throw new Exception("Unable to convert query statement to $type: Type is not supported.");

		$oldtype = self::getQueryType($sql);
		if ($oldtype !== 'SELECT' && $oldtype !== 'DELETE') throw new Exception("Unable to convert $oldtype query statement: Type is not supported.");
		
		$parts = self::split($sql);
		$parts[0] = $type;
		
		switch ($type) {
		    case 'SELECT': if (empty($parts['columns'])) $parts['columns'] = '*'; break;
		    case 'DELETE': if (!empty($parts['columns']) && strpos(',', $parts['columns']) === false && !preg_match('/\.\*\s*$/', $parts['columns'])) $parts['columns'] = ''; break;
		}
		
		return self::join($parts);
	}
		
	/**
	 * Split a query in different parts.
	 * If a part is not set whitin the SQL query, the part is an empty string.
	 *
	 * @param string $sql  SQL query statement
	 * @return array
	 */
	public static function split($sql)
	{
		$type = self::getQueryType($sql);
		switch ($type) {
			case 'SELECT':	 return self::splitSelectQuery($sql);
			case 'INSERT':
			case 'REPLACE':	 return self::splitInsertQuery($sql);
			case 'UPDATE':	 return self::splitUpdateQuery($sql);
			case 'DELETE':   return self::splitDeleteQuery($sql);
			case 'TRUNCATE': return self::splitTruncateQuery($sql);
		}
		
		throw new Exception("Unable to split " . (!empty($type) ? "$type " : "") . "query. $sql");
	}

	/**
	 * Join parts to create a query.
	 * The parts are joined in the order in which they appear in the array.
	 * 
	 * CAUTION: The parts are joined blindly (no validation), so shit in shit out
	 *
	 * @param array $parts
	 * @return string
	 * 
	 * @todo Make blind join optional and let $parts also be an object
	 */
	public static function join($parts)
	{
		$sql_parts = array();
		
		foreach ($parts as $key=>$part) {
			if ($part !== null && trim($part) !== '') {
				if (is_array($part)) $part = join(", ", $part);
				if (is_int($key) || $key === 'columns' || $key === 'query' || $key === 'tables') $key = null;
				$sql_parts[] .= (isset($key) ? strtoupper($key) . " " : "") . $part;
			}
		}

		return join(' ', $sql_parts);
	}


	//------------- Extract subsets --------------------
	
	
	/**
	 * Extract subqueries from sql query (on for SELECT queries) and replace them with #subX in the main query.
	 * Returns array(main query, subquery1, [subquery2, ...])
	 *
	 * @param  string $sql
	 * @param  array  $sets  Do not use!
	 * @return array
	 */
	public static function extractSubsets($sql, $sets=array())
	{
		// There are certainly no subqueries
		if (stripos($sql, 'SELECT', 6) === false) {
			$sets[] = $sql;
			return $sets;
		}

		// Extract any subqueries
		$offset = array_push($sets, null) - 1;
		
		if (self::getQueryType($sql) === 'INSERT') {
			$parts = self::split($sql);
			if (isset($parts['query'])) {
				$sets = self::extractSubsets($parts['query'], $sets);
				$parts['query'] = '#sub' . ($offset+1);
				$sql = self::join($parts);
			}
		}
		
		if (preg_match('/\(\s*SELECT\b/si', $sql)) {
			do {
				$matches = null;
				preg_match('/(?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|\((\s*SELECT\b.*\).*)|\w++|[^`"\'\w])*$/si', $sql, $matches, PREG_OFFSET_CAPTURE);
				if (isset($matches[1])) $sql = substr($sql, 0, $matches[1][1]) . preg_replace('/(?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(?>[^`"\'()]+)|\((?R)\))*/sie', "'#sub' . self::extractSubsets_callback('\$0', \$sets)", substr($sql, $matches[1][1]), 1);
			} while (isset($matches[1]));
		}
		
		$sets[$offset] = $sql;
		return $sets;
	}

	/**
	 * Recursive callback for preg_replace in extractSubset
	 * @ignore 
	 * 
	 * @param string $sql
	 * @param array  $sets
	 * @return string
	 */
	public static function extractSubsets_callback($sql, &$sets=array())
	{
		$key = sizeof($sets);
		$sets = self::extractSubsets($sql, $sets);
		return $key;
	}
	
	/**
	 * Inject extracted subsets back into main sql query.
	 *
	 * @param array $sets   array(main query, subquery1, [subquery2, ...])
	 * @return string
	 */
	public static function injectSubsets($sets)
	{
		if (sizeof($sets) > 1) {
			$count = -1;
			while($count && strpos($sets[0], '#sub') !== false) {
			    $sets[0] = preg_replace('/^(' . self::REGEX_VALUES . ')\#sub(\d+)/e', "'\$1' . \$sets['\$2']", $sets[0], 0xFFFF, $count);
			}
		}
		return $sets[0];
	}
	
	
	/**
	 * Extract childqueries for tree data from sql query (only for SELECT queries) and replace them with NULL in the main query.
	 * Returns array(main query, array(subquery1, parent field, child field), [array(subquery2, parent field, child field), ...])
	 *
	 * @param string $sql
	 * @return array
	 */
	public static function extractTree($sql)
	{
		// There are certainly no childqueries
		if (!preg_match('/^SELECT\b/i', $sql) || !preg_match('/\b(?:VALUES|ROWS)\s*\(\s*SELECT\b/i', $sql)) return array($sql);
		if (!preg_match('/^(' . self::REGEX_VALUES . ')(?:\b(?:VALUES|ROWS)\s*(\(\s*SELECT\b.*))$/si', $sql)) return array($sql);
		
		// Extract any childqueries
		$parts = self::splitSelectQuery($sql);
		$columns = self::splitColumns($parts['columns']);

		$tree = null;
		$matches = null;
		
		foreach ($columns as $i=>$column) {
			if (preg_match('/^(?:VALUES|(ROWS))\s*+\((SELECT\b\s*+' . self::REGEX_VALUES . ')(?>\bCASCADE\s++ON\b\s*+(' . self::REGEX_IDENTIFIER . ')\s*+\=\s*+(' . self::REGEX_IDENTIFIER . '))?\s*+\)\s*+(?:AS\b\s*+(' . self::REGEX_IDENTIFIER . '))?$/si', trim($column), $matches)) {
				if (!isset($tree)) $tree = array(null);
				
				if (!empty($matches[3]) && !empty($matches[4])) {
					$alias = !empty($matches[5]) ? $matches[5] : `tree:col$i`;
					$columns[$i] = $matches[4] .  " AS $alias";
					
					$child_parts = self::splitSelectQuery($matches[2]);
					$child_parts['columns'] .= ", " . $matches[3] . " AS `tree:join`";
					$child_parts['where'] = (!empty($child_parts['where']) ? '(' . $child_parts['where'] . ') AND ' : '') . $matches[3] . " IN (?)";
					$child_parts['order by'] = $matches[3] . (!empty($child_parts['order by']) ? ", " . $child_parts['order by'] : '');
					$tree[] = array(unquote($alias, '`'), self::join($child_parts), $matches[1] ? DB::FETCH_ORDERED : DB::FETCH_VALUE, true);
				} else {
					$columns[$i] = 'NULL' . (!empty($matches[5]) ? ' AS ' . $matches[5] : '');
					trigger_error("Incorrect tree query statement: Child query should end with 'CASCADE ON `parent_field` = `child_field`'. " . $column, E_USER_WARNING);
				}
			}
		}
		
		if (!isset($tree)) return array($sql);

		$parts['columns'] = join(', ', $columns);
		$tree[0] = self::join($parts);
		
		return $tree;
	}	
	
    /**
     * Extract subqueries from sql query and split each subquery in different parts.
     *
     * @param string $statement  Query statement
     * @return array
     */
    public static function extractSplit($sql)
    {
    	$sets = self::extractSubsets($sql);
        if (!isset($sets)) return null;

        return array_map(array(__CLASS__, 'split'), $sets);
    }

    /**
     * Join parts and inject extracted subsets back into main sql query.
     *
     * @param array $sets  array(main parts, parts subquery1 [, parts subquery2, ...])
     * @return array
     */
    public static function joinInject($parts)
    {
        $sets = array_map(array(__CLASS__, 'join'), $parts);
        return count($sets) == 1 ? reset($sets) : self::injectSubsets($sets);
    }    
    	
	
	//------------- Split specific type --------------------
	
	/**
	 * Split select query in different parts.
	 * NOTE: Splitting a query with a subquery is considerably slower.
	 *
	 * @param string $sql  SQL SELECT query statement
	 * @return array
	 */
	static protected function splitSelectQuery($sql)
	{
		$sets = null;
		$matches = null;
		while (preg_match('/^((?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(?>[^`\'"(]+)|\()*?)(\(\s*SELECT\b.*)$/si', $sql, $matches)) {
			if (!isset($sets)) $sets = array(null);
			$sql = $matches[1] . preg_replace('/\((?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(?>[^`"\'()]+)|(?R))*\)/sie', "'#sub' . (array_push(\$sets, '\$0')-1) . ' '", $matches[2], 1);
		}

		$parts = null;
		if (!preg_match('/^\s*' .
		  '(SELECT\b(?:\s+(?:ALL|DISTINCT|DISTINCTROW|HIGH_PRIORITY|STRAIGHT_JOIN|SQL_SMALL_RESULT|SQL_BIG_RESULT|SQL_BUFFER_RESULT|SQL_CACHE|SQL_NO_CACHE|SQL_CALC_FOUND_ROWS)\b)*)\s*(' . self::REGEX_VALUES . ')' .
		  '(?:' .
		  '\bFROM\b\s*(' . self::REGEX_VALUES . ')' .
		  '(?:\bWHERE\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:\bGROUP\s+BY\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:\bHAVING\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:\bORDER\s+BY\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:\bLIMIT\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(\b(?:PROCEDURE|INTO|FOR\s+UPDATE|LOCK\s+IN\s+SHARE\s*MODE|CASCADE\s*ON)\b.*?)?' .
		  ')?' .
		  '(?:;|$)/si', $sql, $parts)) throw new DB_Exception('Unable to split SELECT query, invalid syntax:\n' . $sql);

		if (isset($sets) && sizeof($sets) > 1) {
			for ($i=1; $i < sizeof($parts); $i++) {
			    if (strpos($parts[$i], '#sub') !== false) $parts[$i] = preg_replace('/(' . self::REGEX_VALUES . ')\#sub(\d+)\s?/e', "'\$1' . \$sets['\$2']", $parts[$i]);
			}
		}

		array_shift($parts);
		return array_combine(array(0, 'columns', 'from', 'where', 'group by', 'having', 'order by', 'limit', 100), $parts + array_fill(0, 9, ''));
	}

	/**
	 * Split insert/replace query in different parts.
	 *
	 * @param string $sql  SQL INSERT query statement
	 * @return array
	 */
	static protected function splitInsertQuery($sql)
	{
		$parts = null;
		if (preg_match('/\bVALUES\b/i', $sql) && preg_match('/^\s*' .
		  '((?:INSERT|REPLACE)\b(?:\s+(?:LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)\b)*)\s+INTO\b\s*(' . self::REGEX_VALUES . ')' .
		  '(\(\s*' . self::REGEX_VALUES . '\)\s*)?' .
		  '\bVALUES\s*(\(\s*' . self::REGEX_VALUES . '\)\s*(?:,\s*\(' . self::REGEX_VALUES . '\)\s*)*)' .
		  '(?:\bON\s+DUPLICATE\s+KEY\s+UPDATE\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:;|$)/si', $sql, $parts))
		{
			$keys = array(0, 'into', 'columns', 'values', 'on duplicate key update');
		}
		
		elseif (preg_match('/\bSET\b/i', $sql) && preg_match('/^\s*' .
		  '((?:INSERT|REPLACE)\b(?:\s+(?:LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)\b)*)\s+INTO\b\s*(' . self::REGEX_VALUES . ')' .
		  '\bSET\b\s*(' . self::REGEX_VALUES . ')' .
		  '(?:\bON\s+DUPLICATE\s+KEY\s+UPDATE\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:;|$)/si', $sql, $parts))
		{
		 	$keys = array(0, 'into', 'set', 'on duplicate key update');
		}

		elseif (preg_match('/\bSELECT\b|\#sub\d+/i', $sql) && preg_match('/^\s*' .
		  '((?:INSERT|REPLACE)\b(?:\s+(?:LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)\b)*)\s+INTO\b\s*(' . self::REGEX_VALUES . ')' .
		  '(\(\s*' . self::REGEX_VALUES . '\)\s*)?' .
		  '(\bSELECT\b\s*' . self::REGEX_VALUES . '|\#sub\d+\s*)' .
		  '(?:\bON\s+DUPLICATE\s+KEY\s+UPDATE\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:;|$)/si', $sql, $parts))
		{
			$keys = array(0, 'into', 'columns', 'query', 'on duplicate key update');
		}

		else 
		{
		 	throw new Exception("Unable to split INSERT/REPLACE query, invalid syntax:\n" . $sql);
		}
		
		array_shift($parts);
		return array_combine($keys, $parts + array_fill(0, sizeof($keys), ''));
	}

	/**
	 * Split update query in different parts
	 *
	 * @param string $sql  SQL UPDATE query statement
	 * @return array
	 */
	static protected function splitUpdateQuery($sql)
	{
		$sets = null;
		$matches = null;
		while (preg_match('/^((?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(?>[^`\'"(]+)|\()*?)(\(\s*SELECT\b.*)$/si', $sql, $matches)) {
			if (!isset($sets)) $sets = array(null);
			$sql = $matches[1] . preg_replace('/\((?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(?>[^`"\'()]+)|(?R))*\)/sie', "'#sub' . (array_push(\$sets, '\$0')-1) . ' '", $matches[2], 1);
		}

		$parts = null;
		if (!preg_match('/^\s*' .
		  '(UPDATE\b(?:\s+(?:LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)\b)*)\s*(' . self::REGEX_VALUES . ')' .
		  '\bSET\b\s*(' . self::REGEX_VALUES . ')' .
		  '(?:\bWHERE\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:\bLIMIT\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:;|$)/si', $sql, $parts)) throw new DB_Exception("Unable to split UPDATE query, invalid syntax:\n" . $sql);

		if (isset($sets) && sizeof($sets) > 1) {
			for ($i=1; $i < sizeof($parts); $i++) if (strpos($parts[$i], '#sub') !== false) $parts[$i] = preg_replace('/(' . self::REGEX_VALUES . ')\#sub(\d+)\s?/e', "'\$1' . \$sets['\$2']", $parts[$i]);
		}
		
		array_shift($parts);
		return array_combine(array(0, 'tables', 'set', 'where', 'limit'), $parts + array_fill(0, 5, ''));
	}

	/**
	 * Split delete query in different parts
	 *
	 * @param string $sql  SQL DELETE query statement
	 * @return array
	 */
	static protected function splitDeleteQuery($sql)
	{
		$sets = null;
		$matches = null;
		while (preg_match('/^((?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(?>[^`\'"(]+)|\()*?)(\(\s*SELECT\b.*)$/si', $sql, $matches)) {
			if (!isset($sets)) $sets = array(null);
			$sql = $matches[1] . preg_replace('/\((?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(?>[^`"\'()]+)|(?R))*\)/sie', "'#sub' . (array_push(\$sets, '\$0')-1) . ' '", $matches[2], 1);
		}

		$parts = null;
		if (!preg_match('/^\s*' .
		  '(DELETE\b(?:\s+(?:LOW_PRIORITY|QUICK|IGNORE)\b)*)\s*' .
		  '(' . self::REGEX_VALUES . ')?' .
		  '\bFROM\b\s*(' . self::REGEX_VALUES . ')?' .
		  '(?:\bWHERE\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:\bORDER\s+BY\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:\bLIMIT\b\s*(' . self::REGEX_VALUES . '))?' .
		  '(?:;|$)/si', $sql, $parts)) throw new DB_Exception("Unable to split DELETE query, invalid syntax:\n" . $sql);

		if (isset($sets) && sizeof($sets) > 1) {
			for ($i=1; $i < sizeof($parts); $i++) if (strpos($parts[$i], '#sub') !== false) $parts[$i] = preg_replace('/(' . self::REGEX_VALUES . ')\#sub(\d+)\s?/e', "'\$1' . \$sets['\$2']", $parts[$i]);
		}		
			
		array_shift($parts);
		return array_combine(array(0, 'columns', 'from', 'where', 'order by', 'limit'), $parts + array_fill(0 , 6, ''));
	}
	
	/**
	 * Split delete query in different parts
	 *
	 * @param string $sql  SQL DELETE query statement
	 * @return array
	 */
	static protected function splitTruncateQuery($sql)
	{
		$sets = null;
		$matches = null;
		while (preg_match('/^((?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(?>[^`\'"(]+)|\()*?)(\(\s*SELECT\b.*)$/si', $sql, $matches)) {
			if (!isset($sets)) $sets = array(null);
			$sql = $matches[1] . preg_replace('/\((?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(?>[^`"\'()]+)|(?R))*\)/sie', "'#sub' . (array_push(\$sets, '\$0')-1) . ' '", $matches[2], 1);
		}

		$parts = null;
		if (!preg_match('/^\s*' .
		  '(TRUNCATE\b(?:\s+(?:TABLE)\b)*)\s*' .
		  '(' . self::REGEX_VALUES . ')' .
		  '(?:;|$)/si', $sql, $parts)) throw new DB_Exception("Unable to split TRUNCATE query, invalid syntax:\n" . $sql);

		if (isset($sets) && sizeof($sets) > 1) {
			for ($i=1; $i < sizeof($parts); $i++) if (strpos($parts[$i], '#sub') !== false) $parts[$i] = preg_replace('/(' . self::REGEX_VALUES . ')\#sub(\d+)\s?/e', "'\$1' . \$sets['\$2']", $parts[$i]);
		}		
			
		array_shift($parts);
		$parts = array_combine(array(0, 'tables'), $parts);

		return $parts;
	}	
	
	//------------- Split columns --------------------
	
	/**
	 * Return the columns of a (partual) query.
	 * 
	 * @internal 
	 *
	 * @param string  $sql             SQL query or 'column, column, ...'
	 * @param boolean $splitFieldname  Split fieldname in array(table, field, alias)
	 * @param boolean $assoc           Remove '[AS] alias' (for SELECT) or 'to=' (for INSERT/UPDATE) and return as associated array
	 * @return array
	 * 
	 * @todo Implemented splitColumns() for INSERT, REPLACE and UPDATE
	 * @todo Sets might be parsed in to early. Test this and solve if needed.
	 */
	public static function splitColumns($sql, $splitFieldname=false, $assoc=false)
	{
		$type = self::getQueryType($sql);

		if (!isset($type) || $type === '') {
			// No action
			
		} elseif ($type === 'SELECT') {
			$sets = null;
			$matches = null;
			
			while (preg_match('/^((?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|\w++|[^`"\'\w])*?)(\bFROM\b|\(\s*SELECT\b.*$)/si', $sql, $matches) && strtoupper($matches[2]) !== 'FROM') {
				if (!isset($sets)) $sets = array(null);
				$sql = $matches[1] . preg_replace('/\((?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|(?>[^`"\'()]+)|(?R))*\)/sie', "'#sub' . (array_push(\$sets, '\$0')-1) . ' '", $matches[2], 1);
			}

			preg_match('/^\s*SELECT\b\s*(' . self::REGEX_VALUES . ')(?:\bFROM\b|$)/si', $sql, $matches);
			$sql = isset($matches[1]) ? $matches[1] : null;

			if (isset($sets) && sizeof($sets) > 1 && strpos($sql, '#sub') !== false) $sql = preg_replace('/(' . self::REGEX_VALUES . ')\#sub(\d+)\s?/e', "'\$1' . \$sets['\$2']", $sql);
			
		} elseif($type === 'DELETE') {
			$matches = null;
			preg_match('/^\s*DELETE\b\s*(' . self::REGEX_VALUES . ')\bFROM\b.*$/si', $sql, $matches);
			$sql = isset($matches[1]) ? $matches[1] : null;

		} elseif ($type === 'INSERT' || $type === 'REPLACE' || $type === 'UPDATE') {
			trigger_error("Splitting columns for $type queries is not yet implemented.", E_USER_WARNING);
			return array();

		} else {
			throw new DB_Exception("Unable to split the column for " . (!empty($type) ? "a $type" : "") . "query:\n" . $sql);
		}
		
		// Simple split on comma
		if (!$assoc && !$splitFieldname) {
			preg_match_all('/(?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|\((?:[^()]++|(?R))*\)|[^`"\'(),]++)++/', $sql, $matches, PREG_PATTERN_ORDER);
			return $matches[0];
		}
		
		// Extract fullname(1), tablename(2), fieldname(3 or 4) and alias (5)
		$matches = null;
		preg_match_all('/\s*(' .
		  '(?:(?:(`[^`]*+`|\w++)\.))?(`[^`]*+`|\w++)\s*+|' .
		  '((?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*"|\'(?:[^\'\\\\]|\\\\.)*\'|\((?:[^()]*+|(?R))\)|\s++|\w++(?<!\bAS)|[^`"\'\w\s(),])+)' .
		  ')(?:(?:\bAS\s*)?(`[^`]*+`|\b\w++))?\s*+(?=,|$)' .
		  '/si', $sql, $matches, PREG_PATTERN_ORDER);

		if ($assoc) {
    		$alias = array();
            for ($i=0; $i<sizeof($matches[0]); $i++) $alias[$i] = !empty($matches[5][$i]) ? trim($matches[5][$i]) : (!empty($matches[3][$i]) ? trim($matches[3][$i], ' `') : trim($matches[4][$i]));
		}
		
		if (!$splitFieldname) return array_combine($alias, array_map('trim', $matches[1]));
		
	 	$values = array();
		for ($i=0; $i<sizeof($matches[0]); $i++) $values[$i] = array(trim($matches[2][$i], ' `'), !empty($matches[3][$i]) ? trim($matches[3][$i], ' `') : trim($matches[4][$i]), isset($matches[5][$i]) ? trim($matches[5][$i], ' `') : null);
		
		return $assoc ? array_combine($alias, $values) : $values;
    }

	/**
	 * Return tables from a query or join expression.
	 *
	 * @param string  $sql             SQL query or FROM part
	 * @param boolean $splitTablename  Split tablename in array(db, table, alias)
	 * @param boolean $assoc           Remove 'AS ...' and return as associated array
	 * @return array
	 * 
	 * @todo Make splitTables work for subqueries
	 */
	public static function splitTables($sql, $splitTablename=false, $assoc=false)
	{
	    $type = self::getQueryType($sql);
        if ($type) {
	        $parts = self::split($sql);
	        if (array_key_exists('from', $parts)) $sql = $parts['from'];
	          elseif (array_key_exists('tables', $parts)) $sql = $parts['tables'];
	          else throw new Exception("Unable to get tables from $type query. $sql");
        }
        
        if (empty($sql)) return null;
        
	    $matches = null;
		preg_match_all('/(,\s*|(?:(?>NATURAL\s+)?(?>(?:LEFT|RIGHT)\s+)?(?>(?:INNER|CROSS|OUTER)\s+)?(?>STRAIGHT_)?JOIN\s*+))?+' .
		  '(\\(\s*+(?:[^()]++|(?R))*\\)\s*+|((?:(`[^`]++`|\w++)\.)?(`[^`]++`|\b\w++)\s*+)(?:(\bAS\s*+(?:`[^`]++`|\b\w++)|`[^`]++`|\b\w++(?<!\bON)(?<!\bNATURAL)(?<!\bLEFT)(?<!\bRIGHT)(?<!\bINNER)(?<!\bCROSS)(?<!\bOUTER)(?<!\bSTRAIGHT_JOIN)(?<!\bJOIN))\s*+)?)' .
		  '(?:ON\b\s*+((?:(?:`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*"|\'(?:[^\'\\\\]++|\\\\.)*\'|\s++|\w++(?<!\bNATURAL)(?<!\bLEFT)(?<!\bRIGHT)(?<!\bINNER)(?<!\bCROSS)(?<!\bOUTER)(?<!\bSTRAIGHT_JOIN)(?<!\bJOIN)|[^`"\'\w\s()\,]|\\(\s*+(?:[^()]++|(?R))*\\)))+))?' .
		  '/si', $sql, $matches, PREG_PATTERN_ORDER);

        if (empty($matches)) return array();

        $subtables = array();
        for ($i=0,$m=count($matches[2]); $i<$m; $i++) {
            if ($matches[2][$i][0] === '(') {
                $subtables = array_merge($subtables, self::splitTables(substr(trim($matches[2][$i]), 1, -1), $splitTablename, $assoc));
                unset($matches[2][$i], $matches[3][$i], $matches[4][$i], $matches[5][$i]);
            }
        }
        
        if ($assoc) {
            $alias = array();
            foreach ($matches[1] as $i=>$v) $alias[$i] = !empty($matches[6][$i]) ? preg_replace('/^(?:AS\s*)?\b(`?)(.*?)\\$1\s*$/', '$2', $matches[6][$i]) : trim($matches[3][$i], ' `');
        }
         
        if (!$splitTablename) {
            $tables = $assoc ? array_combine($alias, array_map('trim', $matches[3])) : array_map('trim', $matches[2]);
        } else {
            $tables = array();
            foreach ($matches[1] as $i=>$v) $tables[$i] = array(!empty($matches[4][$i]) ? trim($matches[4][$i], ' `') : null, !empty($matches[5][$i]) ? trim($matches[5][$i], ' `') : null, !empty($matches[6][$i]) ? preg_replace('/^(?:AS\s*)?\b(`?)(.*?)\\$1\s*$/', '$2', $matches[6][$i]) : null);
            if ($assoc) $tables = array_combine($alias, $tables);
        }
        
        if (!empty($subtables)) $tables = array_merge($subtables, $tables);
        return $tables;
    }
		
	/**
	 * Split a single part from a join expression
	 *
	 * @param string $sql
	 * @return array
	 */
    public static function splitJoin($sql)
    {
        if (self::getQueryType($sql)) {
	        $parts = self::split($sql);
	        $sql = isset($parts['from']) ? $parts['from'] : (isset($parts['tables']) ? $parts['tables'] : null);

	        if (empty($sql)) return null;
        }
        
        $parts = null;
        preg_match_all('/(^\s*|,\s*|(?:(?>NATURAL\s+)?(?>(?:LEFT|RIGHT)\s+)?(?>(?:INNER|CROSS|OUTER)\s+)?(?>STRAIGHT_)?JOIN\s*+))' .
          '(\b(?:`[^`]++`|\w++)(?:\.(?:`[^`]++`|\w++))?\s*+)' .
          '(?:(\bAS\s*+\b(?:`[^`]++`|\w++)|`[^`]++`|\w++(?<!\b(?:ON|NATURAL|LEFT|RIGHT|INNER|CROSS|OUTER|STRAIGHT_JOIN|JOIN)))\b\s*+)?' .
          '(?>ON\b\s*+((?:(?:[\,\.]|`[^`]*+`|"(?:[^"\\\\]++|\\\\.)*+"|\'(?:[^\'\\\\]++|\\\\.)*+\'|[^`"\'\w\s\.\,]|\w++(?<!\b(?:NATURAL|LEFT|RIGHT|INNER|CROSS|OUTER|STRAIGHT_JOIN|JOIN)))\s*+)+))?/s',
          $sql, $parts, PREG_PATTERN_ORDER);
          
    }

	/**
	 * Split limit in array(limit, offset)
	 *
	 * @param string $sql  SQL query or limit part
	 * @return array
	 */
	public static function splitLimit($sql)
	{
		$type = self::getQueryType($sql);
		if (isset($type)) {
			$parts = self::split($sql);
			$sql = $parts['limit'];
		}
		if ($sql === null || $sql === '') return array(null, null);
	
		$matches = null;
		if (ctype_digit($sql)) return array($sql, null);
		if (preg_match('/^(\d+)\s+OFFSET\s+(\d+)/', $sql, $matches)) return array($matches[1], $matches[2]);
		if (preg_match('/\d+\s*,\s*(\d+)/', $sql, $matches)) return array($matches[2], $matches[1]);
		
		return null;
	}

    
	//------------ Edit statement -----------------
	
	/**
	 * Add criteria as where or having statement as $column=$value.
	 * If $value == null and $compare == '=', $compare becomes 'IS NULL'.
	 * 
	 * NOTE: This function does not escape $column
	 *
	 * @param Q\DB_SQLStatement $object   The statement object to add the criteria to
	 * @param mixed              $column   Column name, column number or array of column names ($column[0]=$value OR $column[1]=$value)
	 * @param mixed              $value    Value or array of values ($column=$value[0] OR $column=$value[1])
	 * @param string             $compare  Comparision operator oa. =, !=, >, <, >=, <=, LIKE, LIKE%, %LIKE%, REVERSE LIKE (value LIKE column), IN and BETWEEN
	 * @param int                $options  DB_Statement options (language specific) as binairy set
	 * @param int                $subset   Specify to wich subset the change applies (0=main query)
	 */
	public static function addCriteria(DB_Statement $object, $column, $value, $compare="=", $options=0, $subset=0)
	{
		if ($subset === 0 && $object->getQueryType() === 'INSERT' && $object->seekPart('query') !== null) $subset = 1;
		
		// Prepare
		$compare = empty($compare) ? '=' : trim(strtoupper($compare));
		
		// Handle some simple and common cases, just to improve performance
		if (isset($value) && !is_array($value) && is_string($column) && ($compare==='=' || $compare==='!=' || $compare==='>' || $compare==='<' || $compare==='>=' || $compare==='<=')) {
			$object->addWhere("$column $compare " . self::quote($value), $options, $subset);
			return;
		} elseif (is_string($column) && $compare === 'IS NULL' || $compare === 'IS NOT NULL') {
		    if (isset($value) && $value !== '' && (int)$value == 0) $compare = $compare === 'IS NULL' ? 'IS NOT NULL' : 'IS NULL';
			$object->addWhere("$column $compare", $options, $subset);
			return;
		}
		
		// Prepare more
		$column = (array)$column;
		if (isset($value)) $value = (array)$value;
		 elseif ($compare === '=') $compare = 'IS NULL';

		if ($compare === 'ANY' || ($compare === '=' && sizeof($value)>1)) $compare = 'IN';
		if ($compare === 'ALL' && $options & DB::ADD_HAVING) throw new DB_Exception("Unable to add 'ALL' criteria to HAVING section, due to language specific reasons of MySQL.");
		 
		// Only use the non-null values with between, autoconvert to >= or <=
		if (($compare==="BETWEEN" || $compare==="NOT BETWEEN") && (isset($value[0]) xor isset($value[1]))) {
			$compare = ($compare==="BETWEEN" xor isset($value[0])) ? '<=' : '>=';
			$value = isset($value[0]) ? array($value[0]) : array($value[1]);
		}
		
		// Quote value. (For LIKE: Apply % for %LIKE% to value)
		$matches = null;
		if (preg_match('/^(\%?)(?:REVERSE\s+)?LIKE(\%?)$/', $compare, $matches)) {
			if (isset($value)) foreach ($value as $key=>$val) $value[$key] = self::quote((isset($matches[1]) ? $matches[1] : "") . addcslashes($val, '%_') . (isset($matches[2]) ? $matches[2] : ""));
			$compare = trim($compare, "%");
		} elseif (isset($value)) {
			foreach ($value as $key=>$val) $value[$key] = self::quote($val);
		}

		// Replace column numbers for column names
		$columnNames = null;
		foreach ($column as $key=>$col) {
			if (is_int($col)) {
				if (!isset($columnNames)) $columnNames = $object->getColumns($subset);
				if (!isset($columnNames[$col])) throw new DB_Exception("Unable to add criteria for column $col (1st col = 0): Statement only has " . sizeof($columnNames) . " columns. Statement: " . $object->getBaseStatement());
				$column[$key] = $columnNames[$col];
			}
		}

		// Apply reverse -> value LIKE column, instead of column LIKE value
		if (substr($compare, 0, 8) === 'REVERSE ') {
			$tmp = $column;   $column = $value;   $value = $tmp;
			$compare = trim(substr($compare, 8));
		}

		// Compare as in any
		if ($compare === "IN" || $compare === "NOT IN" || $compare === "ALL") $value = array_unique($value);
		
		// Create where expression for each column (using if, instead of switch for performance)
		if ($compare === "ALL") {
			if (!isset($value)) throw new DB_Exception("Unable to add '$compare' criteria: \$value is not set");
			if (!empty($values)) {
			    foreach ($column as $col) {
    				$having[] = "COUNT(DISTINCT $col) = " . sizeof($value);
	    			$where[] = "$col IN (" . join(", ", $value) . ")";
		    	}
			}
		
		} elseif ($compare === "IN" || $compare === "NOT IN") {
			if (!isset($value)) throw new DB_Exception("Unable to add '$compare' criteria: \$value is not set");
			if (!empty($value)) {
			    foreach ($column as $col) $where[] = "$col $compare (" . join(", ", $value) . ")";
			}
		
		} elseif ($compare === "BETWEEN" || $compare === "NOT BETWEEN") {
			if (sizeof($value) != 2) throw new DB_Exception("Unable to add '$compare' criteria: \$value should have exactly 2 items, but has " . sizeof($value) . " items");
			foreach ($column as $col) $where[] = "$col $compare " . $value[0] .  " AND " . $value[1];

		} elseif ($compare === "IS NULL" || $compare === "IS NOT NULL") {
		    if (isset($value) && $value !== '' && (int)$value == 0) $compare = $compare === 'IS NULL' ? 'IS NOT NULL' : 'IS NULL';
		    if (!empty($value)) {
		        foreach ($column as $col) $where[] = "$col $compare";
		    }
			
		} else {
			if (!isset($value)) throw new DB_Exception("Unable to add '$compare' criteria: \$value is not set");
			if (!empty($value)) {
			    foreach ($column as $col) foreach ($value as $val) $where[] = "$col $compare $val";
			}
		}

		// Add where expression(s)
		if (!empty($where)) $object->addWhere(join(" OR ", $where), $options, $subset);
		if (!empty($having)) $object->addWhere(join(" AND ", $having), $options | DB::ADD_HAVING, $subset);
	}
	
	
	//------------ Build statement -----------------
	
	/**
	 * Create a select statement for a table
	 *
	 * @param string  $table      Tablename
	 * @param mixed   $fields     Array with fieldnames, fieldlist (string) or SELECT statement (string). NULL means all fields.
	 * @param mixed   $criteria   The value for the primairy key (int/string or array(value, ...)) or array(field=>value, ...)
	 * @param string  $add_where  Additional criteria as string
	 * @return string
	 */
	public static function buildSelectStatement($table, $fields=null, $criteria=null, $add_where=null)
	{
		// Create where part from $criteria
		if ($criteria === false) {
			$where = 'FALSE';
			
		} elseif (isset($criteria)) {
		    $keys = array_keys($criteria);
			$criteria = array_values($criteria);
	
			$where = array();
			foreach ($keys as $i=>$key) $where[] = self::quoteIdentifier($key) . ' = ' . self::quote($criteria[$i]);
			$where = join(' AND ', $where) . (isset($add_where) ? " AND ($add_where)" : '');
			
		} else {
			$where = $add_where;
		}
		
		// If first field is a full SELECT query
		$main_field = is_array($fields) ? reset($fields) : $fields;
		if (preg_match('/^\s*select\b/i', $main_field)) {
			$parts = self::split($main_field);
			if (!empty($where)) $parts['where'] = !empty($parts['where']) && $where !== 'FALSE' ? "(" . $parts['where'] . ") AND ($where)" : $where;

			if (is_array($fields) && sizeof($fields) > 1) $parts['columns'] .= (isset($parts['columns']) ? ', ' : '') . join(',', array_splice($fields, 1));

			return self::join($parts);
		}
		
		// otherwise
		if (!isset($fields)) $fields = '*';
		  elseif (is_array($fields)) $fields = join(',', $fields);
		
		return "SELECT $fields FROM " . self::quoteIdentifier($table) . (isset($where) ? " WHERE $where" : '');
	}
	
	/**
	 * Build query to count the number of rows
	 * 
	 * @param mixed $statement  
     * @param bool  $all        Don't use limit
     * @return string
	 */
	public static function buildCountStatement($statement, $all=false)
	{
		$parts = is_array($statement) ? $statement : self::split($statement);
		if (self::getQueryType($statement) == 'insert' && isset($parts['query'])) $parts = self::split($parts['query']);
   		
   		if (!isset($parts['from']) && !isset($parts['into']) && !isset($parts['tables'])) return null; # Unable to determine a from, so no rowcount query possible

		if ($all && isset($parts['limit'])) {
			unset($parts['limit']);
			$statement = $parts;
		}
   		
		if (!empty($parts['having'])) return "SELECT COUNT(*) FROM (" . (is_array($statement) ? self::join($statement) : $statement) . ")";
   	
		$distinct = null;
		$column = preg_match('/DISTINCT\b.*?(?=\,|$)/si', $parts['columns'], $distinct) ? "COUNT(" . $distinct[0] . ")" : !empty($parts['group by']) ? "COUNT(DISTINCT " . $parts['group by'] . ")" : "COUNT(*)";
   		if (isset($parts['limit'])) {
   			list($limit, $offset) = self::splitLimit($parts['limit']);
   			if (isset($limit)) $column = "LEAST($column, $limit " . (isset($offset) ? ", ($column) - $offset" : '') . ")";
   		}
   		
   		return self::join(array(0=>'SELECT', 'columns'=>$column, 'from'=>isset($parts['from']) ? $parts['from'] : (isset($parts['into']) ? $parts['into'] : $parts['tables']), 'where'=>isset($parts['where']) ? $parts['where'] : ''));
	}
	
	/**
	 * Create a statement to insert/update rows.
	 * 
	 * @param string $table
	 * @param array  $primairy_key   Array with fields of primary key
	 * @param array  $fieldnames
	 * @param array  $rows           As array(array(value, value, ...), array(value, value, ...), ...)  
	 * @return string
	 */
	public static function buildStoreStatement($table, $primairy_key, $fieldnames, $rows)
	{
		$sql_fields = array();
		$sql_update = array();
		$sql_rows = array();

		if (empty($rows)) throw new Exception("Unable to build store statement: No rows.");
		
		foreach ($fieldnames as $fieldname) {
			$fieldq = self::quoteIdentifier($fieldname);
			$sql_fields[] = $fieldq;
			$sql_update[] = in_array($fieldname, (array)$primairy_key) ? "$fieldq=IFNULL($fieldq, VALUES($fieldq))" : "$fieldq=VALUES($fieldq)";
		}

		foreach ($rows as $row) {
			$sql_row = array();
			foreach ($row as $value) $sql_row[] = self::quote($value, 'DEFAULT');
			$sql_rows[] = "(" . join(", " , $sql_row) . ")";
		}

		return "INSERT INTO " . self::quoteIdentifier($table) . " (" . join(", ", $sql_fields) . ")" . " VALUES " . join(', ', $sql_rows) . " ON DUPLICATE KEY UPDATE " . join(", ", $sql_update);
	}
	
	/**
	 * Create query to update rows of a table.
	 * 
	 * @param string $table
	 * @param array  $criteria  As array(field=>value, ...)
	 * @param array  $values    Assasioted array as (fielname=>value, ...)
	 * @return string
	 */
	public static function buildUpdateStatement($table, $criteria, $values)
	{
		foreach ((array)$criteria as $key=>$value) {
		    $where = (isset($where) ? "$where AND " : '') . self::quoteIdentifier($key) . ' = ' . self::quote($value);
		}
	    
		$sql_set = array();
		foreach ($values as $fieldname=>$value) {
			$sql_set[] = self::quoteIdentifier($fieldname) . '=' . self::quote($value);
		}

		return "UPDATE " . self::quoteIdentifier($table) . " SET " . join(', ', $sql_set) . (isset($where) ? " WHERE $where" : '');
	}
	
	/**
	 * Create query to delete rows from a table.
	 * 
	 * @param string $table     Tablename
	 * @param array  $criteria  As array(field=>value, ...)
	 * @return string
	 */
	public static function buildDeleteStatement($table, $criteria)
	{
		foreach ($criteria as $field=>$value) {
	        $where = (!isset($where) ? 'WHERE ' : "$where AND ") . self::quoteIdentifier($field) . ' = ' . self::quote($value);
	    }
		return "DELETE " . self::quoteIdentifier($table) . ".* FROM " . self::quoteIdentifier($table) . " $where";
	}

	/**
	 * Create query to delete all rows from a table.
	 * 
	 * @param string $table  Tablename
	 * @return string
	 */
	public static function buildTruncateStatement($table)
	{
	    return "TRUNCATE " . self::quoteIdentifier($table);
	}
	/**
	 * Removes white space
	 * 
	 * @author kent
	 * @param string $sql Query
	 * @return string
	 */
	public static function clean($sql) 
	{ 
		return trim(str_replace(array("\n","\t","\r","\s\s"), ' ', preg_replace("/[\s]{2,}/", ' ', $sql)));
	}
	/**
	 * Detects queries that involve any JOIN types incompatible between MySQL 4 and 5
	 * 
	 * Specifically, any usage of USING or NATURAL beyond the first join is detected and rejected.
	 * 
	 * @author kent
	 * @param string $sql Query
	 * @return boolean True if compatible, false otherwise
	 */
	public static function isIncomptible($sql)
	{
		$sql = self::clean($sql);
		
		$aryIrrelevant = array(
			'ALTER',
			'DESC',
			'DROP',
			'USE',
			'SET', 	
			'SHOW',
			'START',
		);
		
		foreach( $aryIrrelevant as $strIrrelevant ) { if( strpos(strtoupper($sql), $strIrrelevant) === 0 ) { return true; } }
		
		if( strtoupper(substr($sql, 0, 6)) == 'CREATE' )
		{
			$strSelect = stristr($sql, 'SELECT');
			
			if( $strSelect ) { return self::isIncomptible($strSelect); }
			else { return true; }
		}
		
		foreach( self::extractSplit($sql) as $arySplit )
		{
			if( strtoupper($arySplit[0]) == 'SELECT' )
			{
				$strFrom = $arySplit['from'];
				
				$aryIncompitable = array(
					"/.*JOIN .*NATURAL/i",
					"/.*\,.*NATURAL/i",
					"/.*JOIN .*JOIN .*USING/i",
					"/.*JOIN .*\,.*USING/i",
					"/.*\,.*JOIN .*USING/i",
					"/.*\,.*\,.*USING/i",
				);
				
				foreach( $aryIncompitable as $strIncompatible )
				{
					if( preg_match($strIncompatible, $strFrom, $aryMatches) > 0 )
					{
						return false;
					}
				}
			}
		}
		
		return true;
	}
}

require_once 'lib/sql.class.php';
$rscConn = mysql_connect('host', 'user', 'pass');

$strQuery = "SHOW TABLES IN local_profiler LIKE 'queries_%'";
$aryTables = dce_mysql_query($strQuery, $rscConn, SQL_ONECOL);

foreach( $aryTables as $strTable )
{
	$strQuery = "SELECT queryId, query FROM local_profiler.$strTable WHERE CHAR_LENGTH(query) < 4000";
	$aryQueries = dce_mysql_query($strQuery, $rscConn, SQL_ONECOL_ASSOC);
	
	foreach( $aryQueries as $intId => $strQuery )
	{	
		try
		{ 
			$blnIsCompatible = DB_MySQL_QuerySplitter::isIncomptible($strQuery);
	
			if( !$blnIsCompatible ) { echo "INCOMPATIBILITY in $strTable.$intId:\n ", DB_MySQL_QuerySplitter::clean($strQuery), "\n"; }
		}
		catch( Exception $e ) {  echo $e->getMessage(), "\n"; }
	}
}
?>