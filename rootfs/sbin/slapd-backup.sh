#!/bin/sh -e

# Usage: /sbin/slapd-backup dbnum filename
dbnum=$1
filename=$2
#LDAP_BACKUP_TTL=${LDAP_BACKUP_TTL}

backupPath="/data/backup"

# delete backups that are over ${LDAP_BACKUP_TTL} days
find $backupPath -type f -mtime +${LDAP_BACKUP_TTL} -exec rm {} \;

# Date format for the dump file name
#dateFileFormat="+%Y%m%dT%H%M%S"
dateFileFormat="+%Y-%m-%d_T%H-%M"
backupFilePath="$backupPath/$(date "$dateFileFormat")_$filename.gz"

/usr/sbin/slapcat -F /etc/openldap/slapd.d -n $dbnum | gzip > $backupFilePath
chmod 600 $backupFilePath

exit 0
