# Capacity

Scripts related to SQL Server file storage, capacity analysis, transaction log usage, file growth configuration, and storage optimization.

## Scripts

### Database File Info.sql

Displays:

- Database Name
- Logical File Name
- Physical File Name
- Physical File Path

Typical use:

- Validate file locations
- Migration planning
- Storage reviews
- File administration

---

### Databases Files Size.sql

Displays size information for every database file in the instance.

Includes:

- Instance Name
- Database Name
- Logical File Name
- Physical File Name
- File Path
- File Size (MB / GB)

Typical use:

- Capacity planning
- Identify large files
- File inventory reviews

---

### Database File Used Space.sql

Displays detailed file-level utilization for the current database.

Includes:

- File Size
- Used Space
- Free Space
- Growth Settings
- Max Size
- Filegroup Information
- Disk Information

Typical use:

- Database-level storage analysis
- Capacity investigations
- File growth reviews

---

### Instance File Space Usage.sql

Displays file-level utilization across all databases in the instance.

Includes:

- File Size
- Used Space
- Free Space
- Growth Settings
- Max Size
- Filegroup Information
- Volume Capacity
- Volume Free Space

Typical use:

- Instance-wide storage reviews
- Capacity planning
- Storage audits
- File configuration validation

---

### Database Files Free Space.sql

Displays file free space and utilization for all databases.

Includes:

- Database Name
- File Name
- Physical File Name
- File Size
- Used Space
- Free Space
- Free Space Percentage

Typical use:

- Quick free space reviews
- Capacity validation
- Database growth monitoring

---

### Databases Total Size.sql

Displays total allocated size for each database.

Includes:

- Instance Name
- Database Name
- Total Size (MB)
- Total Size (GB)

Typical use:

- Capacity reporting
- Database growth reviews
- Storage forecasting

---

### Instance Database File Usage.sql

Provides a database-level summary of allocated, used and free space for data and log files.

Includes:

- Database Name
- File Type (ROWS / LOG)
- Total Size
- Used Space
- Free Space
- Free Space Percentage
- File Count

Typical use:

- Database capacity analysis
- Growth monitoring
- Storage reporting

---

### Log Usage.sql

Displays transaction log utilization for the current database.

Includes:

- Log Size
- Log Used
- Log Free
- Used Percentage
- Free Percentage

Typical use:

- Log growth analysis
- Log troubleshooting
- Recovery model investigations

---

### DBCC SQLPERF (LOGSPACE).sql

Displays transaction log usage for all databases using DBCC SQLPERF.

Typical use:

- Quick transaction log review
- Compare log utilization across databases
- Emergency log troubleshooting

---

### Server Drive Space.sql

Displays storage utilization at the volume level.

Includes:

- Drive Letter
- Total Space
- Used Space
- Free Space
- Free Percentage

Typical use:

- Storage monitoring
- Capacity reviews
- Disk space validation

---

### Shrink Optimal Size.sql

Calculates the recommended file size based on actual utilization and estimated future requirements.

Includes:

- Current Size
- Used Space
- Free Space
- Optimal Size
- Potential Shrink Size

Typical use:

- Shrink evaluations
- Storage reclamation analysis
- Capacity optimization

## Notes

- Start with Databases Total Size.sql for a quick overview of database growth.
- Use Databases Files Size.sql when identifying large MDF, NDF or LDF files.
- Use Database Files Free Space.sql for a simplified free space review across all databases.
- Use Database File Used Space.sql when investigating a specific database.
- Use Instance File Space Usage.sql for detailed file-level analysis across the instance.
- Use Instance Database File Usage.sql when the focus is the database rather than individual files.
- Use Log Usage.sql or DBCC SQLPERF (LOGSPACE).sql when troubleshooting transaction log growth.
- Use Server Drive Space.sql before performing restores, migrations or maintenance operations.
- Use Shrink Optimal Size.sql before considering any shrink operation.
- Instance File Space Usage.sql provides the most detailed storage view in this category.