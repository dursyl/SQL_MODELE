/*
	AGENT SQL
*/
-- Historique des �tapes de travail
	select * from msdb.dbo.sysjobstepslogs
/* 
	Il est possible de planifier une t�che en fonction de l'utilisation de l'UC. La t�che est ex�cut�e lorsque l'UC est peu sollicit�.
	Exemple d'utilisation:
		Pr�voyez donc un travail de reconstruction des index qui s�lectionne au hasard un index fragment� et le reconstruit en minimisant le nombre de processeurs utilis�s 
		(option	MAXDOP de la commande SQL ALTER INDEX). Une fois accomplie, cette t�che est � nouveau activable pour la	d�fragmentation d�un autre index. 
		V�rifiez quand m�me dans l�historique que cette t�che se d�roule r�guli�rement et si ce n�est pas le cas, abaissez encore les seuils.
*/
-- On peut ex�cuter un Job sans passer par la planification
	msdb.dbo.sp_start_job 
-- Ajouter une planification � un travail
	msdb.dbo.sp_add_jobschedule	--@jobId : identifiant du job
/*
	On peut r�cup�er les erreurs journalis�es dans le fichier des �v�nements de Windows. Cela arrive pour les erreurs :
		- d'un niveau sup�rieur � 19.
		- sp�cifiquement journalis�e : RAISERROR ... WITH LOG
*/	
	select * from sys.messages where language_id=1036 and message_id in (1105, 9002)
-- Liste des bases de donn�es avec l'espace qu'occupent leurs LOG
	DBCC SQLPERF(LOGSPACE)
/*
	On peu declencher une alerte sur les performances de SQL Server. Ici lorsque le log atteint 70% de sa value max (parametr�) alors on dfait une sauvegarde (.trn)
	G�n�ral : Objet : "SQLServer:Databases", compteur : "Percent Log Used", Instance : "BOU_EFORCE", Alerte si le compteur "s'�l�ve au-dessus", valeur : "70"
	R�ponse: Ex�cuter le travail : BACKUP LOG DB_SQLPRO TO DISK = 'C:\DATABASE\SAVE\DB_SQLPRO.trn';
*/
-- liste des sous syst�mes de SQL SERVER
	select * FROM msdb.dbo.syssubsystems;


------------------------------------------------------------------------------

SELECT * FROM sys.dm_os_performance_counters


select * from sys.messages where language_id=1036 and message_id=8992
select * from sys.syslanguages

	select * from msdb.dbo.suspect_pages
	select * from sys.databases

	DBCC PAGE ('NEO_ATOFFICE', 2, 2330, 3) WITH TABLERESULTS;


select OBJECT_NAME(1029578706)
select OBJECT_ID('USR')
select * from BOU_EFORCE.dbo.PORT
SELECT DISTINCT OBJECT_NAME(5),OBJECT_NAME(6),OBJECT_NAME(7),OBJECT_NAME(8) FROM RAN_ATOFFICE.dbo.USR
