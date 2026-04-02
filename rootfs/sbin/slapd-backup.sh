#!/bin/sh -e
#
# debug enable
# set -x
# DBNUM=$1

### CUSTOM vars
SCRIPT_NAME="slapd-backup.sh"
BASENAME=${SCRIPT_NAME}
SCRIPT_VERSION="0.0.4"
%Y%m%dT%H%M%S
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILENAME=$2
BACKUP_PATH="/data/backup"
BACKUP_FILE_CONFIG="${BACKUP_PATH}/${TIMESTAMP}_${FILENAME}_config.ldif"
BACKUP_FILE_DATA="${BACKUP_PATH}/${TIMESTAMP}_${FILENAME}_data.ldif"
SLAPD_DIRECTORY="/etc/openldap/slapd.d"

##############################################################################
# >>> Normaly there is no need to change anything below this comment line. ! #
##############################################################################

# slapcat binary path
SLAPCAT_COMMAND=`command -v slapcat`

# gtip binary path
GZIP_COMMAND=`command -v gzip`

### Functions
# show_help
show_help() {
    echo "Info: Backup OpenLDAP Server."
    echo ""
    echo "usage: ${BASENAME} FirstParameter[ 0 | 1 | all | help ] SecondParameter[filename]"
    echo ""
    echo "First parameter"
    echo "---------------"
    echo "  0                 DBNUM=0   - Backup SLAPD configuration"
    echo "  1                 DBNUM=1   - Backup SLAPD data"
    echo "  all               DBNUM=all - Backup SLAPD configuration and data"
    echo "  help              Will show this help."
    echo ""
    echo "Second  parameter"
    echo "-----------------"
    echo "  filename          The name of backup file (for example: slapd)"
    echo ""
    echo "Example1: ${BASENAME} 0 slapd"
    echo "Example2: ${BASENAME} 1 slapd"
    echo "Example3: ${BASENAME} all slapd"
    echo "Example4: ${BASENAME} help"
    echo ""
}

### Check the parameters passed to the script
if [[ $# -eq 0 ]]; then
   echo "Info: You have not specified any parameters."
   echo ""
   show_help
elif [[ $# -eq  1 ]]; then
   #Check if the passed parameter is “help”
   if [[ "$1" == "help" ]]; then
      show_help
      exit 0
   else
      echo "Info: You have specified only one parameter"
      echo ""
      show_help
      exit 0
   fi
fi

# Check first parameter
for POS_PAR in $1; do
   case ${POS_PAR} in
      0)
         DBNUM_CONFIG=0
         echo "Info: Backup SLAPD configuration."

         # Back up config file and compress it
         ${SLAPCAT_COMMAND} -F ${SLAPD_DIRECTORY} -n ${DBNUM_CONFIG} -l ${BACKUP_FILE_CONFIG} && \
         chmod 600 ${BACKUP_FILE_CONFIG} && \ 
         ${GZIP_COMMAND} -8 ${BACKUP_FILE_CONFIG}
         shift
         ;;
      1)
         DBNUM_DATA=1
         echo "Info: Backup SLAPD data."

         # Back up data file and compress it
         ${SLAPCAT_COMMAND} -F ${SLAPD_DIRECTORY} -n ${DBNUM_DATA} -l ${BACKUP_FILE_DATA} && \
         chmod 600 ${BACKUP_FILE_DATA} && \
         ${GZIP_COMMAND} -8 ${BACKUP_FILE_DATA}
         shift
         ;;
      all)
         DBNUM_CONFIG=0; DBNUM_DATA=1
         echo "Info: Backup SLAPD configuration and data."

         # Back up config and data file and compress them
         ${SLAPCAT_COMMAND} -F ${SLAPD_DIRECTORY} -n ${DBNUM_CONFIG} -l ${BACKUP_FILE_CONFIG} && \
         chmod 600 ${BACKUP_FILE_CONFIG} && \
         ${SLAPCAT_COMMAND} -F ${SLAPD_DIRECTORY} -n ${DBNUM_DATA} -l ${BACKUP_FILE_DATA} && \
         chmod 600 ${BACKUP_FILE_DATA} && \
         ${GZIP_COMMAND} -8 ${BACKUP_FILE_CONFIG} ${BACKUP_FILE_DATA}
         shift
         ;;
      *)
          echo "Info: Unrecognized option: ${POS_PAR}"
          echo "Info: See \"${BASENAME} help\" for supported options."
          exit
   esac
done

# delete backups that are over LDAP_BACKUP_TTL days
find ${BACKUP_PATH} -type f -mtime +${LDAP_BACKUP_TTL} -exec rm {} \;

echo ""
echo "Info: Backup SLAPD configuration and data done"

exit 0

#
### ---> Information about Backup and Restore <---
#

### Backup Cronjob
crontab -e
----
#min hour day mon dow command
15   20    *   *   *  cd /opt/openldap; docker compose exec openldap /sbin/slapd-backup.sh all slapd > /dev/null 2>&1
----

### Restore
systemctl stop monit
cd /opt/openldap
docker compose down
docker compose ps
mv data/ldapdb/data.mdb data/ldapdb/data.mdb_old
ls -la data/ldapdb/ 

# decompress backup files
ls -la data/backup/
gzip -dk data/backup/2026-04-02_T21-12_slapd_config.ldif.gz
gzip -dk data/backup/2026-04-02_T21-12_slapd_data.ldif.gz

# change file .env (When starting the container instead of the slapd service, /bin/bash is executed)
vim .env
---
SLAPD_RECOVERY_MODE=true
---

# restore slapd data
docker compose up -d openldap
docker compose exec openldap bash
slapadd -n 1 -l /data/backup/2026-04-02_T21-12_slapd_data.ldif
ls -lah /var/lib/openldap/openldap-data/

# restore slapd configuration (if needed)
slapadd -n 0 -F /etc/openldap/slapd.d -l /data/backup/2026-04-02_T21-12_slapd_config.ldif

# Fix Permissions: Ensure the ldap user owns the restored files
chown -R ldap:ldap /var/lib/openldap/openldap-data/
ls -lah /var/lib/openldap/openldap-data/ 
chown -R ldap:ldap /etc/openldap/slapd.d/
ls -lah /etc/openldap/slapd.d/
exit

# change file .env (When starting containers, the slapd service is run)
vim .env
---
SLAPD_RECOVERY_MODE=false
---

# rerun docker container
docker compose down
docker compose up -d
docker compose ps
docker compose logs

# run monit service 
systemctl start monit
systemctl status monit
