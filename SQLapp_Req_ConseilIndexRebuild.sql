WITH
TX AS
(
SELECT s.name AS TABLE_SCHEMA, o.name AS TABLE_NAME,
       i.name AS INDEX_NAME, o.object_id, i.index_id,
-- La table a-t-elle un LOB ?
       CASE
          WHEN EXISTS(SELECT *
                      FROM   sys.columns AS c
                             INNER JOIN sys.types AS t
                                   ON c.system_type_id = t.system_type_id
                      WHERE  object_id = o.object_id
                        AND  (t.name IN ('image',
                                         'text',
                                         'sql_variant',
                                         'ntext',
                                         'geometry',
                                         'geography', 
										 'xml')
                             OR c.max_length = -1))
             THEN 1
          ELSE 0
       END AS TABLE_HAS_LOB,
-- L’index a-t-il un LOB ?
       CASE
          WHEN EXISTS(SELECT *
                      FROM   sys.index_columns AS ic
                             INNER JOIN sys.columns AS c
                                   ON ic.object_id = c.object_id
                                      AND ic.column_id = c.column_id
                             INNER JOIN sys.types AS t
                                   ON c.system_type_id = t.system_type_id
                      WHERE  ic.object_id = i.object_id
                        AND  ic.index_id = i.index_id
                        AND  (t.name IN ('image',
                                         'text',
                                         'sql_variant',
                                         'ntext',
                                         'geometry',
                                         'geography', 
										 'xml')
                              OR c.max_length = -1))
             THEN 1
          ELSE 0
       END AS INDEX_HAS_LOB,
-- La table a-t-elle un index COLUMNSTORE ?
       CASE WHEN EXISTS(SELECT *
                        FROM   sys.indexes AS x
                        WHERE  x.object_id = o.object_id
                          AND  x.type_desc LIKE '%COLUMNSTORE%')
               THEN 1
            ELSE 0
       END AS TABLE_HAS_COLUMNSTORE
FROM   sys.objects AS o
       INNER JOIN sys.schemas AS s
             ON o.schema_id = s.schema_id
       INNER JOIN sys.indexes AS i
             ON o.object_id = i.object_id
WHERE  o."type" IN ('U', 'V')
  AND  i.name IS NOT NULL
),
TF AS
(
SELECT TABLE_SCHEMA, TABLE_NAME, INDEX_NAME,
-- Choix de la méthode en fonction de la fragmentation et du nombre de pages
       CASE WHEN avg_fragmentation_in_percent > 30 OR page_count <= 8
               THEN 'REBUILD'
            ELSE 'REORGANIZE'
       END AS METHOD,
-- ONLINE ou pas en fonction des LOB, de la nature de l’index,
-- de l’édition et de la présence d’un index COLUMNSTORE
       CASE WHEN LEFT(CAST(SERVERPROPERTY('edition')AS NVARCHAR(256)), 9) IN ('Enterpris', 'Developer') 
	             AND x.index_id > 1 AND INDEX_HAS_LOB = 0 AND TABLE_HAS_COLUMNSTORE = 0
               THEN 'ONLINE'
            WHEN LEFT(CAST(SERVERPROPERTY('edition')AS NVARCHAR(256)), 9) IN ('Enterpris', 'Developer') 
                 AND x.index_id = 1 AND TABLE_HAS_LOB = 0 AND TABLE_HAS_COLUMNSTORE = 0
               THEN 'ONLINE'
            ELSE 'OFFLINE'
       END AS LINE
FROM   sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) AS ips
       INNER JOIN TX AS x
             ON ips.object_id = x.object_id
                AND ips.index_id = x.index_id
WHERE  avg_fragmentation_in_percent > 10 OR page_count BETWEEN 1 AND 8
)
-- Construction de la commande SQL de défragmentation
SELECT 'ALTER INDEX [' + INDEX_NAME + '] ON ['
       + TABLE_SCHEMA + '].[' + TABLE_NAME +'] '
       + METHOD
       + CASE WHEN LINE = 'ONLINE' AND METHOD = 'REBUILD'
                 THEN ' WITH (ONLINE = ON);'
              ELSE ';'
         END AS SQL_COMMANDE
FROM   TF;

-- NOTA : nous avons amélioré cette requête en remplaçant :
--   "CAST(SERVERPROPERTY ('edition') AS NVARCHAR(256)) LIKE 'Enterprise%'" 
-- par 
--   "LEFT(CAST(SERVERPROPERTY('edition')AS NVARCHAR(256)), 9) IN ('Enterpris', 'Developer')" 
-- afin que l'option ONLINE soit pris en compate aussi pour la version developper.