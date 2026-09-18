# Recovery

Scripts used to monitor database recovery operations and long-running maintenance activities that expose completion progress and estimated finish times.

## Scripts

### Database Recovery Progress.sql

Tracks database recovery progress using SQL Server Error Log recovery messages.

Includes:

- Database Name
- Recovery Timestamp
- Recovery Percentage
- Estimated Minutes Remaining
- Estimated Hours Remaining
- Recovery Status Message

Typical use:

- Monitor database recovery after SQL Server startup.
- Track recovery progress after unexpected shutdowns.
- Validate database recovery completion.
- Estimate recovery duration for large databases.

---

### Check Reindexing Progress.sql

Monitors index rebuild operations currently running in SQL Server.

Includes:

- Session ID
- Command
- Percent Complete
- Estimated Completion Time (ETA)
- Elapsed Time
- Remaining Time
- SQL Statement

Typical use:

- Monitor index rebuild progress during maintenance windows.
- Estimate completion time for large index operations.
- Validate maintenance job execution.
- Identify long-running ALTER INDEX operations.

## Notes

- Use Database Recovery Progress.sql when a database is in RECOVERING state or after SQL Server startup.
- Update the `@DBName` variable before executing Database Recovery