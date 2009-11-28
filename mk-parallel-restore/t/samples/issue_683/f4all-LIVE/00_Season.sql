CREATE TABLE `Season` (
  `DTYPE` varchar(31) NOT NULL,
  `id` int(11) NOT NULL auto_increment,
  `version` int(11) NOT NULL,
  `yearsAsString` varchar(255) default NULL,
  `begin` datetime default NULL,
  `name` varchar(255) default NULL,
  `alias_id` int(11) default NULL,
  PRIMARY KEY  (`id`),
  KEY `FK935F5703B0A81CB7` (`alias_id`),
  CONSTRAINT `FK935F5703B0A81CB7` FOREIGN KEY (`alias_id`) REFERENCES `Season` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=48 DEFAULT CHARSET=utf8