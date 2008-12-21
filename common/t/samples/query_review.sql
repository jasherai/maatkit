USE test;
DROP TABLE IF EXISTS query_review;
CREATE TABLE query_review (
  checksum     BIGINT UNSIGNED NOT NULL PRIMARY KEY, -- md5 of fingerprint
  fingerprint  TEXT NOT NULL,
  sample       TEXT NOT NULL,
  first_seen   TIMESTAMP,
  last_seen    TIMESTAMP,
  reviewed_by  VARCHAR(20),
  reviewed_on  TIMESTAMP,
  comments     VARCHAR(100),
  cnt          INT UNSIGNED DEFAULT 1,
  Query_time_sum     INT UNSIGNED,
  Query_time_sttdev  DECIMAL(5, 3)
);

INSERT INTO query_review VALUES
(11676753765851784517, 'select col from foo_tbl', 'SELECT col FROM foo_tbl', '2008-12-19 16:56:31', '2008-12-20 11:48:27', NULL, NULL, NULL, 3, NULL, NULL),
(15334040482108055940, 'select col from bar_tbl', 'SELECT col FROM bar_tbl', '2008-12-19 16:56:31', '2008-12-20 11:48:57', NULL, NULL, NULL, 3, NULL, NULL);

