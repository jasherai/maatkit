USE test;
DROP TABLE IF EXISTS t1;
CREATE TABLE t1 ( a INT NOT NULL, INDEX idx (a) );

INSERT INTO t1 VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(6),(3),(2),(5),(76),(3),(2),(5),(7),(3),(21),(5),(7),(4),(2),(1),(13),(54),(7),(8),(7),(6),(5),(4),(2),(21),(4),(5),(6),(76),(7),(67),(65),(9),(5),(4),(3),(2),(1),(1),(2),(100),(3),(4),(65),(6);

DROP TABLE IF EXISTS t2;
CREATE TABLE t2 ( a INT NOT NULL, INDEX idx (a) );

DROP TRIGGER IF EXISTS test_trig;
DELIMITER //
CREATE TRIGGER test_trig BEFORE INSERT ON test.t1
   FOR EACH ROW BEGIN
   INSERT INTO test.t2 SET a = NEW.a;
END
