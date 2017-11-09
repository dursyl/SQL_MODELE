/*
	PERFORMANCE SQL
*/
/*
	On peut utiliser SQL Profiler pour collecter, dans un fichier ou une table, une charge de travail qu'on rejoue sur un serveur de test de charge.
	SQL Profiler utilise SQL Trace, qui permet d'auditer toutes les ressources utilis�es par un proc�dure stock�e et collecter �galement toutes 
		les valeurs de parametres pass�s � celle-ci. Mais aussi les connexions �chou�s, les verrous mortels, etc.
	SQL Trace est obsolete, il peut �tre supprim� d�s la version 2016. Il est remplac� par les �v�nements �tendus.
	Il ne faut pas ex�cuter Profiler sur un serveur en production, �a consomme trop.
	Il est recommand� d'enregistrer les traces dans un fichier puis de charger ce fichier dans une table � l'aide de sys.fn_trace_gettable(). 
	C'est bien d'utiliser "Enable trace stop time" pour stopper la trace automatiquement.
*/

/*
	RPC:Completed, P:StmtCompleted -> collecte les appels � des proc�dures stock�es
	SQL:BatchCompleted -> Signifie la fin de l'ex�cution d'un lot de requ�tes, donne la consommation de ressources effectu�e.
*/
-- Trace en cours. Attention la trace id=1 est une trace interne, il ne faut pas y toucher.
	select * from sys.traces
-- Arreter la trace. (0 arr�te la trace, 1 d�marre la trace, 2 ferme la trace et supprime sa d�finition du serveur)
	EXEC sys.sp_trace_setstatus 2,0 -- identifiant de la trace, �tat de la trace.
/*
	Verrous mortels. Erreur 1205
	On peut cr�er des traces du cot� du serveur pour r�cuperer les dead lock.
*/
	select * from sys.sysmessages where msglangid=1036 and error=1205
-- Liste des proc�dure stock�es relatives aux traces
	SELECT S.name + '.' + O.name AS object_name, O.type_desc FROM sys.all_objects AS O INNER JOIN sys.schemas AS S ON O.schema_id = S.schema_id
		WHERE O.name LIKE '%?_trace?_%' ESCAPE '?' ORDER BY O.type_desc, O.name
-- cr�er une trace
	declare @TraceID int
	declare @rc int
	declare @maxfilesize bigint
	set @maxfilesize = 5 
	exec @rc = sp_trace_create @TraceID output, 0, N'C:\Users\sdurand\Desktop\test_deadlock.trc', @maxfilesize, NULL -- @TraceID: Id renvoy� par la procedure, 5:MaxFileSize
	print @rc
	print @TraceID
	if (@rc != 0) goto error
	exec sp_trace_setevent @TraceID, 148, 11, 1 -- 148: evenement, num�ro de colonne, 1: captur�e la colonne (changeable en cours d'ex�cution)
	exec sp_trace_setevent @TraceID, 148, 12, 1
	exec sp_trace_setstatus @TraceID, 1				-- 1 d�marre la trace
	goto finish
	error: 
	select ErrorCode=@rc
	finish: 
	go
/*
	On a 9 �v�nements qu'on peut capturer (82-91) qu'on peut s�lectionner dans Profiler (UserConfigurable0-UserConfigurable9)
	On d�clenche ces �v�nements en ex�cutant la proc�dure sys.sp_trace_generateevent
	On peut mettre cette ligne dans un proc�dure stock�e et ne choisir que de ne capturer que UserConfigurable0. Comme �a on a une capture personnaliser � 1 proc�dure.
*/
	exec sys.sp_trace_generateevent 82, N'etetet'

-- D�finition d'une trace
	DECLARE @trace_id int = 1
	SELECT CG.name AS category_name, E.name AS event_name,EI.eventid, EI.columnid, C.name AS column_name,C.type_name AS column_data_type
		, CASE FI.logical_operator WHEN 0 THEN 'AND' ELSE 'OR' END AS logical_operator
		, CASE FI.comparison_operator WHEN 0 THEN '=' WHEN 1 THEN '<>' WHEN 2 THEN '>' WHEN 3 THEN '<' WHEN 4 THEN '>=' WHEN 5 THEN '<=' WHEN 6 THEN 'LIKE' WHEN 7 THEN 'NOT LIKE' END AS comparison_operator
		, FI.value AS filter_value, R.host_name, R.login_name
	FROM sys.fn_trace_geteventinfo(@trace_id) AS EI	INNER JOIN sys.trace_events AS E ON EI.eventid = E.trace_event_id
	INNER JOIN sys.trace_categories AS CG ON E.category_id = CG.category_id	INNER JOIN sys.trace_columns AS C ON EI.columnid = C.trace_column_id
	LEFT JOIN sys.fn_trace_getfilterinfo(@trace_id) AS FI ON FI.columnid=EI.columnid AND FI.columnid = C.trace_column_id
	OUTER APPLY (SELECT S.host_name, S.login_name FROM sys.traces AS T INNER JOIN sys.dm_exec_sessions AS S ON T.reader_spid = S.session_id) AS R
	ORDER BY E.trace_event_id

-- Connaitre la liste des tous les �v�nements
	SELECT EC.trace_event_id, CG.name AS category_name, E.name AS event_name, C.name AS column_name, EC.trace_column_id
		, 'EXEC sys.sp_trace_setevent @trace_id, '+ CAST(EC.trace_event_id AS VARCHAR(10))+', '+ CAST(EC.trace_column_id AS VARCHAR(10))+', @on --'+ E.name + ' => ' + C.name AS SQLTrace_sp_call
	FROM sys.trace_event_bindings AS EC INNER JOIN sys.trace_events AS E ON EC.trace_event_id=E.trace_event_id
	INNER JOIN sys.trace_categories AS CG ON E.category_id = CG.category_id INNER JOIN sys.trace_columns AS C ON EC.trace_column_id = C.trace_column_id
	ORDER BY category_name, event_name, column_name

--
	select * FROM sys.fn_trace_gettable('C:\TestCongfigurable.trc', DEFAULT) -- DEFAULT: si on a parametr� la cr�ation de fichier de taille identique lors de l'ex�cution de la trace alors on met le num�ro de fichier.


------------------------------------------------------------------------------

SELECT * FROM sys.dm_os_performance_counters


select * from sys.messages where language_id=1036 and message_id=8992 and severity=12
select * from sys.syslanguages

	select * from msdb.dbo.suspect_pages
	select * from sys.databases

	DBCC PAGE ('NEO_ATOFFICE', 2, 2330, 3) WITH TABLERESULTS;


select OBJECT_NAME(1029578706)
select OBJECT_ID('USR')
select * from BOU_EFORCE.dbo.PORT
SELECT DISTINCT OBJECT_NAME(5),OBJECT_NAME(6),OBJECT_NAME(7),OBJECT_NAME(8) FROM RAN_ATOFFICE.dbo.USR
