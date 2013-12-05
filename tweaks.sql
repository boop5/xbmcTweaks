/* "K�rzlich hinzugef�gt" richtig* berechnen:
 * Das Datum richtet sich nach dem Datum des Hinzuf�gens in die Datenbank
 * statt nach dem Created Datum der entsprechenden Datei.
 */
 CREATE TRIGGER `bi_files` BEFORE INSERT ON `files` FOR EACH ROW SET NEW.dateAdded = now();
  
/* Die sogenannten RESUME Bookmarks werden pro SQL Account angelegt
 * statt f�r Alle Benutzer.
 */ 

# Delete table, trigger and view if neccessary
DROP TABLE IF EXISTS `bookmark`;
DROP TRIGGER IF EXISTS `bi_bookmark`;
/* DROP VIEW IF EXISTS movieview */

# Create the bookmark table
CREATE TABLE `bookmark` (
    `idBookmark` INT(11) NOT NULL AUTO_INCREMENT,
    `idFile` INT(11) NULL DEFAULT NULL,
    `timeInSeconds` DOUBLE NULL DEFAULT NULL,
    `totalTimeInSeconds` DOUBLE NULL DEFAULT NULL,
    `thumbNailImage` TEXT NULL,
    `player` TEXT NULL,
    `playerState` TEXT NULL,
    `type` INT(11) NULL DEFAULT NULL,
    `sqlUser` VARCHAR(250),
    PRIMARY KEY (`idBookmark`),
    INDEX `ix_bookmark` (`idFile`, `type`)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
AUTO_INCREMENT=0;

# Create the trigger that sets the current user
CREATE TRIGGER `bi_bookmark` BEFORE INSERT ON `bookmark` FOR EACH ROW SET NEW.sqlUser = SUBSTRING_INDEX(USER(),'@',1)

# Create the movieview
/* WIRD NUN VON DEM WATCHED TABELLEN SKRIPT ERZEUGT!! */
/* SELECT  movie.*,  sets.strSet AS strSet,  files.strFileName AS strFileName,  path.strPath AS strPath,
		files.playCount AS playCount,  files.lastPlayed AS lastPlayed,   files.dateAdded AS dateAdded,
		bookmark.timeInSeconds AS resumeTimeInSeconds,   bookmark.totalTimeInSeconds AS totalTimeInSeconds 
	FROM movie  
	LEFT JOIN sets ON    sets.idSet = movie.idSet  
	JOIN files ON    files.idFile=movie.idFile  
	JOIN path ON    path.idPath=files.idPath  
	LEFT JOIN bookmark ON    bookmark.idFile=movie.idFile AND bookmark.type=1 AND bookmark.sqlUser = SUBSTRING_INDEX(USER(),'@',1) */

/* Erzeugt die Tabelle, welche den 'watched' Status pro SQL Account verwaltet
 * statt ein Status f�r alle Benutzer
 */
 DROP TABLE IF EXISTS `filestate`;
 CREATE TABLE `filestate` (
	`idFile` INT(11) NOT NULL,
	`lastPlayed` TEXT NOT NULL,
	`playCount` INT NOT NULL,
	`sqlUser` VARCHAR(250) NOT NULL,
	PRIMARY KEY (`idFile`),
	UNIQUE INDEX `idFile_sqlUser` (`idFile`, `sqlUser`)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

/* Trigger der den Playcount etc �bertr�gt
 */
DELIMITER |
DROP TRIGGER IF EXISTS `bu_files`; 
CREATE TRIGGER `bu_files` BEFORE UPDATE ON `files` 
	FOR EACH ROW BEGIN
		DELETE FROM filestate WHERE filestate.idFile = new.idFile AND filestate.sqlUser = SUBSTRING_INDEX(USER(),'@',1);
		INSERT INTO filestate (idFile, lastPlayed, playCount, sqlUser) VALUES(new.idFile, new.lastPlayed, new.playCount, SUBSTRING_INDEX(USER(),'@',1));
	END;
--UPDATE filestate SET filestate.lastPlayed = new.lastPlayed, filestate.playCount = new.playCount 
--WHERE filestate.idFile = new.idFile AND filestate.sqlUser = SUBSTRING_INDEX(USER(),'@',1);
--INSERT INTO filestate  (idFile, lastPlayed, playCount, sqlUser) VALUES(new.idFile, new.lastPlayed, new.playCount, SUBSTRING_INDEX(USER(),'@',1))
--ON DUPLICATE KEY UPDATE
--  lastPlayed     = VALUES(NEW.lastPlayed),
--  playCount = VALUES(NEW.playCount)
--REPLACE INTO filestate (idFile, lastPlayed, playCount, sqlUser) VALUES(new.idFile, new.lastPlayed, new.playCount, SUBSTRING_INDEX(USER(),'@',1));

/* Erzeugt die movieview neu. 
 * Enth�lt auch �nderungen f�r die RESUME bookmarks
 */
DROP VIEW IF EXISTS `movieview`;
CREATE VIEW `movieview` AS
	SELECT  movie.*,  sets.strSet AS strSet,  files.strFileName AS strFileName,  path.strPath AS strPath,  
			filestate.playCount AS playCount,  filestate.lastPlayed AS lastPlayed,   files.dateAdded AS dateAdded,   
			bookmark.timeInSeconds AS resumeTimeInSeconds,   bookmark.totalTimeInSeconds AS totalTimeInSeconds 
		FROM movie  
		LEFT JOIN sets ON    sets.idSet = movie.idSet  
		JOIN files ON    files.idFile=movie.idFile  
		JOIN path ON    path.idPath=files.idPath  
		LEFT JOIN bookmark ON    bookmark.idFile=movie.idFile AND bookmark.type=1 AND bookmark.sqlUser = SUBSTRING_INDEX(USER(),'@',1)
		LEFT JOIN filestate ON filestate.idFile = files.idFile AND filestate.sqlUser = SUBSTRING_INDEX(USER(),'@',1)