CREATE TABLE IF NOT EXISTS `bans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account` varchar(255) NOT NULL DEFAULT '0',
  `identifier` varchar(255) DEFAULT NULL,
  `expires` longtext DEFAULT NULL,
  `reason` text DEFAULT NULL,
  `issuer` varchar(255) DEFAULT NULL,
  `active` int(11) DEFAULT NULL,
  `started` longtext DEFAULT NULL,
  `tokens` longtext DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


CREATE TABLE IF NOT EXISTS `users` (
  `_id` uuid NOT NULL DEFAULT uuid(),
  `identifier` varchar(255) DEFAULT NULL,
  `priority` int(11) NOT NULL DEFAULT 0,
  `groups` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`groups`)),
  `name` varchar(50) DEFAULT NULL,
  `joined` bigint(20) DEFAULT NULL,
  `verified` tinyint(1) DEFAULT NULL,
  `account` int(11) NOT NULL AUTO_INCREMENT,
  `tokens` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`tokens`)),
  PRIMARY KEY (`account`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;