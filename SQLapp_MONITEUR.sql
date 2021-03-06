/*
	MONITEUR d'ACTIVITE
*/
/*
	Cliquer droit sur l'instance dans SSMS et choisir "Moniteur d'activité" (Ctrl + Alt +A).
		Cette interface permet de diagnostiquer la source de problème de performance.
		Mais il faut utiliser d'autres outils pour que le problème soit confirmé (examen de plan de requêtes, SQL Sentry Plan Explorer, vues DMV)
		On peut sauvé un plan de requête.
		Fermer le moniteur quand on a fini parce qu'il consomme des ressources (par le biais de vues DMV) et stocke les résultats dans tempDB.
		On peut regler la frequence de raifraichissement des informations (clqiue droit dans une zone neutre).
		En survolant les colonnes il y a une infobulle qui s'affiche. On peut y voir le noùm de la requête d'où l'info est issue.
*/
/*
	Processus:
		Click droit et "détails" sur une ligne -> on peut terminer le processus.
		Click droit et "détails" sur une ligne -> on peut lancer des traces sur le processus (@@SPID).
*/
/*
	Attentes de retour (Resource Wait)
		permet de visualiser les ressources attendues par les threads d’un processus pour pouvoir s’exécuter : il peut s’agir de l’acquisition d’un verrou, de l’import de pages qui ne sont pas
			dans le cache de données depuis les disques…	
*/
/*
	Onglet Data File I/O (E/S du fichier de données)
		Si vous pensez qu’une base de données subit des problèmes de performance liés à un nombre important d’accès disques, vous pourrez le vérifier à l’aide de cet onglet.
		Chaque ligne correspond à un fichier de données (les fichiers du journal des transactions de chaque base de données ne sont donc pas exposés ici)
*/
/*
	Onglet Recent Expensive Queries
		liste des requêtes récemment exécutées et étant les plus coûteuses, c’est-à-dire celles qui sont toujours dans le cache des procédures.
		Colonnes : 
			le nombre d’exécutions par seconde
			, le temps CPU consommé
			, lenombre de lectures physiques effectuées par la requête (nombre de pages importées par lecture directe des disques du fait qu’elles n’étaient pas disponibles dans le cache de données)
			, le nombre de lectures logiques (nombre de lectures de pages effectuées directement à partir du cache de données)
			, la durée moyenne d’exécution de ladite requête, le nombre de plans que la requête a généré dans le cache de plans et la base de données dans laquelle la requête s’est exécutée.
		Une valeur élevée pour l’un de ces compteurs, excepté le nombre d’exécutions par seconde, indique un problème potentiel. 
		Une analyse du plan d’exécution de ladite requête le révélera probablement. 
		Pour obtenir ce plan, effectuez un clic droit sur la requête suspectée et choisissez l’option Montrer le plan d’exécution(Show Execution Plan).
*/
	select * from sys.dm_os_wait_stats

