--------------------------------VERIFICATION PHYSIQUE
-------Toutes les donn�es graves sont inscrites dans le journal (codes d'erreur 823 et 824 - codes erreurs renvoy�s par WINDOWS parce que c'est lui qui gere les lectures/ecritures)
/*
	Il faut checker les bases de donn�es � la m�me frequence que les sauvegardes compl�tes. Faire tous les jours si il y a des heures creuses.
	Pour alleger les temps de traitement on peut activer que l'option DATA_PURITY et la commandes CHECKCONSTRAINTS de temps en temps
*/

/*
	V�rification lors des �critures. Les bases sont parametr�es pour v�rifier les donn�es lors de leurs lectures.
	CHECKSUM - cl� de hachage sur la totalit� des donn�es de la page, TORN_PAGE_DETECTION - teste les 2 premiers bits de bloc de 512ko
	Taches peu couteuse en rapport du temps de lecture sur un DD
	Pour modifier: ALTER DATABASE � SET PAGE_VERIFY TORN_PAGE_DETECTION
*/
	SELECT name, page_verify_option_desc FROM sys.databases;

-- La table syst�me msdb.dbo.suspect_pages est aliment�e par une r�f�rence � la page endommag�e et la nature de l�erreur.
	select * from msdb.dbo.suspect_pages

/*
	V�rification complete de la base
		DBCC CHECKALLOC - V�rifie la coh�rence d�allocation des pages de la base de donn�es.
		DBCC CHECKTABLE - V�rifie l�int�grit� des donn�es dans les pages (pages, structures et index)
		DBCC CHECKDB	- Effectue toutes les v�rifications physiques d�une base pour toutes les donn�es.
	la v�rification s�effectue dans une copie interne des donn�es (snapshot) effectu�e dans la base tempdb pour ne pas bloquer la production.	
*/
	DBCC CHECKALLOC (RAN_ATOFFICE) WITH ESTIMATEONLY; --Donne l'espace necessaire dans TEMPDB pour faire la v�rification
	DBCC CHECKALLOC (RAN_ATOFFICE) WITH NO_INFOMSGS, TABLOCK;	--Ne retroune pas les messages d'informations et v�rouille la base (travaille directement sur la base, pas de copie dasn TEMPDB), plus rapide
	DBCC CHECKTABLE ('USR', NOINDEX) WITH DATA_PURITY -- DATA_PURITY v�rifie que les donn�es bonaires corrrespondent aux types de donn�es attendus.
	DBCC CHECKTABLE ('RAN_ATOFFICE.dbo.CMD', 2) -- V�rification de l'index 2 de la table CMD
--Liste de l'ensemble des commandes DBCC CHECKTABLE pour tous les objets de la base
	SELECT 'DBCC CHECKTABLE (''' + DB_NAME() + '.' + s.name	+ '.' + o.name + ''') WITH NO_INFOMSGS, DATA_PURITY, ' + 'EXTENDED_LOGICAL_CHECKS;'
	FROM sys.objects AS o
	INNER JOIN sys.schemas AS s
	ON o.schema_id = s.schema_id
	WHERE EXISTS(SELECT *
	FROM sys.indexes AS i
	WHERE o.object_id = i.object_id)
	AND o.type_desc IN ('USER_TABLE', 'VIEW');
-- DBCC CHECKDB (ex�cute successivement CHECKALLOC, CHECKTABLE et CHECKCATALOG
	DBCC CHECKDB (0) WITH DATA_PURITY, EXTENDED_LOGICAL_CHECKS;
-- Exemple de CHECK complet de serveur: https://ola.hallengren.com/sql-server-integrity-check.html
-- On peut effectuer les v�rifications quotidiennes hors index pour alleger et reporter les v�rifications compl�tes le week-end
/* DBCC CHECKCONSTRAINTS v�rifie les contraintes FOREIGN KEY et CHECK (v�rifie les pages du disque mais d'abord les pages en memoire quand c'est possible)
	DBCC CHECKCONSTRAINTS - v�rifie toutes les contraintes actives de la base
*/
	DBCC CHECKCONSTRAINTS ('FACT') WITH ALL_CONSTRAINTS; --ALL_CONSTRAINTS - v�rifie les contraintes actives et inactives
/*
-------REPARATION
	- D�placer les fichiers de la base du m�dia sur lequel les erreurs sont apparues (sp_detach_db, CREATE DATABASE � FOR ATTACH)
	- Si l�erreur porte sur la donn�e (DATA_PURITY), ex�cutez un UPDATE sur les lignes incrimin�es pour forcer une nouvelle valeur.
	- Si l�erreur porte sur des index, supprimez-les et reconstruisez-les. Vous pouvez, par exemple, utiliser la commande CREATE INDEX � WITH (DROP_EXISTING = ON).
	- Si l�erreur porte sur une vue index�e, supprimez-la et reconstruisez-la.
	- Si l�erreur porte sur des donn�es des tables de production, proc�dez � une restauration de page (RESTORE DATABASE/LOG � PAGE = '�' �)
	- Si l�erreur porte sur des donn�es autres que les tables de production (tables ou pages syst�me), vous devez proc�der � une restauration enti�re de la base.
	- Si vous ne disposez pas d�une sauvegarde dans laquelle les pages incrimin�es saines, vous pouvez tenter d�appliquer un DBCC CHECK� avec une option de r�paration.
*/
	USE RAN_ATOFFICE;
	GO
	ALTER DATABASE RAN_ATOFFICE
	SET SINGLE_USER
	WITH ROLLBACK IMMEDIATE;	 -- Les transactions incomplete seront restaur�es et les autres connexions d�connect�es
	GO
	DBCC CHECKTABLE('USR', REPAIR_REBUILD);
	GO
	ALTER DATABASE RAN_ATOFFICE
	SET MULTI_USER;
	GO
/* Lorsque la v�rification physique (DBCC CHECK �) l�ve une erreur, celle-ci fournit de nombreuses informations, deux d�entre elles �tant indispensables :
		- l�identifiant du fichier dans la base
		- l�identifiant de la page dans le fichier
	Les DBCC CHCK* cr�ent des rapport d'erreurs (dump) - dans le repertoire \log de l'instance (SQLDUMPnnnn.txt)
*/
-- Donne la r�f�rence de fichier, de page et slot de ligne en erreur:
	USE RAN_ATOFFICE;
	GO
	DBCC CHECKTABLE('LIGFACT')	WITH DATA_PURITY;
--Utiliser DBCC PAGE pour connaitre quelle ligne de donn�es est en erreur. 
--A partir de ces donn�es on peut MAJ la ligne en erreur.
	DBCC PAGE ('RAN_ATOFFICE', 3, 1136, 3) WITH TABLERESULTS; --(nom de la BDD, num fichier, num page, mode  de visualisation)
-- Informations d'allocations de la table
	DBCC EXTENTINFO(10,901578250,-1); 

	DECLARE @db_name SYSNAME; 
	DECLARE @tb_name SYSNAME;
	SET @db_name = N'RAN_ATOFFICE'; 
	SET @tb_name = N'USR';
	DBCC EXTENTINFO(@db_name,@tb_name,-1);  -- nom DB, nom table, num�ro d'index
	GO
-- Espace utilis� par une table
	sp_spaceused USR
/*Dans le cadre de mirroring les pages endommag�es sont r�par�es automatiquement. Voir les corrections
	Une erreur est enregistr�e dans le journal. Si il y a bcp d'erreur il faut se demander si il ne faut pas changer le support de stockage ou le controleur
*/
	select * from sys.dm_db_mirroring_auto_page_repair


/*
	Metrique des donn�es - Proc�dure
		Les m�triques fournies par cette proc�dure sont les suivantes :
			BASE_TAILLE_MO : taille globale de la base y compris transactions
			DONNEES_RESERVE_MO : taille r�serv�e pour les donn�es de la base
			DONNEES_UTILISEES_MO : volume effectif des donn�es de la base (tables et index)
			DONNEES_UTILISEES_POURCENT : taux de remplissage des donn�es dans les fichiers de la base
			TABLES_MO : volume des donn�es des tables (� titre indicatif)
			INDEX_MO : volume des index (� titre indicatif)
			TABLES_POURCENT : proportion du volume des tables en % (� titre indicatif)
			INDEX_POURCENT : proportion du volume des index en % (� titre indicatif)
			TRANSACTIONS_RESERVEES_MO : taille r�serv�e pour le journal de transaction de la base
			TRANSACTIONS_UTILISEES_MO : volume effectif des transactions de la base
			TRANSACTIONS_UTILISEES_POURCENT : taux de remplissage des transactions dans les fichiers de la base
	
		Les deux m�triques les plus importantes sont : DONNEES_UTILISEES_POURCENT et TRANSACTIONS_UTILISEES_POURCENT
			C�est sur celles-ci qu�il faut r�agir au plus vite en redimensionnant les fichiers ou en rajoutant de nouveaux fichiers�
			Il est d�usage de se poser des questions lorsque les taux de remplissage d�passe 70%, de planifier la croissance � 80 et d�agir imp�rativement � 90%.			
*/
USE master;
GO
CREATE PROCEDURE dbo.sp__METRIQUE_STOCKAGE @REAJUSTE BIT = 0 AS
SET NOCOUNT ON;
IF @REAJUSTE = 1 --> r�ajustement des statistiques des espaces de stockage
   DBCC UPDATEUSAGE (0); --> volume des transactions
DECLARE @T TABLE (database_name sysname, log_size_mb FLOAT, log_space_used_percent FLOAT, STATUS bit);
DECLARE @TRANSACTIONS_RESERVEES_MO BIGINT, @TRANSACTIONS_UTILISEES_MO BIGINT, @TRANSACTIONS_UTILISEES_POURCENT DECIMAL(5,2);
INSERT INTO @T
EXEC ('DBCC SQLPERF(LOGSPACE)')
SELECT @TRANSACTIONS_RESERVEES_MO = ROUND(log_size_mb, 0), @TRANSACTIONS_UTILISEES_MO = ROUND(log_size_mb * log_space_used_percent / 100.0, 0)
       , @TRANSACTIONS_UTILISEES_POURCENT = CAST(log_space_used_percent AS DECIMAL(5,2)) FROM @T WHERE database_name = DB_NAME(); -- taille de l'enveloppe de stockage :
	WITH 
	T_FILES AS (SELECT CAST(ROUND(SUM(CASE WHEN "type" = 1 THEN SIZE ELSE 0 END) / 128.0, 0) AS BIGINT) AS TRANSACTIONS_RESERVEES_MO
		   , CAST(ROUND(SUM(CASE WHEN "type" != 1 THEN SIZE ELSE 0 END) / 128.0, 0) AS BIGINT) AS DONNEES_RESERVE_MO
	FROM   sys.database_files),	T_DB AS (SELECT TRANSACTIONS_RESERVEES_MO + DONNEES_RESERVE_MO AS BASE_TAILLE_MO, DONNEES_RESERVE_MO, TRANSACTIONS_RESERVEES_MO
											FROM   T_FILES), T_PAGES AS (-- taille des pages donn�es et index           
	SELECT CAST(ROUND(SUM(au.used_pages) / 128.0, 0) AS BIGINT) AS DONNEES_UTILISEES_MO,
		   CAST(ROUND(SUM(CASE WHEN it.internal_type IN (202, 204, 211, 212, 213, 214, 215, 216) THEN 0 WHEN au.TYPE != 1 THEN au.used_pages WHEN p.index_id < 2  
								THEN au.data_pages ELSE 0 END) / 128.0, 0) AS BIGINT) AS TABLES_MO
	FROM   sys.partitions AS p INNER JOIN sys.allocation_units au ON p.partition_id = au.container_id LEFT OUTER JOIN sys.internal_tables AS it ON p.object_id = it.object_id)
	SELECT BASE_TAILLE_MO, DONNEES_RESERVE_MO, DONNEES_UTILISEES_MO, CAST(100.0 * CAST( DONNEES_UTILISEES_MO AS FLOAT) / DONNEES_RESERVE_MO AS DECIMAL(5,2)) AS DONNEES_UTILISEES_POURCENT
		   , TABLES_MO, DONNEES_UTILISEES_MO - TABLES_MO AS INDEX_MO, CAST(100.0 * CAST( TABLES_MO AS FLOAT) / DONNEES_UTILISEES_MO AS DECIMAL(5,2)) AS TABLES_POURCENT 
		   , CAST(100.0 * CAST( DONNEES_UTILISEES_MO - TABLES_MO AS FLOAT) / DONNEES_UTILISEES_MO AS DECIMAL(5,2)) AS INDEX_POURCENT, TRANSACTIONS_RESERVEES_MO
		   , @TRANSACTIONS_UTILISEES_MO AS TRANSACTIONS_UTILISEES_MO, @TRANSACTIONS_UTILISEES_POURCENT AS TRANSACTIONS_UTILISEES_POURCENT
	FROM   T_PAGES CROSS JOIN  T_DB;
	GO
-- Rendre la proc�dure syst�me accessible � partir de toutes bases
	EXEC sp_MS_marksystemobject 'sp__METRIQUE_STOCKAGE';
	GO	
	EXEC sp__METRIQUE_STOCKAGE
	
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



