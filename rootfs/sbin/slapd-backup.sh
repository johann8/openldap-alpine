#!/bin/sh -e
#
# debug enable
# set -x
# DBNUM=$1

### CUSTOM vars
SCRIPT_START_TIME=$SECONDS                                # Script start time
SCRIPT_NAME="slapd-backup.sh"
BASENAME=${SCRIPT_NAME}
SCRIPT_VERSION="0.0.6"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
_DATUM="$(date '+%Y-%m-%d %Hh:%Mm:%Ss')"
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

# tree binary path
TREE_COMMAND=`command -v tree`

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

#
### Main script
#
echo -e "Info: Started on \"$(hostname -f)\" at \"${_DATUM}\""
echo -e "Info: Script version is: \"${SCRIPT_VERSION}\""

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
         echo -n "Info: A backup of the \"SLAPD configuration\" is being created..." && \
         # Back up slapd config  and compress it
         ${SLAPCAT_COMMAND} -F ${SLAPD_DIRECTORY} -n ${DBNUM_CONFIG} -l ${BACKUP_FILE_CONFIG} >&2 && \
         chmod 600 ${BACKUP_FILE_CONFIG} >&2 && \
         echo "[ DONE ]"
         echo -n "Info: A Backup files are compressed...                         " && \
         ${GZIP_COMMAND} -8 ${BACKUP_FILE_CONFIG} >&2 && \
         echo "[ DONE ]"
         shift
         ;;
      1)
         DBNUM_DATA=1
         echo -n "Info: A backup of the \"SLAPD data\" is being created...         " && \
         # Back up slapd data and compress it
         ${SLAPCAT_COMMAND} -F ${SLAPD_DIRECTORY} -n ${DBNUM_DATA} -l ${BACKUP_FILE_DATA} >&2 && \
         chmod 600 ${BACKUP_FILE_DATA} >&2 && \
         echo "[ DONE ]"
         echo -n "Info: A Backup files are compressed...                         " && \
         ${GZIP_COMMAND} -8 ${BACKUP_FILE_DATA} >&2 && \
         echo "[ DONE ]"
         shift
         ;;
      all)
         DBNUM_CONFIG=0; DBNUM_DATA=1
         echo -n "Info: A backup of the \"SLAPD configuration\" is being created..." && \
         # Back up config and data file and compress them
         ${SLAPCAT_COMMAND} -F ${SLAPD_DIRECTORY} -n ${DBNUM_CONFIG} -l ${BACKUP_FILE_CONFIG} >&2 && \
         chmod 600 ${BACKUP_FILE_CONFIG} >&2 && \
         echo "[ DONE ]"
         echo -n "Info: A backup of the \"SLAPD data\" is being created...         " && \
         ${SLAPCAT_COMMAND} -F ${SLAPD_DIRECTORY} -n ${DBNUM_DATA} -l ${BACKUP_FILE_DATA} >&2 && \
         chmod 600 ${BACKUP_FILE_DATA} >&2 && \
         echo "[ DONE ]"
         echo -n "Info: A Backup files are compressed...                         " && \
         ${GZIP_COMMAND} -8 ${BACKUP_FILE_CONFIG} ${BACKUP_FILE_DATA} >&2 && \
         echo "[ DONE ]"
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
echo "Info: Backup SLAPD configuration and data done."
${TREE_COMMAND} -ifFrh ${BACKUP_PATH} | grep gz

END_TIME="$(date -R)"
echo ""
echo "---------------------------------------------------------------------"
echo "| Info: Script exiting normally at: $END_TIME |"
echo "---------------------------------------------------------------------"

exit 0

#
### ---> Information about Backup and Restore <---
#

### Backup - create cronjob
crontab -e
----
#min hour day mon dow command
15   20    *   *   *  cd /opt/openldap; docker compose exec openldap /sbin/slapd-backup.sh all slapd > /dev/null 2>&1
----

### Restore
# stop monitoring tool monit
systemctl stop monit

# show database records
cd /opt/openldap
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b 'dc=rohrkabel,dc=eu' '(uid=*)' | wc -l
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b 'dc=rohrkabel,dc=eu' '(objectclass=*)' | grep "^# numEntries".

# stop docker stack
docker compose down
docker compose ps

# run docker stack with overwritten entrypoint
docker compose run -it --entrypoint=/bin/bash openldap
/var/lib/openldap/openldap-data/
ls -la /data/backup
ls -la /etc/openldap/slapd.d/


# Move slapd data folder to backup folder
mkdir -p /data/backup/openldap-data_old
mv /var/lib/openldap/openldap-data/* /data/backup/openldap-data_old/
ls -lah /data/backup/openldap-data_old/

# decompress backup files
ls -la /data/backup/
gzip -dk /data/backup/2026-04-06_13-00-06_slapd_config.ldif.gz
gzip -dk /data/backup/2026-04-06_13-00-06_slapd_data.ldif.gz


# restore slapd data
slapadd -n 1 -l /data/backup/2026-04-06_13-00-06_slapd_data.ldif
ls -lah /var/lib/openldap/openldap-data/

# restore slapd configuration (if needed)
mkdir -p /data/backup/slapd.d/
mv /etc/openldap/slapd.d/* /data/backup/slapd.d/
slapadd -n 0 -F /etc/openldap/slapd.d -l /data/backup/2026-04-06_13-00-06_slapd_config.ldif

# copy slaps control file back into working directory
cp /data/backup/slapd.d/openldap-config.control /etc/openldap/slapd.d/

# Fix Permissions: Ensure the ldap user owns the restored files
chown -R ldap:ldap /var/lib/openldap/openldap-data/
ls -lah /var/lib/openldap/openldap-data/
chown -R ldap:ldap /etc/openldap/slapd.d/
ls -lah /etc/openldap/slapd.d/
exit

# remove temp docker container 
docker ps -a --filter "status=exited"
docker rm 5796f57db9fe

# Start docker container and test
docker compose up -d
docker compose ps
docker compose logs

show database records
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b 'dc=rohrkabel,dc=eu' '(uid=*)' | wc -l
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b 'dc=rohrkabel,dc=eu' '(objectclass=*)' | grep "^# numEntries".
-----------------
SASL/EXTERNAL authentication started
SASL username: gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth
SASL SSF: 0
# numEntries: 23
-----------------

# run monit service
systemctl start monit
systemctl status monit

# Delete old files after test
cd /opt/openldap
rm -rf data/backup/slapd.d
rm -rf data/backup/openldap-data_old
rm -rf data/backup/*.ldif
ls -la  data/backup/
