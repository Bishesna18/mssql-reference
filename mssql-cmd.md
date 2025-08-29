# MSSQL Server Reference (Ubuntu)

## Common Paths

- `/var/opt/mssql/data` — MSSQL data directory  
- `/var/opt/mssql/backups` — Default backup location (may need to be created)  

---

## MSSQL Server Commands

- `sudo systemctl status mssql-server` — Check if MSSQL service is running  
- `sudo systemctl start mssql-server` — Start MSSQL service  
- `sudo systemctl stop mssql-server` — Stop MSSQL service  
- `sudo systemctl restart mssql-server` — Restart MSSQL service  
- `/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P '<YourPassword>'` — Connect to MSSQL via CLI (`sqlcmd`)  
- `/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P '<YourPassword>' -Q "<SQL_QUERY>"` — Run a single SQL query via CLI  

---

## Backup & Restore

**Backup a database**
```bash
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P '<YourPassword>' -Q "BACKUP DATABASE YourDatabaseName TO DISK='/var/opt/mssql/backups/YourDatabaseName.bak' WITH FORMAT;"
