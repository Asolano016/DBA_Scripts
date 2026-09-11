# Blocking

Scripts used to identify blocking sessions, root blockers, locking chains, and execution plans involved in blocking scenarios.

## Scripts

### Blocking Analysis.sql
Provides detailed blocking analysis including blocked and blocking sessions, lock types, wait types, affected objects, and SQL statements.

### Blocking Query Plan.sql
Displays the SQL text and execution plan of sessions currently acting as blockers.

### Blocking Tree.sql
Builds a blocking hierarchy to quickly identify the head blocker and the full blocking chain.

## Notes
- Start with Blocking Tree.sql to identify the root blocker.
- Use Blocking Analysis.sql for detailed investigation.
- Use Blocking Query Plan.sql when execution plan review is required.