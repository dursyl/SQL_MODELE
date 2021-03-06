/*
	EVENEMENTS ETENDUS
*/
/*
	Outils de diagnostic de tout ce qui peut infecter une instance SQL Server, en interne comme en externe, toue en ayant un umpact négligeable sur les performances.
*/

/*
	Liste des packages (conteneur de métadonnées)	
	- package0: Objets système nécessaires au bon fonctionnement d'une session d'événements étendus.
	- SecAudit: Objets dont le moteur se sert pour implémenter la fonctionnalité d'audit de sécurité. Il est privée, on ne peut pas l'utiliser directement.
	- sqlos contient tous les objets relatifs au fonctionnement interne du moteur de base de données.
	- sqlserver contient tous les objets concernant la vie d’une instance (attachement d’une base de données, exécution d’une requête, 
			gestion des fonctionnalités comme FileStream et Service Broker, etc.).
	Chacun de ces packages peut contenir : des événements, des cibles (réceptacle de la capture), des actions (caractéristiques à capturées), etc.
	
*/
	SELECT P.name AS package_name, P.description, P.capabilities_desc, RIGHT(M.name, CHARINDEX('\', REVERSE(M.name)) - 1) AS module_name
	FROM sys.dm_xe_packages AS P INNER JOIN sys.dm_os_loaded_modules AS M ON P.module_address = M.base_address ORDER BY P.name
	
-- Liste des événements par package
	select P.name as package_name, O.name as event_name, O.description
	from sys.dm_xe_objects as O inner join sys.dm_xe_packages as p on O.package_guid = P.guid where O.object_type = 'event' order by P.name, O.name

/*
	on peut enregistrer les événements dans (cibles):
		- fichier binaire
		- mémoire en anneau (ring buffer)
		- le journal des événements de Windows
		- les cumuler pour caractériser une charge de travail
		- trouver des paires d'événements
	On peut utiliser plusieurs cibles dans une même session.
*/
-- Liste des cibles 
	SELECT P.name AS package_name, O.name AS target_name, OC.column_id, OC.name AS column_name, OC.column_type, OC.capabilities_desc, OC.column_value, OC.description AS column_description
	FROM sys.dm_xe_objects AS O	INNER JOIN sys.dm_xe_object_columns AS OC ON O.name = OC.object_name INNER JOIN sys.dm_xe_packages AS P ON O.package_guid = P.guid
	WHERE O.object_type = 'target'
	
-- Liste des actions -> exemple: on êut collecter le CPU, le nom de la machine, la BDD, etc.
	SELECT P.name AS package_name, O.name AS action_name, O.capabilities_desc, O.description
	FROM sys.dm_xe_objects AS O	INNER JOIN sys.dm_xe_packages AS P ON O.package_guid = P.guid
	WHERE O.object_type = 'action'	

-- Les prédicats permettent de filtrer les événements (seuil, capturer d'un échantillon, limiter la consommation, etc.)
-- Liste des maps 
	SELECT P.name AS package_name, O.name AS event_name
	FROM sys.dm_xe_objects AS O	INNER JOIN sys.dm_xe_packages AS P ON O.package_guid = P.guid
	WHERE O.object_type = 'map'
-- liste des valeurs utilisées par le moteur de BDD (pour le package sqlos et un événement d'attente).
	SELECT P.name AS package_name, O.name AS event_name, MV.map_key, MV.map_value
	FROM sys.dm_xe_objects AS O	INNER JOIN sys.dm_xe_packages AS P ON O.package_guid = P.guid inner join sys.dm_xe_map_values as MV on MV.object_package_guid=O.package_guid and MV.name=O.name
	WHERE O.object_type = 'map' and p.name='sqlos' and O.name='wait_types'
-- Liste des types
	SELECT P.name AS package_name, O.name AS type_name, O.type_size
	FROM sys.dm_xe_objects AS O	INNER JOIN sys.dm_xe_packages AS P ON O.package_guid = P.guid
	WHERE O.object_type = 'type'
-- Liste des packages
	select * from sys.dm_xe_packages
-- Liste des objets des événements étendus (packages, événements, cibles, actions, prédicats, maps et types)
	select * from sys.dm_xe_objects	

-- Liste de sessions d'événements étendus existants (en cours d'exécution ou non)
	select * from sys.dm_xe_sessions	-- system_health est utilisé par le moteur pour lsa propre optimisation
-- Liste des événements capturés en cours d'exécution
	select * from sys.dm_xe_session_event_actions
	select * from sys.dm_xe_session_events
-- Liste des targets en cours d'éxecution
	select * from sys.dm_xe_session_targets
-- Liste de toutes les sessions, démarrées ou non. 
	SELECT name AS session_name, event_retention_mode_desc, max_dispatch_latency, max_event_size, max_memory, memory_partition_mode_desc
		, CASE startup_state WHEN 1 THEN 'Démarre automatiquement avec l''instance' ELSE 'Démarrée par action de l''utilisateur' END AS startup_state
		, track_causality, memory_partition_mode_desc
	FROM sys.server_event_sessions
-- Retourne les caractéristiques des événeents capturés par une session (tiré d'un fichier binaire) - une liste de fichier XML
	SELECT CAST(event_data AS xml) AS data FROM sys.fn_xe_file_target_read_file('D:\dossier\uneSessionXE*.xel' -- Fichier de capture des événements XE
		, NULL -- Fichier de métadonnées de la session
		, NULL -- Nom du premier fichier à lire avec l’option MAX_ROLLOVER_FILES
		, NULL) -- Index à partir duquel doit commencer la lecture du fichier

/*
	EXEMPLES 1 - erreur de connexion
*/
-- Exemple 1 - erreur de connexion, quel événements sont à disposition pour cela ?
	SELECT P.name + '.' + O.name AS event_name, O.description
	FROM sys.dm_xe_objects AS O INNER JOIN sys.dm_xe_packages AS P ON O.package_guid = P.guid
	WHERE O.object_type = 'event' AND O.name LIKE '%error%'
-- Exemple 1 - Quelles informations auditées par l'événement 'error_reported'. 'data' dans column_type est les données dont on a besoin.
	SELECT P.name + '.' + C.name AS column_name, C.type_name AS data_type_name, C.column_type, C.description
	FROM sys.dm_xe_object_columns AS C INNER JOIN sys.dm_xe_packages AS P ON P.guid = C.object_package_guid
		INNER JOIN sys.dm_xe_packages AS PT ON PT.guid = C.type_package_guid
	WHERE C.object_name = 'error_reported' ORDER BY C.column_type DESC
-- Exemple 1 - Le message d'erreur de connexion est le 4060
	select * from sys.messages where language_id=1036 and message_id in (4060)
-- Exemple 1 - Liste des actions susceptibles de nous interresser pour capturer les probleme de connexion (nous retiendrons client_app_name, nt_username, database_id, etc.)
	SELECT P.name + '.' + O.name AS action_name, O.description
	FROM sys.dm_xe_objects AS O INNER JOIN sys.dm_xe_packages AS P ON O.package_guid = P.guid
	WHERE O.object_type = 'action' AND P.name = 'sqlserver' 
-- Exemple 1 - Création de la session d'événements étendues
	CREATE EVENT SESSION login_failure_audit ON SERVER 
		ADD EVENT sqlserver.error_reported(ACTION(sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.nt_username, sqlserver.database_id, sqlserver.username)
		WHERE error = 4060) -- 2012: error_number
		--WHERE error = 207) -- 2012: error_number  207: erreur de colonne inconnu dans un select
		ADD TARGET package0.asynchronous_file_target(SET FILENAME = 'C:\temp_XE\login_failure_audit.xel')	-- 2012: event_file 
		-- DROP EVENT SESSION login_failure_audit ON SERVER 	
-- Exemple 1 - Vérifions que la session login_failure_audit Est en cours d'exécution (ce n'est pas encore le cas)
	SELECT name AS nom_session_XE_demarree, create_time FROM sys.dm_xe_sessions
-- Exemple 1 - Vérifions que la session login_failure_audit est enregistrer dans l'instance
	SELECT name AS nom_session_XE FROM sys.server_event_sessions
-- Exemple 1 - Lancer la session login_failure_audit
	ALTER EVENT SESSION login_failure_audit ON SERVER STATE = START
-- Exemple 1 - Vérifions que la session login_failure_audit Est en cours d'exécution (c'est le cas maintenant)
	SELECT name AS nom_session_XE_demarree, create_time FROM sys.dm_xe_sessions
-- Exemple 1 - Voir le contenu du fichier
	SELECT CAST(event_data AS xml) AS data FROM sys.fn_xe_file_target_read_file('C:\temp_XE\login_failure_audit*.xel'
	,'C:\temp_XE\login_failure_audit*.xem'	-- a partir de 2012 on peut mettre NULL
	,NULL,NULL)
-- Exemple 1 - Infos essentielles du document XML
	;WITH CTE (event_data_xml) AS (SELECT CAST(event_data AS xml) AS data FROM sys.fn_xe_file_target_read_file('C:\temp_XE\login_failure_audit*.xel', 'C:\temp_XE\login_failure_audit*.xem', NULL, NULL))
		SELECT DATEADD(hour, DATEDIFF(hour, GETUTCDATE(), GETDATE()), event_data_xml.value('(/event/@timestamp)[1]', 'datetime')) AS time_stamp
			, event_data_xml.value('(/event/data/value)[1]', 'int') AS message_id, event_data_xml.value('(/event/data/value)[5]', 'varchar(max)') AS message_label
			, event_data_xml.value('(/event/action/value)[1]', 'sysname') AS client_app_name, event_data_xml.value('(/event/action/value)[5]', 'sysname') AS login_name
			, event_data_xml.value('(/event/action/value)[4]', 'sysname') AS database_id
		FROM CTE ORDER BY time_stamp
	
/*
	Exemple 2 - Collecte des requêtes peu performantes
*/
-- 	Exemple 2 - Recherche des événements relatifs à l'exécution de requête DML ou de PS.
	select name, description from sys.dm_xe_objects where object_type='event' and (name like '%statement%' OR name like '%module%')
	select * from sys.dm_xe_objects where object_type='event' and (name like '%statement%' OR name like '%module%')

-- 	Exemple 2 - Données collectées par les évenements de la requête ci-dessus - données intéressante: cpu, duration, source_database_id, state
	SELECT o.name as event_name, c.name as column_name, c.type_name as column_data_type, c.column_type as column_usage
	FROM sys.dm_xe_object_columns AS c INNER JOIN sys.dm_xe_objects AS o ON c.object_name = o.name
	WHERE (o.name like '%statement%' OR o.name like '%module%') -- and c.column_type = 'readonly'
-- 	Exemple 2 - Création de la session
	CREATE EVENT SESSION counter_performing_queries ON SERVER ADD EVENT sqlserver.sql_statement_completed(ACTION(sqlserver.sql_text) WHERE
		(duration >= 5000000)) -- 5 secondes en μsecondes)
		-- OR cpu_time > 1000000 -- 1 seconde en μsecondes
		-- OR physical_reads > 0 -- en nombre de pages
		-- OR logical_reads > 50000)) -- en nombre de pages
		-- AND database_id = 5)) -- SELECT DB_ID('maDB')),
		ADD TARGET package0.asynchronous_file_target(SET FILENAME = 'C:\temp_XE\counter_performing_queries.xel')
		WITH (STARTUP_STATE = ON) -- Si le service SQL Server est redémarré, la session démarre avant que l’instance soit disponible aux connexions
		GO
-- 	Exemple 2 - Démarrage de la session
	ALTER EVENT SESSION counter_performing_queries ON SERVER STATE = START
-- 	Exemple 2 - Voir les documents créés - On doit COALESCE parce que les caracteristiques ne sont pas tjrs placées au même endroit en fonciton de l'événement.
	;WITH CTE AS (SELECT CAST(event_data AS XML) AS event_data FROM sys.fn_xe_file_target_read_file('C:\temp_XE\counter_performing_queries*.xel', 'C:\temp_XE\counter_performing_queries*.xem', NULL, NULL))
	SELECT COALESCE(DATEADD(hour, DATEDIFF(hour, GETUTCDATE(), GETDATE()), BC.bc.value('(@timestamp)[1]', 'datetime2(3)')), DATEADD(hour, DATEDIFF(hour, GETUTCDATE(), GETDATE())
			, SC.sc.value('(@timestamp)[1]', 'datetime2(3)')), DATEADD(hour, DATEDIFF(hour, GETUTCDATE(), GETDATE()), SP.sp.value('(@timestamp)[1]', 'datetime2(3)')))AS log_time
		, COALESCE(BC.bc.value('(@name)[1]', 'varchar(128)'), SC.sc.value('(@name)[1]', 'varchar(128)'), SP.sp.value('(@name)[1]', 'varchar(128)')) AS event_name	
		, COALESCE(BC.bc.value('(./data/value)[1]', 'bigint'), SC.sc.value('(./data/value)[2]', 'bigint'), SP.sp.value('(./data/value)[5]', 'bigint')) / 1000 AS CPU_time_ms
		, COALESCE(BC.bc.value('(./data/value)[5]', 'bigint'), SC.sc.value('(./data/value)[5]', 'bigint'), SP.sp.value('(./data/value)[5]', 'bigint')) / 1000 AS duration_microseconde
		, COALESCE(BC.bc.value('(./data/value)[3]', 'bigint'), SC.sc.value('(./data/value)[3]', 'bigint'), SP.sp.value('(./data/value)[6]', 'bigint')) AS physical_reads
		, COALESCE(BC.bc.value('(./data/value)[4]', 'bigint'), SC.sc.value('(./data/value)[4]', 'bigint'), SP.sp.value('(./data/value)[7]', 'bigint')) AS logical_reads		
		, COALESCE(BC.bc.value('(./data/value)[5]', 'bigint'), SC.sc.value('(./data/value)[5]', 'bigint'), SP.sp.value('(./data/value)[8]', 'bigint')) AS writes
		, COALESCE(BC.bc.value('(./data/value)[6]', 'bigint'), SC.sc.value('(./data/value)[6]', 'bigint'), SP.sp.value('(./data/value)[9]', 'bigint')) AS row_count
		, SC.sc.value('(./action/value)[1]', 'varchar(max)') AS query_text
		, SC.sc.value('(./data/value)[2]', 'int') AS object_id
	FROM CTE AS C
	OUTER APPLY C.event_data.nodes('/event[@name="sql_batch_completed"]') AS BC(bc)
	OUTER APPLY C.event_data.nodes('/event[@name="sql_statement_completed"]') AS SC(sc)
	OUTER APPLY C.event_data.nodes('/event[@name="sp_statement_completed"]') AS SP(sp)
	ORDER BY log_time

-- 	Exemple 2 - 
		SELECT CAST(event_data AS xml) AS data FROM sys.fn_xe_file_target_read_file('C:\temp_XE\counter_performing_queries*.xel'
	,'C:\temp_XE\counter_performing_queries*.xem'	-- a partir de 2012 on peut mettre NULL
	,NULL,NULL)		
p.178
-- 	Exemple 3 - Utilisation de la cible histogramme
-- Liste des cibles histogramme
	SELECT P.name AS package_name, O.name AS target_name, OC.column_id, OC.name AS column_name, OC.column_type, OC.capabilities_desc, OC.column_value, OC.description AS column_description
	FROM sys.dm_xe_objects AS O	INNER JOIN sys.dm_xe_object_columns AS OC ON O.name = OC.object_name INNER JOIN sys.dm_xe_packages AS P ON O.package_guid = P.guid
	WHERE O.object_type = 'target' and o.name='histogram'
-- 	Exemple 3 - Création de la session 
	CREATE EVENT SESSION module_call ON SERVER ADD EVENT sqlserver.module_start(WHERE (sqlserver.database_id = 6))
		ADD TARGET package0.histogram(SET filtering_event_name = 'sqlserver.module_start', source_type = 0	-- 0 : filtrage sur le nom de l’événement. 1 : sur le nom de l’action
	, source = 'object_name', slots = 10240)																-- Nombre d’étapes dans l’histogramme
	
	ALTER EVENT SESSION module_call ON SERVER STATE = START													-- Démarrage de la session

-- Exemple 3 - 
	SELECT CAST(T.target_data AS xml) AS target_data FROM sys.dm_xe_sessions AS S INNER JOIN sys.dm_xe_session_targets AS T ON S.address = T.event_session_address
		WHERE S.name = 'module_call' AND T.target_name = 'histogram'	
		
-- Exemple 3 - Lecture des données collectées
	;WITH CTE AS (SELECT CAST(T.target_data AS xml) AS target_data FROM sys.dm_xe_sessions AS S	INNER JOIN sys.dm_xe_session_targets AS T ON S.address = T.event_session_address
					WHERE S.name = 'module_call' AND T.target_name = 'histogram')
	SELECT bucket.value('./value[1]', 'sysname') AS module_name, bucket.value('(@count)[1]', 'int') AS call_count FROM CTE
		CROSS APPLY target_data.nodes('HistogramTarget/Slot') AS BZ(bucket) INNER JOIN sys.objects AS O ON bucket.value('./value[1]', 'sysname') = O.name
		WHERE bucket.value('./value[1]', 'sysname') NOT LIKE 'sp?_MS%' ESCAPE '?'

/*
	Exemple 4 - Detecter si il y a un grand nombre de session ouvertes sur une instance
		ring_buffer: anneau de mémoire, c'est un FIFO, le plus ancien est remplacé par le plus recent. Nbre d'événements à conserver est parametrable.
		En règle générale on utilise:
			la cible fichier pour un audit de long terme, comme les traces
			La cible anneau mémoire pour un audit:
				de courte durée
				avec des filtres tres restrictifs qui ne capture que de faible quantité de données
				pour qu'un faible pourcentage des événements
*/

-- Exemple 4 - Detecter si il y a un grand nombre de session ouvertes sur une instance
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	GO
	SELECT SM.host_name, SM.login_name, SM.program_name, UPPER(SM.status) AS status, COUNT(*) AS session_count, OSC.total_opened_session_count
		, MIN(SM.login_time) AS min_login_time, MAX(SM.login_time) AS max_login_time, MIN(SM.last_request_end_time) AS min_last_request_end_time, EC.client_net_address, SL.session_list
	FROM sys.dm_exec_sessions AS SM	INNER JOIN sys.dm_exec_connections AS EC ON SM.session_id = EC.session_id
		OUTER APPLY (SELECT 'KILL ' + CAST(SS.session_id AS varchar(10)) + '; '	FROM sys.dm_exec_sessions AS SS
	WHERE SS.login_name = SM.login_name	AND SS.host_name = SM.host_name	FOR XML PATH('')) AS SL (session_list)
		OUTER APPLY (SELECT COUNT(*) AS total_opened_session_count FROM sys.dm_exec_sessions) AS OSC
	GROUP BY SM.host_name, SM.program_name, SM.status, SM.login_name, SL.session_list, EC.client_net_address, OSC.total_opened_session_count
	HAVING COUNT(*) > 5	ORDER BY COUNT(*) DESC

-- Exemple 4 - Liste des cibles ring_buffer
	SELECT P.name AS package_name, O.name AS target_name, OC.column_id, OC.name AS column_name, OC.column_type, OC.capabilities_desc, OC.column_value, OC.description AS column_description
	FROM sys.dm_xe_objects AS O	INNER JOIN sys.dm_xe_object_columns AS OC ON O.name = OC.object_name INNER JOIN sys.dm_xe_packages AS P ON O.package_guid = P.guid
	WHERE O.object_type = 'target' and o.name='ring_buffer'
	
-- Exemple 4 - Liste des événements:
	SELECT P.name as package_name, O.name AS event_name, OC.name as column_name, OC.column_type, OC.column_value, OC.description as column_description
	FROM sys.dm_xe_objects AS O INNER JOIN sys.dm_xe_object_columns AS OC ON O.name = OC.object_name INNER JOIN sys.dm_xe_packages AS P ON O.package_guid = P.guid
	WHERE O.object_type = 'event' AND O.name = 'login' and column_type <> 'readonly'
-- Exemple 4 - Créationd e la session
	CREATE EVENT SESSION non_pooled_connections ON SERVER ADD EVENT sqlserver.login(ACTION(sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_name, sqlserver.nt_username
			, sqlserver.server_principal_name, sqlserver.session_nt_username)
	WHERE is_cached = 0) ADD TARGET package0.ring_buffer
-- Exemple 4 - Résultat de la collecte
	SELECT CAST(T.target_data AS xml) AS target_data FROM sys.dm_xe_sessions AS S INNER JOIN sys.dm_xe_session_targets AS T ON S.address = T.event_session_address
		WHERE S.name = 'non_pooled_connections'	AND T.target_name = 'ring_buffer'	
-- Exemple 4 - Résultat	sous forme de lignes à partir des XML
	;WITH 
		CTE 
			AS (SELECT CAST(T.target_data AS xml) AS target_data FROM sys.dm_xe_sessions AS S	INNER JOIN sys.dm_xe_session_targets AS T ON S.address = T.event_session_address
					WHERE S.name = 'non_pooled_connections' AND T.target_name = 'ring_buffer')
		, DATA(database_name, session_nt_username, server_principal_name, nt_username, client_hostname, client_app_name)
			AS (SELECT DB_NAME(RB.buffer.value('(./data/value)[3]', 'int')), RB.buffer.value('(./action/value)[1]', 'sysname'), RB.buffer.value('(./action/value)[2]', 'sysname')
						, RB.buffer.value('(./action/value)[3]', 'sysname'), RB.buffer.value('(./action/value)[5]', 'sysname'), RB.buffer.value('(./action/value)[6]', 'sysname')
				FROM CTE CROSS APPLY target_data.nodes('RingBufferTarget/event') AS RB(buffer))

	SELECT database_name, session_nt_username, server_principal_name, nt_username
	, client_hostname, client_app_name, COUNT(*) AS occurences
	FROM DATA
	GROUP BY database_name, session_nt_username, server_principal_name, nt_username
	, client_hostname, client_app_name
	ORDER BY database_name

	
-------------------------
select column_type,* from sys.dm_xe_objects AS O INNER JOIN sys.dm_xe_object_columns AS OC ON O.name = OC.object_name where column_type <> 'readonly' and O.object_type = 'event' AND O.name = 'login'
select column_type,* from sys.dm_xe_object_columns where column_type <> 'readonly'
select column_type,* from sys.dm_xe_packages 