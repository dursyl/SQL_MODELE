/*

	SCENARIO BACKUP PRATIQUE
https://www.mssqltips.com/sqlservertip/5028/sql-server-2017-differential-backup-changes/

http://www.sqlservergeeks.com/smart-differential-backup/
*/

------------------------------BACKUP
-- BackUp complet
BACKUP DATABASE [RAN_ATOFFICE] 
TO DISK = N'C:\DATA\BKP\RAN_ATOFFICE.bak'
WITH NOFORMAT, NOINIT, NAME = N'RAN_ATOFFICE-Full Database Backup', SKIP, NOREWIND, NOUNLOAD, STATS = 10
GO
-- BackUp diff�rentiel
BACKUP DATABASE RAN_ATOFFICE TO DISK = N'C:\DATA\BKP\RAN_BACKUP_AUTO\RAN_ATOFFICE.bak' WITH DIFFERENTIAL, NAME = N'RAN_ATOFFICE-Differentiel'
-- BackUp LOG
BACKUP LOG RAN_ATOFFICE TO DISK = N'C:\DATA\BKP\RAN_BACKUP_AUTO\RAN_ATOFFICE.bak' WITH NAME = N'RAN_ATOFFICE-Log'

-- Quels backup de sauvegarde dans .bak ?
	RESTORE HEADERONLY FROM DISK = 'C:\DATA\BKP\RAN_ATOFFICE.bak'
-- Quels fichiers de sauvegarde dans .bak ?
	RESTORE FILELISTONLY FROM DISK = 'C:\DATA\BKP\RAN_ATOFFICE.bak'

-- Pour test
--update CLIENT set VILLE='CRETEIL1' where VILLE='CRETEIL'



---------------------------------------RESTAURE
--Exemple de restauration
	ALTER DATABASE RAN_ATOFFICE
	SET SINGLE_USER
	WITH ROLLBACK IMMEDIATE;
	GO
	RESTORE DATABASE [RAN_ATOFFICE] FROM  DISK = N'C:\DATA\BKP\RAN_ATOFFICE_Full_20171214114750.bak' WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  REPLACE,  STATS = 10
	GO
	RESTORE DATABASE [RAN_ATOFFICE] FROM  DISK = N'C:\DATA\BKP\RAN_ATOFFICE_Diff_20171214115028.bak' WITH  FILE = 1,  NOUNLOAD,  REPLACE,  STATS = 10
	GO
	ALTER DATABASE RAN_ATOFFICE
	SET MULTI_USER;
	GO

------------------------COPIE des FICHIERS, DETACHEMENT
-- Voir les connexions actives sur la BDD
SELECT *  FROM   sys.dm_exec_connections AS ec 
       INNER JOIN sys.dm_exec_sessions AS es ON ec.session_id = es.session_id 
       INNER JOIN sys.dm_exec_requests AS er ON ec.session_id = er.session_id 
WHERE  database_id = DB_ID('RAN_ATOFFICE')
-- Forcer la d�connexion tout de suite
ALTER DATABASE RAN_ATOFFICE SET SINGLE_USER WITH ROLLBACK IMMEDIATE
-- Forcer la d�connexion en attendant quelques temps avant de couper. Il n'y aura plus de transaction entreprise en attendant
ALTER DATABASE RAN_ATOFFICE SET SINGLE_USER WITH ROLLBACK AFTER 30 SECONDS

-- D�tacher la base
EXEC sp_detach_db 'RAN_ATOFFICE'
-- Attacher la base
CREATE DATABASE RAN_ATOFFICE ON (FILENAME = 'C:\DATA\DATA RANBAXY\RAN_ATOFFICE.mdf'), (FILENAME = 'C:\DATA\DATA RANBAXY\RAN_ATOFFICE_log.ldf') FOR ATTACH

-------------------------DEVICE
-- Un device est un super fichier dans lequel on peut stocker tous les fichiers de son plan de sauvegardes.
-- Cr�ation d'un device
EXEC sp_addumpdevice 'disk', 'DVC_backup_advw', 'C:\DATA\BKP\dvc.toto' 
GO
-- BackUp dans un device
BACKUP DATABASE [RAN_ATOFFICE] TO DVC_backup_advw
GO
BACKUP DATABASE master TO DVC_backup_advw 
GO 
BACKUP DATABASE msdb TO DVC_backup_advw 
GO
-- BackUp diff�rentielle
BACKUP DATABASE [RAN_ATOFFICE] TO DVC_backup_advw WITH DIFFERENTIAL
GO
-- BackUp LOG
BACKUP LOG [RAN_ATOFFICE] TO DVC_backup_advw 
GO

-- m�tadonn�es du device : 
RESTORE LABELONLY FROM DVC_backup_advw 
-- on peut les obtenir de la m�me fa�on en utilisant un acc�s directe au fichier si le device n'est pas connu du serveur par exemple 
RESTORE LABELONLY FROM DISK = 'C:\DATA\BKP\dvc.toto' 
GO
-- Contenu du device
RESTORE HEADERONLY FROM DVC_backup_advw
-- nous y voyons toutes les sauvegardes, qui les a faites, � quelle heure, quelle base est concern�e, quel type de sauvegarde c'est... 
-- notez la colonne position du r�sultat de cette commande, elle va nous �tre utile par la suite... 
-- enfin, on peut conna�tre les �l�ments d'une sauvegarde en particulier. 
-- pour cela il faut indiquer la sauvegarde en faisant r�f�rence � sa position dans le device 
RESTORE FILELISTONLY FROM DVC_backup_advw WITH FILE = 1
RESTORE FILELISTONLY FROM DVC_backup_advw WITH FILE = 4
RESTORE FILELISTONLY FROM DVC_backup_advw WITH FILE = 5