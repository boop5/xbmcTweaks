/* Tweaks for XBMC
 * Tested with "Frodo" 12.2
 */

/* "Kürzlich hinzugefügt" richtig* berechnen:
 * Das Datum richtet sich nach dem Datum des Hinzufügens in die Datenbank
 * statt nach dem Created Datum der entsprechenden Datei.
 */
DROP TRIGGER IF EXISTS `bi_files`;
CREATE TRIGGER `bi_files` BEFORE INSERT ON `files` FOR EACH ROW SET NEW.dateAdded = now();
  
/* Die sogenannten RESUME Bookmarks werden pro SQL Account angelegt
 * statt für Alle Benutzer.
 */ 
DROP TABLE IF EXISTS `bookmark`;
DROP TRIGGER IF EXISTS `bi_bookmark`;

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

CREATE TRIGGER `bi_bookmark` BEFORE INSERT ON `bookmark` FOR EACH ROW SET NEW.sqlUser = SUBSTRING_INDEX(USER(),'@',1);

/* Erzeugt die Tabelle, welche den 'watched' Status pro SQL Account verwaltet
 * statt ein Status für alle Benutzer
 */
DROP TABLE IF EXISTS `filestate`;
CREATE TABLE `filestate` (
	`idFile` INT(11) NOT NULL,
	`lastPlayed` TEXT,
	`playCount` INT,
	`sqlUser` VARCHAR(250) NOT NULL,
	PRIMARY KEY (`idFile`),
	UNIQUE INDEX `idFile_sqlUser` (`idFile`, `sqlUser`)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

/* Trigger der den Playcount etc überträgt
 */
DELIMITER |
DROP TRIGGER IF EXISTS `bu_files`; 
CREATE TRIGGER `bu_files` BEFORE UPDATE ON `files` 
	FOR EACH ROW BEGIN
		DELETE FROM filestate WHERE filestate.idFile = new.idFile AND filestate.sqlUser = SUBSTRING_INDEX(USER(),'@',1);
		INSERT INTO filestate (idFile, lastPlayed, playCount, sqlUser) VALUES(new.idFile, new.lastPlayed, new.playCount, SUBSTRING_INDEX(USER(),'@',1));
	END;

/* Erzeugt die movieview neu. 
 * Enthält auch Änderungen für die RESUME bookmarks
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
		LEFT JOIN filestate ON filestate.idFile = files.idFile AND filestate.sqlUser = SUBSTRING_INDEX(USER(),'@',1);
		
		
/* View für Episoden(Serien) anpassen, um den watched state zu verteilen
 */		
DROP VIEW IF EXISTS `episodeview`;		
CREATE VIEW `episodeview` AS
	SELECT 
		episode.*, files.strFileName AS strFileName, path.strPath AS strPath, 
		filestate.playCount AS playCount, filestate.lastPlayed AS lastPlayed, files.dateAdded AS dateAdded, 
		tvshow.c00 AS strTitle, tvshow.c14 AS strStudio, tvshow.c05 AS premiered, tvshow.c13 AS mpaa, 
		tvshow.c16 AS strShowPath, bookmark.timeInSeconds AS resumeTimeInSeconds,
		bookmark.totalTimeInSeconds AS totalTimeInSeconds, seasons.idSeason AS idSeason
	FROM episode
	JOIN files ON files.idFile=episode.idFile
	JOIN tvshow ON tvshow.idShow=episode.idShow
	LEFT JOIN seasons ON seasons.idShow=episode.idShow AND seasons.season=episode.c12
	JOIN path ON files.idPath=path.idPath
	LEFT JOIN bookmark ON bookmark.idFile=episode.idFile AND bookmark.type=1
	LEFT JOIN filestate ON filestate.idFile = files.idFile AND filestate.sqlUser = SUBSTRING_INDEX(USER(),'@',1);
	

/* View für Serien anpassen, um den watched state zu verteilen
 */		
DROP VIEW IF EXISTS `tvshowview`;
CREATE VIEW `tvshowview` AS
	SELECT 
		tvshow.*, path.strPath AS strPath, path.dateAdded AS dateAdded, 
		MAX(filestate.lastPlayed) AS lastPlayed, NULLIF(COUNT(episode.c12), 0) AS totalCount, 
		COUNT(filestate.playCount) AS watchedcount, NULLIF(COUNT(DISTINCT(episode.c12)), 0) AS totalSeasons
	FROM tvshow
	LEFT JOIN tvshowlinkpath ON tvshowlinkpath.idShow=tvshow.idShow
	LEFT JOIN path ON path.idPath=tvshowlinkpath.idPath
	LEFT JOIN episode ON episode.idShow=tvshow.idShow
	LEFT JOIN files ON files.idFile=episode.idFile
	LEFT JOIN filestate on filestate.idFile = episode.idFile AND filestate.sqlUser = SUBSTRING_INDEX(USER(),'@',1)
	GROUP BY tvshow.idShow