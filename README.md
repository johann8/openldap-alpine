<h1 align="center">OpenLDAP</h1>
<p align='justify'>
<a href="https://openldap.org)">OpenLDAP</a>OpenLDAP
</p>

## OCS Inventory Docker Image
| pull | size alpine | version | platform | alpine version |
|:---------------------------------:|:----------------------------------:|:--------------------------------:|:--------------------------------:|:--------------------------------:|
| ![Docker Pulls](https://img.shields.io/docker/pulls/johann8/alpine-openldap?logo=docker&label=pulls&style=flat-square&color=blue) | ![Docker Image Size](https://img.shields.io/docker/image-size/johann8/alpine-openldap/latest?logo=docker&style=flat-square&color=blue&sort=semver) | [![](https://img.shields.io/docker/v/johann8/alpine-openldap/latest?logo=docker&style=flat-square&color=blue&sort=semver)](https://hub.docker.com/r/johann8/alpine-openldap/tags "Version badge") | ![](https://img.shields.io/badge/platform-amd64-blue "Platform badge") | [![Alpine Version](https://img.shields.io/badge/Alpine%20version-v3.18.0-blue.svg?style=flat-square)](https://alpinelinux.org/) |

## Install OpenLDAP

- create folders

### Variables

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

If overriding default root DN, it should be specified in the form `cn=admin,dc=example,dc=com`.

The root password must be specified in one of three ways:

* `SLAPD_ROOTPW` - plain text value, only for testing
* `SLAPD_ROOTPW_HASH` - encrypted value starting with `{PBKDF2-SHA512}`
* `openldap-ro-password` secret - most secure place to store the hash

You will want to override values for `SLAPD_FQDN` and `SLAPD_ORGANIZATION`. All the other default values will work for many typical use-cases.

User passwords are normally initialized by the administrator using `ldappasswd`, and from then on updated by the user (through the same tool or protocol). With this image, you can also define user passwords by providing their (hashed) values via a secret. Don't use `ldappasswd` to update passwords that are provided with the latter method: use it to generate a new hashed value and update the secret.
### Volumes

Mount these path names to persistent storage; all are optional.

Path | Description
---- | -----------
/etc/openldap/prepopulate | Zero or more .ldif files to load upon startup
/var/lib/openldap/openldap-data | Persistent storage for ldap database
/etc/ssl/openldap | TLS/SSL certificate

### Secrets

Secret | Description
------ | -----------
openldap-rootpw | Hashed password (key name openldap-rootpw-hash)
openldap-ssl | Certificate (cacert.pem, tls.crt, tls.key)
openldap-user-passwords | Hashed passwords (in _user: {PBK...} hash_ form)
