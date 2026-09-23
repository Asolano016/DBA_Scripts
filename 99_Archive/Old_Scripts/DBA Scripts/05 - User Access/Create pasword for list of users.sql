SET QUOTED_IDENTIFIER OFF
GO

DECLARE @credentialCount INT,
	    @cnt INT,
		@query NVARCHAR(MAX),
		@intanceList NVARCHAR(MAX)

SET @intanceList = "'USQASWSPC000183','USQASWS0571\CASSDB'"

CREATE TABLE #tCrendialIdentity(
Id INT IDENTITY (1,1),
server VARCHAR(50),
service VARCHAR(50),
account VARCHAR(50)
)

DECLARE @tCrendialPassword TABLE(
server VARCHAR(50),
service VARCHAR(50),
account VARCHAR(50),
newpassword VARCHAR(50)
)

SET @query = "INSERT INTO #tCrendialIdentity
SELECT ti.InstanceName AS server
	  ,'PROXY' AS service
	  ,CredentialIdentity AS account 
FROM [Audit].[tCredentials] tc
INNER JOIN tInstances ti ON ti.ID = tc.InstanceId
WHERE ti.InstanceName IN (" + @intanceList +")
AND CredentialIdentity LIKE '%srv%'"

EXEC sp_executesql @query

SET @credentialCount = (SELECT COUNT(*) FROM #tCrendialIdentity)
SET @cnt = 1

WHILE (@credentialCount >= @cnt)
BEGIN

	DECLARE @char CHAR = ''
	DECLARE @charI INT = 0
	DECLARE @password VARCHAR(100) = ''
	DECLARE @len INT = 33 -- Length of Password
	WHILE @len > 0
	BEGIN
	SET @charI = ROUND(RAND()*100,0)
	SET @char = CHAR(@charI)
 
	IF @charI > 48 AND @charI < 122
	BEGIN
	SET @password += @char
	SET @len = @len - 1
	END
	END
	
	INSERT INTO @tCrendialPassword
	SELECT server
		  ,service
		  ,account
		  ,(SELECT @password) newpassword
	FROM #tCrendialIdentity
	WHERE Id = @cnt
	
	SET @cnt = @cnt + 1
END

SELECT "('" + server + "','" + service + "','" + account + "','" + newpassword + "')," InsertNewPassword
FROM @tCrendialPassword

--INSERT INTO TEMP_srv_acc_pwd_change
--VALUES ('usqaswspc000183','PROXY','PHX-DC\srv_usqas-sqlcp00018','VD@7EPXVSW\E@9G\?1[B`NNMEU_ZWMQ?\'),
--	   ('usqaswspc000183','PROXY','phx-dc\srv_usqas-sqlcp0183','>CQ3YZZ14a>S[YaW>@P?F:HO^7O41T^6T'),
--	   ('usqasws0571\cassdb','PROXY','phx-dc\srv_usqas-sqlp0571','L_?DUT=H>J=697PM9SB`c6@P1GZONdR?U')

--DROP TABLE #tCrendialIdentity
