CREATE TABLE backupset (
  setname  CHAR(10)  NOT NULL,
  priority INT       NOT NULL DEFAULT 0,
  db       CHAR(64)  NOT NULL,
  tbl      CHAR(64)  NOT NULL,
  ts       TIMESTAMP NOT NULL,
  PRIMARY KEY(setname, db, tbl),
  KEY(setname, priority, db, tbl)
);
