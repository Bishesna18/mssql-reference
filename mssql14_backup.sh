#!/bin/bash

# Config
SA_PASSWORD="Bishesna9"
SQLCMD="/opt/mssql-tools/bin/sqlcmd"
ZIP="/usr/bin/zip"
FULLBACKUP_BASE="/var/opt/mssql/backups/fullbackup"
DIFFBACKUP_BASE="/var/opt/mssql/backups/differentialbackup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Default list of databases
DATABASES=("last" "newnew")

# Backup function
backup_db() {
    DB="$1"
    TYPE="$2"

    # Choose backup base folder by type
    if [[ "$TYPE" == "full" ]]; then
        BACKUP_BASE="$FULLBACKUP_BASE"
    elif [[ "$TYPE" == "differential" ]]; then
        BACKUP_BASE="$DIFFBACKUP_BASE"
    else
        echo "Unknown backup type: $TYPE"
        return
    fi

    BACKUP_FOLDER="${BACKUP_BASE}/${DB}"
    FILE_PATH="${BACKUP_FOLDER}/${DB}_${TYPE}_${TIMESTAMP}.bak"
    ZIP_PATH="${BACKUP_FOLDER}/${DB}_${TYPE}_${TIMESTAMP}.zip"
    LOG_PATH="${BACKUP_FOLDER}/${DB}_${TYPE}_${TIMESTAMP}.log"

    sudo mkdir -p "$BACKUP_FOLDER"
    sudo chown -R mssql:mssql "$BACKUP_FOLDER"
    sudo chmod 755 "$BACKUP_FOLDER"

    # Check if DB exists
    DB_EXISTS=$($SQLCMD -S localhost -U SA -P "$SA_PASSWORD" -Q "SET NOCOUNT ON; SELECT COUNT(name) FROM sys.databases WHERE name = '$DB';" -h -1 -W)
    if [ "$DB_EXISTS" != "1" ]; then
        echo "[$DB] ❌ Skipped - Database not found."
        return
    fi

    # Run backup command
    if [[ "$TYPE" == "full" ]]; then
        echo "[$DB] 📦 Starting FULL backup..."
        $SQLCMD -S localhost -U SA -P "$SA_PASSWORD" -Q "BACKUP DATABASE [$DB] TO DISK = N'$FILE_PATH' WITH INIT;" > "$LOG_PATH" 2>&1
    elif [[ "$TYPE" == "differential" ]]; then
        echo "[$DB] 📦 Starting DIFFERENTIAL backup..."
        $SQLCMD -S localhost -U SA -P "$SA_PASSWORD" -Q "BACKUP DATABASE [$DB] TO DISK = N'$FILE_PATH' WITH DIFFERENTIAL, INIT;" > "$LOG_PATH" 2>&1
    fi

    # Compress backup if file exists and is not empty
    if [ -s "$FILE_PATH" ]; then
        echo "[$DB] ✅ Backup completed. Compressing..."
        if zip -j "$ZIP_PATH" "$FILE_PATH" && rm "$FILE_PATH"; then
            echo "[$DB] ✅ Compressed to $ZIP_PATH"
        else
            echo "[$DB] ⚠️ Compression failed."
        fi
    else
        echo "[$DB] ❌ Backup failed. Check log: $LOG_PATH"
    fi
}

# Handle 'audit' backup separately
if [[ "$1" == "audit" ]]; then
    echo "📦 Archiving ALL MSSQL audit logs..."
    AUDIT_SRC_BASE="/var/opt/mssql/data"
    AUDIT_DEST_BASE="/var/opt/mssql/backups/auditbackup"
    sudo mkdir -p "$AUDIT_DEST_BASE"
    sudo chown mssql:mssql "$AUDIT_DEST_BASE"
    sudo chmod 755 "$AUDIT_DEST_BASE"

    for AUDIT_DIR in "$AUDIT_SRC_BASE"/Audit*/; do
        [ -d "$AUDIT_DIR" ] || continue
        AUDIT_NAME=$(basename "$AUDIT_DIR")
        DEST_FOLDER="${AUDIT_DEST_BASE}/${AUDIT_NAME}"
        ZIP_FILE="${DEST_FOLDER}/${AUDIT_NAME}_${TIMESTAMP}.zip"
        sudo mkdir -p "$DEST_FOLDER"
        sudo chown -R mssql:mssql "$DEST_FOLDER"
        sudo chmod 755 "$DEST_FOLDER"
        sudo zip -r "$ZIP_FILE" "$AUDIT_DIR" > /dev/null 2>&1
        if [ -f "$ZIP_FILE" ]; then
            echo "✅ Archived $AUDIT_NAME to $ZIP_FILE"
        else
            echo "❌ Failed to archive $AUDIT_NAME"
        fi
    done
    exit 0
fi

# Override backup type and/or databases if passed
if [[ "$1" == "full" || "$1" == "differential" ]]; then
    BACKUP_TYPE="$1"
    shift
else
    BACKUP_TYPE="full"
fi

# Use passed DB names if provided
if [ "$#" -gt 0 ]; then
    DATABASES=("$@")
fi

# Ensure base folders exist
sudo mkdir -p "$FULLBACKUP_BASE" "$DIFFBACKUP_BASE"
sudo chown -R mssql:mssql "$FULLBACKUP_BASE" "$DIFFBACKUP_BASE"
sudo chmod -R 755 "$FULLBACKUP_BASE" "$DIFFBACKUP_BASE"

# Start backup
for DB in "${DATABASES[@]}"; do
    backup_db "$DB" "$BACKUP_TYPE"
done
