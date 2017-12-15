-- liste des fichiers des bases de données du server
	select * from sys.master_files
/* La base de master doit être sauvegardée régulierement parce qu'elle contient :
	- Les comptes de connexion, les rôles de serveur et les privileges
	- La liste des bases de données et leur paramétrage
	- Les messages d'erreur
On peut ajouter des objets dans master. Mettre dans un autre schéma que dbo.
Pour créer une procédure qui pourra être exécuté dans n'importe quelle base il faut:
	- Qu'elle soit placé dans le schéma dbo
	- Elle doit être préfixé par sp_
	- Elle doit être marquée système grace à sp_MS_marksystemobject:
	CREATION D'UNE PROCEDURE STOCKEE ACCESSIBLE A PARTIR DE TOUTES BASES
*/
	USE master;
	GO
	CREATE PROCEDURE dbo.sp_dbcc_checkconstraints
	AS
	DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS, ALL_ERRORMSGS;
	GO
	EXEC sp_MS_marksystemobject 'dbo.sp_dbcc_checkconstraints';
/*
	Base mssqlsystemresource (resource): sous-base de master pour ne pas arreter master lors de mises à jour
		Elle contient les tables et routines système. Ces objets sont appelés par le biais e master.
		Elle se sauvegarde par l'intermediaire de la base master
*/
-- Recuperer le script de création d'un objet ssystème
	select 'sys.sp_help' as objet, OBJECT_DEFINITION(object_id('sys.sp_help')) as SQL_DEFINITION
/* 
	Création d'une base utilisateur. Mieux vaut prendre la collation BIN (French_BIN). Plus rapide pour le moteur d'utiliser du binaire.
	Il vaut mieux créer les bases à l'aide de compte SQL Server en cas de deplacement de la base.
*/
-- Passage en lecture seule d'urgence
	ALTER DATABASE RAN_ATOFFICE SET READ_ONLY WITH ROLLBACK IMMEDIATE --annule toute transactions actives
-- Modifier le proprietaire d'une base
	ALTER AUTHORIZATION ON DATABASE::RAN_ATOFFICE TO sa;
-- Détacher une base
	EXEC sp_detach_db 'RAN_ATOFFICE'
/*
	MIGRATION de version MS SQL SERVER:
		- UAFS (Upgrade Assistant for SQL Server): MAJ nouvelle version
		- SSMA (SQL Server Migration Assistant): Migration depuis d'autres SGBDR (Oracle, MySQL, etc.)
	Si on veut garder la même instance malgré l'upgrade alors il faut exécuter l'installation et choisir Upgrader l'instance existante.
	Sinon on installe la nouvelle version à côté (sur le même serveur), on migre les objets et les bases et on renomme l'instance comme l'ancienne.
	On peut aussi migrer en faisant du mirroring (il supporte deux version SQL différentes), en basculant sur le serveur avec la nouvelle version
	A NOTER: le moteur de calcul des statistiques évolue à chaque version. Il faut les MAJ à chaque upgrade.
*/
-- Voir l'espace utilisé par une table
	exec sp_spaceused 'USR'
-- Consulter les pages de débordement --IN_ROW_DATA: données de lignes ou d'index, LOB_DATA: Données de LOB, ROW_OVERFLOW_DATA: Données à longueur variables (varchar, etc.)
	select * from sys.allocation_units
-- Une extension c'est 8 pages (64ko). Chaque lecture ou création se fait par bloc de 8 page (1 extension). Elles peuvent être mixtes ou uniformes.
-- Les pages techniques (page renseignant sur le contenu des pages). Ce sont les 11 premieres pages d'une base de données. Il y en a toutes les 64 000 extensions
-- Données d'en-tête du fichier 1 d'une base de données
	select * from sys.database_files
	DBCC FILEHEADER ('RAN_ATOFFICE')


-- Liste des pages techniques (page renseignant sur le contenu des pages)
	DBCC TRACEON(3604)
	DBCC PAGE ('RAN_ATOFFICE', 1, 0, 3)
	DBCC TRACEOFF(3604)

/*
	JOURNAL des TRANSACTIONS
*/
-- CHECKPOINT (ecriture sur DD à partir de la memoire) - Réglage du délai entre deux CHECKPOINT
	ALTER DATABASE RAN_ATOFFICE SET TARGET_RECOVERY_TIME = 90 SECONDS; -- Environ 1 minutes en général par défaut
	EXEC sp_configure 'recovery interval', '3'; --minutes
	RECONFIGURE WITH OVERRIDE;
-- Ajouter les CHECKPOINT dans le journal des événements (3502, 3605, 3504)

-- Déclencher une erreur:
	RAISERROR (15600,-1,-1, 'mysp_CreateCustomer'); 

-- Lire le fichier log
	select * from sys.fn_dblog(NULL, NULL)

-- Lire le fichier log - Logiciel pour lire les fichiers log: apexSQL Log, Log Explorer, SQL Log Rescue.
	select * from sys.fn_dump_dblog(DEFAULT, DEFAULT, DEFAULT, DEFAULT,'D:\MSSQL\DATA\RAN_ATOFFICE.ldf'
		,DEFAULT, DEFAULT, DEFAULT, DEFAULT,DEFAULT, DEFAULT, DEFAULT, DEFAULT,DEFAULT, DEFAULT
		,DEFAULT, DEFAULT, DEFAULT, DEFAULT,DEFAULT, DEFAULT, DEFAULT, DEFAULT,DEFAULT, DEFAULT
		,DEFAULT, DEFAULT, DEFAULT, DEFAULT,DEFAULT, DEFAULT, DEFAULT, DEFAULT,DEFAULT, DEFAULT
		,DEFAULT, DEFAULT, DEFAULT, DEFAULT,DEFAULT, DEFAULT, DEFAULT, DEFAULT,DEFAULT, DEFAULT
		,DEFAULT, DEFAULT, DEFAULT, DEFAULT,DEFAULT, DEFAULT, DEFAULT, DEFAULT,DEFAULT, DEFAULT
		,DEFAULT, DEFAULT, DEFAULT, DEFAULT,DEFAULT, DEFAULT, DEFAULT,DEFAULT,DEFAULT, DEFAULT
		,DEFAULT, DEFAULT, DEFAULT)

---------- Métadonnées sur la volumétrie, le placement des tables et index (fichiers et groupes de fichiers)
WITH T_VOL AS
(SELECT o.object_id, SUM(p.rows) AS ROW_COUNT, CAST((SUM(au.total_pages) * 8) / 1024.0 AS DECIMAL(18,3)) AS TOTAL_SPACE_MB,
       CAST(SUM(au.used_pages) * 8 / 1024.0 AS DECIMAL(18,3)) AS USED_SPACE_MB, CAST((SUM(au.total_pages) - SUM(au.used_pages)) * 8 / 1024.0 AS DECIMAL(18,3)) AS UNUSED_SPACE_MB
FROM   sys.objects AS o INNER JOIN sys.indexes i ON o.object_id = i.object_id
       LEFT OUTER JOIN sys.partitions AS p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
       LEFT OUTER JOIN sys.allocation_units AS au ON p.partition_id = au.container_id
GROUP BY o.object_id)
SELECT s.name AS TABLE_SCHEMA, o.name AS TABLE_NAME, o.type_desc AS TABLE_TYPE, i.name AS INDEX_NAME, ROW_COUNT, TOTAL_SPACE_MB,
       USED_SPACE_MB, UNUSED_SPACE_MB, fg.name AS FILE_GROUP, df.name AS LOGICAL_FILE, df.physical_name AS PHYSICAL_FILE,
       o.object_id, i.index_id, p.partition_id
FROM   sys.objects AS o INNER JOIN sys.schemas AS s ON o.schema_id = s.schema_id
       INNER JOIN sys.indexes i ON o.object_id = i.object_id
       LEFT OUTER JOIN sys.filegroups AS fg ON i.data_space_id = fg.data_space_id
       LEFT OUTER JOIN sys.database_files AS df ON fg.data_space_id = df.data_space_id
       LEFT OUTER JOIN sys.partitions AS p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
       LEFT OUTER JOIN T_VOL AS V ON o.object_id = V.object_id
WHERE  o.is_ms_shipped = 0 AND  i.OBJECT_ID > 255;


------- Y a t'il une transaction ouverte ?  DBCC OPENTRAN
-- On veut savoir si il y a une transaction active qui empeche le journal d'etre tronqué
CREATE TABLE T1(Col1 int, Col2 char(3));  
GO  
BEGIN TRAN  
INSERT INTO T1 VALUES (101, 'abc');  
GO  
DBCC OPENTRAN;  
ROLLBACK TRAN;  
GO  
DROP TABLE T1;  
GO  

---- Bénéfice théorique de la compression - Bon pour la lecture donc pour le BI
DECLARE @T TABLE (object_name sysname, schema_name sysname, index_id INT, partition_number INT, size_with_current_compression_setting_Ko BIGINT,
                  size_with_requested_compression_setting_Ko BIGINT, sample_size_with_current_compression_setting_Ko BIGINT,
                  sample_size_with_requested_compression_setting_Ko BIGINT);
DECLARE @F TABLE (object_name sysname, schema_name sysname, index_id INT, partition_number INT, size_with_current_compression_setting_Ko BIGINT,
                  size_with_requested_compression_setting_Ko BIGINT, sample_size_with_current_compression_setting_Ko BIGINT,
                  sample_size_with_requested_compression_setting_Ko BIGINT, compression_method CHAR(4));
DECLARE @s_name sysname, @o_name sysname, @idxid INT, @SQL NVARCHAR(max)
DECLARE C CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR
      SELECT s.name AS s_name, o.name AS o_name, index_id FROM sys.indexes AS i
             INNER JOIN sys.objects AS o ON i.object_id = o.object_id INNER JOIN sys.schemas AS s ON o.schema_id = s.schema_id
      WHERE  o."type" IN ('U', 'V') AND is_ms_shipped = 0 AND index_id < 256 
		AND NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = o.name AND TABLE_SCHEMA = s.name AND DATA_TYPE IN ('geography', 'geometry', 'hierarchyid'));
OPEN C;
	FETCH C INTO @s_name, @o_name, @idxid;
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		SET @SQL = N'EXEC sp_estimate_data_compression_savings ''' + @s_name + N''', ''' + @o_name + N''', ' + CAST(@idxid AS NVARCHAR(16)) +', NULL , ''PAGE'';';
	PRINT @SQL --> pour vérification, peut être supprimé !
	   INSERT INTO @T EXEC (@SQL);
	   INSERT INTO @F SELECT *, 'PAGE' FROM @T;
	   DELETE FROM @T;
	   SET @SQL = N'EXEC sp_estimate_data_compression_savings ''' + @s_name + N''', ''' + @o_name + N''', ' + CAST(@idxid AS NVARCHAR(16)) +', NULL , ''ROW'';';
	PRINT @SQL --> pour vérification, peut être supprimé !
	   INSERT INTO @T EXEC (@SQL);
	   INSERT INTO @F SELECT *, 'ROW' FROM @T;
	   DELETE FROM @T;
	   FETCH C INTO @s_name, @o_name, @idxid;
	END
CLOSE C;
DEALLOCATE C;
WITH
T1 AS ( 
	SELECT schema_name +'.' + object_name AS table_name, index_id, SUM(size_with_current_compression_setting_Ko) AS actual_size_Ko,
       SUM(size_with_requested_compression_setting_Ko) AS comp_size_Ko, SUM(sample_size_with_current_compression_setting_Ko) AS actual_sample_size_Ko,
       SUM(sample_size_with_requested_compression_setting_Ko) AS sample_comp_size_Ko, GROUPING(index_id) + GROUPING(schema_name +'.' + object_name) AS subtotal_level
	FROM @F WHERE  compression_method = 'PAGE' GROUP BY ROLLUP (schema_name +'.' + object_name, index_id))
, T2 AS (
	SELECT schema_name +'.' + object_name AS table_name, index_id, SUM(size_with_current_compression_setting_Ko) AS actual_size_Ko,
       SUM(size_with_requested_compression_setting_Ko) AS comp_size_Ko, SUM(sample_size_with_current_compression_setting_Ko) AS actual_sample_size_Ko,
       SUM(sample_size_with_requested_compression_setting_Ko) AS sample_comp_size_Ko, GROUPING(index_id) + GROUPING(schema_name +'.' + object_name) AS subtotal_level
	FROM @F WHERE compression_method = 'ROW' GROUP BY ROLLUP (schema_name +'.' + object_name, index_id))
SELECT T1.table_name, T1.index_id, T1.actual_size_Ko, T1.actual_sample_size_Ko, T1.comp_size_Ko AS estim_comp_PAGE_size_Ko,
       T2.comp_size_Ko AS estim_comp_ROW_size_Ko, T1.sample_comp_size_Ko AS estim_sample_comp_PAGE_size_Ko, T2.sample_comp_size_Ko AS estim_sample_comp_ROW_size_Ko,
       CAST(((T1.actual_size_Ko - T1.comp_size_Ko )/NULLIF((T1.actual_size_Ko * 1.0), 0)) * 100 AS DECIMAL(5,2)) AS percent_gain_PAGE_comp,
       CAST(((T1.actual_size_Ko - T2.comp_size_Ko )/NULLIF((T1.actual_size_Ko * 1.0), 0)) * 100 AS DECIMAL(5,2)) AS percent_gain_ROW_comp
FROM T1 INNER JOIN T2 ON COALESCE(T1.table_name, '') = COALESCE(T2.table_name, '') AND COALESCE(T1.index_id, -1) = COALESCE(T2.index_id, -1);


-- Qui a modifié la routine en dernier
SELECT * FROM   sys.sql_modules AS sm INNER JOIN sys.objects AS o ON sm.object_id = o.object_id
       INNER JOIN sys.schemas AS s ON o.schema_id = s.schema_id
WHERE  o.object_id = OBJECT_ID('dbo.TsGetVersion') -- Nom de l’objet préfixé du nom du schéma

-- Liste des connexions Windows et leurs rôles
SELECT CNX.name AS WIN_LOGIN_NAME, ROL.name AS ROLE_NAME FROM sys.server_principals AS CNX
       INNER JOIN sys.server_role_members AS SRM ON CNX.principal_id = SRM.member_principal_id
       INNER JOIN sys.server_principals AS ROL ON SRM.role_principal_id = ROL.principal_id
WHERE   CNX.type_desc IN ('WINDOWS_LOGIN', 'WINDOWS_GROUP');

-- Liste des connexions SQL et leurs rôles
SELECT USR.name AS UTILISATEUR_SQL, ROL.name AS ROLE_NAME
FROM   sys.database_principals AS USR INNER JOIN sys.database_role_members AS DRM ON USR.principal_id = DRM.member_principal_id
       INNER JOIN sys.database_principals AS ROL ON DRM.role_principal_id = ROL.principal_id
WHERE  USR.type_desc = 'SQL_USER';

-- Cryptologie. Utilisation de ENCRYPTBYPASSPHRASE et DATALENGTH
CREATE TABLE T_PATIENT_PTT (PTT_ID INT IDENTITY, PTT_PRENOM VARCHAR(25), PTT_NOM CHAR(32), PTT_NUMSECU CHAR(13));
GO
INSERT INTO T_PATIENT_PTT VALUES ('marc', 'Dupont', '1234567890000'), ('Marc',  'DUPONT', '7894561230000'),
	('Jean', 'Duval',  '4561237890000'), ('Luc',   'Dubois', '3216549870000'),('Zoé',  'Aldic',  '9876543210000'), ('Alain', 'Zorn',   '3216549870000');
SELECT PTT_ID, PTT_NOM, ENCRYPTBYPASSPHRASE('Mon Passe !', PTT_NOM) AS NOM_CRYPTE, DATALENGTH(PTT_NOM) AS LONG_NOM
	, DATALENGTH(ENCRYPTBYPASSPHRASE('Mon Passe !', PTT_NOM)) AS LONG_CRYPT
FROM   T_PATIENT_PTT ORDER  BY NOM_CRYPTE;
drop table T_PATIENT_PTT

-- Quels backup de sauvegarde dans .bak ?
	RESTORE HEADERONLY FROM DISK = 'C:\DATA\BKP\RAN_ATOFFICE_Full_20171214114750.bak'
-- Quels fichiers de sauvegarde dans .bak ?
	RESTORE FILELISTONLY FROM DISK = 'C:\DATA\BKP\RAN_ATOFFICE_Full_20171214114750.bak'

-- Pages défaillantes ?
 select * from msdb.dbo.suspect_pages
 
-- Plans en cache p645, 13.001
SELECT usecounts, cacheobjtype, objtype, text, query_plan FROM   sys.dm_exec_cached_plans
	CROSS APPLY sys.dm_exec_sql_text(plan_handle)
    CROSS APPLY sys.dm_exec_query_plan(plan_handle)
ORDER  BY usecounts DESC;
	
-- Cache p645, 13.002
SELECT * FROM sys.dm_os_memory_cache_entries AS ce LEFT OUTER JOIN sys.dm_exec_cached_plans AS cp ON ce.memory_object_address = cp.memory_object_address;

-- Cache p645, 13.003
IF LEFT(@@VERSION, 25) <= 'Microsoft SQL Server 2008'
	EXEC ('SELECT *, SUM(pages_allocated_count * page_size_in_bytes / 1024) OVER(PARTITION BY "type") AS size_per_type_Kb FROM sys.dm_os_memory_objects ORDER BY size_per_type_Kb DESC;');
ELSE
   EXEC ('SELECT *, SUM(pages_in_bytes / 1024) OVER(PARTITION BY "type") AS size_per_type_Kb FROM sys.dm_os_memory_objects ORDER BY size_per_type_Kb DESC;');

-- Métriques requêtes en cours
SELECT r.session_id, connect_time, client_net_address, program_name, login_name, nt_user_name, start_time, r.database_id,
       wait_time, r.cpu_time, r.total_elapsed_time, r.reads, r.writes, r.logical_reads, q.text AS sql_texte, p.query_plan
FROM   sys.dm_exec_requests AS r INNER JOIN sys.dm_exec_sessions AS s ON r.session_id = s.session_id
       INNER JOIN sys.dm_exec_connections AS c ON r.session_id = c.session_id
       CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS q CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS p
-- Requêtes bloquantes
	SELECT tl.request_session_id AS session_id, DB_NAME(tl.resource_database_id) AS nom_base, tl.resource_type AS type_ressource
			, CASE WHEN tl.resource_type IN ('BASE', 'FICHIER', 'MÉTADONNÉES') THEN tl.resource_type
				WHEN tl.resource_type = 'OBJET' THEN OBJECT_NAME(tl.resource_associated_entity_id, tl.resource_database_id)
				WHEN tl.resource_type IN ('CLEF', 'PAGE', 'LIGNE') THEN (SELECT OBJECT_NAME(object_id)
			FROM sys.partitions AS p WHERE p.hobt_id = tl.resource_associated_entity_id) ELSE 'Inconnu' END AS objet_parent
       , tl.request_mode AS type_verrou, tl.request_status AS statut_requete, er.blocking_session_id AS id_session_bloquante, es.login_name
       , CASE tl.request_lifetime WHEN 0 THEN sql_a.text ELSE sql_r.text END AS commande_SQL
	FROM sys.dm_tran_locks AS tl LEFT OUTER JOIN sys.dm_exec_requests AS er ON tl.request_session_id = er.session_id
       INNER JOIN sys.dm_exec_sessions AS es ON tl.request_session_id = es.session_id
       INNER JOIN sys.dm_exec_connections AS ec ON tl.request_session_id = ec.most_recent_session_id
       OUTER APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) AS sql_r
       OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) AS sql_a
	WHERE tl.resource_database_id = DB_ID() AND tl.resource_type NOT IN ('DATABASE', 'METADATA') ORDER BY tl.request_session_id;
-- Requete SQL en cours
	SELECT asdt.transaction_id, asdt.session_id, asdt.transaction_sequence_num, asdt.first_snapshot_sequence_num,
       asdt.commit_sequence_num, asdt.is_snapshot, asdt.elapsed_time_seconds, st.text AS commande_SQL
	FROM sys.dm_tran_active_snapshot_database_transactions AS asdt INNER JOIN sys.dm_exec_connections AS ec ON asdt.session_id = ec.most_recent_session_id
       INNER JOIN sys.dm_tran_database_transactions AS dt ON asdt.transaction_id = dt.transaction_id
       CROSS APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) AS st
	WHERE dt.database_id = DB_ID();
-- Requête de creation de script Create index à partir de missing.index
	WITH T_INDEX_A_CREER AS (
	 SELECT 'CREATE INDEX X_' + CONVERT(CHAR(8), CURRENT_TIMESTAMP, 112) + '_' + REPLACE(CAST(NEWID() AS VARCHAR(38)), '-', '_') + ' ON ' + statement
       + '(' + COALESCE(equality_columns + ', ' + inequality_columns, equality_columns, inequality_columns) + ')' + COALESCE(' INCLUDE (' + included_columns +')', '')
       + ' WITH (FILLFACTOR = 90);' AS COMMANDE_SQL, PERCENT_RANK() OVER(ORDER BY avg_user_impact * user_seeks DESC) * 100.0 AS RANG
	 FROM   sys.dm_db_missing_index_details AS mid INNER JOIN sys.dm_db_missing_index_groups AS mig ON mid.index_handle = mig.index_handle
       INNER JOIN sys.dm_db_missing_index_group_stats AS migs ON mig.index_group_handle = migs.group_handle)
	 SELECT COMMANDE_SQL FROM   T_INDEX_A_CREER WHERE  RANG <= 20;
-- Attente sur fichiers
SELECT mf.physical_name AS FICHIER, pir.io_pending AS NATURE_ATTENTE, pir.io_pending_ms_ticks * @@TIMETICKS / 1000.0 AS ATTENTE_MS
FROM   sys.dm_io_pending_io_requests AS pir INNER JOIN sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs ON pir.io_handle = vfs.file_handle
       INNER JOIN sys.master_files AS mf ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER  BY pir.io_pending, pir.io_pending_ms_ticks DESC;
