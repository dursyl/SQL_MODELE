/*
	AUDIT
		DECLENCHEURS
			Niveau BDD		: Tracer les DLL
			Niveau INSTANCE	: Tracer les connexions, etc.
		SERVICE BROKER
			Niveau BDD		: Tracer l'ajout de colonne, l'octroi de privilèges à un USER, etc.
			Niveau INSTANCE	: Création de BDD, modifs des options d'une BDD, l'octroi de privilèges à un LOGIN, modification de la configuration du gouverneur de ressources, 
								occurence d'un verrou mortel, modification d'un login (mdp), etc.
		AUDIT
			Niveau BDD		:
			Niveau INSTANCE	: 
*/

/*
	DECLENCHEURS LDD sur BASE DE DONNEES
		Dans ces exemples on rempli une table créée pour collecter les informations de DLL (DDL_audit). En production c'est bien de nettoyer cette table régulierement
			par une tache auto.
*/
-- Liste des scripts LDD gerés
	select * from sys.trigger_event_types where type_name like '%TABLE%'

-- Hierarchie des scripts DLL (a éxecuter dans du texte) 
	;WITH CTE AS (SELECT type_name AS nom_type_evenement, type, 0 AS niveau,CAST(type_name AS varchar(max)) AS tri FROM sys.trigger_event_types WHERE parent_type IS NULL
		UNION ALL SELECT TET.type_name, TET.type, C.niveau + 1, C.tri+CAST(TET.type_name AS varchar(max)) FROM CTE AS C INNER JOIN sys.trigger_event_types AS TET ON C.type = TET.parent_type)
	SELECT REPLICATE(' |', niveau)+nom_type_evenement FROM CTE /*where nom_type_evenement like '%TABLE%' */ ORDER BY tri;

-- 
-- Création d’une base de données sans objet
	CREATE DATABASE DDL_AUDIT 
	GO 
	USE DDL_AUDIT 
	GO
-- Création du déclencheur LDD
	CREATE TRIGGER TR_DB_AUDIT_SCHEMA_SECURITE ON DATABASE
		FOR DDL_TABLE_VIEW_EVENTS, DDL_FUNCTION_EVENTS, DDL_PROCEDURE_EVENTS, DDL_TRIGGER_EVENTS, DDL_TYPE_EVENTS, DDL_ASSEMBLY_EVENTS, DDL_USER_EVENTS, DDL_ROLE_EVENTS
		AS BEGIN SET NOCOUNT ON; SELECT EVENTDATA(); END 
	GO
-- Création d'une table
	CREATE TABLE dbo.DDL_audit(DDL_audit_id int IDENTITY(1,1) NOT NULL
	CONSTRAINT PK_DDL_audit PRIMARY KEY, server_name varchar(128), event_type varchar(128) NULL, occurence_date_time datetime NOT NULL, login_name varchar(128) NULL, database_user_name varchar(128) NULL
			, database_name varchar(128) NULL, database_schema_name varchar(128) NULL, database_object_name varchar(128) NULL, database_object_type varchar(128) NULL, sql_statement nvarchar(max) NULL);
-- Modifier le déclancheur
	ALTER TRIGGER TR_DB_AUDIT_SCHEMA_SECURITE ON DATABASE FOR DDL_TABLE_VIEW_EVENTS, DDL_SYNONYM_EVENTS, DDL_FUNCTION_EVENTS, DDL_PROCEDURE_EVENTS, DDL_TRIGGER_EVENTS, DDL_TYPE_EVENTS, DDL_ASSEMBLY_EVENTS, DDL_USER_EVENTS, DDL_ROLE_EVENTS
	AS BEGIN SET NOCOUNT ON
		DECLARE @event_data xml = EVENTDATA() INSERT INTO dbo.DDL_Audit(server_name, event_type, occurence_date_time, login_name, database_user_name, database_name
			, database_schema_name, database_object_name, database_object_type, sql_statement)
		SELECT ED.ei.value('(./ServerName)[1]', 'varchar(128)'), ED.ei.value('(./EventType)[1]', 'varchar(128)'), ED.ei.value('(./PostTime)[1]', 'datetime'), ED.ei.value('(./LoginName)[1]', 'varchar(128)'),
				ED.ei.value('(./UserName)[1]', 'varchar(128)'), ED.ei.value('(./DatabaseName)[1]', 'varchar(128)'), ED.ei.value('(./SchemaName)[1]', 'varchar(128)'), ED.ei.value('(./ObjectName)[1]', 'varchar(128)'),
				ED.ei.value('(./ObjectType)[1]', 'varchar(128)'), ED.ei.value('(./TSQLCommand)[1]', 'varchar(max)') FROM @event_data.nodes('/EVENT_INSTANCE') AS ED(ei) END;		
				
-- Voir les lignes déclenchées par le TRIGGER (par le biais de la table DLL_audit
	select * from DDL_audit
	
/*
	DECLENCHEURS LDD sur INSTANCE
		Permet également de déclencher sur les évenements: création de connexion, de serveurs liés, etc.
*/

-- MAJ de la table DLL_AUDIT créée plus haut
	ALTER TABLE [dbo].[DDL_audit] ALTER COLUMN database_name VARCHAR(128) NULL
	GO
	ALTER TABLE [dbo].[DDL_audit] ALTER COLUMN database_user_name VARCHAR(128) NULL
	GO
	ALTER TABLE [dbo].[DDL_audit] ALTER COLUMN database_schema_name VARCHAR(128) NULL
	GO
	ALTER TABLE dbo.DDL_AUDIT ALTER COLUMN database_object_name VARCHAR(128) NULL
	GO
	ALTER TABLE dbo.DDL_AUDIT ALTER COLUMN [database_object_type] VARCHAR(128) NULL
	GO
	DROP TRIGGER TR_DB_AUDIT_SCHEMA_SECURITE ON DATABASE
-- Création du trigger
	CREATE TRIGGER [TR_SRV_AUDIT] ON ALL SERVER FOR DDL_TABLE_VIEW_EVENTS, DDL_SYNONYM_EVENTS, DDL_FUNCTION_EVENTS, DDL_PROCEDURE_EVENTS, DDL_TRIGGER_EVENTS, DDL_TYPE_EVENTS,
		DDL_ASSEMBLY_EVENTS, DDL_USER_EVENTS, DDL_ROLE_EVENTS, DDL_LINKED_SERVER_EVENTS, DDL_LOGIN_EVENTS, DDL_DATABASE_EVENTS
	AS BEGIN
		SET NOCOUNT ON DECLARE @event_data xml = EVENTDATA()
		INSERT INTO DDL_AUDIT.dbo.DDL_Audit(server_name, event_type, occurence_date_time, login_name, database_user_name, database_name
												, database_schema_name, database_object_name, database_object_type, sql_statement)															
		SELECT ED.ei.value('(./ServerName)[1]', 'varchar(128)'), ED.ei.value('(./EventType)[1]', 'varchar(128)', ED.ei.value('(./PostTime)[1]', 'datetime'), ED.ei.value('(./LoginName)[1]', 'varchar(128)'), ED.ei.value('(./UserName)[1]', 'varchar(128)'), ED.ei.value('(./DatabaseName)[1]', 'varchar(128)'), ED.ei.value('(./SchemaName)[1]', 'varchar(128)')
				, ED.ei.value('(./ObjectName)[1]', 'varchar(128)'), ED.ei.value('(./ObjectType)[1]', 'varchar(128)'), ED.ei.value('(./TSQLCommand)[1]', 'varchar(max)')	
			FROM @event_data.nodes('/EVENT_INSTANCE') AS ED(ei) 
		END;

/*
	DECLENCHEURS de notifications d'événements 
		Au niveau BDD:		ajout d'une colonne, octroi de provilèges à un utilisateur, etc.
		Au niveau Instance: Création de BDD, modification des options de BDD, Octroi de privilège, modification de la configuration du gouverneur de ressources, etc.
		En cours de fonctionnement: Ajout d'une connexion à un rôle, occurence d'un verrou mortel, etc.
		La notification d'événements utilise Service Broker:
			Création de QUEUE
			Création de SERVICE 
			Création de EVENT NOTIFICATION
			Consultation: dbo.Queue_Notification_Evenement
*/
-- Liste des événements que l'on peut capturer
	select * from sys.event_notification_event_types where type_name like '%TABLE%'

-- Création de la base de test, activation du service broker et de la QUEUE
	USE DDL_AUDIT --CREATE DATABASE DDL_AUDIT
	GO
	ALTER DATABASE DDL_AUDIT SET ENABLE_BROKER									-- Activation de la fonctionnalité Service Broker pour la base de données
	GO
	SELECT name, is_broker_enabled FROM sys.databases WHERE name = 'DDL_AUDIT'	-- Vérification de l’activation de la fonctionnalité Service Broker
	GO
	CREATE QUEUE dbo.Queue_Notification_Evenement								-- Création de la queue qui tracera les événements
	GO
	SELECT *FROM sys.service_queues WHERE name = 'Queue_Notification_Evenement'	-- Vérification de création de la queue
	GO

-- Création du service qui transmettra les informations auditées pour chaque événement
-- Le contrat existe (sys.service_contracts) et permet à ce service d’envoyer les notifications d’événements
	CREATE SERVICE [//NE/Service_Notification_Evenement] ON QUEUE dbo.Queue_Notification_Evenement([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification])
	GO
-- Vérification
	SELECT S.name AS nom_service, Q.name AS nom_queue FROM sys.services AS S INNER JOIN sys.service_queues AS Q ON S.service_queue_id = Q.object_id WHERE S.name = '//NE/Service_Notification_Evenement'

-- Création de la notification d’événement
	--drop EVENT NOTIFICATION notification_modification_schema_physique ON DATABASE
	CREATE EVENT NOTIFICATION notification_modification_schema_physique	ON DATABASE	FOR DDL_TABLE_EVENTS -- CREATE, ALTER et DROP TABLE
	TO SERVICE '//NE/Service_Notification_Evenement', 'current database'
	GO
	-- Vérification
	SELECT EN.name AS nom_notification, S.name AS nom_service, SQ.name AS nom_queue	FROM sys.event_notifications AS EN
	INNER JOIN sys.services AS S ON EN.service_name = S.name INNER JOIN sys.service_queues AS SQ ON SQ.object_id = S.service_queue_id

	-- Test avec des création de tables
	/*
		drop table tb_personne_nom
		drop table tb_type_nom_personne
		drop table tb_personne
	*/
	CREATE TABLE tb_personne(personne_id INT NOT NULL IDENTITY(-2147483648, 1) CONSTRAINT PK_tb_personne PRIMARY KEY, personne_nom_id INT NOT NULL, date_naissance SMALLDATETIME NOT NULL)
	GO
	CREATE TABLE tb_type_nom_personne (type_nom_personne_id TINYINT IDENTITY NOT NULL CONSTRAINT PK_tb_type_nom_personne PRIMARY KEY, nom_type VARCHAR(16) NOT NULL CONSTRAINT UQ_tb_type_nom_personne__nom_type UNIQUE)
	GO
	CREATE TABLE tb_personne_nom (tb_personne_nom_id BIGINT NOT NULL IDENTITY(-9223372036854775808, 1) CONSTRAINT PK_tb_personne_nom PRIMARY KEY, personne_id INT NOT NULL CONSTRAINT FK_tb_personne_nom__personne_id
		FOREIGN KEY (personne_id) REFERENCES dbo.tb_personne,type_nom_personne_id TINYINT NOT NULL CONSTRAINT FK_tb_personne_nom__type_nom_personne_id FOREIGN KEY (type_nom_personne_id) REFERENCES dbo.tb_type_nom_personne, nom_personne NVARCHAR(128) NOT NULL)
	GO
	ALTER TABLE dbo.tb_personne	ADD genre CHAR(1) NOT NULL CONSTRAINT CHK_tb_personne__genre CHECK (genre IN ('M','F','U'))
	GO

	-- Capture des script DLL ci-dessus:
	DECLARE @notification TABLE(message_body XML);
	RECEIVE CAST(message_body AS XML) FROM dbo.Queue_Notification_Evenement
	INTO @notification SELECT message_body FROM @notification

/*
	AUDITER les changements de mot de passe
		A l'aide de SERVICE BROKER et d'une procédure stockée. Audit au niveau INSTANCE
		La procédure stockée doit être exécuter de manière automatique, elle dépile la QUEUE pour nourrir un table de trace.
*/

-- Création d'une table où nous allons stocker les événements collectées
	CREATE TABLE dbo.journal_mot_de_passe(journal_mot_de_passe_id INT NOT NULL IDENTITY(-2147483648, 1), log_date_time DATETIME NOT NULL, nom_connexion_source SYSNAME, nom_connexion_cible SYSNAME)
	GO
-- Création des objets de base du SERVICE BROKER
	CREATE QUEUE dbo.Queue_Notification_Mot_De_Passe
	GO
	CREATE SERVICE [//NE/Service_Notification_Mot_De_Passe] ON QUEUE dbo.Queue_Notification_Mot_De_Passe ([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification])
	GO
	CREATE EVENT NOTIFICATION notification_modification_mot_de_passe ON SERVER FOR AUDIT_LOGIN_CHANGE_PASSWORD_EVENT TO SERVICE '//NE/Service_Notification_Mot_De_Passe', 'current database'
	GO
-- Création de la procedure stokckée qui sera rattachée à la queue 
	CREATE PROCEDURE dbo.usp_Queue_Notification_Mot_De_Passe_get WITH EXECUTE AS OWNER AS
		BEGIN
			SET NOCOUNT ON
			DECLARE @notification_evenement XML
			WHILE 1 = 1
			BEGIN
			BEGIN TRY
			BEGIN TRANSACTION
			WAITFOR (RECEIVE TOP (1) @notification_evenement = message_body	FROM dbo.Queue_Notification_Mot_De_Passe), TIMEOUT 1000
			IF @@ROWCOUNT = 0
				BEGIN
					ROLLBACK TRANSACTION
					BREAK
				END
			ELSE
				BEGIN
					INSERT INTO dbo.journal_mot_de_passe(log_date_time, nom_connexion_source, nom_connexion_cible)
						SELECT n.value('(/EVENT_INSTANCE/PostTime)[1]', 'datetime'), n.value('(/EVENT_INSTANCE/LoginName)[1]', 'sysname'), n.value('(/EVENT_INSTANCE/TargetLoginName)[1]', 'sysname')
						FROM @notification_evenement.nodes('/EVENT_INSTANCE') AS EM(n)
					COMMIT TRANSACTION
				END
				END TRY
				BEGIN CATCH
					DECLARE @err_msg NVARCHAR(2048) = ERROR_MESSAGE()
					IF XACT_STATE() <> 0 ROLLBACK TRANSACTION
					RAISERROR(@err_msg, 16, 1)
					BREAK
				END CATCH
			END
		END
		GO
-- Modification de la QUEUE pour y intégrer la procédure stockée qui dépilera la QUEUE
	ALTER QUEUE dbo.Queue_Notification_Mot_De_Passe	WITH ACTIVATION(STATUS = ON, PROCEDURE_NAME = dbo.usp_Queue_Notification_Mot_De_Passe_get, MAX_QUEUE_READERS = 1, EXECUTE AS OWNER)
	GO
-- Modifs sur les mots de passe pour tester
	CREATE LOGIN test_notification_changement_mot_de_passe WITH PASSWORD = 'UnM0t2Pâ$$e!C0çt0d'
	GO
	ALTER LOGIN test_notification_changement_mot_de_passe
	WITH PASSWORD = 'UnAutreM0t2Pâ$$e!C0çt0d'
	GO
-- Execution de la procédure stockée (qui sera exécutée réglierement de maniere auto pour recolter les traces) et consultation de la trace
	EXEC dbo.usp_Queue_Notification_Mot_De_Passe_get
	GO
	SELECT * FROM dbo.journal_mot_de_passe


/*
	AUDIT de SECURITE
		Un objet d’audit de sécurité est un groupe d’actions effectuées par l’utilisateur sur les données, la structure ou les options de la base de données 
			ou encore sur les options de configuration de l’instance SQL Server
		Les audits de sécurité reposent sur la fonctionnalité d’événements étendus (package SecAudit). Comme les événements étendus, un événement de sécurité n’est capturé 
			qu’une seule fois, avant d’être distribué à tous les audits qui sont à l’écoute de l’occurrence d’un tel événement. Ceci implique que l’on peut créer plusieurs 
			audits de sécurité, aussi bien au niveau serveur qu’au niveau base de données.
		Lors de la création de tout audit de sécurité, il est obligatoire de spécifier le fichier qui servira à la fois de réceptable à l’audit et de base pour le reporting.
		La mise en place d’un audit de sécurité journalisant les événements dans le journal des événements de sécurité de Windows nécessite des autorisations externes à SQL Server.
*/
/*
	AUDIT de Server
		Il ne peut y avoir q'un seul audit de serveur et plusieurs audit de BDD
		 CREATE SERVER AUDIT
		 ALTER SERVER AUDIT ... WITH (STATE=ON)
		 CREATE SERVER AUDIT SPECIFICATION				-- lié au AUDIT SERVER
		 ALTER SERVER AUDIT SPECIFICATION ... WITH (STATE=ON)
		 CREATE DATABASE AUDIT SPECIFICATION			-- lié au AUDIT SERVER
		  
*/
-- Liste des objets d'audit
	select * from sys.server_audits
	
	SELECT SA.name AS instance_audit_name, SA.audit_guid, SA.create_date, SA.modify_date, SP.name AS creator_name, SA.type_desc AS target_type, SA.on_failure_desc, SA.is_state_enabled, SA.queue_delay,
		SFA.create_date AS audit_file_creation_date, SFA.modify_date AS audit_file_last_modificarion_date, SFA.max_file_size,SFA.max_rollover_files
		, SFA.reserve_disk_space, SFA.log_file_path + SFA.log_file_name AS audit_file_path
	FROM sys.server_audits AS SA INNER JOIN sys.server_principals AS SP ON SA.principal_id = SP.principal_id LEFT JOIN sys.server_file_audits AS SFA ON SFA.audit_id = SA.audit_id AND SFA.audit_guid = SA.audit_guid
-- Liste des spécifications
	select * from sys.server_audit_specifications
	select * from sys.database_audit_specifications
-- Liste actions des spécifications	
	select * from sys.server_audit_specification_details
	select * from sys.database_audit_specification_details

	USE master
	CREATE SERVER AUDIT audit_securite_exemple 
		TO FILE	(FILEPATH=N'C:\temp_XE\', MAXSIZE=128 MB, MAX_ROLLOVER_FILES=5, RESERVE_DISK_SPACE=ON)
		WITH (QUEUE_DELAY = 1000, ON_FAILURE = FAIL_OPERATION, AUDIT_GUID = '53ba3a31-b1a4-4767-9ee5-fc6a67b8ecd2') -- ON_FAILURE: que fait le server si il remonte une erreur
		WHERE (database_name = 'RAN_ATOFFICE' AND object_name LIKE '%CMD%')
	GO
		ALTER SERVER AUDIT audit_securite_exemple WITH (STATE=ON)
	GO


-- Création d'un AUDIT SPECIFICATION lié à l'AUDIT
	USE master
	GO
	CREATE SERVER AUDIT SPECIFICATION server_audit_exemple FOR SERVER AUDIT audit_securite_exemple ADD (DATABASE_OBJECT_CHANGE_GROUP), ADD (BACKUP_RESTORE_GROUP),
		ADD (FAILED_LOGIN_GROUP), ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP), ADD (SERVER_OPERATION_GROUP), ADD (SERVER_STATE_CHANGE_GROUP), ADD (TRACE_CHANGE_GROUP)
	GO
	ALTER SERVER AUDIT SPECIFICATION server_audit_exemple WITH (STATE = ON)

-- Liste de groupes d'actions d'audit à disposition pour l'AUDIT SERVER
	SELECT DISTINCT CASE WHEN name NOT LIKE '%GROUP' THEN covering_action_name ELSE name END AS action_group_name FROM sys.dm_audit_actions WHERE class_desc = 'SERVER'
	-- SELECT * FROM sys.dm_audit_actions where covering_parent_action_name like '%FAILED_LOGIN%'
-- Liste de groupes d'actions et d'actions à disposition pour l'AUDIT DATABASE
	SELECT name AS action_name, class_desc, COALESCE(covering_action_name, covering_parent_action_name) AS covering_action_name FROM sys.dm_audit_actions WHERE class_desc <> 'SERVER' ORDER BY class_desc
-- Création d'un AUDIT SPECIFICATION DATABASE
	CREATE DATABASE AUDIT SPECIFICATION database_audit_exemple FOR SERVER AUDIT audit_securite_exemple ADD (DATABASE_PERMISSION_CHANGE_GROUP), ADD (EXECUTE, SELECT
		, INSERT, UPDATE, DELETE ON OBJECT::dbo.USR BY dbo, db_datareader)	

/*
	AUDIT de BASE DE DONNEES
	
*/

-- Actions et groupes d'actions qu'on peut auditer 
	SELECT name AS action_name, class_desc, COALESCE(covering_action_name, covering_parent_action_name) AS covering_action_name
	FROM sys.dm_audit_actions WHERE class_desc <> 'SERVER' ORDER BY class_desc

-- creation d'un audit au niveau base de données
	CREATE DATABASE AUDIT SPECIFICATION database_audit_exemple FOR SERVER AUDIT audit_securite_exemple
	ADD (DATABASE_PERMISSION_CHANGE_GROUP), ADD (EXECUTE, SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.USR BY dbo, db_datareader)
-- activer la specification
	ALTER DATABASE AUDIT SPECIFICATION database_audit_exemple WITH (STATE = ON)
	
/*
	AUDIT DE SECURITE 
		EXEMPLE 1 :
			Type	: SERVER
			Cible	: le journal de sécurité de Windows
			Audit sur tous les changements de mots de passe
		On peut spécifier comme cible le journal Windows de sécurité. On peut voir aussi les événéments dans le menu de l'AUDIT (journaux d'audit).
		Les événements à auditer sont: ADD(FAILED_DATABASE_AUTHENTICATION_GROUP), ADD (FAILED_LOGIN_GROUP), ADD (LOGIN_CHANGE_PASSWORD_GROUP),ADD (USER_CHANGE_PASSWORD_GROUP)
		
*/		

/*
	AUDIT DE SECURITE 
		EXEMPLE 2 :
			Type	: BASE DE DONNEES
			Cible	: fichier binaire
			Audit sur QUI a interrogé et modifié les données d'une table
*/		
-- Création de l'audit de sécuritévers une cible fichier binaire
	CREATE SERVER AUDIT AuditSecurite_AccesTables_AdventureWorks TO FILE (FILEPATH = N'C:\temp_XE\', MAXSIZE = 128 MB, MAX_FILES = 16, RESERVE_DISK_SPACE = ON)
	WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE, AUDIT_GUID = '95560bae-e1e8-40f7-8267-607c737b9b86') WHERE database_name = 'RAN_ATOFFICE'
	GO
-- Création de l'audit de spécification, audite les SELECT sur l'objet CLIENT (ici dbo pour auditer n'importe quel utilisateur
	USE [RAN_ATOFFICE]
	GO
	CREATE DATABASE AUDIT SPECIFICATION [SpecificationAuditBase_AccesTables_AdventureWorks] FOR SERVER AUDIT [AuditSecurite_AccesTables_AdventureWorks]
	ADD (SELECT ON OBJECT::[CLIENT] BY [dbo])
	GO
-- Ajouter l'audit sur la table ACTEUR (select, insert, update, delete)
	ALTER DATABASE AUDIT SPECIFICATION SpecificationAuditBase_AccesTables_AdventureWorks FOR SERVER AUDIT AuditSecurite_AccesTables_AdventureWorks
	ADD (SELECT,INSERT,UPDATE,DELETE ON OBJECT::CLIENT BY dbo), ADD (SELECT,INSERT,UPDATE,DELETE ON OBJECT::ACTEUR BY dbo)
	GO
	ALTER DATABASE AUDIT SPECIFICATION SpecificationAuditBase_AccesTables_AdventureWorks
	WITH (STATE = ON)
	GO

-- Lire les données d'audit
	SELECT DATEADD(HOUR, DATEDIFF(HOUR, GETUTCDATE(), GETDATE()), AF.event_time) AS event_time
	, AF.sequence_number AS idx, AA.name AS action_name, AF.succeeded, AF.schema_name + '.' + AF.object_name AS audited_table_name
	, AF.statement, AF.session_server_principal_name
	FROM sys.fn_get_audit_file('C:\temp_XE\AuditSecurite_AccesTables_AdventureWorks*', DEFAULT, DEFAULT) AS AF
	INNER JOIN sys.dm_audit_actions AS AA ON AF.action_id = AA.action_id
	WHERE AA.parent_class_desc = 'DATABASE'

/*
	AUDIT de changements de données (CDC - change data capture, CT - Change tracking)
		Cet audit permet de remplacer (les contre performant) :
			- les déclencheurs DML développés pour cipier les anciennes/nouvelles données dans une table dédiée
			- l'ajout de type date de mise à jour aux tables à auditer
		Il faut activer la fonctionnalité au niveau base puis au niveau table.
		L'audit est stocké dans des tables système
*/
/*
	CT - Change tracking (suivi des modifications)
	
*/
-- activer la fonctionnalité au niveau BDD (CHANGE_RETENTION: nettoyage des données stockées auditées - sys.syscommittab)
	ALTER DATABASE RAN_ATOFFICE SET CHANGE_TRACKING = ON (AUTO_CLEANUP = ON, CHANGE_RETENTION = 1 DAYS); -- ou HOURS ou MINUTES 
	USE RAN_ATOFFICE;
	ALTER TABLE CLIENT ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON)		-- table à auditer
	GO
-- Parametres de CT au niveau server
	SELECT D.name AS database_name, CTD.is_auto_cleanup_on, CTD.retention_period, CTD.retention_period_units_desc
	FROM sys.databases AS D INNER JOIN sys.change_tracking_databases AS CTD ON CTD.database_id = D.database_id
-- Liste des tables auditées
	SELECT * FROM sys.all_objects
	WHERE type_desc = 'INTERNAL_TABLE'
	AND name LIKE 'change_tracking%'

	SELECT * FROM sys.internal_tables
	WHERE internal_type_desc = 'CHANGE_TRACKING'

	SELECT S.name + '.' + T.name AS table_name, TT.is_track_columns_updated_on, TT.min_valid_version, TT.begin_version, TT.cleanup_version
	FROM sys.change_tracking_tables AS TT INNER JOIN sys.tables AS T ON T.object_id = TT.object_id INNER JOIN sys.schemas AS S ON S.schema_id = T.schema_id

-- Exemple de table d'audit (avec id de l'objet audité en sufixe). La table n'est pas interrogeable.
	select * from change_tracking_1826105546
	select OBJECT_NAME(1826105546)

-- Modifs de la table CLIENT pour test
	select * from Client
	update CLIENT set ADR2='MONT-MELY' where IDCLIENT=2
	update CLIENT set ADR2='ICI', VILLE='ST ETIENNE' where IDCLIENT=34848

-- Voir les changements:
	SELECT CHANGE_TRACKING_CURRENT_VERSION();
	SELECT CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('CLIENT'));
	SELECT * FROM CHANGETABLE(CHANGES CLIENT, 0) AS CT;

	DECLARE @version_sync bigint = 0
	SELECT CT.IDCLIENT, CASE CT.SYS_CHANGE_OPERATION WHEN 'I' THEN 'Ajout' WHEN 'U' THEN 'Modification' WHEN 'D' THEN 'Suppression' END AS operation
	, P.ADR2, P.VILLE, P.CDCLIENT, CT.SYS_CHANGE_VERSION AS version, CAST(CT.SYS_CHANGE_CONTEXT AS varchar(128)) AS contexte
	, LEFT(CC.changed_column_list, LEN(CC.changed_column_list) - 1) AS changed_column_list
	FROM CHANGETABLE(CHANGES CLIENT, @version_sync) AS CT LEFT JOIN CLIENT AS P ON P.IDCLIENT = CT.IDCLIENT CROSS APPLY(
		SELECT name + ', ' FROM sys.columns AS C WHERE object_id = OBJECT_ID('CLIENT') AND CHANGE_TRACKING_IS_COLUMN_IN_MASK(C.column_id, CT.SYS_CHANGE_COLUMNS) = 1
			AND CT.SYS_CHANGE_OPERATION = 'U' FOR XML PATH('')) AS CC(changed_column_list)  ORDER BY CT.SYS_CHANGE_VERSION

-- Desactiver le suivi de modifs sur une table
	ALTER TABLE CLIENT DISABLE CHANGE_TRACKING

/*
	CDC - Change data capture
		Cas courant: synchronisation avec un entrepot de données, pour savoir quelles lignes à été supprimées.
		Avec cette fonctionnalité on peut savoir quoi et quand une donnée à été modifiée mais pas par qui.
		Il faut activer la fonctionnalité au niveau base puis au niveau table.
		L'audit est stocké dans des tables système
*/
-- Create table pour test
	CREATE TABLE dbo.client (client_id int NOT NULL IDENTITY(-2147483648, 1) CONSTRAINT PK_client PRIMARY KEY, client_numero char(10) NOT NULL CONSTRAINT UQ_client__client_numero UNIQUE, client_nom varchar(32) NOT NULL, client_telephone char(10) NOT NULL, client_adresse varchar(256) NOT NULL)
-- Activer CDC sur la base active -- un user est créé
	EXEC sys.sp_cdc_enable_db
-- Verifier l'activation 
	SELECT name, is_cdc_enabled FROM sys.databases WHERE name = 'TEST';
-- On peut créer un groupe de fichiers dédié au cdc
	ALTER DATABASE TEST ADD FILEGROUP CDC
	GO
	ALTER DATABASE TEST ADD FILE (NAME = CDC_data, FILENAME = 'C:\DATA\TEST_CDC_data.ndf', SIZE = 1GB, FILEGROWTH = 1GB) TO FILEGROUP CDC
	GO
-- Activer CDC sur la table CLIENT -- Des tables systémes sont créées dans la base (du nom de la table à suivre - cdc.dbo_client_CT)
	EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'client2', @role_name = 'CDC_role', @supports_net_changes = 1
		, @captured_column_list = 'client_id,client_telephone,client_adresse', @filegroup_name = 'CDC'
-- Liste des jobs créée dans la base mscb (base qui gere les jobs)
	SELECT J.name AS job_name, D.name AS for_database, CJ.job_type, CJ.maxtrans, CJ.maxscans, CJ.continuous, CJ.pollinginterval, CJ.retention, CJ.threshold
	FROM msdb.dbo.cdc_jobs AS CJ INNER JOIN msdb.dbo.sysjobs AS J ON CJ.job_id = J.job_id INNER JOIN sys.databases AS D ON CJ.database_id = D.database_id
-- Changement pour TEST
	INSERT INTO dbo.client(client_numero, client_nom, client_telephone, client_adresse) VALUES('YSGSTY1257', 'Soutou', '0610101010', '2, rue des yaourts, 31000 Toulouse'), ('ZTQGRSDY12', 'Brouard', '0720202020', '12, avenue des entités, SQLand'), ('DYSTYSF785', 'Souquet', '0830303030', '1, place Lumphini, 10120 Bangkok, Thaïlande') ;
-- il est déconseillé d'interroger les tables système cdc parce que cela peut entrainer des blocages important
-- Liste des changements
	SELECT CASE SRC.__$operation WHEN 1 THEN 'DELETE' WHEN 2 THEN 'INSERT' WHEN 3 THEN 'UPDATE (OLD VALUES)' WHEN 4 THEN 'UPDATE (NEW VALUES)' END AS operation
		, SRC.client_id, SRC.client_telephone, SRC.client_adresse
		, LEFT(CL.changed_column_list, LEN(CL.changed_column_list) - 1) AS changed_column_list
		, sys.fn_cdc_map_lsn_to_time(SRC.__$start_lsn) AS tran_time
	FROM cdc.dbo_client_CT AS SRC CROSS APPLY (SELECT CC.column_name + ', ' FROM cdc.change_tables AS CT INNER JOIN cdc.captured_columns AS CC ON CT.object_id = CC.object_id
	WHERE CT.source_object_id = OBJECT_ID('dbo.client') AND POWER(2, CC.column_ordinal - 1) & SRC.__$update_mask > 0 FOR XML PATH ('')) AS CL (changed_column_list);
-- Update pour test
	UPDATE dbo.client SET client_adresse = CASE client_id WHEN -2147483648 THEN '11, place du 6 Juin 1944, 31000 Toulouse, France' WHEN -2147483647 THEN '5, avenue Charles de Gaulle, 83200 Toulon, France'
		WHEN -2147483646 THEN '87, Ouparatkhambua Road, Luang Prabang, Laos' END

-- il est déconseillé d'interroger les tables système cdc parce que cela peut entrainer des blocages important
-- Alors on peut utiliser des fonctions - Extraire tous les changements
	DECLARE @begin_lsn binary(10) = sys.fn_cdc_get_min_lsn('dbo_client'), @end_lsn binary(10) = sys.fn_cdc_get_max_lsn();
	SELECT * FROM cdc.fn_cdc_get_all_changes_dbo_client(@begin_lsn, @end_lsn, 'all update old');
	DECLARE @begin_lsn2 binary(10) = sys.fn_cdc_get_min_lsn('dbo_client'), @end_lsn2 binary(10) = sys.fn_cdc_get_max_lsn();
	SELECT * FROM cdc.fn_cdc_get_all_changes_dbo_client(@begin_lsn2, @end_lsn2, 'all');
-- Desactiver CDC
	EXEC sys.sp_cdc_disable_table @source_schema = 'dbo', @source_name = 'client', @capture_instance = 'dbo_client'

/*
	STRATEGIES (PBM - Policy Based Management))
		Permet d'être alerté lorsqu'un écart de configuration est constaté.
		facettes-condition-stratégie
		1- Créer une (des) condition(s) - lié à une facette (procédure stockée, base de données, connexion, etc.)
		2- Créer une startégie
		3- 
*/
-- Liste de la liste des façettes disponibles
	select * from dbo.syspolicy_management_facets

-- Il existe 4 modes d'évaluation (a la demande, planification, empecher sur modification, journaliser sur modification)
-- Requete qui liste les modes d'évaluation disponible par façette
	;WITH CTE AS (SELECT F.name AS facet_name, EM.eval_mode_name FROM msdb.dbo.syspolicy_management_facets AS F INNER JOIN (VALUES (0, 'On Demand')
		, (1, 'On Change : Prevent'), (2, 'On Change : Log Only'), (4, 'On Schedule')) AS EM (mask, eval_mode_name) ON F.execution_mode & EM.mask = EM.mask)
	SELECT DISTINCT C.facet_name, LEFT(S.eval_mode_list, LEN(S.eval_mode_list) - 1) AS eval_mode_list
	FROM CTE AS C CROSS APPLY (SELECT eval_mode_name + ' | 'FROM CTE AS S WHERE S.facet_name = C.facet_name FOR XML PATH ('')) AS S(eval_mode_list)

-- Log renvoyer par la STRATEGIES pour celles qui sont parametrées pour envoyer dans le log
	SELECT P.name AS policy_name, C.name AS condition_name, HD.execution_date, HD.target_query_expression
		, CASE HD.result WHEN 0 THEN 'Success' WHEN 1 THEN 'Failure' END AS result, HD.result_detail, HD.exception, HD.exception_message
	FROM msdb.dbo.syspolicy_policy_execution_history AS H INNER JOIN msdb.dbo.syspolicy_policy_execution_history_details AS HD ON H.history_id = HD.history_id
	INNER JOIN msdb.dbo.syspolicy_policies AS P ON P.policy_id = H.policy_id INNER JOIN msdb.dbo.syspolicy_conditions AS C ON P.condition_id = C.condition_id


-------------------------

select * from dbo.Queue_Notification_Evenement
select * from sys.event_notifications
select * from sys.services
select * from sys.service_contracts
select * from sys.service_queues
SELECT EN.name AS nom_notification, S.name AS nom_service FROM sys.event_notifications AS EN INNER JOIN sys.services AS S ON EN.service_name = S.name
select * from sys.services AS S INNER JOIN sys.service_queues AS SQ ON SQ.object_id = S.service_queue_id






----------------------------------
/*
	EXTRA
*/
-- Une BDD qui est en RECOVERY_PENDNG -> dû a des transaction non commited: base mal fermés, fichier log supprimé ou corrompu, manque d'espace de stockage. Solution:
-- Solution 1 - 
	ALTER DATABASE [DBName] SET EMERGENCY;
	GO
	ALTER DATABASE [DBName] set single_user
	GO
	DBCC CHECKDB ([DBName], REPAIR_ALLOW_DATA_LOSS) WITH ALL_ERRORMSGS;
	GO 
	ALTER DATABASE [DBName] set multi_user
	GO
-- Solution 2 - ratacher la base recrera un fichier log
	ALTER DATABASE [DBName] SET EMERGENCY;
	ALTER DATABASE [DBName] set multi_user
	EXEC sp_detach_db '[DBName]'
	EXEC sp_attach_single_file_db @DBName = '[DBName]', @physname = N'[mdf path]'
	
/*
	RECHERCHE d'index sous utilisés
		Cette requête donne le nombre de fois qu'un index a été modifé VS le nombre de lecture de cette index.
		En cas de menage, bien faire attention :
			- de ne pas supprimer d'index PRIMARY KEY ou FOREIGN KEY
			- Certains index peuvent être utile lors de chargement en masse. Paraissant peu utlisé mais ralentissant fortement l'intégration en masse.
			- Les données apparaissant dans les vues DMV sont vidées à chaque redemarrage, s'assurer que celui-ci n'est pas récent.
		
*/
	SELECT   OBJECT_NAME(s.[object_id]) AS [Table Name] ,
			 i.name AS [Index Name] ,
			 i.fill_factor ,
			 user_updates AS [Total Writes] ,
			 user_seeks + user_scans + user_lookups AS [Total Reads] ,
			 user_updates - ( user_seeks + user_scans + user_lookups ) AS [Difference]
	FROM     sys.dm_db_index_usage_stats AS s WITH ( NOLOCK )
			 INNER JOIN sys.indexes AS i WITH ( NOLOCK ) ON s.[object_id] = i.[object_id]
															AND i.index_id = s.index_id
	WHERE    OBJECTPROPERTY(s.[object_id], 'IsUserTable') = 1
			 AND s.database_id = DB_ID()
			 AND user_updates > ( user_seeks + user_scans + user_lookups )
			 AND i.index_id > 1
	ORDER BY [Difference] DESC ,
			 [Total Writes] DESC ,
			 [Total Reads] ASC
	OPTION ( RECOMPILE );
