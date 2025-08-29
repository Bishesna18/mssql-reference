# 📘 MSSQL Backup Automation

This repository contains scripts to automate **Microsoft SQL Server backups** and upload them to **Google Drive** (via `rclone` + Google Cloud Service Account) or **AWS S3**.

---

## 🚀 Features
- Full and Differential backups for MSSQL databases  
- Automatic compression into `.zip`  
- Upload to:
  - **Google Drive** (secure via Service Account)  
  - **AWS S3** (optional)  
- Logs generated for each backup  
- Supports multiple databases  

---

## 🛠️ Prerequisites
- **SQL Server Tools** (`sqlcmd`)  
- **zip** (for compression)  
- **rclone** (for Google Drive)  
- **AWS CLI** (if using S3)  
- Writable backup folder at `/var/opt/mssql/backups/`  

Setup commands:  
```bash
sudo apt-get install mssql-tools unixodbc-dev -y
sudo apt-get install zip -y
