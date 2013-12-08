/* Tweaks for XBMC
 * Tested with "Frodo" 12.2
 */


/* Artistview anpassen um 'doppelte' Einträge zu entfernen.
 * Beispiel:
 * Eminem
 *
 * Statt:
 * Eminem
 * Eminem feat. Skylar Grey
 * Eminem feat D12
 * ...
 */
 
 DROP VIEW IF EXISTS `artistview`
 CREATE VIEW `artistview` AS
	SELECT DISTINCT  
		artist.idArtist AS idArtist, strArtist,   strBorn, strFormed, artistinfo.strGenres,  
		artistinfo.strMoods, artistinfo.strStyles, strInstruments,   strBiography, strDied, strDisbanded,   
		strYearsActive, artistinfo.strImage, strFanart 
	FROM artist   
	LEFT OUTER JOIN artistinfo ON    artist.idArtist = artistinfo.idArtist
	JOIN album ON album.strArtists = artist.strArtist;