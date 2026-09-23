SELECT */*[Current LSN] LSN
      ,[Transaction ID]
	  ,Operation
	  ,Context
	  ,AllocUnitName*/
FROM
fn_dblog(NULL, NULL)
WHERE Operation  = 'LOP_DELETE_ROWS'

USE analytics_product
GO
SELECT [Operation]
      ,[Transaction ID]
      ,[Begin Time]
      ,[Transaction Name]
      ,[Transaction SID]
FROM fn_dblog(NULL, NULL)
WHERE [Transaction ID] = '0000:004d3254'