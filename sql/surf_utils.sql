CREATE TABLE `rankings` (
`ID` int(11) NOT NULL AUTO_INCREMENT,
`TimeStamp` timestamp,
`MapName` varchar(32) NOT NULL,
`UserName` varchar(32),
`UserID` int(11) NOT NULL,
`Score` float NOT NULL,
PRIMARY KEY (`ID`)
)