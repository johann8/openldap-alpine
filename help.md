## RootDN
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b "cn=config" "(olcRootDN=*)" olcSuffix olcRootDN olcRootPW -LLL -Q

## Log level
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b cn=config "(objectClass=olcGlobal)" olcLogLevel -LLL -Q

## PW Policy
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b "dc=wassermanngruppe,dc=de" -LLL -Q "(cn=passwordDefault)"
dcexec openldap slapcat -n 0

## PasswordHash
dcexec openldap slapcat -n 0 -a olcPasswordHash=*

## supportedSASLMechanisms
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b "" -LLL -s base supportedSASLMechanisms
dcexec openldap ldapsearch -x -H ldap://localhost -s base -b "" -D "cn=admin,dc=wassermanngruppe,dc=de" -W -LLL supportedSASLMechanisms
dcexec openldap ldapsearch -x -H ldaps://localhost -s base -b "" -D "cn=admin,dc=wassermanngruppe,dc=de" -W -LLL supportedSASLMechanisms
dcexec openldap ldapsearch -ZZ -x -H ldap://localhost -s base -b "" -D "cn=admin,dc=wassermanngruppe,dc=de" -W -LLL supportedSASLMechanisms

## TLS
dcexec openldap slapcat -b "cn=config" | grep olcTLS

## Show access permission 
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b cn=config '(olcDatabase={1}mdb)' olcAccess

## Show modules
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b "cn=config" -LLL -Q "objectClass=olcModuleList"
dcexec openldap slapcat -n 0 | grep -i module

## Show backends
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b "cn=config" -LLL -Q "objectClass=olcBackendConfig"

## Show databases
dcexec openldap ldapsearch -H ldapi://%2Frun%2Fopenldap%2Fldapi -Y EXTERNAL -b "cn=config" -LLL -Q "olcDatabase=*" dn

## keys 
```
  -b basedn  base dn for search
  -f file    read operations from `file'
  -F prefix  URL prefix for files (default: file:///tmp/)
  -l limit   time limit (in seconds, or "none" or "max") for search
  -L         print responses in LDIFv1 format
  -LL        print responses in LDIF format without comments
  -LLL       print responses in LDIF format without comments
             and version
  -M         enable Manage DSA IT control (-MM to make critical)
  -P version protocol version (default: 3)
  -s scope   one of base, one, sub or children (search scope)
  -S attr    sort the results by attribute `attr'
  -t         write binary values to files in temporary directory
  -tt        write all values to files in temporary directory
  -T path    write files to directory specified by path (default: /tmp)
  -u         include User Friendly entry names in the output
  -z limit   size limit (in entries, or "none" or "max") for search
  -H URI     LDAP Uniform Resource Identifier(s)
  -I         use SASL Interactive mode
  -n         show what would be done but don't actually do it
  -N         do not use reverse DNS to canonicalize SASL host name
  -O props   SASL security properties
  -o <opt>[=<optparam>] any libldap ldap.conf options, plus
             ldif_wrap=<width> (in columns, or "no" for no wrapping)
             nettimeout=<timeout> (in seconds, or "none" or "max")
  -Q         use SASL Quiet mode
  -R realm   SASL realm
  -U authcid SASL authentication identity
  -v         run in verbose mode (diagnostics to standard output)
  -V         print version info (-VV only)
  -w passwd  bind password (for simple authentication)
  -W         prompt for bind password
  -x         Simple authentication
  -X authzid SASL authorization identity ("dn:<dn>" or "u:<user>")
  -y file    Read password from file
  -Y mech    SASL mechanism
  -Z         Start TLS request (-ZZ to require successful response)
```
