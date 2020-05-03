CREATE TABLE IF NOT EXISTS `rankings` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `TimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `MapName` varchar(32) NOT NULL,
  `UserName` varchar(32) DEFAULT NULL,
  `UserID` int(11) NOT NULL,
  `Score` float NOT NULL,
  PRIMARY KEY (`ID`)
);

CREATE TABLE IF NOT EXISTS `spawnpoint` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `TimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `MapName` char(32) NOT NULL,
  `Pos0_X` float,
  `Pos0_Y` float,
  `Pos0_Z` float,
  `Pos1_X` float,
  `Pos1_Y` float,
  `Pos1_Z` float,
PRIMARY KEY (`ID`)
);