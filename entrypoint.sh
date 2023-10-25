#!/bin/sh -e

SLAPD_CONF_DIR=/etc/openldap/slapd.d
SLAPD_DATA_DIR=/var/lib/openldap/openldap-data
SLAPD_URLPREFIX=ldap
INSTALL_CONTROL_FILE=openldap-config.control
#PASSWORD_LOAD_MODULE=pw-pbkdf2.so
#PASSWORD_HASH="{PBKDF2-SHA512}"
#PW_LOAD_MODULE=argon2.so
#PW_CRYPT_PREFIX="{ARGON2}"

export SLAPD_IPC_URL=ldapi://%2Frun%2Fopenldap%2Fldapi

# functions
welcome() {
   echo "+----------------------------------------------------------+"
   echo "|                                                          |"
   echo "|               Welcome to OpenLDAP Docker!                |"
   echo "|                                                          |"
   echo "+----------------------------------------------------------+"
}


DC_STR=$(echo ${SLAPD_FQDN} | sed -e s:[.]:,dc=:g)

[ -z "$SLAPD_SUFFIX" ] && export SLAPD_SUFFIX=dc=${DC_STR}

# Set ulimit - See https://github.com/docker/docker/issues/8231
ulimit -n $SLAPD_ULIMIT

if [ -f ${SLAPD_CONF_DIR}/${INSTALL_CONTROL_FILE} ]; then
   echo ""
   echo "+-----------------------------------------------+"
   echo "|     OpenLDAP has already been installed!      |"
   echo "+-----------------------------------------------+"
   echo ""
else
    echo ""
    echo "+-----------------------------------------------+"
    echo "|        OpenLDAP is not installed yet!         |"
    echo "+-----------------------------------------------+"
    echo ""
    echo "INFO: Start install openLDAP version \"${OPENLDAP_VERSION}\"."
    echo ""
fi



# if control file "openldap-config.control" does not exist
if [ ! -f ${SLAPD_CONF_DIR}/${INSTALL_CONTROL_FILE} ]; then
    # At first startup, create directories and configurations
    [ -z "${SLAPD_ROOTDN}" ] && SLAPD_ROOTDN=cn=admin,${SLAPD_SUFFIX}
    if [ ! -z "$SLAPD_ROOTPW" ]; then
        echo "INFO: Var \"SLAPD_ROOTPW\"is set. "
        echo -n "Setting hashed RootDN password...               "
        SLAPD_ROOTPW_HASH=$(slappasswd -o module-load=${PASSWORD_LOAD_MODULE} -h ${SLAPD_PASSWORD_HASH} -s "$SLAPD_ROOTPW")
        echo "[ DONE ]"
    elif [[ -z "$SLAPD_ROOTPW_HASH" && -s /run/secrets/$SLAPD_ROOTPW_SECRET ]]; then
        echo -n "Setting hashed RootDN password...                "
        SLAPD_ROOTPW_HASH=$(slappasswd -o module-load=${PASSWORD_LOAD_MODULE} -h ${SLAPD_PASSWORD_HASH} -s "$(cat /run/secrets/$SLAPD_ROOTPW_SECRET)")
         echo "[ DONE ]"
    fi

    # var SLAPD_ROOTPW_HASH is emty
    if [ -z "$SLAPD_ROOTPW_HASH" ]; then
        echo "** Secret SLAPD_ROOTPW_SECRET unspecified **"
        exit 1
    fi

    export SLAPD_DATA_DIR
    # mkdir -p -m 750 ${SLAPD_CONF_DIR}
    mkdir -p -m 750 /run/openldap

    if [[ "$(ls -A /etc/ssl/openldap)" ]]; then
        # if cert.pem does not exist
        #if [ ! -f /etc/ssl/openldap/cert.pem ]; then
        #    echo -n "Coping \"cert.pem\"...   "
        #    cp /etc/ssl/certs/ca-certificates.crt /etc/ssl/openldap/cert.pem
        #    echo "[ DONE ]"
        #fi

        echo "Setting paths for certificates..."
        CA_CERT=/etc/ssl/openldap/cert.pem
        TLS_KEY=/etc/ssl/openldap/tls.key
        TLS_CERT=/etc/ssl/openldap/tls.pem
        DHPARAM_FILE=/etc/ssl/openldap/dhparam2.pem
        TRUST_SOURCE=/usr/share/ca-certificates/mozilla
        # TLS_CLIENT_CERT=/etc/ssl/openldap/tls_client.crt 

        # user-provided tls certs
        if [[ -f ${CA_CERT} ]]; then
            echo  "INFO: ${CA_CERT} exist"
            echo "TLSCACertificateFile ${CA_CERT}" >> /root/slapd.conf
        fi

        # add cert path into slapd.conf
        echo "Writting certificate into slapd.conf...  "
        echo "TLSCertificateFile ${TLS_CERT}" >> /root/slapd.conf
        echo "TLSCertificateKeyFile ${TLS_KEY}" >> /root/slapd.conf
        echo "TLSCACertificatePath ${TRUST_SOURCE}" >> /root/slapd.conf
        echo "TLSDHParamFile ${DHPARAM_FILE}" >> /root/slapd.conf
        # echo "TLSVerifyClient" ${TLS_CLIENT_CERT} >> /root/slapd.conf
        echo "TLSCipherSuite HIGH:-SSLv2:-SSLv3" >> /root/slapd.conf
        # TLSProtocolMin specifies the minimum version in wire format, so "3.3" actually means TLSv1.2
        echo "TLSProtocolMin 3.3" >> /root/slapd.conf
        SLAPD_URLPREFIX=ldaps
    fi

    # create config for openldap clients
    echo -n "Creating config file for openldap clients...    "
    sed -i -e "s/^#BASE.*/BASE  ${SLAPD_SUFFIX}/" /etc/openldap/ldap.conf
    echo "[ DONE ]"
    export SLAPD_DOMAIN=$(echo ${SLAPD_FQDN} | cut -d . -f 1)

    # replace variable with the value
    echo -n "Replacing variable with the value...   "
    (TMP=$(mktemp)
    for file in $(find /root/ldif -type f) /root/slapd.conf; do
        cat "${file}" | envsubst > $TMP
        mv $TMP "${file}"
    done
    )
    echo "[ DONE ]"

    # copy slapd.conf into config directory
    echo -n "Coping \"slapd.conf\" into config directory...    "
    cp /root/slapd.conf /etc/openldap/slapd.conf
    echo "[ DONE ]"

    # change openLDAP config from file to directory
    slaptest -f /etc/openldap/slapd.conf -F ${SLAPD_CONF_DIR} -n0

    if [ ! -s ${SLAPD_DATA_DIR}/data.mdb ]; then
        cd /root/ldif
        for file in 1-domain.ldif 0-auditlog.ldif 0-memberof.ldif 0-ppolicy.ldif 1-passwordDefaultPolicy.ldif; do
            DB=$(basename "${file}" | cut -d- -f 1)
            echo -n "Adding ${file} into OpenLDAP DB...     "
            slapadd -F ${SLAPD_CONF_DIR} -l "${file}" -n${DB}
            echo "[ DONE ]"
        done

        # Populate ldif's
        if [[ -d /etc/openldap/prepopulate ]]; then 
            for file in `find /etc/openldap/prepopulate -name '*.ldif' -type f`; do
                slapadd -F ${SLAPD_CONF_DIR} -l "${file}"
            done
        fi
    fi

    # create install controll file
    echo "INFO: OpenLDAP is successfully installed!"
    touch ${SLAPD_CONF_DIR}/${INSTALL_CONTROL_FILE}
fi

echo -n "Creating slapd-audit.log...                       "
(touch /var/log/slapd-audit.log
mkdir -p -m 750 /run/openldap
chown -R ldap:ldap ${SLAPD_CONF_DIR} ${SLAPD_DATA_DIR} /run/openldap /var/log/slapd-audit.log
)
echo "[ DONE ]"

#
echo "Setting FQDN and HOST_PARAM...    "
FQDN="$(/bin/hostname -f)"
if [ -f /etc/ssl/openldap/tls.pem ]; then
   HOST_PARAM="ldap:/// ldaps:///"
   echo "INFO: Host parameter are: ${HOST_PARAM}"
else
   HOST_PARAM="ldap:///"
   echo "INFO: Host parameter are: ${HOST_PARAM}"
fi

# run service
echo ""
echo "+-----------------------------------------------+"
echo "|          Starting OpenLDAP service...         |"
echo "+-----------------------------------------------+"
echo ""

echo "Forward the output to log file."
tail -f -n0 /var/log/slapd-audit.log |
    sed "s/^${SLAPD_PWD_ATTRIBUTE}::.*/${SLAPD_PWD_ATTRIBUTE}:: --redacted--/" &
(   sleep 10
    # Post-startup actions
    echo 'Setting user passwords'
    PW_FILE=$(find /run/secrets/$SLAPD_USERPW_SECRET -type f | head -1)
    if [[ ! -z "${PW_FILE}" && -s "${PW_FILE}" ]]; then
        awk -F : -v dnattr=${SLAPD_DN_ATTR} \
	  -v suffix=,${SLAPD_OU}${SLAPD_SUFFIX} \
          -v pwdattr=${SLAPD_PWD_ATTRIBUTE} \
	  '{ print "dn: " dnattr "=" $1 suffix "\n" \
          "changetype: modify\n" \
          "replace: " pwdattr "\n" \
          pwdattr ": " $2 "\n" }' <${PW_FILE} | \
        ldapmodify -Y EXTERNAL -H ${SLAPD_IPC_URL}
    fi
) &
# Start openLDAP Servie
echo ""
welcome
echo ""
exec slapd -h "${HOST_PARAM} ${SLAPD_IPC_URL}" -F ${SLAPD_CONF_DIR} -u ldap -g ldap -d "${SLAPD_LOG_LEVEL}"

#exec slapd -h "${HOST_PARAM} ldapi:///" -F ${SLAPD_CONF_DIR} -u ldap -g ldap -d "${SLAPD_LOG_LEVEL}"

# Run slapd service

#exec slapd -h "${SLAPD_URLPREFIX}:/// ${SLAPD_IPC_URL}" -F ${SLAPD_CONF_DIR} -u ldap -g ldap -d "${SLAPD_LOG_LEVEL}"
