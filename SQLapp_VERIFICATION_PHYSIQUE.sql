--------------------------------VERIFICATION PHYSIQUE
-------Toutes les données graves sont inscrites dans le journal (codes d'erreur 823 et 824 - codes erreurs renvoyés par WINDOWS parce que c'est lui qui gere les lectures/ecritures)
/*
	Il faut checker les bases de données à la même frequence que les sauvegardes complètes. Faire tous les jours si il y a des heures creuses.
	Pour alleger les temps de traitement on peut activer que l'option DATA_PURITY et la commandes CHECKCONSTRAINTS de temps en temps
*/

/*
	Vérification lors des écritures. Les bases sont parametrées pour vérifier les données lors de leurs lectures.
	CHECKSUM - clé de hachage sur la totalité des données de la page, TORN_PAGE_DETECTION - teste les 2 premiers bits de bloc de 512ko
	Taches peu couteuse en rapport du temps de lecture sur un DD
	Pour modifier: ALTER DATABASE … SET PAGE_VERIFY TORN_PAGE_DETECTION
*/
	SELECT name, page_verify_option_desc FROM sys.databases;

-- La table système msdb.dbo.suspect_pages est alimentée par une référence à la page endommagée et la nature de l’erreur.
	select * from msdb.dbo.suspect_pages

/*
	Vérification complete de la base
		DBCC CHECKALLOC - Vérifie la cohérence d’allocation des pages de la base de données.
		DBCC CHECKTABLE - Vérifie l’intégrité des données dans les pages (pages, structures et index)
		DBCC CHECKDB	- Effectue toutes les vérifications physiques d’une base pour toutes les données.
	la vérification s’effectue dans une copie interne des données (snapshot) effectuée dans la base tempdb pour ne pas bloquer la production.	
*/
	DBCC CHECKALLOC (RAN_ATOFFICE) WITH ESTIMATEONLY; --Donne l'espace necessaire dans TEMPDB pour faire la vérification
	DBCC CHECKALLOC (RAN_ATOFFICE) WITH NO_INFOMSGS, TABLOCK;	--Ne retroune pas les messages d'informations et vérouille la base (travaille directement sur la base, pas de copie dasn TEMPDB), plus rapide
	DBCC CHECKTABLE ('USR', NOINDEX) WITH DATA_PURITY -- DATA_PURITY vérifie que les données bonaires corrrespondent aux types de données attendus.
	DBCC CHECKTABLE ('RAN_ATOFFICE.dbo.CMD', 2) -- Vérification de l'index 2 de la table CMD
--Liste de l'ensemble des commandes DBCC CHECKTABLE pour tous les objets de la base
	SELECT 'DBCC CHECKTABLE (''' + DB_NAME() + '.' + s.name	+ '.' + o.name + ''') WITH NO_INFOMSGS, DATA_PURITY, ' + 'EXTENDED_LOGICAL_CHECKS;'
	FROM sys.objects AS o
	INNER JOIN sys.schemas AS s
	ON o.schema_id = s.schema_id
	WHERE EXISTS(SELECT *
	FROM sys.indexes AS i
	WHERE o.object_id = i.object_id)
	AND o.type_desc IN ('USER_TABLE', 'VIEW');
-- DBCC CHECKDB (exécute successivement CHECKALLOC, CHECKTABLE et CHECKCATALOG
	DBCC CHECKDB (0) WITH DATA_PURITY, EXTENDED_LOGICAL_CHECKS;
-- Exemple de CHECK complet de serveur: https://ola.hallengren.com/sql-server-integrity-check.html
-- On peut effectuer les vérifications quotidiennes hors index pour alleger et reporter les vérifications complètes le week-end
/* DBCC CHECKCONSTRAINTS vérifie les contraintes FOREIGN KEY et CHECK (vérifie les pages du disque mais d'abord les pages en memoire quand c'est possible)
	DBCC CHECKCONSTRAINTS - vérifie toutes les contraintes actives de la base
*/
	DBCC CHECKCONSTRAINTS ('FACT') WITH ALL_CONSTRAINTS; --ALL_CONSTRAINTS - vérifie les contraintes actives et inactives
/*
-------REPARATION
	- Déplacer les fichiers de la base du média sur lequel les erreurs sont apparues (sp_detach_db, CREATE DATABASE … FOR ATTACH)
	- Si l’erreur porte sur la donnée (DATA_PURITY), exécutez un UPDATE sur les lignes incriminées pour forcer une nouvelle valeur.
	- Si l’erreur porte sur des index, supprimez-les et reconstruisez-les. Vous pouvez, par exemple, utiliser la commande CREATE INDEX … WITH (DROP_EXISTING = ON).
	- Si l’erreur porte sur une vue indexée, supprimez-la et reconstruisez-la.
	- Si l’erreur porte sur des données des tables de production, procédez à une restauration de page (RESTORE DATABASE/LOG … PAGE = '…' …)
	- Si l’erreur porte sur des données autres que les tables de production (tables ou pages système), vous devez procéder à une restauration entière de la base.
	- Si vous ne disposez pas d’une sauvegarde dans laquelle les pages incriminées saines, vous pouvez tenter d’appliquer un DBCC CHECK… avec une option de réparation.
*/
	USE RAN_ATOFFICE;
	GO
	ALTER DATABASE RAN_ATOFFICE
	SET SINGLE_USER
	WITH ROLLBACK IMMEDIATE;	 -- Les transactions incomplete seront restaurées et les autres connexions déconnectées
	GO
	DBCC CHECKTABLE('USR', REPAIR_REBUILD);
	GO
	ALTER DATABASE RAN_ATOFFICE
	SET MULTI_USER;
	GO
/* Lorsque la vérification physique (DBCC CHECK …) lève une erreur, celle-ci fournit de nombreuses informations, deux d’entre elles étant indispensables :
		- l’identifiant du fichier dans la base
		- l’identifiant de la page dans le fichier
	Les DBCC CHCK* créent des rapport d'erreurs (dump) - dans le repertoire \log de l'instance (SQLDUMPnnnn.txt)
*/
-- Donne la référence de fichier, de page et slot de ligne en erreur:
	USE RAN_ATOFFICE;
	GO
	DBCC CHECKTABLE('LIGFACT')	WITH DATA_PURITY;
--Utiliser DBCC PAGE pour connaitre quelle ligne de données est en erreur. 
--A partir de ces données on peut MAJ la ligne en erreur.
	DBCC PAGE ('RAN_ATOFFICE', 3, 1136, 3) WITH TABLERESULTS; --(nom de la BDD, num fichier, num page, mode  de visualisation)
-- Informations d'allocations de la table
	DBCC EXTENTINFO(10,901578250,-1); 

	DECLARE @db_name SYSNAME; 
	DECLARE @tb_name SYSNAME;
	SET @db_name = N'RAN_ATOFFICE'; 
	SET @tb_name = N'USR';
	DBCC EXTENTINFO(@db_name,@tb_name,-1);  -- nom DB, nom table, numéro d'index
	GO
-- Espace utilisé par une table
	sp_spaceused USR
/*Dans le cadre de mirroring les pages endommagées sont réparées automatiquement. Voir les corrections
	Une erreur est enregistrée dans le journal. Si il y a bcp d'erreur il faut se demander si il ne faut pas changer le support de stockage ou le controleur
*/
	select * from sys.dm_db_mirroring_auto_page_repair

	
	
------------------------------------------------------------------------------
select * from sys.messages where language_id=1036 and message_id=8992
select * from sys.syslanguages

	select * from msdb.dbo.suspect_pages
	select * from sys.databases

	DBCC PAGE ('NEO_ATOFFICE', 2, 2330, 3) WITH TABLERESULTS;

	

select OBJECT_NAME(10)
select OBJECT_ID('USR')
select * from BOU_EFORCE.dbo.PORT
SELECT DISTINCT OBJECT_NAME(3) FROM RAN_ATOFFICE
