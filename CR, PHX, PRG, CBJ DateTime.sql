DECLARE @GrantDate			DATETIME2(0),
        @RevokeDate		    DATETIME2(0),
		@CR_timeZoneOffSet  INT,
		@PHX_timeZoneOffSet INT,
		@PRG_timeZoneOffSet INT,
		@CBJ_timeZoneOffSet INT,
        @dateToGrant		DATETIME2(0),
        @dateToRevoke		DATETIME2(0);

SET @GrantDate			= 'ADDDATE'
SET @RevokeDate			= 'ADDDATE'
SET @CR_timeZoneOffSet  = 0
SET @PHX_timeZoneOffSet = 2
SET @PRG_timeZoneOffSet = 8
SET @CBJ_timeZoneOffSet = 14

--CR_TIME

SET @dateToGrant  = DATEADD(HOUR,@CR_timeZoneOffSet,@GrantDate);   
SET @dateToRevoke = DATEADD(HOUR,@CR_timeZoneOffSet,@RevokeDate);  
SELECT 'CR_TIME' AS 'TimeZone', @dateToGrant AS 'GrantDate', @dateToRevoke AS 'RevokeDate', @CR_timeZoneOffSet AS 'TimeOffSet'

--PHX_TIME

SET @dateToGrant  = DATEADD(HOUR,@PHX_timeZoneOffSet,@GrantDate);   
SET @dateToRevoke = DATEADD(HOUR,@PHX_timeZoneOffSet,@RevokeDate);    
SELECT 'PHX_TIME' AS 'TimeZone', @dateToGrant AS 'GrantDate', @dateToRevoke AS 'RevokeDate', @PHX_timeZoneOffSet AS 'TimeOffSet'

--PRG_TIME

SET @dateToGrant  = DATEADD(HOUR,@PRG_timeZoneOffSet,@GrantDate);   
SET @dateToRevoke = DATEADD(HOUR,@PRG_timeZoneOffSet,@RevokeDate);    
SELECT 'PRG_TIME' AS 'TimeZone', @dateToGrant AS 'GrantDate', @dateToRevoke AS 'RevokeDate', @PRG_timeZoneOffSet AS 'TimeOffSet'

--CBJ_TIME

SET @dateToGrant  = DATEADD(HOUR,@CBJ_timeZoneOffSet,@GrantDate);   
SET @dateToRevoke = DATEADD(HOUR,@CBJ_timeZoneOffSet,@RevokeDate);  
SELECT 'CBJ_TIME' AS 'TimeZone', @dateToGrant AS 'GrantDate', @dateToRevoke AS 'RevokeDate', @CBJ_timeZoneOffSet AS 'TimeOffSet'