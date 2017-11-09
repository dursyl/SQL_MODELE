/*
	POLITQUE ADMINISTRATION (GESTION de la STRATEGIE)
*/
-- Liste des tables de la BDD 
	select * from INFORMATION_SCHEMA.TABLES
-- Liste des colonnes
	select * from INFORMATION_SCHEMA.COLUMNS
-- Configuration du server
	select * from sys.configurations
-- Liste des script de création des procédures systèmes
	select * from sys.all_sql_modules
-- Liste des fichiers de la base de données
	select * from sys.database_files
-- Liste des LOGINS et USERS
	select * from sys.database_principals
-- Liste des BDD
	select * from sys.databases
-- Liste des sessions en cours	
	select * from sys.dm_exec_sessions
--Liste des stratégies mises en place et des conditions
	select * FROM msdb.dbo.syspolicy_policies
	select * FROM msdb.dbo.syspolicy_conditions
-- Liste des facets à disposition
	select * FROM msdb.dbo.syspolicy_management_facets --execution_mode : 4 () 
-- Liste de stratégies proposées par Microsoft (respecte SOX par exemple). importable en cliquant droit sur Stratégie dans SSMS
	C:\Program Files (x86)\Microsoft SQL Server\100\Tools\Policies\DatabaseEngine\1036	

/*
	TRIGGERS (DECLENCHEURS)
	3 types: 
		LOGON (à la connexion réussie)
		declencheurs DLL globaux (s'active dans toutes les BDD su serveur)
		déclencheurs locaux	(s'active dans la BDD uniquement)
*/
-- Création d'un déclencheur de niveau base (interdisant les noms de procédures commençant par sp)
-- EVENTDATA() renvoie un XML des inforamtions relatives à l'événement survenu
	CREATE TRIGGER E_DDL_SRV_CREATEPROC ON DATABASE FOR CREATE_PROCEDURE AS
		IF LEFT(EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]', 'sysname'), 3)= 'sp_' COLLATE Latin1_General_100_CI_AI ROLLBACK; --collation pour rendre insensible à la casse
-- liste des evenements sur lesquels on peut mettre un declencheurs
	select * from sys.trigger_event_types
-- Déclencheur qui stocke dans une table (msdb.Schema_DDL.T_SUIVI_DDL) les modifications de structure
	CREATE TRIGGER E_DDL_BASE_ALL_EVENTS ON DATABASE FOR DDL_DATABASE_LEVEL_EVENTS --ON ALL SERVER pour toutes les bases du serveur
	AS BEGIN INSERT INTO msdb.Schema_DDL.T_SUIVI_DDL(DDL_DATA, DDL_EVENT)
	SELECT EVENTDATA(),EVENTDATA().value('(/EVENT_INSTANCE/EventType)[1]', 'sysname');END;
-- Liste des LOGIN de la base 
	SELECT name,principal_id,cnx.type, is_disabled, create_date,modify_date,default_database_name,default_language_name,permission_name
	FROM sys.server_principals AS cnx INNER JOIN sys.server_permissions AS sp ON cnx.principal_id = sp.grantee_principal_id


------------------------------------------------------------------------------


select * from sys.messages where language_id=1036 and message_id=8992
select * from sys.syslanguages

	select * from msdb.dbo.suspect_pages
	select * from sys.databases

	DBCC PAGE ('NEO_ATOFFICE', 2, 2330, 3) WITH TABLERESULTS;

	

select OBJECT_NAME(1029578706)
select OBJECT_ID('USR')
select * from BOU_EFORCE.dbo.PORT
SELECT DISTINCT OBJECT_NAME(3) FROM RAN_ATOFFICE
