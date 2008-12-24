USE test;
DROP TABLE IF EXISTS query_review;
CREATE TABLE query_review (
  checksum     BIGINT UNSIGNED NOT NULL PRIMARY KEY, -- md5 of fingerprint
  fingerprint  TEXT NOT NULL,
  sample       TEXT NOT NULL,
  first_seen   DATETIME,
  last_seen    DATETIME,
  reviewed_by  VARCHAR(20),
  reviewed_on  DATETIME,
  comments     VARCHAR(100),
  cnt          INT UNSIGNED DEFAULT 1
);
