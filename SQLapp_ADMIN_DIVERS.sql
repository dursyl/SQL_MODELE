/*
	Divers requête d'administration
*/

----------------------------------1. Surveillance de l’activité du serveur---------------------------
-- Requêtes en cours et inforamtions completes à propos de celles-ci
	SQLapp_who_is_active_v11_17.sql

-- Alternative à la requête ci-dessus
-- Quels utilisateurs monopolise le serveur
	SELECT TOP 20 SPID, Blocked, convert(varchar(10),db_name(dbid)) as Base, CPU, datediff(second,login_time, getdate())/60 as Minutes,
		convert(float, cpu / datediff(second,login_time, getdate())) as PScore, convert(varchar(16), hostname) as Hôte,
		convert(varchar(20), loginame) as Login, convert(varchar(50), program_name) as Programme
	FROM master..sysprocesses WHERE datediff(second,login_time, getdate()) > 0 and SPID > 50 ORDER BY PScore desc

-- Colonne BFactor nous donne le programme le plus gourmand
	SELECT convert(varchar(50), program_name) as Programme, count(*) as CliCount, sum(cpu) as CPUSum, sum(datediff(second, login_time, getdate())) as SecSum,
		convert(float, sum(cpu)) / convert(float, sum(datediff(second, login_time, getdate()))) as Score,
		convert(float, sum(cpu)) / convert(float, sum(datediff(second, login_time, getdate()))) / count(*) as BFactor
	FROM master..sysprocesses WHERE spid > 50 GROUP BY convert(varchar(50), program_name) ORDER BY score DESC

----------------------------------2. Surveillance de l’utilisation de l’espace disque---------------------------
-- Taille des bases de données

	 SELECT      @@SERVERNAME AS Instance,
	db.name AS Base,
	SUM(CASE WHEN af.groupid = 0 THEN 0 ELSE 8192.0E * af.size / 1048576.0E END) AS Taille_Base,
	SUM(CASE WHEN af.groupid = 0 THEN 8192.0E * af.size / 1048576.0E ELSE 0 END) AS Taille_Log,
	SUM(8192.0E * af.size / 1048576.0E) AS Taille_Totale
	FROM        master..sysdatabases AS db
	INNER JOIN master..sysaltfiles AS af ON af.[dbid] = db.[dbid]
	WHERE       db.name NOT IN('distribution', 'Resource', 'master', 'tempdb', 'model', 'msdb')
	GROUP BY    db.name	

----------------------------------3. Analyse des performances des index---------------------------
-- Analyser la pertinence et l’utilisation des index présents sur les tables d’une base
-- Script de Jason Strate que je n'ai pa réussi à récuperer


-- Si vous souhaitez afficher les Seeks, Scans et Lookups rapidement, vous pouvez utiliser le script suivant :
	SELECT   OBJECT_NAME(S.[OBJECT_ID]) AS [OBJECT NAME],
	I.[NAME] AS [INDEX NAME],
	USER_SEEKS,
	USER_SCANS,
	USER_LOOKUPS,
	USER_UPDATES
	FROM     SYS.DM_DB_INDEX_USAGE_STATS AS S
	INNER JOIN SYS.INDEXES AS I
	ON I.[OBJECT_ID] = S.[OBJECT_ID]
	AND I.INDEX_ID = S.INDEX_ID
	WHERE    OBJECTPROPERTY(S.[OBJECT_ID],'IsUserTable') = 1

-- Pour étudier l’impact des requêtes en Insert, Update et Delete sur les index, vous pouvez utiliser ce script :
	SELECT OBJECT_NAME(A.[OBJECT_ID]) AS [OBJECT NAME],
	I.[NAME] AS [INDEX NAME],
	A.LEAF_INSERT_COUNT,
	A.LEAF_UPDATE_COUNT,
	A.LEAF_DELETE_COUNT
	FROM   SYS.DM_DB_INDEX_OPERATIONAL_STATS (NULL,NULL,NULL,NULL ) A
	INNER JOIN SYS.INDEXES AS I
	ON I.[OBJECT_ID] = A.[OBJECT_ID]
	AND I.INDEX_ID = A.INDEX_ID
	WHERE  OBJECTPROPERTY(A.[OBJECT_ID],'IsUserTable') = 1	

-- Pour lister les index inutilisés et déterminer si oui ou non ils peuvent être supprimés, vous pouvez utiliser le script suivant
	DECLARE @dbid INT, @dbName VARCHAR(100);
	SELECT @dbid = DB_ID(), @dbName = DB_NAME();

	WITH partitionCTE (OBJECT_ID, index_id, row_count, partition_count)
	AS (SELECT [OBJECT_ID], index_id, SUM([ROWS]) AS 'row_count', COUNT(partition_id) AS 'partition_count' FROM sys.partitions	GROUP BY [OBJECT_ID], index_id)
 
	SELECT OBJECT_NAME(i.[OBJECT_ID]) AS objectName, i.name, CASE WHEN i.is_unique = 1 THEN 'UNIQUE ' ELSE '' END + i.type_desc AS 'indexType'
		, ddius.user_seeks, ddius.user_scans, ddius.user_lookups, ddius.user_updates, cte.row_count, CASE WHEN partition_count > 1 THEN 'yes' ELSE 'no' END AS 'partitioned?'
		, CASE WHEN i.type = 2 And i.is_unique_constraint = 0 THEN 'Drop Index ' + i.name + ' On ' + @dbName + '.dbo.' + OBJECT_NAME(ddius.[OBJECT_ID]) + ';' WHEN i.type = 2 And i.is_unique_constraint = 1
			THEN 'Alter Table ' + @dbName + '.dbo.' + OBJECT_NAME(ddius.[OBJECT_ID]) + ' Drop Constraint ' + i.name + ';' ELSE '' END AS 'SQL_DropStatement'
	FROM sys.indexes AS i INNER Join sys.dm_db_index_usage_stats ddius ON i.OBJECT_ID = ddius.OBJECT_ID And i.index_id = ddius.index_id INNER Join partitionCTE AS cte ON i.OBJECT_ID = cte.OBJECT_ID And i.index_id = cte.index_id
	WHERE ddius.database_id = @dbid ORDER BY (ddius.user_seeks + ddius.user_scans + ddius.user_lookups) ASC, user_updates DESC;

-- Enfin pour lister les index manquants suggérés par SQL Server, vous pouvez utiliser ce script :
	SELECT t.name AS 'Table', 'Create NonClustered Index IX_' + t.name + '_missing_' + CAST(ddmid.index_handle AS VARCHAR(10)) + ' On ' + ddmid.STATEMENT + ' (' + IsNull(ddmid.equality_columns,'')
		+ CASE WHEN ddmid.equality_columns IS Not Null And ddmid.inequality_columns IS Not Null THEN ',' ELSE '' END + IsNull(ddmid.inequality_columns, '') + ')' 
		+ IsNull(' Include (' + ddmid.included_columns + ');', ';') AS sql_statement, ddmigs.user_seeks, ddmigs.user_scans
		, CAST((ddmigs.user_seeks + ddmigs.user_scans) * ddmigs.avg_user_impact AS INT) AS 'est_impact', ddmigs.last_user_seek
	FROM sys.dm_db_missing_index_groups AS ddmig INNER Join sys.dm_db_missing_index_group_stats AS ddmigs ON ddmigs.group_handle = ddmig.index_group_handle
	INNER Join sys.dm_db_missing_index_details AS ddmid ON ddmig.index_handle = ddmid.index_handle INNER Join sys.tables AS t ON ddmid.OBJECT_ID = t.OBJECT_ID
	WHERE ddmid.database_id = DB_ID() And CAST((ddmigs.user_seeks + ddmigs.user_scans) * ddmigs.avg_user_impact AS INT) > 100 
	ORDER BY CAST((ddmigs.user_seeks + ddmigs.user_scans) * ddmigs.avg_user_impact AS INT) DESC;

----------------------------------4. Défragmentation des index---------------------------
-- Script de defragmetention, defragmente selon le niveau de defrag des indexes.
	SQLapp_Req_DefragIndex.sql


----------------------------------5. Dernière utilisation des tables---------------------------
-- Dernieres dates de lecture et d'écriture
SET ANSI_WARNINGS OFF;
SET NOCOUNT ON;
GO
WITH agg AS (SELECT [object_id], last_user_seek, last_user_scan, last_user_lookup, last_user_update FROM sys.dm_db_index_usage_stats WHERE database_id = DB_ID())
SELECT [Schema] = OBJECT_SCHEMA_NAME([object_id]), [Table_Or_View] = OBJECT_NAME([object_id]), last_read = MAX(last_read), last_write = MAX(last_write) FROM
	(SELECT [object_id], last_user_seek, NULL FROM agg 
		UNION ALL SELECT [object_id], last_user_scan, NULL FROM agg
		UNION ALL SELECT [object_id], last_user_lookup, NULL FROM agg
		UNION ALL SELECT [object_id], NULL, last_user_update FROM agg
	) AS x ([object_id], last_read, last_write)
GROUP BY OBJECT_SCHEMA_NAME([object_id]), OBJECT_NAME([object_id]) ORDER BY 1,2;




/*
----------------------------------AUTRES DIVERS
*/

/*
	Maintenance générale
		Toutes les x minutes: 
			Sauvegarde des journeaux de transactions
			Vérification de la capacité des espaces de stockage et des disques.
		Tous les jours:
			Maintenance des index			(que ceux qui en ont bsoin, en fonction d'un seuil de fragmentation)
			Maintenance des statistiques	(que celles qui en ont besoin, il existe des script pour mesurer ça) Pas besoin si elle fait suite à un rebuild d'index.
			DBCC CHECKDB des BDD < 250 Go
			Sauvegarde FULL des BDD < 250 Go
			Sauvegarde DIFF des BDD > 250 Go
		Toutes les semaines
			DBCC CHECKDB des BDD > 250 Go
			Sauvegarde FULL des BDD > 250 Go
		Verifier que ses sauvegardes ne sont pas corrompues
*/

/*
	STATISTIQUES
		ALTER INDEX ... REBUILD met à jour les stats
		Il vaut mieux mettre à jour les stats des tables avec un taux de modif d'au moins 10 à 20 %
		Pour savoir si il faut mettre les stats à jour :
			- sys.stats
			- sys.dm_db_stats_properties
*/
-- Mise à jour des statistiques de la base
exec sp_updatestats --A ne pas utiliser tel quel. Elle recalcule tout alors qu'il vaut mieux ne mettre à jour que les stats qui en on besoin (il existe des scripts qui calcule ça)



/*
	SAUVEGARDES
		Faire un DBCC CHECKDB à chaque sauvegarde pour éviter de sauvegarder une base corrompre 
*/


/*
	Plan de maintenance
		Utiliser l'agent SQL (planificateur de taches) SSMS parce qu'il gère des logs, ça envoie une alerte en cas d'erreur, otpimise les moments de lancement des taches, etc. 
			Mais faire ses propres scripts plutot qu'utiliser les taches du plan de maintenance. On recupere les stats et métriques dans les tables msdb sys.job.
			
*/

/*
	BLOCAGE (Pas DEAD LOCK)
	
*/
-- Vue qui donne les sessions qui bloquent. Attention, il peut y avoir toute une chaine. 
	select session_id, blocking_session_id from sys.dm_exec_requests -- session en cours, session qui bloque
-- D'abord killer les bloqueurs de tête.

-- Sessions bloquantes, qui permet de choisir laquelle killer
	WITH 
		T_SESSION AS -- on récupère les sessions en cours des utilisateurs
			(SELECT session_id, blocking_session_id FROM   sys.dm_exec_requests AS tout WHERE  session_id > 50)
		, T_LEAD AS-- on recherche les bloqueurs de tête
			(SELECT session_id, blocking_session_id FROM   T_SESSION AS tout WHERE  session_id > 50 AND  blocking_session_id = 0 
				AND  EXISTS(SELECT * FROM   T_SESSION AS tin WHERE  tin.blocking_session_id = tout.session_id))
		, T_CHAIN AS -- requête récursive pour trouver les chaines de blocage
			(SELECT session_id AS lead_session_id, session_id, blocking_session_id, 1 AS p FROM T_LEAD
				UNION  ALL
			SELECT C.lead_session_id, S.session_id, S.blocking_session_id, p+1 FROM   T_CHAIN AS C JOIN T_SESSION AS S ON C.session_id = S.blocking_session_id)
		, T_WEIGHT AS -- calculs finaux
			(SELECT lead_session_id AS LEAD_BLOCKER, COUNT(*) -1 AS BLOCKED_SESSION_COUNT, MAX(p) - 1 AS BLOCKED_DEEP, 'KILL ' + CAST(lead_session_id AS VARCHAR(16)) + ';' AS SQL_CMD
				FROM   T_CHAIN GROUP  BY lead_session_id)
	SELECT T.*, DB_NAME(r.database_id) AS database_name, host_name, program_name, nt_user_name, q.text AS sql_command, DATEDIFF(ms, last_request_start_time, 
					COALESCE(last_request_end_time, GETDATE())) AS duration_ms, s.open_transaction_count, r.cpu_time, r.reads, r.writes, r.logical_reads, r.total_elapsed_time 
	FROM   T_WEIGHT AS T JOIN sys.dm_exec_sessions AS s ON T.LEAD_BLOCKER = s.session_id JOIN sys.dm_exec_requests AS r ON s.session_id = r.session_id
		   OUTER APPLY sys.dm_exec_sql_text(sql_handle) AS q
	ORDER  BY BLOCKED_SESSION_COUNT DESC, BLOCKED_DEEP DESC;


-- Connaitre les droits attribuables à un objet 
		SELECT * FROM sys.fn_builtin_permissions(DEFAULT);
		SELECT * FROM sys.fn_builtin_permissions('SERVER');
