<h1 align="center">OpenLDAP</h1>
<p align='justify'>
<a href="https://openldap.org)">OpenLDAP</a> ist eine Implementierung des Lightweight Directory Access Protocol (LDAP), die als freie Software unter der der BSD-Lizenz ähnlichen OpenLDAP Public License veröffentlicht wird.
</p>

- [OpenLDAP Docker Image](#openldap-docker-image)
- [Variables](#variables)
- [Volumes](#volumes)
- [Secrets](#secrets)
- [Install OpenLDAP](#install-openldap)
  - [Traefik integration](#traefik-integration)
  - [Authelia integration](#authelia-integration)
  - [PhpLdapAdmin integration](#phpldapadmin-integration)
  - [Olefia integration](#olefia-integration)
  - [Add ldap schema  to old docker container](#add-ldap-schema-to-old-docker-container)

## OpenLDAP Docker Image 🐋
Image is based on [Alpine 3.21](https://hub.docker.com/repository/docker/johann8/alpine-openldap/general)

| pull | size alpine | version | platform | alpine version |
|:---------------------------------:|:----------------------------------:|:--------------------------------:|:--------------------------------:|:--------------------------------:|
| ![Docker Pulls](https://img.shields.io/docker/pulls/johann8/alpine-openldap?logo=docker&label=pulls&style=flat-square&color=blue) | ![Docker Image Size](https://img.shields.io/docker/image-size/johann8/alpine-openldap/latest?logo=docker&style=flat-square&color=blue&sort=semver) | [![](https://img.shields.io/docker/v/johann8/alpine-openldap/latest?logo=docker&style=flat-square&color=blue&sort=semver)](https://hub.docker.com/r/johann8/alpine-openldap/tags "Version badge") | ![](https://img.shields.io/badge/platform-amd64-blue "Platform badge") | [![Alpine Version](https://img.shields.io/badge/Alpine%20version-v3.21.0-blue.svg?style=flat-square)](https://alpinelinux.org/) |

## Variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| SLAPD_DN_ATTR | uid | Attribute of user dn (usually `cn` or `uid`) |
| SLAPD_FQDN | example.com | |
| SLAPD_LOG_LEVEL | Config,Stats | See [loglevel keywords](https://www.openldap.org/doc/admin24/slapdconfig.html) |
| SLAPD_ORGANIZATION | Example | |
| SLAPD_OU | ou=users, | Org-unit component of DN |
| SLAPD_PWD_ATTRIBUTE | userPassword | Attribute of hashed password |
| SLAPD_PWD_CHECK_QUALITY | 2 | Password-modify enforcement option 0-2 |
| SLAPD_PWD_FAILURE_COUNT_INTERVAL | 1200 | Reset failures [20 min] |
| SLAPD_PWD_LOCKOUT_DURATION | 1200 | Clear lockout [20 min] |
| SLAPD_PWD_MAX_FAILURE | 5 | Maximum attempts before lockout |
| SLAPD_PWD_MIN_LENGTH | 8 | Password-modify minimum length |
| SLAPD_ROOTDN | cn=admin,dc=(suffix)  | Admin user's DN |
| SLAPD_ROOTPW |  | Plain-text admin password |
| SLAPD_ROOTPW_HASH |  | Hashed admin password |
| SLAPD_ROOTPW_SECRET | openldap-ro-password | Name of secret to hold pw |
| SLAPD_SUFFIX | (based on `SLAPD_FQDN`) | Suffix of DN |
| SLAPD_ULIMIT | 2048 | maximum file size |
| SLAPD_USERPW_SECRET | openldap-user-passwords | Name of secret to hold pws |
| SLAPD_PASSWORD_HASH | ARGON2 | encrypted with {ARGON2} |
| LDAP_BACKUP_TTL | 15 | Number of backups |

If overriding default root DN, it should be specified in the form `cn=admin,dc=example,dc=com`.

The root password must be specified in one of three ways:

* `SLAPD_ROOTPW` - plain text value, only for testing
* `SLAPD_ROOTPW_HASH` - encrypted value starting with `{ARGON2}`
* `openldap-ro-password` secret - most secure place to store the hash

You will want to override values for `SLAPD_FQDN` and `SLAPD_ORGANIZATION`. All the other default values will work for many typical use-cases.

User passwords are normally initialized by the administrator using `ldappasswd`, and from then on updated by the user (through the same tool or protocol). With this image, you can also define user passwords by providing their (hashed) values via a secret. Don't use `ldappasswd` to update passwords that are provided with the latter method: use it to generate a new hashed value and update the secret.

## Volumes

Mount these path names to persistent storage; all are optional.

Path | Description
---- | -----------
/data/backup | Persistent storage for Backups
/etc/openldap/slapd.d | Persistent storage for SLAPD config
/etc/openldap/ldif | Persistent storage for produced ldifs
/etc/openldap/prepopulate | Zero or more .ldif files to load upon startup
/var/lib/openldap/openldap-data | Persistent storage for ldap database
/etc/ssl/openldap | TLS/SSL certificate

## Secrets

Secret | Description
------ | -----------
openldap-rootpw | Hashed password (key name openldap-rootpw-hash)
openldap-ssl | Certificate (cacert.pem, tls.crt, tls.key)
openldap-user-passwords | Hashed passwords (in _user: {ARGON2} hash form)



## Install OpenLDAP

- create folders, files and set rights

```bash
mkdir -p /opt/openldap/data/{prepopulate,ldapdb,ssl,config,backup}
mkdir -p /opt/openldap/data/config/ldap/{slapd.d,ldif,secrets,custom-schema}
touch /opt/openldap/data/config/ldap/secrets/openldap-user-passwords
touch /opt/openldap/data/config/ldap/secrets/openldap-root-password
chmod 0600 /opt/openldap/data/config/ldap/secrets/openldap-user-passwords
chmod 0600 /opt/openldap/data/config/ldap/secrets/openldap-root-password
chown 100:101 /opt/openldap/data/config/ldap/slapd.d
tree /opt/openldap/
```
- create docker-compose.yml
```bash
vim /opt/openldap/docker-compose.yml
------------------------------------
version: "3.2"
networks:
  ldapNet:
    ipam:
      driver: default
      config:
        - subnet: ${SUBNET}.0/24

services:
  openldap:
    image: johann8/alpine-openldap:${VERSION_OPENLDAP:-latest}
    container_name: openldap
    restart: unless-stopped
    environment:
      SLAPD_ROOTDN:            ${SLAPD_ROOTDN}
      SLAPD_ROOTPW:            ${SLAPD_ROOTPW}
      SLAPD_ROOTPW_HASH:       ${SLAPD_ROOTPW_HASH}
      SLAPD_ORGANIZATION:      ${SLAPD_ORGANIZATION}
      SLAPD_FQDN:              ${SLAPD_FQDN}
      SLAPD_SUFFIX:            ${SLAPD_SUFFIX}
      SLAPD_PWD_CHECK_QUALITY: ${SLAPD_PWD_CHECK_QUALITY}
      SLAPD_PWD_MIN_LENGTH:    ${SLAPD_PWD_MIN_LENGTH}
      SLAPD_PWD_MAX_FAILURE:   ${SLAPD_PWD_MAX_FAILURE}
      SLAPD_ROOTPW_SECRET:     ${SLAPD_ROOTPW_SECRET}
      SLAPD_USERPW_SECRET:     ${SLAPD_USERPW_SECRET}
      SLAPD_PASSWORD_HASH:     ${SLAPD_PASSWORD_HASH}
    hostname: ${HOSTNAME0}.${DOMAINNAME}
    volumes:
      - ${DOCKERDIR}/data/backup:/data/backup
      - ${DOCKERDIR}/data/prepopulate:/etc/openldap/prepopulate:ro
      - ${DOCKERDIR}/data/ldapdb:/var/lib/openldap/openldap-data
      - ${DOCKERDIR}/data/ssl:/etc/ssl/openldap
      - ${DOCKERDIR}/data/config/ldap/ldif:/etc/openldap/ldif:ro
      - ${DOCKERDIR}/data/config/ldap/slapd.d:/etc/openldap/slapd.d
      - ${DOCKERDIR}/data/config/ldap/custom-schema:/etc/openldap/custom-schema
      - ${DOCKERDIR}/data/config/ldap/secrets:/run/secrets
    ports:
      - ${PORT_LDAP:-389}:389
      - ${PORT_LDAPS:-636}:636
    networks:
      - ldapNet
    secrets:
      - ${SLAPD_ROOTPW_SECRET}
      - ${SLAPD_USERPW_SECRET}

  phpldapadmin:
    image: johann8/phpldapadmin:${PLA_VERSION}
    container_name: phpldapadmin
    restart: unless-stopped
    #volumes:
      #- ${DOCKERDIR}/data/html:/var/www/html
    #ports:
      #- ${PORT_PLA:-8083}:8080
    environment:
      - TZ=${TZ}
      - PHPLDAPADMIN_LANGUAGE=${PHPLDAPADMIN_LANGUAGE}
      - PHPLDAPADMIN_PASSWORD_HASH=${PHPLDAPADMIN_PASSWORD_HASH}
      - PHPLDAPADMIN_SERVER_NAME=${PHPLDAPADMIN_SERVER_NAME}
      - PHPLDAPADMIN_SERVER_HOST=${PHPLDAPADMIN_SERVER_HOST}
      - PHPLDAPADMIN_BIND_ID=${PHPLDAPADMIN_BIND_ID}
    depends_on:
      - openldap
    networks:
      - ldapNet

secrets:
  openldap-root-password:
    file: ${DOCKERDIR}/data/config/ldap/secrets/${SLAPD_ROOTPW_SECRET}
  openldap-user-passwords:
    file: ${DOCKERDIR}/data/config/ldap/secrets/${SLAPD_USERPW_SECRET}
```

- create `.env` file

```bash
vim .env
-----------
#### SYSTEM
TZ=Europe/Berlin
DOCKERDIR=/opt/openldap

### Network
DOMAINNAME=mydomain.de
HOSTNAME0=ldap
PORT_LDAP=389
PORT_LDAPS=636
SUBNET=172.26.12

### === APP OpenLDAP ===
VERSION_OPENLDAP=latest
SLAPD_ORGANIZATION="My Organisation"
SLAPD_FQDN=${DOMAINNAME}
SLAPD_SUFFIX="dc=mydomain,dc=de"
SLAPD_ROOTDN="cn=admin,${SLAPD_SUFFIX}"
SLAPD_OU="ou=Users,"
# Plain-text admin password (pwgen -1cnsB 25 3)
SLAPD_ROOTPW=MySuperPaSSwOrD
SLAPD_ROOTPW_HASH=
SLAPD_PASSWORD_HASH=ARGON2
SLAPD_PWD_CHECK_QUALITY=2
SLAPD_PWD_MIN_LENGTH=10
SLAPD_PWD_MAX_FAILURE=5
SLAPD_ROOTPW_SECRET=openldap-root-password
SLAPD_USERPW_SECRET=openldap-user-passwords

### === PHPLDAPAdmin Alpine ===
DOMAINNAME_PLA=mydomain.de
HOSTNAME_PLA=pla
PORT_PLA=8080
PLA_VERSION=latest
PHPLDAPADMIN_LANGUAGE="de_DE"
PHPLDAPADMIN_PASSWORD_HASH="ssha"
PHPLDAPADMIN_SERVER_NAME="${SLAPD_ORGANIZATION} LDAP Server"
PHPLDAPADMIN_SERVER_HOST="ldap://${HOSTNAME0}.${DOMAINNAME}"
PHPLDAPADMIN_BIND_ID="cn=admin,${SLAPD_SUFFIX}"

# change rights
chmod 0600 /opt/openldap/.env
```

- Copy certifikate from ACME docker container

```bash
# copy cert from docker01
scp /opt/acme/data/acmedata/\*.mydomain.de_ecc/fullchain.cer root@pbs01:/opt/openldap/data/ssl/cert.pem
scp /opt/acme/data/acmedata/\*.mydomain.de_ecc/\*.mydomain.de.cer root@pbs01:/opt/openldap/data/ssl/tls.pem
scp /opt/acme/data/acmedata/\*.mydomain.de_ecc/\*.mydomain.de.key root@pbs01:/opt/openldap/data/ssl/tls.key

# change rights
chmod 0644 /opt/openldap/data/ssl/*
ls -lah /opt/openldap/data/ssl/

# show certificate
openssl x509 -in /opt/openldap/data/ssl/tls.crt -text -noout
```
- create dhparam file

```bash
openssl dhparam -dsaparam -out /opt/openldap/data/ssl/dhparam2.pem 4096
chmod 0644 /opt/openldap/data/ssl/*
ls -la /opt/openldap/data/ssl/
```
- Create an start docker container

```bash
docker-compose up -d
docker-compose ps
docker-compose logs
```

- check access to ldap server

```bash
# over API
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b "" -s base '(objectclass=*)' namingContexts

# over ldap
cat /opt/openldap/.env
dcexec openldap ldapsearch -x -H ldap://localhost -b dc=mydomain,dc=de -D "cn=admin,dc=mydomain,dc=de" -W

# over ldaps
cat /opt/openldap/.env
dcexec openldap ldapsearch -x -H ldaps://localhost -b dc=mydomain,dc=de -D "cn=admin,dc=mydomain,dc=de" -W
```


## Traefik integration

- create docker-compose.override.yml (For [phpldapadmin](https://github.com/johann8/phpldapadmin) behind RP Traefik)

```bash
vi docker-compose.override.yml
---------------------------
version: "3.2"
services:

  phpldapadmin:
    labels:
      - "traefik.enable=true"
      ### ==== to https ====
      - "traefik.http.routers.phpldapadmin-secure.entrypoints=websecure"
      - "traefik.http.routers.phpldapadmin-secure.rule=Host(`${HOSTNAME_PLA}.${DOMAINNAME_PLA}`)"
      - "traefik.http.routers.phpldapadmin-secure.tls=true"
      - "traefik.http.routers.phpldapadmin-secure.tls.certresolver=production"  # für eigene Zertifikate
      ### ==== to service ====
      - "traefik.http.routers.phpldapadmin-secure.service=phpldapadmin"
      - "traefik.http.services.phpldapadmin.loadbalancer.server.port=${PORT_PLA}"
      - "traefik.docker.network=proxy"
      ### ==== redirect to authelia for secure login ====
      - "traefik.http.routers.phpldapadmin-secure.middlewares=rate-limit@file,secHeaders@file"
      #- "traefik.http.routers.phpldapadmin-secure.middlewares=authelia@docker,rate-limit@file,secHeaders@file"
    networks:
      - proxy

networks:
  proxy:
    external: true
```

## Authelia integration

- `traefik` container: add middleware `authelia` into traefik config file

```bash
vim /opt/traefik/data/conf/traefik.yml
--------------------------------------
...
http:
...
  middlewares:
...
    authelia:
      forwardAuth:
        address: "http://authelia:9091/api/verify?rd=https://auth.mydomain.de"
        trustForwardHeader: true
...

# restart `Traefik` docker container
cd /opt/traefik && docker-compose up -d
```

- `authelia` container: add FQDN for PhpLdapAdmin web `pla.mydomain.de`

```bash
vim /opt/authelia/data/authelia/config/configuration.yml
--------------------------------------------------------
...
access_control:
  default_policy: deny 
  rules:
    - domain:
...
      - 'pla.mydomain.de'
      policy: one_factor
...

# restart `authelia` docker container
cd /opt/authelia && docker-compose up -d
```

- `openldap` container: change `docker-compose.override.yml` as below

```bash
vim /opt/openldap/docker-compose.override.yml
---------------------------------
version: "3.2"
services:

  phpldapadmin:
    labels:
      - "traefik.enable=true"
...
      #- "traefik.http.routers.phpldapadmin-secure.middlewares=rate-limit@file,secHeaders@file"
      - "traefik.http.routers.phpldapadmin-secure.middlewares=authelia@docker,rate-limit@file,secHeaders@file"
    networks:
      - proxy
...

# restart `openldap` docker container
cd /opt/openldap && docker-compose up -d
```

## PhpLdapAdmin integration

- add `phpldapadmin` service [Description here](https://github.com/johann8/phpldapadmin)

```bash
vim /opt/openldap/docker-compose.yml
---------------------------------
version: "3.2"
...
services:
...
  phpldapadmin:
    image: johann8/phpldapadmin:${PLA_VERSION}
    container_name: phpldapadmin
    restart: unless-stopped
    #volumes:
      #- ${DOCKERDIR}/data/html:/var/www/html
    ports:
      - 8083:8080
    environment:
      - TZ=${TZ}
      - PHPLDAPADMIN_LANGUAGE=${PHPLDAPADMIN_LANGUAGE}
      - PHPLDAPADMIN_PASSWORD_HASH=${PHPLDAPADMIN_PASSWORD_HASH}
      - PHPLDAPADMIN_SERVER_NAME=${PHPLDAPADMIN_SERVER_NAME}
      - PHPLDAPADMIN_SERVER_HOST=${PHPLDAPADMIN_SERVER_HOST}
      - PHPLDAPADMIN_BIND_ID=${PHPLDAPADMIN_BIND_ID}
    networks:
      - ldapNet
...
```

## Olefia integration

[Ofelia](https://github.com/mcuadros/ofelia) is a modern and low footprint job scheduler for docker environments, built on Go. We make a backup of `slapd` with the help of this service.

- add `ofelia` labels to `openldap` service

```bash
vim /opt/openldap/docker-compose.yml
---------------------------------
version: "3.2"
...
services:
  openldap:
...
    labels:
      ofelia.enabled: "true"
      ofelia.job-exec.slapd_backup_config.schedule: "0 0 2 * * *"
      ofelia.job-exec.slapd_backup_config.command: "/bin/sh -c \"/sbin/slapd-backup.sh 0 slapd-config || exit 0\""
      ofelia.job-exec.slapd_backup_data.schedule: "0 0 2 * * *"
      ofelia.job-exec.slapd_backup_data.command: "/bin/sh -c \"/sbin/slapd-backup.sh 1 slapd-data || exit 0\""
...
```

- Add `ofelia-openldap` service (If you already have `olefia` container, then you do not need to create another)

```bash
vim /opt/openldap/docker-compose.yml
---------------------------------
version: "3.2"
...
services:
...
  ofelia-openldap:
    image: mcuadros/ofelia:latest
    container_name: ofelia
    restart: always
    command: daemon --docker
    environment:
      - TZ=${TZ}
    depends_on:
      - openldap
    labels:
      ofelia.enabled: "true"
    security_opt:
      - label=disable
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - ldapNet
...
```

## Add ldap schema to old docker container

As of `docker image version 0.1.1`, I have also added the `postfix-book` schema.
Unfortunately, I could not find a way to add this schema automatically. I kept getting the error: \
"ldap_add: Other (e.g., implementation specific) error (80) additional info: olcAttributeTypes: Unexpected token before  SINGLE-VALUE )" \
Below you will find a description of how to add the schema `postfix-book.schema` to docker container before `docker image version 0.1.1` manually.


```bash
# Docker container stoppen
cd /opt/openldap && \
dc down

# Customize the .env file. As of this version, the schema postfix-book.schema is available in the Docker image.
vim .env
----------------
### === APP OpenLDAP ===
VERSION_OPENLDAP=0.1.1
----------------

# Create a backup
mv data data_bkp

# Create folder
mkdir -p /opt/openldap/data/{prepopulate,ldapdb,ssl,config,backup}
mkdir -p /opt/openldap/data/config/ldap/{slapd.d,ldif,secrets,custom-schema}
touch /opt/openldap/data/config/ldap/secrets/openldap-user-passwords
touch /opt/openldap/data/config/ldap/secrets/openldap-root-password
chmod 0600 /opt/openldap/data/config/ldap/secrets/openldap-user-passwords
chmod 0600 /opt/openldap/data/config/ldap/secrets/openldap-root-password
chown 100:101 /opt/openldap/data/config/ldap/slapd.d
tree /opt/openldap/

# Start the Docker container. The LDIF postfix-book.ldif is generated.
dc up -d

# Save the generated LDIF postfix-book.ldif to “custom-schema”. Adjust the number if necessary.
dcexec openldap sh
cd /etc/openldap/slapd.d/cn=config/cn=schema/
ls -la
cp cn={6}postfix-book.ldif ../../../custom-schema/
chown ldap:ldap ../../../custom-schema/cn=\{6}postfix-book.ldif
ls -la ../../../custom-schema/
exit

# Stop Conteiner, restore backup and copy LDIF postfix-book.ldif to folder “cn=schema”.
dc down 
mv data data_new
mv data_bkp data
cp data_new/config/ldap/custom-schema/cn\=\{6\}postfix-book.ldif data/config/ldap/slapd.d/cn\=config/cn\=schema/
ls -la data/config/ldap/slapd.d/cn\=config/cn\=schema/
chown 100:101 /opt/openldap/data/config/ldap/slapd.d/cn\=config/cn\=schema/cn\=\{6\}postfix-book.ldif
ls -la data/config/ldap/slapd.d/cn\=config/cn\=schema/

# Customize the .env file. 
vim .env
----------------
### === APP OpenLDAP ===
VERSION_OPENLDAP=latest
----------------

# Delete old Docker image and start Docker container.
docker images -a
docker rmi 11f6169e8b47
dc up -d

# Check the result
dcexec openldap ldapsearch -Q -LLL -Y EXTERNAL -H ldapi://%2Frun%2Fopenldap%2Fldapi -b cn=config postfix-book
```
- From now on the OpenLDAP config database is extended by the schema `postfix-book.schema`.

Enjoy !

