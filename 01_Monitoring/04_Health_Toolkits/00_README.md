# SQL Server 2019+ DBA Health & Diagnostic Toolkit

A comprehensive, production-safe, **read-only** T-SQL diagnostic suite designed for Senior Database Administrators, Production Engineers, and Performance Specialists troubleshooting Microsoft SQL Server 2019 and SQL Server 2022+.

---

## 1. Philosophy & Safety Principles

1. **Strictly Read-Only:** None of the scripts in this toolkit modify database state, change server configurations, rebuild indexes, kill sessions, or alter permissions.
2. **Low Production Overhead:** Queries are optimized to avoid lock contention, using safe DMVs, filtered metadata views, and `OPTION (MAXDOP 1)` where appropriate.
3. **Structured DBA Guidance:** Every script and section is documented with operational context: **Purpose**, **Why It Matters**, **Healthy Baselines**, **Warning Indicators**, and **Next Actions**.
4. **Subsystem Modularity:** Troubleshoot issues hierarchically, starting from emergency triage down into dedicated subsystem toolkits.

---

## 2. Compatibility & Required Permissions

### Target Versions
- **SQL Server 2019** (15.x) — All Cumulative Updates
- **SQL Server 2022** (16.x) — All Cumulative Updates
- Compatible with SQL Server on Windows and Linux.

### Required Permissions
To run all diagnostic scripts without permission errors:
- **SQL Server 2019:** `GRANT VIEW SERVER STATE, VIEW ANY DATABASE TO [login];`
- **SQL Server 2022+:** `GRANT VIEW SERVER PERFORMANCE STATE, VIEW SERVER SECURITY STATE, VIEW ANY DATABASE TO [login];`
- Access to `tempdb` and `master` system catalogs.

---

## 3. Toolkit Inventory & Architecture

```
                               ┌────────────────────────┐
                               │   Toolkit Triage.sql   │ (Tier 1 Emergency Response)
                               └───────────┬────────────┘
                                           │
         ┌───────────────────┬─────────────┴───────┬───────────────────┐
         │                   │                     │                   │
┌────────▼────────┐ ┌────────▼────────┐   ┌────────▼────────┐ ┌────────▼────────┐
│  CPU & Threads  │ │ Memory & Cache  │   │  I/O & TempDB   │ │ Concurrency & HA│
├─────────────────┤ ├─────────────────┤   ├─────────────────┤ ├─────────────────┤
│Toolkit CPU.sql  │ │Toolkit Memory   │   │Toolkit IO.sql   │ │Toolkit Blocking │
│Toolkit Waits    │ │Toolkit Plan C.  │   │Toolkit TempDB   │ │Toolkit AlwaysOn │
│High CPU Usage   │ │Toolkit Query P. │   │Toolkit Indexes  │ │Filter ERRORLOG  │
│                 │                   │                     │Check Schema Chg   │
└─────────────────┘ └─────────────────┘   └─────────────────┘ └─────────────────┘
```

### Script Directory

| Script | Purpose | When to Use |
| :--- | :--- | :--- |
| `Toolkit Triage.sql` | **Tier 1 Incident Response.** High-level overview across all subsystems. | First script to run when a server is reported slow or unresponsive. |
| `Toolkit CPU.sql` | Scheduler health, runnable queues, compilation rates, parallelism. | High CPU utilization, `SOS_SCHEDULER_YIELD`, or `CXPACKET` waits. |
| `Toolkit Memory.sql` | Memory clerks, buffer pool distribution, memory grants, PLE (NUMA). | Low PLE, memory pressure warnings, or `RESOURCE_SEMAPHORE` waits. |
| `Toolkit IO.sql` | File read/write latencies, disk stalls, transaction log throughput. | High `PAGEIOLATCH_*` or `WRITELOG` waits, slow storage response. |
| `Toolkit Blocking.sql` | Blocking chains, idle head blockers, lock escalation, isolation levels. | User transactions timing out, `LCK_M_*` waits, application deadlock alerts. |
| `Toolkit TempDB.sql` | Space allocation (User/Internal/Version Store), memory spills, file layout. | TempDB growth alerts, disk space exhaustion, snapshot transaction bloat. |
| `Toolkit Wait Stats.sql` | Instance-wide wait stats categorized with benign waits filtered. | General performance reviews or identifying root bottleneck domain. |
| `Toolkit Query Performance.sql` | Multidimensional query stats (CPU, Reads, Writes, Duration, Sniffing). | Query tuning, identifying top resource consumers, Query Store review. |
| `Toolkit Plan Cache.sql` | Plan cache distribution, single-use ad-hoc plan pollution, cache bloat. | Memory bloat in `CACHESTORE_SQLCP`, high compilation overhead. |
| `Toolkit Indexes.sql` | Missing index recommendations, duplicate index detection, usage stats. | Performance optimization, reducing write overhead, table scan tuning. |
| `Toolkit Always On.sql` | Availability Group replica states, log send/redo queues, failover readiness. | AG synchronization lag, replica disconnection, latency on secondaries. |
| `Filter ERRORLOG.sql` | Parameterized search of SQL Server Error Log for authentication failures. | Security audits, brute force logon investigation, service errors. |
| `Check Schema Change History.sql` | Default trace extraction for DDL changes (CREATE, ALTER, DROP). | Unexpected schema modifications, missing object investigations. |
| `High CPU Usage.sql` | Fast active CPU request snapshot with statement-level text slicing. | Standalone quick query for active high-CPU sessions. |

---

## 4. Recommended Incident Troubleshooting Workflow

```
[ALERT: System Slow / Outage]
               │
               ▼
   1. Execute Toolkit Triage.sql
               │
   ┌───────────┴───────────────────────────────────────────┐
   │ Check Dominant Bottleneck Matrix                     │
   └───────────┬───────────────────────────────────────────┘
               │
   ├─► High CPU / Schedulers?    ──► Run Toolkit CPU.sql & Toolkit Wait Stats.sql
   ├─► Memory Grants / Low PLE?  ──► Run Toolkit Memory.sql & Toolkit Plan Cache.sql
   ├─► Storage Latency / Disks?  ──► Run Toolkit IO.sql & Toolkit TempDB.sql
   ├─► Blocked Sessions / Locks? ──► Run Toolkit Blocking.sql
   ├─► Specific Slow Queries?    ──► Run Toolkit Query Performance.sql & Toolkit Indexes.sql
   └─► AG Synchronization Lag?   ──► Run Toolkit Always On.sql
```

---

## 5. Important Limitations & Caveats

1. **DMV Volatility:** Many DMVs (such as `sys.dm_os_wait_stats`, `sys.dm_db_index_usage_stats`, and `sys.dm_exec_query_stats`) reset when the SQL Server instance restarts or when specific maintenance tasks occur (e.g., index rebuilds). Always check instance uptime before making architectural changes.
2. **Cumulative Counters:** Performance counters (`sys.dm_os_performance_counters`) display cumulative totals since service start, not instantaneous rates.
3. **Database Context:** Unless specified, execute scripts from the `master` database. Scripts analyzing database-scoped objects will evaluate the current database context.
