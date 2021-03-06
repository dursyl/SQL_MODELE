/*
	HAUTE DISPONIBILITE

	RTO (Recovery Time Objective) : Temps d'indispo maximal
	RPO (Recovery Point Objective): Quantité maximale perdu tolérée
	PRA : Plan de reprise d'activité
	SLA : Service Level Agreement
		dispo de 99%		-> 3.65 jours par an
		dispo de 99,9%		-> 8.76 h par an		(Le plus réaliste)
		dispo de 99,99%		-> 53 minutes par an
		dispo de 99.9999%	-> 31.5 s par an
*/
/*
	RAID
		RAID 0 : Decoupe des fichiers pour les repartir que les disques. Pas de sécurité (pas de miroir des données).
		RAID 1 : Fonctionne pas pair de disques, les disques doublonnent. Le système est capable de lire sur le disque qui offre la meilleur performance.
		RAID 5 : Decoupe les fichiers pour les répartir sur tous les disques et copie chaque répartion du fichier sur un des disque en doublon. 
			Plus long parce qu'il faut ecrire sur tous les disques a chaque ecriture mais plus rapide en écriture parce que le système lit sur tous les disques en parallèle.
			Ne supporte pas la défaillance sur deux disques en même temps.
		RAID 0+1 : découpe les fichiers pour les répartir sur les disques, comme RAID 0, puis double les disques comme RAID 1. 
			Interressant parce que les sytème travaille en paralèlle et permet une redondance pour la sécurité.
*/

/*	
	TECHNIQUE
		Log-shipping
			Basculement auto: Non
			Perte de données: Oui (transacations non récuperées)
			Lecture des réplicas : Oui en mode stanby
			Utile pour la lecture seule 
			Mise à jour des serveurs secondaires grace au journaux de transactions.
			Generre des journaux de transactions (atention à la place sur le DD)
		mirroring : seulement deux serveur (plus un serveur témoin, pas obligatoire)
			Basculement auto: Oui
			Perte de données: Oui en mode Haute sécurité / Non en mode Haute performance
			Lecture des réplicas : oui
			Réparation auto des pages, support de basculement (auto possible si il y aun temoin), plusieurs mode de réplication.
			3 modes de d'opération: 
				Haute sécurité avec basculement auto		: Synchro
				Haute sécurité sans basculement automatique : Synchro
				Haute performance							: Asynchrone, pas de basculement auto
			Il faut modifier la chaine de connexion du côté client si on veut que le basculement automatique fonctionne.
				(Server=Partner_A; Failover Partner=Partner_B; Database=RAN_ATOFFICE;Network=dbmssocn)
		Cluster de basculement (FCI)
			Basculement auto: Oui
			Perte de données: Non
			Lecture des réplicas : Non
			Concerne toute l'instance
			FCI pour Failover Cluster Instance - exploite la fonctionnalité  de cluster à basculement Windows Server (WSFC)
		Groupes de disponibilité
			Basculement auto: Oui		
			Perte de données: Non
			Lecture des réplicas : Oui
			AlwaysOn
			Peut Faire basculer simultanement un ensemble de bases.
			Ils s'appuient sur une couche cluster à basculement Windows
			On peut utiliser les serveurs secondaires en lecture seule et en tant que sauvegarde
		REPLICATION
			Bascule manuelle possible.
			Notion de publicateur et d'abonnés.
			La réplication transactionelle est le type de réplication le plus souvent utilisée.
			Il existe aussi la réplication: réplication transactionnelle bidirectionelle, fusion, peer to peer.
			Nécessite une clé primaire sur chaque table
*/

---------------------------------------------------------MIRORING--------------------------
/*
	MISE EN PAUSE d'une session MIROIR
		Attention, une pause trop longue fait gonfler l'expansion du journal
		Les transactions non répliquées sont stockées dans une file d'attente : send queue
		Surveiller l'état et les performance d'un miroir: moniteur de bases de données en miroir (Database Mirroring Monitor)
			
*/
-- Mettre en pause un miroir (pour faire une grosse MAJ, éviter le basculement)
	ALTER DATABASE 'RAN_ATOFFICE' SET PARTNER SUSPEND
-- Redemarrer un miroir
	ALTER DATABASE 'RAN_ATOFFICE' SET PARTNER RESUME
-----------------------------------------------------------------------------------



p.313
