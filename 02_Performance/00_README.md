# Performance

Scripts used to identify performance bottlenecks, evaluate SQL Server configuration settings, and generate tuning recommendations.

## Scripts

### Long Running Queries.sql

Identifies the most expensive queries currently stored in the plan cache.

Includes:

- Query Text
- Execution Statistics
- CPU Consumption
- Elapsed Time
- Execution Plan Information

Typical use:

- Investigate slow workloads
- Identify high CPU consumers
- Review expensive queries for tuning opportunities

---

### Index Fragmentation Analysis.sql

Displays index fragmentation levels and generates rebuild or reorganize recommendations.

Includes:

- Database Name
- Table Name
- Index Name
- Fragmentation Percentage
- Page Count
- Suggested Maintenance Command

Typical use:

- Index maintenance reviews
- Performance optimization
- Maintenance planning

---

### Indexes Missing Analysis.sql

Displays missing index recommendations collected by SQL Server.

Includes:

- Affected Objects
- Equality Columns
- Inequality Columns
- Included Columns
- User Seeks
- Estimated Impact
- Suggested CREATE INDEX Statement

Typical use:

- Query tuning
- Performance optimization
- Index design improvements

---

### MAXDOP Analysis.sql

Provides MAXDOP recommendations based on server topology.

Includes:

- Logical CPUs
- Physical CPUs
- Hyperthreading Status
- NUMA Configuration
- Recommended MAXDOP Value

Typical use:

- New server reviews
- Performance assessments
- Configuration validation

---

### Parallelism Cost Threshold Analysis.sql

Identifies cached execution plans currently using parallelism.

Includes:

- Query Text
- Query Cost
- Optimization Level
- Execution Plan
- Use Counts

Typical use:

- Parallelism investigations
- Cost Threshold for Parallelism reviews
- MAXDOP and parallelism tuning

## Notes

- Start with Long Running Queries.sql when investigating performance complaints.
- Use Indexes Missing Analysis.sql to identify potential indexing opportunities.
- Use Index Fragmentation Analysis.sql before scheduling index maintenance.
- Use MAXDOP Analysis.sql when validating parallelism configuration.
- Use Parallelism Cost Threshold Analysis.sql to determine whether the current Cost Threshold for Parallelism setting is appropriate.
- Missing index recommendations should always be reviewed before implementation.
- Fragmentation alone should not drive index maintenance decisions; page count and workload patterns should also be considered.
- MAXDOP and Cost Threshold for Parallelism should be evaluated together, not independently.