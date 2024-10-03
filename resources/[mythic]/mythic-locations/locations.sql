CREATE TABLE IF NOT EXISTS `locations` (
  `_id` uuid NOT NULL DEFAULT uuid(),
  `Coords` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`Coords`)),
  `Heading` int(11) DEFAULT NULL,
  `Type` varchar(255) DEFAULT NULL,
  `Name` varchar(50) DEFAULT NULL,
  `default` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;