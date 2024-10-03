CREATE TABLE IF NOT EXISTS `weed` (
  `id` uuid NOT NULL DEFAULT uuid(),
  `isMale` tinyint(1) NOT NULL,
  `location` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `growth` int(11) DEFAULT 0,
  `output` int(11) DEFAULT 1,
  `material` varchar(255) NOT NULL,
  `planted` longtext DEFAULT NULL,
  `water` float DEFAULT 100,
  CONSTRAINT `location` CHECK (json_valid(`location`))
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;