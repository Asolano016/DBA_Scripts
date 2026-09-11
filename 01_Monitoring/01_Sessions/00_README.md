# Sessions

Scripts related to active connections, running requests, Query Store searches and session monitoring.

## Scripts

### Sessions Running.sql

Shows currently executing requests including:

- Login
- Host
- Database
- Command
- CPU Time
- Elapsed Time
- Blocking Session
- SQL Statement

### Sessions Active.sql

Shows active requests with troubleshooting details:

- Wait Types
- Blocking Information
- Request Age
- Parent Query
- Individual Statement

### Sessions by Database.sql

Lists sessions grouped by database usage.

### Sessions Progress.sql

Shows operations reporting percent_complete such as:

- Backup
- Restore
- DBCC
- Index Maintenance

### Query Store Search Text.sql

Searches query text stored in Query Store.

### Filter SP_WHO2.sql

Returns sp_who2 output with optional filtering.

## Notes

- Start with Sessions Running.sql for a quick overview of active activity.
- Use Sessions Active.sql when investigating waits or blocking.
- Use Sessions Progress.sql to monitor long-running maintenance operations.
- Use Sessions by Database.sql to identify users connected to a specific database.
- Use Query Store Search Text.sql when historical query execution needs to be located.