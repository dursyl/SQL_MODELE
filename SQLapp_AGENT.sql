/*
	AGENT SQL
*/
-- Historique des étapes de travail
	select * from msdb.dbo.sysjobstepslogs
/* 
	Il est possible de planifier une tâche en fonction de l'utilisation de l'UC. La tâche est exécutée lorsque l'UC est peu sollicité.
	Exemple d'utilisation:
		Prévoyez donc un travail de reconstruction des index qui sélectionne au hasard un index fragmenté et le reconstruit en minimisant le nombre de processeurs utilisés 
		(option	MAXDOP de la commande SQL ALTER INDEX). Une fois accomplie, cette tâche est à nouveau activable pour la	défragmentation d’un autre index. 
		Vérifiez quand même dans l’historique que cette tâche se déroule régulièrement et si ce n’est pas le cas, abaissez encore les seuils.
*/
-- On peut exécuter un Job sans passer par la planification
	msdb.dbo.sp_start_job 
-- Ajouter une planification à un travail
	msdb.dbo.sp_add_jobschedule	--@jobId : identifiant du job
/*
	On peut récupéer les erreurs journalisées dans le fichier des événements de Windows. Cela arrive pour les erreurs :
		- d'un niveau supérieur à 19.
		- spécifiquement journalisée : RAISERROR ... WITH LOG
*/	
	select * from sys.messages where language_id=1036 and message_id in (1105, 9002)
-- Liste des bases de données avec l'espace qu'occupent leurs LOG
	DBCC SQLPERF(LOGSPACE)
/*
	On peu declencher une alerte sur les performances de SQL Server. Ici lorsque le log atteint 70% de sa value max (parametré) alors on dfait une sauvegarde (.trn)
	Général : Objet : "SQLServer:Databases", compteur : "Percent Log Used", Instance : "BOU_EFORCE", Alerte si le compteur "s'élève au-dessus", valeur : "70"
	Réponse: Exécuter le travail : BACKUP LOG DB_SQLPRO TO DISK = 'C:\DATABASE\SAVE\DB_SQLPRO.trn';
*/
-- liste des sous systèmes de SQL SERVER
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
