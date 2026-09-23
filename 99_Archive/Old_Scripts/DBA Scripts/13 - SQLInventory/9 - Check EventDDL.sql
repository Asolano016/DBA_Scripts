SELECT TOP (1000) [EventDate]
      ,[EventDateUTC]
      ,[EventType]
      ,[EventDDL]
      ,[DatabaseName]
      --,[SchemaName]
      ,[ObjectName]
      ,[HostName]
      --,[IPAddress]
      ,[ProgramName]
      ,[LoginName]
      --,[EventID]
      --,[Flag]
FROM [Admin].[dbo].[DDLEvents]
WHERE [ObjectName] = 'PHX-DC\GS_PHXAMHGDEV$'
--WHERE EventDDL LIKE '%GS_PHXAMHGDEV%'
ORDER BY EventDate DESC
