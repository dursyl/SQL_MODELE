/*
il est possible de les calculer en stockant r�guli�rement le
nombre de mises � jours effectu�es sur chaque index. L�exemple 17-49 montre une table cr��e dans msdb
pour stocker les m�triques d�utilisation des index, la requ�te � ex�cuter une fois par jour pour alimenter
cette table et la requ�te qui extrait le taux de mise � jour de ces index sur une p�riode de 24 heures.
Exemple 17-49. Calcul du nombre de mises � jour effectu�es en 24 h sur les index du serveur
*/

--> Pr�alable 
-- USE msdb;

-- la table qui recueille les statistiques d'utilisation des index
CREATE TABLE msdb.dbo.sys_dm_db_index_write_stats
(id            BIGINT IDENTITY PRIMARY KEY,
 date_usage    DATE   NOT NULL,
 database_id   SMALLINT NOT NULL,
 object_id     INT NOT NULL,
 index_id      INT NOT NULL,
 updates       BIGINT NOT NULL);
GO

-- la requ�te qui ins�re chaque jour les statistiques d'utilisation des index
INSERT INTO msdb.dbo.sys_dm_db_index_write_stats
SELECT CAST(GETDATE() AS DATE) AS date_usage,
       database_id, object_id, index_id,
       user_updates + system_updates AS updates
FROM   sys.dm_db_index_usage_stats;
GO

-- la requ�te quirenvoie le delta de mise � jour sur 24 h
WITH
T_ALL AS
(
SELECT database_id, object_id, index_id,
       MAX(date_usage) AS LAST_UPDATES
FROM   msdb.dbo.sys_dm_db_index_write_stats
GROUP  BY database_id, object_id, index_id
)
SELECT T.database_id,
       T.object_id,
       T.index_id,
       COALESCE(T0.updates, 0) - COALESCE(T1.updates, 0) AS DELTA_UPDATE_24H
FROM   T_ALL AS T
       LEFT OUTER JOIN msdb.dbo.sys_dm_db_index_write_stats AS T0
            ON T.database_id = T0.database_id
               AND T.object_id = T0.object_id
               AND T.index_id = T0.index_id
               AND T0.date_usage = T.LAST_UPDATES
       LEFT OUTER JOIN msdb.dbo.sys_dm_db_index_write_stats AS T1
            ON T.database_id = T1.database_id
               AND T.object_id = T1.object_id
               AND T.index_id = T1.index_id
               AND T1.date_usage = DATEADD(day, -1, LAST_UPDATES);;