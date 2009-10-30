USE test;
DROP TABLE IF EXISTS `t001`;
CREATE TABLE `t001` (
   u int unsigned,
   i int not null,
   d datetime
);

INSERT INTO `test`.`t001` VALUES (1, 2, NOW()), (2, 3, NOW());
