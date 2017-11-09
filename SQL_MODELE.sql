/*
USE BOU_EFORCE
*/

-- Liste TABLES et COLONNES, CHAMPS
	select * from INFORMATION_SCHEMA.TABLES
	select * from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME='LIGFACT' and COLUMN_NAME='CIP'

-- Liste messages
	select * from sys.messages where language_id=1036 and message_id=17054

-- User courant, en cours
	DECLARE @usr char(30)
	SET @usr = CURRENT_USER
	select @usr

-- Base BDD en cours, courant
	select db_id()
	select * from sys.databases where database_id=DB_ID()
-- IDENTIFIANT d'une base de donénes (BDD)
	select db_id('RAN_ATOFFICE')

-- Nombre (nbre) de USERS (utilisateurs) connectés (connexions)
	SELECT COUNT(*) FROM sys.sysprocesses WHERE dbid=db_id() 

-- Liste des PROCESSUS en cours 
	select * from sys.sysprocesses

-- liste des logins, derniere mise a jour, creation, BDD par défaut
	select * from sys.syslogins

-- Quelles pages ?
	DBCC IND(RAN_ATOFFICE, CMD, -1)
-- Voir la page
	DBCC PAGE(RAN_ATOFFICE, 1, 247066, 3) WITH TABLERESULTS --index
	DBCC PAGE(RAN_ATOFFICE, 1, 386125, 3) WITH TABLERESULTS --données

-- Quelle table est concernée ?
	select OBJECT_NAME(901578250) -- PAHE_HEADER, Field (Metadata: ObjectId)
