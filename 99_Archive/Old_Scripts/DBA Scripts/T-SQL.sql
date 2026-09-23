USE [SQLInventory]
GO

-- =============================================
-- GenAI DBA - Deployment Script
-- Author:    Andres Solano Alpizar
-- Date:      14/05/2026
-- Changes:   - Added [Guidance] column to [AI].[tGenAIDBACheck]
--            - Recreated [AI].[udttGenAIDBACheck] with [Guidance] column
--            - Updated [AI].[sp_MergeGenAIDBACheck] with [Guidance] column
--            - CREATE OR ALTER applied to all stored procedures (idempotent)
-- Note:      Safe to run on existing environments. All steps are idempotent.
-- =============================================

PRINT '======================================================'
PRINT ' GenAI DBA - Deployment Script'
PRINT ' Starting deployment...'
PRINT '======================================================'
GO

-- =============================================
-- STEP 1: Add [Guidance] column to [AI].[tGenAIDBACheck] if it does not exist
-- =============================================
IF NOT EXISTS (
    SELECT 1 FROM sys.columns 
    WHERE object_id = OBJECT_ID('[AI].[tGenAIDBACheck]') 
    AND name = 'Guidance'
)
BEGIN
    ALTER TABLE [AI].[tGenAIDBACheck] ADD [Guidance] [nvarchar](max) NULL;
    PRINT 'STEP 1: Column [Guidance] added to [AI].[tGenAIDBACheck].'
END
ELSE
    PRINT 'STEP 1: Column [Guidance] already exists in [AI].[tGenAIDBACheck] - skipped.'
GO

-- =============================================
-- STEP 2: Create [AI].[tGenAIDBACheck] if it does not exist
-- =============================================
IF OBJECT_ID('[AI].[tGenAIDBACheck]', 'U') IS NULL
BEGIN
    CREATE TABLE [AI].[tGenAIDBACheck](
        [CheckId]        [int] IDENTITY(1,1) NOT NULL,
        [IncidentNumber] [varchar](15) NULL,
        [GenAIResponse]  [varchar](max) NULL,
        [Service]        [varchar](125) NULL,
        [InstanceList]   [varchar](max) NULL,
        [Type]           [varchar](50) NULL,
        [Category]       [varchar](50) NULL,
        [Summary]        [nvarchar](max) NULL,
        [Guidance]       [nvarchar](max) NULL,
        [RetryCount]     [int] NULL,
        [CheckResult]    [varchar](255) NULL,
        [ServiceCiUpdate][varchar](50) NULL,
        [IsFailed]       [bit] NULL,
        [CreateDate]     [datetime] NULL,
        [UpdateDate]     [datetime] NULL,
        PRIMARY KEY CLUSTERED ([CheckId] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
        ON [PRIMARY]
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
    PRINT 'STEP 2: Table [AI].[tGenAIDBACheck] created.'
END
ELSE
    PRINT 'STEP 2: Table [AI].[tGenAIDBACheck] already exists - skipped.'
GO

-- =============================================
-- STEP 3: Recreate [AI].[udttGenAIDBACheck] with [Guidance] column
--         Must drop [sp_MergeGenAIDBACheck] first (depends on the UDTT)
-- =============================================
IF OBJECT_ID('[AI].[sp_MergeGenAIDBACheck]', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE [AI].[sp_MergeGenAIDBACheck];
    PRINT 'STEP 3a: Procedure [AI].[sp_MergeGenAIDBACheck] dropped (will be recreated in STEP 5).'
END
GO

IF TYPE_ID('[AI].[udttGenAIDBACheck]') IS NOT NULL
BEGIN
    DROP TYPE [AI].[udttGenAIDBACheck];
    PRINT 'STEP 3b: Type [AI].[udttGenAIDBACheck] dropped.'
END
GO

CREATE TYPE [AI].[udttGenAIDBACheck] AS TABLE(
  [CheckId] [int] IDENTITY(1,1) NOT NULL,
  [IncidentNumber] [varchar](15) NULL,
  [GenAIResponse] [varchar](max) NULL,
  [Service] [varchar](125) NULL,
  [InstanceList] [varchar](max) NULL,
  [Type] [varchar](50) NULL,
  [Category] [varchar](50) NULL,
  [Summary] [nvarchar](max) NULL,
  [Guidance] [nvarchar](max) NULL,
  [RetryCount] [int] NULL,
  [CheckResult] [varchar](255) NULL,
  [ServiceCiUpdate] [varchar](50) NULL,
  [IsFailed] [bit] NULL,
  PRIMARY KEY CLUSTERED 
(
  [CheckId] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
PRINT 'STEP 3c: Type [AI].[udttGenAIDBACheck] created with [Guidance] column.'
GO

-- =============================================
-- STEP 4: Create [AI].[sp_GetInstanceByCI] (CREATE OR ALTER - idempotent)
-- =============================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:    Andres Solano Alpizar
-- Create date: 15/01/2025
-- Description: Check if CI exists in the SQL Inventory.
-- =============================================
CREATE OR ALTER PROCEDURE [AI].[sp_GetInstanceByCI]
    @GsnNumber VARCHAR(20) = '',
    @HostName VARCHAR(255) = ''
AS
BEGIN
    DECLARE @tResults TABLE (
        [InstanceID] INT,
        [InstanceName] VARCHAR(255),
        [HostName] VARCHAR(255),
    [InstanceConnection] VARCHAR(255),
    [ServiceName] VARCHAR(255),
        [GsnNumber] VARCHAR(20),
        [GsnName] VARCHAR(255),
    [GsnStatus] VARCHAR(20),
    [Status] VARCHAR(10),
    [Domain] VARCHAR(15)
    )

    -- First, try the query with @GsnNumer
    INSERT INTO @tResults
    SELECT i.[ID] AS 'InstanceID' 
        ,UPPER(i.[InstanceName]) AS 'InstanceName'
        ,UPPER(h.[HostName]) AS 'HostName'
    ,CASE 
      WHEN i.InstanceName LIKE '%\%' THEN REPLACE(InstanceName, '\', '.' + i.Domain + '\') + ', ' + TcpPort
      ELSE i.InstanceName + '.' + i.Domain + ', ' + TcpPort
     END InstanceConnection
    ,s.[ServiceName]
        ,i.[GsnNumber]
        ,i.[GsnName]
    ,i.[GsnStatus]
    ,hi.[Status]
    ,i.[Domain]
    FROM [dbo].[tInstances] i
    INNER JOIN [dbo].[tHostInstances] hi ON hi.InstanceID = i.ID
    INNER JOIN [dbo].[tHosts] h ON hi.HostID = h.HostID
  INNER JOIN [dbo].[tInstanceServices] si ON si.InstanceID = i.ID
  INNER JOIN [dbo].[tServices] s ON s.ServiceID = si.ServiceID
    WHERE [InProduction] IN (2, 8, 10, 13, 14)
    AND i.[GsnNumber] = @GsnNumber
  --AND hi.[Status] = 'Running'

    -- If no results, try the query with @HostName
    IF ((SELECT COUNT(*) FROM @tResults) = 0)
    BEGIN
        INSERT INTO @tResults
        SELECT i.[ID] AS 'InstanceID' 
            ,UPPER(i.[InstanceName]) AS 'InstanceName'
            ,UPPER(h.[HostName]) AS 'HostName'
      ,CASE 
        WHEN i.InstanceName LIKE '%\%' THEN REPLACE(InstanceName, '\', '.' + i.Domain + '\') + ', ' + TcpPort
        ELSE i.InstanceName + '.' + i.Domain + ', ' + TcpPort
       END InstanceConnection
            ,s.[ServiceName]
      ,i.[GsnNumber]
            ,i.[GsnName]
      ,i.[GsnStatus]
      ,hi.[Status]
      ,i.[Domain]
        FROM [dbo].[tInstances] i
        INNER JOIN [dbo].[tHostInstances] hi ON hi.InstanceID = i.ID
        INNER JOIN [dbo].[tHosts] h ON hi.HostID = h.HostID
    INNER JOIN [dbo].[tInstanceServices] si ON si.InstanceID = i.ID
    INNER JOIN [dbo].[tServices] s ON s.ServiceID = si.ServiceID
        WHERE [InProduction] IN (2, 8, 10, 13, 14)
        AND h.[HostName] = @HostName
    --AND hi.[Status] = 'Running'
    END

  -- If still no results, try the query with InstanceName = @HostName
  IF ((SELECT COUNT(*) FROM @tResults) = 0)
  BEGIN
    INSERT INTO @tResults
    SELECT i.[ID] AS 'InstanceID' 
      ,UPPER(i.[InstanceName]) AS 'InstanceName'
      ,UPPER(h.[HostName]) AS 'HostName'
      ,CASE 
        WHEN i.InstanceName LIKE '%\%' THEN REPLACE(InstanceName, '\', '.' + i.Domain + '\') + ', ' + TcpPort
        ELSE i.InstanceName + '.' + i.Domain + ', ' + TcpPort
       END InstanceConnection
      ,s.[ServiceName]
      ,i.[GsnNumber]
      ,i.[GsnName]
      ,i.[GsnStatus]
      ,hi.[Status]
      ,i.[Domain]
    FROM [dbo].[tInstances] i
    INNER JOIN [dbo].[tHostInstances] hi ON hi.InstanceID = i.ID
    INNER JOIN [dbo].[tHosts] h ON hi.HostID = h.HostID
    INNER JOIN [dbo].[tInstanceServices] si ON si.InstanceID = i.ID
    INNER JOIN [dbo].[tServices] s ON s.ServiceID = si.ServiceID
    WHERE [InProduction] IN (2, 8, 10, 13, 14)
    AND i.[InstanceName] = @HostName
    --AND hi.[Status] = 'Running'
  END

  -- If still no results, try the query with InstanceName like @HostName
  IF ((SELECT COUNT(*) FROM @tResults) = 0)
  BEGIN
    INSERT INTO @tResults
    SELECT i.[ID] AS 'InstanceID' 
      ,UPPER(i.[InstanceName]) AS 'InstanceName'
      ,UPPER(h.[HostName]) AS 'HostName'
      ,CASE 
        WHEN i.InstanceName LIKE '%\%' THEN REPLACE(InstanceName, '\', '.' + i.Domain + '\') + ', ' + TcpPort
        ELSE i.InstanceName + '.' + i.Domain + ', ' + TcpPort
       END InstanceConnection
      ,s.[ServiceName]
      ,i.[GsnNumber]
      ,i.[GsnName]
      ,i.[GsnStatus]
      ,hi.[Status]
      ,i.[Domain]
    FROM [dbo].[tInstances] i
    INNER JOIN [dbo].[tHostInstances] hi ON hi.InstanceID = i.ID
    INNER JOIN [dbo].[tHosts] h ON hi.HostID = h.HostID
    INNER JOIN [dbo].[tInstanceServices] si ON si.InstanceID = i.ID
    INNER JOIN [dbo].[tServices] s ON s.ServiceID = si.ServiceID
    WHERE [InProduction] IN (2, 8, 10, 13, 14)
    AND i.[InstanceName] LIKE '%' + @HostName + '%'
    --AND hi.[Status] = 'Running'
  END

    -- Return the results
    SELECT [InstanceID]
      ,[InstanceName]
      ,[HostName]
      ,[InstanceConnection]
      ,[ServiceName]
      ,[GsnNumber]
      ,[GsnName]
      ,[GsnStatus]
      ,[Status]
      ,[Domain]
  FROM @tResults
END
GO
PRINT 'STEP 4: Procedure [AI].[sp_GetInstanceByCI] created/updated.'
GO

-- =============================================
-- STEP 5: Create [AI].[sp_GetInstanceData] (CREATE OR ALTER - idempotent)
-- =============================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:    Andres Solano Alpizar
-- Create date: 26/12/2024
-- Description: Check if instance extracted by AI exists in the SQL Inventory
-- =============================================
CREATE OR ALTER PROCEDURE [AI].[sp_GetInstanceData]
    @ServerName VARCHAR(255) = ''
AS
BEGIN
    DECLARE @tResults TABLE (
    [InstanceID] INT,
    [InstanceName] VARCHAR(255),
    [HostName] VARCHAR(255),
    [InstanceConnection] VARCHAR(255),
    [ServiceName] VARCHAR(255),
    [GsnNumber] VARCHAR(20),
    [GsnName] VARCHAR(255),
    [GsnStatus] VARCHAR(20),
    [Status] VARCHAR(10),
    [Domain] VARCHAR(15)
  )

  -- First, try the query with @ServerName
  INSERT INTO @tResults
  SELECT i.[ID] AS 'InstanceID' 
    ,UPPER(i.[InstanceName]) AS 'InstanceName'
    ,UPPER(h.[HostName]) AS 'HostName'
    ,CASE 
      WHEN i.InstanceName LIKE '%\%' THEN REPLACE(InstanceName, '\', '.' + i.Domain + '\') + ', ' + TcpPort
      ELSE i.InstanceName + '.' + i.Domain + ', ' + TcpPort
     END InstanceConnection
    ,s.[ServiceName]
    ,i.[GsnNumber]
    ,i.[GsnName]
    ,i.[GsnStatus]
    ,hi.[Status]
    ,i.[Domain]
  FROM [dbo].[tInstances] i
  INNER JOIN [dbo].[tHostInstances] hi ON hi.InstanceID = i.ID
  INNER JOIN [dbo].[tHosts] h ON hi.HostID = h.HostID
  INNER JOIN [dbo].[tInstanceServices] si ON si.InstanceID = i.ID
  INNER JOIN [dbo].[tServices] s ON s.ServiceID = si.ServiceID
  WHERE i.[InstanceName] = @ServerName

  -- If no results, try the query with @ServerName
  IF ((SELECT COUNT(*) FROM @tResults) = 0)
  BEGIN
    INSERT INTO @tResults
    SELECT i.[ID] AS 'InstanceID' 
      ,UPPER(i.[InstanceName]) AS 'InstanceName'
      ,UPPER(h.[HostName]) AS 'HostName'
      ,CASE 
        WHEN i.InstanceName LIKE '%\%' THEN REPLACE(InstanceName, '\', '.' + i.Domain + '\') + ', ' + TcpPort
        ELSE i.InstanceName + '.' + i.Domain + ', ' + TcpPort
       END InstanceConnection
      ,s.[ServiceName]
      ,i.[GsnNumber]
      ,i.[GsnName]
      ,i.[GsnStatus]
      ,hi.[Status]
      ,i.[Domain]
    FROM [dbo].[tInstances] i
    INNER JOIN [dbo].[tHostInstances] hi ON hi.InstanceID = i.ID
    INNER JOIN [dbo].[tHosts] h ON hi.HostID = h.HostID
    INNER JOIN [dbo].[tInstanceServices] si ON si.InstanceID = i.ID
    INNER JOIN [dbo].[tServices] s ON s.ServiceID = si.ServiceID
    WHERE h.[HostName] = @ServerName
  END

  -- If still no results, try the query with Listener like @ServerName
  IF ((SELECT COUNT(*) FROM @tResults) = 0)
  BEGIN
    INSERT INTO @tResults
    SELECT i.[ID] AS 'InstanceID' 
        ,UPPER(i.[InstanceName]) AS 'InstanceName'
        ,UPPER(h.[HostName]) AS 'HostName'
        ,CASE 
          WHEN i.InstanceName LIKE '%\%' THEN REPLACE(InstanceName, '\', '.' + i.Domain + '\') + ', ' + TcpPort
          ELSE i.InstanceName + '.' + i.Domain + ', ' + TcpPort
         END InstanceConnection
        ,s.[ServiceName]
        ,i.[GsnNumber]
        ,i.[GsnName]
        ,i.[GsnStatus]
        ,hi.[Status]
        ,i.[Domain]
    FROM [dbo].[tAG] a
    INNER JOIN [dbo].[tAGReplica] ar ON ar.AvailabilityGroupID = a.AvailabilityGroupID
    INNER JOIN [dbo].[tInstances] i ON i.ID = ar.InstanceID
    INNER JOIN [dbo].[tHostInstances] hi ON hi.InstanceID = i.ID
    INNER JOIN [dbo].[tHosts] h ON hi.HostID = h.HostID
    INNER JOIN [dbo].[tInstanceServices] si ON si.InstanceID = i.ID
    INNER JOIN [dbo].[tServices] s ON s.ServiceID = si.ServiceID
    WHERE a.[ListenerName] = @ServerName
    AND ar.[Role] = 'PRIMARY'
  END

  -- Return the results
  SELECT DISTINCT TOP 1 [InstanceID]
      ,[InstanceName]
      ,[HostName]
      ,[InstanceConnection]
      ,[ServiceName]
      ,[GsnNumber]
      ,[GsnName]
      ,[GsnStatus]
      ,[Status]
      ,[Domain]
  FROM @tResults
  WHERE [Status] = 'Running'
END
GO
PRINT 'STEP 5: Procedure [AI].[sp_GetInstanceData] created/updated.'
GO

-- =============================================
-- STEP 6: Recreate [AI].[sp_MergeGenAIDBACheck] with [Guidance] column
--         (was dropped in STEP 3a before UDTT recreation)
-- =============================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:    Andres Solano Alpizar
-- Create date: 06/01/2025
-- Description: Merge GenAI DBA incident result check
-- =============================================
CREATE PROCEDURE [AI].[sp_MergeGenAIDBACheck] (@tTempGenAIDBACheck [AI].[udttGenAIDBACheck] READONLY)
AS
BEGIN
  --Merge into [AI].[tGenAIDBACheck]
  MERGE [AI].[tGenAIDBACheck] AS TARGET
  USING @tTempGenAIDBACheck AS SOURCE
  ON SOURCE.[IncidentNumber] = TARGET.[IncidentNumber]

  --UPDATE
  WHEN MATCHED
  AND TARGET.[GenAIResponse]   != SOURCE.[GenAIResponse]
  AND TARGET.[Service]     != SOURCE.[Service]
   OR TARGET.[InstanceList]  != SOURCE.[InstanceList]
   OR TARGET.[Type]      != SOURCE.[Type]
   OR TARGET.[Category]    != SOURCE.[Category]
   OR TARGET.[Summary]     != SOURCE.[Summary]
   OR TARGET.[RetryCount]    != SOURCE.[RetryCount]
   OR TARGET.[CheckResult]   != SOURCE.[CheckResult]
   OR TARGET.[ServiceCiUpdate] != SOURCE.[ServiceCiUpdate]
   OR TARGET.[IsFailed]    != SOURCE.[IsFailed]
   OR TARGET.[UpdateDate]    != GETDATE()
   THEN UPDATE SET TARGET.[GenAIResponse]   = SOURCE.[GenAIResponse]
          ,TARGET.[Service]     = SOURCE.[Service]
          ,TARGET.[InstanceList]    = SOURCE.[InstanceList]
          ,TARGET.[Type]        = SOURCE.[Type]
          ,TARGET.[Category]      = SOURCE.[Category]
          ,TARGET.[Summary]     = SOURCE.[Summary]
          ,TARGET.[Guidance]      = SOURCE.[Guidance]
          ,TARGET.[RetryCount]    = TARGET.[RetryCount] + 1
          ,TARGET.[CheckResult]   = CASE 
                          WHEN SOURCE.[InstanceList] IS NOT NULL THEN 'Instance(s) Found'
                          WHEN SOURCE.[InstanceList] IS NULL THEN 'Instance(s) Not Found'
                        END
          ,TARGET.[ServiceCiUpdate] = CASE 
                          WHEN SOURCE.[ServiceCiUpdate] = 'NULL' THEN NULL
                          WHEN SOURCE.[ServiceCiUpdate] = '' THEN NULL
                          ELSE SOURCE.[ServiceCiUpdate]
                        END
          ,TARGET.[IsFailed]      = SOURCE.[IsFailed]
          ,TARGET.[UpdateDate]    = GETDATE()

  --INSERT 
  WHEN NOT MATCHED BY TARGET
  THEN INSERT ([IncidentNumber]
        ,[GenAIResponse]
        ,[Service]
        ,[InstanceList]
        ,[Type]
        ,[Category]
        ,[Summary]
        ,[Guidance]
        ,[RetryCount]
        ,[CheckResult]
        ,[ServiceCiUpdate]
        ,[IsFailed]
        ,[CreateDate]
        ,[UpdateDate])
    VALUES(SOURCE.[IncidentNumber]
        ,SOURCE.[GenAIResponse]
        ,SOURCE.[Service]
        ,SOURCE.[InstanceList]
        ,SOURCE.[Type]
        ,SOURCE.[Category]
        ,SOURCE.[Summary]
        ,SOURCE.[Guidance]
      ,SOURCE.[RetryCount]
      ,CASE 
        WHEN SOURCE.[InstanceList] IS NOT NULL THEN 'Instance(s) Found'
        WHEN SOURCE.[InstanceList] IS NULL THEN 'Instance(s) Not Found'
           END
      ,CASE 
        WHEN SOURCE.[ServiceCiUpdate] = 'NULL' THEN NULL
        WHEN SOURCE.[ServiceCiUpdate] = '' THEN NULL
        ELSE SOURCE.[ServiceCiUpdate]
       END
      ,SOURCE.[IsFailed]
      ,GETDATE()
      ,GETDATE());
END
GO
PRINT 'STEP 6: Procedure [AI].[sp_MergeGenAIDBACheck] created with [Guidance] column.'
GO

PRINT '======================================================'
PRINT ' Deployment completed successfully.'
PRINT '======================================================'
GO
