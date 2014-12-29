/* Tweaks for XBMC
 * Tested with "Frodo" 12.2 / 12.3
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
DROP VIEW IF EXISTS `bookmark`;
DROP TABLE IF EXISTS `bookmark_orig`;
DROP TRIGGER IF EXISTS `bi_bookmark`;

CREATE TABLE `bookmark_orig` (
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

CREATE TRIGGER `bi_bookmark` BEFORE INSERT ON `bookmark_orig` FOR EACH ROW SET NEW.sqlUser = SUBSTRING_INDEX(USER(),'@',1);

CREATE VIEW `bookmark` AS
	SELECT idBookmark, idFile, timeinSeconds, totalTimeInSeconds, thumbnailImage, player, playerstate, type
	FROM bookmark_orig
	WHERE bookmark_orig.sqlUser = SUBSTRING_INDEX(USER(),'@',1);

/* Erzeugt die Tabelle, welche den 'watched' Status pro SQL Account verwaltet
 * statt ein Status für alle Benutzer
 */
DROP TABLE IF EXISTS `filestate`;
CREATE TABLE `filestate` (
	`idFile` INT(11) NOT NULL,
	`lastPlayed` TEXT,
	`playCount` INT,
	`sqlUser` VARCHAR(250) NOT NULL,
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
			bookmark_orig.timeInSeconds AS resumeTimeInSeconds,   bookmark_orig.totalTimeInSeconds AS totalTimeInSeconds 
		FROM movie  
		LEFT JOIN sets ON    sets.idSet = movie.idSet  
		JOIN files ON    files.idFile=movie.idFile  
		JOIN path ON    path.idPath=files.idPath  
		LEFT JOIN bookmark_orig ON    bookmark_orig.idFile=movie.idFile AND bookmark_orig.type=1 AND bookmark_orig.sqlUser = SUBSTRING_INDEX(USER(),'@',1)
		LEFT JOIN filestate ON filestate.idFile = files.idFile AND filestate.sqlUser = SUBSTRING_INDEX(USER(),'@',1);
		
		
/* View für Episoden(Serien) anpassen, um den watched state zu verteilen
 */		
DROP VIEW IF EXISTS `episodeview`;		
CREATE VIEW `episodeview` AS
	SELECT 
		episode.*, files.strFileName AS strFileName, path.strPath AS strPath, 
		filestate.playCount AS playCount, filestate.lastPlayed AS lastPlayed, files.dateAdded AS dateAdded, 
		tvshow.c00 AS strTitle, tvshow.c14 AS strStudio, tvshow.c05 AS premiered, tvshow.c13 AS mpaa, 
		bookmark_orig.timeInSeconds AS resumeTimeInSeconds,
		bookmark_orig.totalTimeInSeconds AS totalTimeInSeconds, seasons.idSeason AS idSeason
	FROM episode
	JOIN files ON files.idFile=episode.idFile
	JOIN tvshow ON tvshow.idShow=episode.idShow
	LEFT JOIN seasons ON seasons.idShow=episode.idShow AND seasons.season=episode.c12
	JOIN path ON files.idPath=path.idPath
	LEFT JOIN bookmark_orig ON bookmark_orig.idFile=episode.idFile AND bookmark_orig.type=1 AND bookmark_orig.sqlUser = SUBSTRING_INDEX(USER(),'@',1)
	LEFT JOIN filestate ON filestate.idFile = files.idFile AND filestate.sqlUser = SUBSTRING_INDEX(USER(),'@',1);
	

/* View für Serien anpassen, um den watched state zu verteilen
 */		
DROP VIEW IF EXISTS `tvshowcounts`;
CREATE VIEW tvshowcounts AS
	SELECT
		tvshow.idShow AS idShow,
        MAX(files.lastPlayed) AS lastPlayed,
        NULLIF(COUNT(episode.c12), 0) AS totalCount,
        COUNT(files.playCount) AS watchedcount,
        NULLIF(COUNT(DISTINCT(episode.c12)), 0) AS totalSeasons,
		MAX(files.dateAdded) as dateAdded
	FROM tvshow
	LEFT JOIN episode ON episode.idShow=tvshow.idShow
	LEFT JOIN files ON files.idFile=episode.idFile
	LEFT JOIN filestate on filestate.idFile = episode.idFile AND filestate.sqlUser = SUBSTRING_INDEX(USER(),'@',1)
	GROUP BY tvshow.idShow

DROP VIEW IF EXISTS `seasonview`;
CREATE VIEW seasonview AS
	SELECT
		seasons.*,
		tvshowview.strPath AS strPath,
		tvshowview.c00 AS showTitle,
		tvshowview.c01 AS plot,
		tvshowview.c05 AS premiered,
		tvshowview.c08 AS genre,
		tvshowview.c14 AS strStudio,
		tvshowview.c13 AS mpaa,
		count(DISTINCT episodeview.idEpisode) AS episodes,
		count(files.playCount) AS playCount
	FROM seasons
        JOIN tvshowview ON tvshowview.idShow = seasons.idShow
        JOIN episodeview ON episodeview.idShow = seasons.idShow AND episodeview.12 = seasons.season
        JOIN files ON files.idFile = episodeview.idFile
        LEFT JOIN filestate on filestate.idFile = episodeview.idFile AND filestate.sqlUser = SUBSTRING_INDEX(USER(),'@',1)
        GROUP BY seasons.idSeason
