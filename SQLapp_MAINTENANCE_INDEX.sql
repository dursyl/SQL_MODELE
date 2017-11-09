--------------------------------MAINTENANCE INDEX
-------Toutes les données graves sont inscrites dans le journal (codes d'erreur 823 et 824 - codes erreurs renvoyés par WINDOWS parce que c'est lui qui gere les lectures/ecritures)
/*
	Les index se fragmentent parce que lors d'une insertion on split les pages. Ca se produit aux feuilles de l'arbre mais aussi à des niveaux supérieurs.
*/
-- RANDOM de characteres répliqués
	SELECT REPLICATE(CHAR(CAST(FLOOR((RAND() * 223) + 32) AS INT)), 780)
/* Mesure de contiguïté des données
	Liste des index, le nbre de pages, le nombre de données par etage de l'arbre B, densité de l'index sur les pages.
	AverageFreeBytes donne l'espace libre par page. Plus AveragePagesDensity est élevé et moins l'index est fragmenté
	Plus LogicalFragmentation est élevé plus l'index est fragmenté
	Moins l'index a de pages et plus il est rapide à parcourir (en prenant en compte chaque noeuds de l'arbre (level)
*/
	DBCC SHOWCONTIG('FACT') WITH TABLERESULTS, ALL_INDEXES, ALL_LEVELS;
-- Si un index est peu dense (AverageFreeBytes elevé) alors il faut reconstruire l'index. Reconstruction de l'index:
	DBCC DBREINDEX ('LIGFACT');
-- Les lignes supprimées ne libere pas de place sur les pages (les slots restent vides - ghost record).
-- Liste des pages d'index d'une table:
	DBCC IND ('RAN_ATOFFICE', 'FACT', 9); -- '-1' tous les index, on peut mettre le numéro de l'index
-- Visualisation du contenu d'une page à partir d PageFID et de PageID
	DBCC PAGE ('RAN_ATOFFICE', 1, 699445, 1) WITH TABLERESULTS; 
	DBCC PAGE ('RAN_ATOFFICE', 1, 694461, 3) WITH TABLERESULTS; -- avec colonnes contenant les valeurs des INDEX et les identifiants de la table
/*
	sys.dm_db_index_physical_stats remplace SHOWCONTIG
*/
	SELECT * FROM sys.dm_db_index_physical_stats(DB_ID('RAN_ATOFFICE'),NULL, NULL, NULL, 'DETAILED'); --DETAILED plus long, LIMITED renvoie un échantillon
-- Filtre sur une table (OBJECT_ID) et un index de cette table (INDEX_ID)
	SELECT * FROM sys.dm_db_index_physical_stats(DB_ID('RAN_ATOFFICE'),NULL, NULL, NULL, 'DETAILED') where OBJECT_ID=OBJECT_ID('FACT') and index_id=9;
-- Etat des index dans la base avec liaison avec métadonnées pour avoir des noms d'objets explicites
	SELECT s.name AS TABLE_SCHEMA, o.name AS TABLE_NAME, i.name AS INDEX_NAME, i.type_desc AS INDEX_TYPE, alloc_unit_type_desc AS ALLOC_UNIT_TYPE,
		avg_fragmentation_in_percent AS FRAG_PC, page_count AS PAGES, ips.object_id as table_id, ips.index_id 
	FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) AS ips
	INNER JOIN sys.objects AS o ON ips.object_id = o.object_id 
	INNER JOIN sys.schemas AS s On o.schema_id = s.schema_id
	LEFT OUTER JOIN sys.indexes AS i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
	--where ips.index_id=1 order by TABLE_NAME

/*
	Reconstruire l'index, remplace DBREINDEX.
	Il est recommandé de reconstruire l'index si la fragmentation est supérieur à 30%.
	Il est recommandé de réorganiser l'index si la fragmentation est entre 10 et 30%.
	Une defragmentation inférieur à 10% est normale. Si l'index a peu de pages alors la fragmentation importante est normale.
*/
	ALTER INDEX ALL ON RAN_ATOFFICE.dbo.ACTEUR REBUILD;
-- recontruire un index spécifique de la table
	ALTER INDEX I_TOURNEE ON RAN_ATOFFICE.dbo.TOURNEE REBUILD;
-- reconstruire un index partitionné
	ALTER INDEX I_TOURNEE ON RAN_ATOFFICE.dbo.TOURNEE REBUILD PARTITION = 1;
-- réorganiser un index - la réorganisation ne travaille que sur les feuilles
	ALTER INDEX X_CHG_DATE_DVS1_DVS2 ON S_ITF.T_E_CHANGE_CHG REORGANIZE;
-- Requête qui donne le TRNSACT-SQL ddes rebuild et reorganize des index de la base en fonction de leursfragmentation, du type de données, etc.
	--VOIR SQLapp_Req_ConseilIndexRebuild.sql
-- FILLFACTOR (facteur de remplissage des pages d'index) - On considere qu'il faut qu'il soit entre 80 et 90
/*
	Dans l'idéal il faut defragmenter tous les jours (si on dispose d'heures creuses).
	Il faut faire des estimation de fragmentation en mode DETAILED chaque semaine. Parce qu'on peut passer à côté d'une défragmentation lorsqu'une distribution est anormale.
	Pour de tres grandes bases on peut faire des défragmentations limitées aux index les plus fragmentés ou les plus utilisés. Pour cela il faut combiner
		avec sys.dm_db_index_usage_stats (ces stats démarre au demarrage de l'instance alors il faut calculer la différence de nombres de lectures/écritures par laps de temps.
	VOIR COMMENT CA MARCHE : select object_name(object_id),* from sys.dm_db_index_usage_stats
*/
/*
	STATISTIQUES
	On peut mettre votre base en AUTO_UPDATE_STATISTICS mais la MAJ peut se déclencher n'importe quand (quand l'optimiseur n'a plus confiance en ses statistiques)
	Il vaut mieux être proactif pour la MAJ des statistiques.
	On peut mettre la base en mode AUTO_UPDATE_STATISTICS_ASYNC mais il vaut mieux quand même prévoir un recalcul des stats aux heures creuses.
*/
-- MAJ des stats
	UPDATE STATISTICS RAN_ATOFFICE.dbo.ACTEUR WITH FULLSCAN;
	UPDATE STATISTICS RAN_ATOFFICE.dbo.FACT WITH COLUMNS, SAMPLE 25 PERCENT; -- COLUMNS: MAJ des stats colonnes uniquement, SAMPLE: MAJ à partir d'un échantillon de 25% de la table
	UPDATE STATISTICS RAN_ATOFFICE.dbo.ACTEUR WITH INDEX, NORECOMPUTE; -- INDEX: MAJ des stats sur les index uniquement, NORECOMPUTE: MAJ ne sera pas refaite lors d'un AUTO_STATISTICS_UPDATE
-- Afficher le parametrage de MAJ des stats auto
	EXEC sp_autostats 'dbo.FACT';
-- Activation du recalcul auto des stats pour l'index I_CDCLIENT de la table FACT
	EXEC sp_autostats @tblname = 'dbo.FACT', @flagc = 'ON', @indname = 'I_CDCLIENT';	
-- MAJ des stats sur tous les objets de la BDD
	EXEC sp_updatestats 'resample'; -- 'FULL', 'SAMPLE'
-- Date de la dernière MAJ des stats pour chaque index, colonne. On peut décider de faire des MAJ à partir du résultat
	SELECT sc.name AS TABLE_SCHEMA, o.name AS TABLE_NAME, s.name AS STATS_NAME, CASE WHEN index_id IS NULL THEN 'COLUMN' ELSE 'INDEX' END AS STATS_TYPE,
		STATS_DATE(s.object_id, s.stats_id) AS STATS_LAST_UPDATE, auto_created, user_created, no_recompute
	FROM sys.stats AS s
	LEFT OUTER JOIN sys.indexes AS i ON s.object_id = i.object_id AND s.name = i.name
	INNER JOIN sys.objects AS o ON s.object_id = o.object_id
	INNER JOIN sys.schemas AS sc ON o.schema_id = sc.schema_id;
-- Infos à propos des statistiques 
	SELECT sc.name AS TABLE_SCHEMA, o.name AS TABLE_NAME, s.name AS STAT_OR_INDEX_NAME, 
		CASE WHEN i.name IS NULL THEN 'statistiques' ELSE 'index' END AS OBJECT_TYPE, last_updated, rows, rows_sampled, steps, unfiltered_rows, modification_counter
	FROM sys.stats AS s
	CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS p
	INNER JOIN sys.objects AS o ON s.object_id = o.object_id
	INNER JOIN sys.schemas AS sc ON o.schema_id = sc.schema_id
	LEFT OUTER JOIN sys.indexes AS i ON s.object_id = i.object_id AND s.name=i.name;
-- Index candidats au recalcul p.878
	SELECT sc.name AS TABLE_SCHEMA, o.name AS TABLE_NAME, s.name AS STAT_NAME, last_updated, rows, modification_counter, (1.0 * modification_counter / rows) * 100 AS PERCENT_MODIFIED
	FROM sys.stats AS s 
	CROSS APPLY sys.dm_db_stats_properties(s.object_id,s.stats_id) AS p
	INNER JOIN sys.objects AS o ON s.object_id = o.object_id
	INNER JOIN sys.schemas AS sc ON o.schema_id = sc.schema_id
	WHERE o."type" IN ('U', 'V') AND CASE WHEN modification_counter = 0 THEN 0 WHEN rows < 300 AND (1.0 * modification_counter / rows) * 100 > 1 THEN 1 WHEN rows > 100000
	AND (1.0 * modification_counter / rows) * 100 > 16 THEN 1 WHEN (1.0 * modification_counter / rows) * 100 > (SQUARE(LOG((rows/1000.0) + 1) + 2) / 8) THEN 1 ELSE 0 END = 1;
	
-- On peut mettre en place une table dans msdb qui receuille les nombre d'index MAJ par jour et alimente cette table
	--SQLapp_Req_ConseilIndexRebuild.sql
/*
	SQL Server declenche le calcul des stats quand le nbre de modifs dépasse 20%. Cela peut être bcp trop élevé pour de très grandes tables.
	Il convient de déclencher un recalcul plus fréquemment manuellement ou activer un drapeau de trace particulier (DBCC TRACEON 2371).
	L'inconveniant est que ce drapeau s'applique au niveau server.
	Les stats sont recalculées lorsqu'un index est reconstruit. Les stats doivent recalculées tous les jours comme les index (si AUTO_UPDATE_STATISTICS=OFF)
	En mode synchrone la MAJ des stats intervient entre le calcul du plan de requête et l'exécution du plan (ça allonge la requête).
	En mode asynchrone c'est une tâche de fonds qui recalcule les stats indépendement des besoins.
	On peut reclaculer les stats dans la journée à partir d'un échantillon (WITH SAMPLE) et le faire en mode FULLSCAN en heures creuses.
	Dans le cas de grandes tables SQL Server ne prends en compte que des échantillons (35% pour 1 millions de lignes, 4% pour 10 millions)
*/


	
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
