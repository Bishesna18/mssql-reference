#!/bin/bash

# ---------------------------
# CONFIG
# ---------------------------
SA_PASSWORD="Bishesna9"
SQLCMD="/opt/mssql-tools/bin/sqlcmd"
ZIP="/usr/bin/zip"

FULLBACKUP_BASE="/var/opt/mssql/backups/fullbackup"
DIFFBACKUP_BASE="/var/opt/mssql/backups/differentialbackup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Default list of databases
DATABASES=("second")

# Optional AWS S3 upload path (leave empty to skip upload)
AWS_PATH=""

# Google Drive remote name from rclone config
GDRIVE_REMOTE="gdrive"

# ---------------------------
# BACKUP FUNCTION
# ---------------------------
backup_db() {
    DB="$1"
    TYPE="$2"

    # Choose backup base folder by type
    BACKUP_BASE="$FULLBACKUP_BASE"
    [ "$TYPE" == "differential" ] && BACKUP_BASE="$DIFFBACKUP_BASE"

    BACKUP_FOLDER="${BACKUP_BASE}/${DB}"
    FILE_PATH="${BACKUP_FOLDER}/${DB}_${TYPE}_${TIMESTAMP}.bak"
    ZIP_PATH="${BACKUP_FOLDER}/${DB}_${TYPE}_${TIMESTAMP}.zip"
    LOG_PATH="${BACKUP_FOLDER}/${DB}_${TYPE}_${TIMESTAMP}.log"

    # Ensure folder exists with correct ownership/permissions
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
    if [ "$TYPE" == "full" ]; then
        echo "[$DB] 📦 Starting FULL backup..."
        $SQLCMD -S localhost -U SA -P "$SA_PASSWORD" -Q "BACKUP DATABASE [$DB] TO DISK = N'$FILE_PATH' WITH INIT;" > "$LOG_PATH" 2>&1
    else
        echo "[$DB] 📦 Starting DIFFERENTIAL backup..."
        $SQLCMD -S localhost -U SA -P "$SA_PASSWORD" -Q "BACKUP DATABASE [$DB] TO DISK = N'$FILE_PATH' WITH DIFFERENTIAL, INIT;" > "$LOG_PATH" 2>&1
    fi

    # Compress backup if file exists and is not empty
    if [ -s "$FILE_PATH" ]; then
        echo "[$DB] ✅ Backup completed. Compressing..."
        if zip -j "$ZIP_PATH" "$FILE_PATH" && rm "$FILE_PATH"; then
            echo "[$DB] ✅ Compressed to $ZIP_PATH"

            # Upload to AWS S3 if AWS_PATH is set
            if [ -n "$AWS_PATH" ]; then
                echo "[$DB] ☁️ Uploading to S3: $AWS_PATH"
                if aws s3 cp "$ZIP_PATH" "$AWS_PATH"; then
                    echo "[$DB] ✅ Uploaded to $AWS_PATH"
                else
                    echo "[$DB] ❌ Upload to S3 failed!"
                fi
            fi

            # Upload to Google Drive if remote is configured
            if rclone listremotes | grep -q "^$GDRIVE_REMOTE:"; then
                echo "[$DB] ☁️ Uploading to Google Drive..."
                if rclone copy "$ZIP_PATH" "$GDRIVE_REMOTE:/$DB/" --progress; then
                    echo "[$DB] ✅ Uploaded to Google Drive"
                else
                    echo "[$DB] ❌ Upload to Google Drive failed!"
                fi
            fi
        else
            echo "[$DB] ⚠️ Compression failed."
        fi
    else
        echo "[$DB] ❌ Backup failed. Check log: $LOG_PATH"
    fi
}

# ---------------------------
# BACKUP TYPE AND DATABASES
# ---------------------------
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

# Ensure base folders exist with proper ownership
sudo mkdir -p "$FULLBACKUP_BASE" "$DIFFBACKUP_BASE"
sudo chown -R mssql:mssql "$FULLBACKUP_BASE" "$DIFFBACKUP_BASE"
sudo chmod -R 755 "$FULLBACKUP_BASE" "$DIFFBACKUP_BASE"

# ---------------------------
# START BACKUP
# ---------------------------
for DB in "${DATABASES[@]}"; do
    backup_db "$DB" "$BACKUP_TYPE"
done
