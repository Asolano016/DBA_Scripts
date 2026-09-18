# Performance

Scripts used to identify query bottlenecks, evaluate parallelism settings, analyze index health, and generate performance tuning recommendations.

## Scripts

### Long Running Queries.sql

Identifies active requests and historical query outliers.

Includes:

- Active long-running requests
- CPU consumption
- Elapsed time
- Logical reads
- Physical reads
- Writes
- Wait types
- Blocking sessions
- Historical execution outliers

Typical use:

- Active performance incidents
- Slow query investigations
- Blocking analysis
- Query performance troubleshooting

---

### Index Fragmentation Analysis.sql

Displays index fragmentation levels and generates index maintenance recommendations.

Includes:

- Table Name
- Index Name
- Index Type
- Fragmentation Percentage
- Page Count
- Suggested REBUILD command
- Suggested REORGANIZE command

Typical use:

- Index maintenance reviews
- Performance optimization
- Maintenance planning

---

### Indexes Missing Analysis.sql

Displays SQL Server missing index recommendations and generates CREATE INDEX statements.

Includes:

- Equality Columns
- Inequality Columns
- Included Columns
- User Seeks
- User Scans
- Last User Seek
- Recommendation Age
- Impact Score
- Suggested CREATE INDEX statement

Typical use:

- Query tuning
- Index design reviews
- Performance optimization

---

### MAXDOP Analysis.sql

Analyzes CPU topology and compares current MAXDOP settings against Microsoft recommendations.

Includes:

- Logical CPUs
- Physical Cores
- Hyperthread Ratio
- NUMA Nodes
- CPUs per NUMA Node
- Current MAXDOP
- Current Cost Threshold for Parallelism
- Recommended MAXDOP
- Configuration Assessment

Typical use:

- New server reviews
- Performance assessments
- Parallelism tuning
- Configuration validation

---

### Parallelism Cost Threshold Analysis.sql

Analyzes cached parallel execution plans and evaluates parallelism cost distribution.

Includes:

- Number of Parallel Plans
- Minimum Cost
- Average Cost
- Maximum Cost
- P50 Cost
- P75 Cost
- P90 Cost
- P95 Cost

Typical use:

- Parallelism investigations
- Cost Threshold for Parallelism reviews
- CPU optimization
- Parallel workload analysis

## Notes

- Start with Long Running Queries.sql during active performance incidents.
- Use Indexes Missing Analysis.sql to identify potential indexing opportunities.
- Use Index Fragmentation Analysis.sql when reviewing index maintenance requirements.
- Review existing indexes before implementing any missing index recommendation.
- Use MAXDOP Analysis.sql when validating parallelism configuration.
- Use Parallelism Cost Threshold Analysis.sql together with MAXDOP Analysis.sql.
- MAXDOP and Cost Threshold for Parallelism should always be evaluated together.
- Missing index recommendations are suggestions, not implementation requirements.
- Index fragmentation should be evaluated together with page count and workload characteristics.
- Long Running Queries.sql is typically the first script executed during performance troubleshooting.