#!/bin/bash
##################################################################################################
# Half-automated script for Spacewalk installation and RedHat package sync 
# ------------------------------------------------------------------------------
# Script will do the following:
#  - Install Spacewalk 2.9
#  - Create RedHat and RedHat 7 channels
#  - Create some usual RedHat repositories 
#  - Create activation keys for clients
#  - Create crontab for package sync (every Sunday at 1AM)
#  - Use Postgress instead of sqlite for sessions storage
#  - Fix some bugs which I find during installation
# 
# To be done: Create selinux rules, use custom disk path for package store, jabberd password to 
# be used as a variable (now is fixed in script).
#
##################################################################################################
#
#-------------------------------------------------------------------------------------------------
#-- Created             : 01/Feb/2020
#-- Author              : Darko Drazovic (kompjuteras.com)
#-------------------------------------------------------------------------------------------------


# Some input parameters (change it by your will)
SERVER_IP_OR_DOMAIN="spacewalk-server.kompjuteras.com"
SPACEWALK_ADMIN_EMAIL="darko.drazovic@example.com"
SPACEWALK_USERNAME="spacewalkadmin"
SPACEWALK_PASSWORD="SomeSexyPassword"
SSL_EMAIL="darko.drazovic@example.com"
SSL_PASSWORD="fancySSLpass"
SSL_CNAME="spacewalk-server.draza"
SSL_ORG="KOMPJUTERAS"
SSL_ORG_UNIT="NA"
SSL_CITY="Belgrade"
SSL_STATE="Serbia"
SSL_XX_COUNTRY="YU"
PSQL_DB_NAME="spacewalkdb"
PSQL_DB_USERNAME="spacewalkuser"
PSQL_DB_PASSWORD="spacepass4KOMPJUTERAS"


# RedHat registration check
if [[ $(ls -l /etc/rhsm/ca/redhat-uep.pem /etc/pki/entitlement/*[0-9].pem /etc/pki/entitlement/*[0-9]-key.pem 2>/dev/null | wc -l) -lt 3 ]]
  then 
  echo "You are not properly registed to RedHat or related keys and certs missing. Please register system first" 
  echo "Check files: /etc/rhsm/ca/redhat-uep.pem /etc/pki/entitlement/*[0-9].pem /etc/pki/entitlement/*[0-9]-key.pem"
  exit 1
fi


# Check do you have enough space for synced packages and the installation. Recommendation is 200GB of free space
mkdir -p /var/satellite/
FREE_SPACE="$(df -hPBG /var/satellite/ | tail -1 | awk '{print $4}' | grep -o [0-9]*)"
if [[ ${FREE_SPACE} -lt 200 ]]
  then
    echo "----------------------------------------------------------------------------------"
    echo "You have ${FREE_SPACE}GB of free space in /var/satellite/ and recommendation is 200GB"
    echo "It will be not enough for downloaded packages, please extend that size if possible"
    echo "----------------------------------------------------------------------------------"
    df -hPT /var/satellite/
    echo "----------------------------------------------------------------------------------"
    read -n 1 -p  "Press Y if that is OK for you and we can continue: " OK ; echo
      if [[ ${OK} != Y ]] ; then
        echo "Exiting from the installation...." ; exit 1
      fi
fi
rm -rf /var/satellite/


# If firewalld running - add related rules. Also, stop Selinux (I didn't have time to deal with this)
systemctl status firewalld &> /dev/null
if [[ $? -eq 0 ]]
  then 
  firewall-cmd --add-service=http  --permanent
  firewall-cmd --add-service=https --permanent
  firewall-cmd --add-port=69/tcp   --permanent
  firewall-cmd --add-port=4545/tcp --permanent
  firewall-cmd --add-port=5222/tcp --permanent
  firewall-cmd --add-port=5269/tcp --permanent
  firewall-cmd --reload
fi
# selinux part
setenforce 0
sed -i s/"SELINUX=enforcing"/"SELINUX=permissive"/g /etc/selinux/config


# Install necessary packages end enable necessary repos
yum install -y yum-plugin-tmprepo pam_krb5
yum install -y spacewalk-repo --tmprepo=https://copr-be.cloud.fedoraproject.org/results/%40spacewalkproject/spacewalk-2.9/epel-7-x86_64/repodata/repomd.xml --nogpg
subscription-manager repos --enable rhel-7-server-optional-rpms
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum update -y
yum -y install spacewalk-setup-postgresql expect spacecmd


# Main install
yum -y install spacewalk-postgresql 


# Spacewalk initial setup
cat > /root/spacewalksetup.txt <<EOF
admin-email = ${SPACEWALK_ADMIN_EMAIL}
ssl-config-sslvhost = Y
ssl-password = ${SSL_PASSWORD}
ssl-set-cnames = ${SSL_CNAME}
ssl-set-org = ${SSL_ORG}
ssl-set-org-unit = ${SSL_ORG_UNIT}
ssl-set-email = ${SSL_EMAIL}
ssl-set-city = ${SSL_CITY}
ssl-set-state = ${SSL_STATE}
ssl-set-country = ${SSL_XX_COUNTRY}
db-backend=postgresql
db-name=${PSQL_DB_NAME}
db-user=${PSQL_DB_USERNAME}
db-password=${PSQL_DB_PASSWORD}
db-host=localhost
db-port=5432
enable-tftp=Y
EOF
spacewalk-setup --answer-file=/root/spacewalksetup.txt
rm -f /root/spacewalksetup.txt

# Change server URL
cp /etc/sysconfig/rhn/up2date /etc/sysconfig/rhn/up2date.backup
sed -i s/"enter.your.server.url.here"/"$(hostname -f)"/g /etc/sysconfig/rhn/up2date

# Allow httpd to follow symlinks (because of apps partition) on line 151
cp -p /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd_conf.backup
sed -i '151s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf

# Configure jabberd to use PostgreSQL database
systemctl stop jabberd tomcat spacewalk-wait-for-tomcat httpd spacewalk-wait-for-jabberd osa-dispatcher rhn-search cobblerd taskomatic spacewalk.target

cp /etc/jabberd/sm.xml /etc/jabberd/sm_xml.backup
sed -i s/"<driver>sqlite"/"<driver>pgsql"/g /etc/jabberd/sm.xml
sed -i s/"dbname=jabberd2 user=jabberd2 password=secret"/"dbname=jabberd2 user=jabberd2 password=jabberd2"/g /etc/jabberd/sm.xml

cp /etc/jabberd/c2s.xml /etc/jabberd/c2s_xml.backup
sed -i s/"<module>sqlite"/"<module>pgsql"/g /etc/jabberd/c2s.xml
sed -i s/"dbname=jabberd2 user=jabberd2 password=secret"/"dbname=jabberd2 user=jabberd2 password=jabberd2"/g /etc/jabberd/c2s.xml


# Create related psql database and user and add related permissions. 
runuser -l postgres -c expect <<'EOF'
spawn createuser -P -U postgres jabberd2
expect -exact "Enter password for new role: "
send -- "jabberd2\r"
expect -exact "Enter it again: "
send -- "jabberd2\r"
expect eof
EOF
runuser -l postgres -c 'createdb -U postgres -O jabberd2 jabberd2'

# Related psql permission and initial DB schema
echo "local jabberd2 jabberd2 md5" >> /var/lib/pgsql/data/pg_hba.conf
runuser -l postgres -c 'psql -l'
systemctl restart postgresql
runuser -l postgres -c 'export PGPASSWORD=jabberd2 ; psql -U jabberd2 jabberd2 < /usr/share/jabberd/db-setup.pgsql'


# Fix for change after jabberd start and some which I found related to Spacewalk 2.9
sed -i s/"After=network.target jabberd-router.service jabberd-sm.service jabberd-c2s.service jabberd-s2s.service"/"After=network.target jabberd-router.service jabberd-sm.service jabberd-c2s.service jabberd-s2s.service postgresql.service"/g /usr/lib/systemd/system/jabberd.service
systemctl daemon-reload

# Bugs related to Spacewalk 2.9 version
chmod 644 /etc/logrotate.d/osa-dispatcher
chmod 755 /var/log/cobbler 
chmod 755 /var/log/cobbler/tasks/


# Create initial Spacewalk user. 
/usr/sbin/spacewalk-service restart
LANG=C
tempfile=$(mktemp /tmp/$(basename $0).XXXXXX)
trap cleanup EXIT
cleanup() {
  exitcode=$?
  test -f "$tempfile" && rm -f "$tempfile"
  exit $exitcode
}
if [ "$(satwho | wc -l)" = "0" ]; then
  curl --silent https://localhost/rhn/newlogin/CreateFirstUser.do --insecure -D - >$tempfile

  cookie=$(egrep -o 'JSESSIONID=[^ ]+' $tempfile)
  csrf=$(egrep csrf_token $tempfile | egrep -o 'value=[^ ]+' | egrep -o '[0-9]+')

    curl --noproxy '*' \
      --cookie "$cookie" \
      --insecure \
      --data "csrf_token=-${csrf}&submitted=true&orgName=DefaultOrganization&login=${SPACEWALK_USERNAME}&desiredpassword=${SPACEWALK_PASSWORD}&desiredpasswordConfirm=${SPACEWALK_PASSWORD}&email=set-this-email%40localhost.local&prefix=Mr.&firstNames=Administrator&lastName=Spacewalk&" \
      https://localhost/rhn/newlogin/CreateFirstUser.do
  if [ "$(satwho | wc -l)" = "0" ]; then
    echo "Error: user creation failed" >&2
  fi
else
  echo "Error: There is already a user. Check with satwho. No user created." >&2
fi


# Apply RedHat certs into Spacewalk (will be used for RedHat repo sync)
cat > /tmp/path-one << EOF
spawn spacecmd -u ${SPACEWALK_USERNAME} -p ${SPACEWALK_PASSWORD} cryptokey_create
expect -exact "GPG or SSL \[G/S\]: "
send -- "SSL\r"
expect -exact "Description: "
send -- "RHEL SSL CA CERT\r"
expect -exact "Read an existing file \[y/N\]: "
send -- "y\r"
expect -exact "File: "
send -- "/etc/rhsm/ca/redhat-uep.pem\r"
expect eof
EOF
expect /tmp/path-one
  
cat > /tmp/path-one << EOF
spawn spacecmd -u ${SPACEWALK_USERNAME} -p ${SPACEWALK_PASSWORD} cryptokey_create
expect -exact "GPG or SSL \[G/S\]: "
send -- "SSL\r"
expect -exact "Description: "
send -- "RHEL SSL CLIENT CERT\r"
expect -exact "Read an existing file \[y/N\]: "
send -- "y\r"
expect -exact "File: "
send -- "$(ls -1trh /etc/pki/entitlement/*[0-9].pem | tail -1)\r"
expect eof
EOF
expect /tmp/path-one

cat > /tmp/path-one << EOF
spawn spacecmd -u ${SPACEWALK_USERNAME} -p ${SPACEWALK_PASSWORD} cryptokey_create
expect -exact "GPG or SSL \[G/S\]: "
send -- "SSL\r"
expect -exact "Description: "
send -- "RHEL SSL CLIENT KEY\r"
expect -exact "Read an existing file \[y/N\]: "
send -- "y\r"
expect -exact "File: "
send -- "$(ls -1trh /etc/pki/entitlement/*[0-9]-key.pem | tail -1)\r"
expect eof
EOF
expect /tmp/path-one

rm -f /tmp/path-one
  

# Create channel for RedHat 7 clients
expect << EOF
spawn spacecmd -u ${SPACEWALK_USERNAME} -p ${SPACEWALK_PASSWORD} softwarechannel_create
expect -exact "Channel Name: "
send -- "RHEL7 - 64 Bit\r"
expect -exact "Channel Label: "
send -- "rhel7-x86_64\r"
expect -exact "Channel Summary: "
send -- "Red Hat 7 Server\r"
expect -exact "Select Parent \[blank to create a base channel\]: "
send -- "\r"
expect -exact "Select: "
send -- "x86_64\r"
expect -exact "Select: "
send -- "sha1\r"
expect -exact "GPG URL: "
send -- "\r"
expect -exact "GPG ID: "
send -- "\r"
expect -exact "GPG Fingerprint: "
send -- "\r"
expect eof
EOF


# Create channel for RedHat 6 clients
expect << EOF
spawn spacecmd -u ${SPACEWALK_USERNAME} -p ${SPACEWALK_PASSWORD} softwarechannel_create
expect -exact "Channel Name: "
send -- "RHEL6 - 64 Bit\r"
expect -exact "Channel Label: "
send -- "rhel6-x86_64\r"
expect -exact "Channel Summary: "
send -- "Red Hat 6 Server\r"
expect -exact "Select Parent \[blank to create a base channel\]: "
send -- "\r"
expect -exact "Select: "
send -- "x86_64\r"
expect -exact "Select: "
send -- "sha1\r"
expect -exact "GPG URL: "
send -- "\r"
expect -exact "GPG ID: "
send -- "\r"
expect -exact "GPG Fingerprint: "
send -- "\r"
expect eof
EOF


# Function for create of repos and their attaching to channel
function add_repo () {
CHANNEL_NAME="${1}"
REPONAME="${2}"
REPOURL="${3}"
# Create Expect file
cat > /tmp/add_new_repo.expect << EOF
spawn spacecmd -u ${SPACEWALK_USERNAME} -p ${SPACEWALK_PASSWORD} repo_create
expect -exact "Name: "
send -- "${REPONAME}\r"
expect -exact "URL: "
send -- "${REPOURL}\r"
expect -exact "Type: "
send -- "yum\r"
expect -exact "SSL CA cert: "
send -- "RHEL SSL CA CERT\r"
expect -exact "SSL Client cert: "
send -- "RHEL SSL CLIENT CERT\r"
expect -exact "SSL Client key: "
send -- "RHEL SSL CLIENT KEY\r"
expect eof
EOF
   # Run expect file
   expect /tmp/add_new_repo.expect
   rm -f /tmp/add_new_repo.expect
   spacecmd -u ${SPACEWALK_USERNAME} -p ${SPACEWALK_PASSWORD} softwarechannel_addrepo ${CHANNEL_NAME} "${REPONAME}"
}


# Add Redhat 7 repos
add_repo "rhel7-x86_64" "Red Hat Enterprise Linux 7 Server RPMs"                    "https://cdn.redhat.com/content/dist/rhel/server/7/7Server/x86_64/os"
add_repo "rhel7-x86_64" "RHEL High Availability for RHEL 7 Server RPMs"             "https://cdn.redhat.com/content/dist/rhel/server/7/7Server/x86_64/highavailability/os"
add_repo "rhel7-x86_64" "RHEL High Availability for RHEL 7 Server EUS RPMs"         "https://cdn.redhat.com/content/eus/rhel/server/7/7Server/x86_64/highavailability/os"
add_repo "rhel7-x86_64" "Red Hat Enterprise Linux for Real Time RHEL 7 Server RPMs" "https://cdn.redhat.com/content/dist/rhel/server/7/7Server/x86_64/rt/os"
add_repo "rhel7-x86_64" "Red Hat Enterprise Linux 7 Server RH Common RPMs"          "https://cdn.redhat.com/content/dist/rhel/server/7/7Server/x86_64/rh-common/os"
add_repo "rhel7-x86_64" "Red Hat Enterprise Linux 7 Server Optional RPMs"           "https://cdn.redhat.com/content/dist/rhel/server/7/7Server/x86_64/optional/os"
add_repo "rhel7-x86_64" "Red Hat Enterprise Linux 7 Server Extras RPMs"             "https://cdn.redhat.com/content/dist/rhel/server/7/7Server/x86_64/extras/os"  
add_repo "rhel7-x86_64" "Red Hat Enterprise Linux 7 Server EUS RPMs"                "https://cdn.redhat.com/content/eus/rhel/server/7/7Server/x86_64/os"
add_repo "rhel7-x86_64" "Red Hat Enterprise Linux 7 Server EUS RH Common RPMs"      "https://cdn.redhat.com/content/eus/rhel/server/7/7Server/x86_64/rh-common/os"
add_repo "rhel7-x86_64" "Red Hat Enterprise Linux 7 Server EUS Optional RPMs"       "https://cdn.redhat.com/content/eus/rhel/server/7/7Server/x86_64/optional/os"
add_repo "rhel7-x86_64" "Red Hat Enterprise Linux 7 Resilient Storage RPMs"         "https://cdn.redhat.com/content/dist/rhel/server/7/7Server/x86_64/resilientstorage/os"
add_repo "rhel7-x86_64" "Red Hat Enterprise Linux 7 Resilient Storage EUS RPMs"     "https://cdn.redhat.com/content/eus/rhel/server/7/7Server/x86_64/resilientstorage/os" ### 531 packages
add_repo "rhel7-x86_64" "Red Hat Enterprise Linux 7 Developer Tools RPMs"           "https://cdn.redhat.com/content/dist/rhel/server/7/7Server/x86_64/devtools/1/os"

# Add Redhat 6 repos
add_repo "rhel6-x86_64" "Red Hat Developer Toolset 2 for RHEL 6 Server EUS RPMs"    "https://cdn.redhat.com/content/eus/rhel/server/6/6Server/x86_64/devtoolset/2/os"
add_repo "rhel6-x86_64" "Red Hat Developer Toolset 2 RPMs for RHEL 6 Server"        "https://cdn.redhat.com/content/dist/rhel/server/6/6Server/x86_64/devtoolset/2/os"
add_repo "rhel6-x86_64" "Red Hat Developer Toolset for RHEL 6 Server EUS RPMs"      "https://cdn.redhat.com/content/eus/rhel/server/6/6Server/x86_64/devtoolset/os"
add_repo "rhel6-x86_64" "Red Hat Developer Toolset RPMs for RHEL 6 Server"          "https://cdn.redhat.com/content/dist/rhel/server/6/6Server/x86_64/devtoolset/os"
add_repo "rhel6-x86_64" "Red Hat Enterprise Linux 6 Server EUS RPMs"                "https://cdn.redhat.com/content/eus/rhel/server/6/6Server/x86_64/os"
add_repo "rhel6-x86_64" "Red Hat Enterprise Linux 6 Server Optional RPMs"           "https://cdn.redhat.com/content/dist/rhel/server/6/6Server/x86_64/optional/os"
add_repo "rhel6-x86_64" "Red Hat Enterprise Linux 6 Server RPMs"                    "https://cdn.redhat.com/content/dist/rhel/server/6/6Server/x86_64/os"
add_repo "rhel6-x86_64" "RHEL High Availability for RHEL 6 Server EUS RPMs"         "https://cdn.redhat.com/content/eus/rhel/server/6/6Server/x86_64/highavailability/os"
add_repo "rhel6-x86_64" "RHEL High Availability for RHEL 6 Server RPMs"             "https://cdn.redhat.com/content/dist/rhel/server/6/6Server/x86_64/highavailability/os"
add_repo "rhel6-x86_64" "RHEL High Performance Networking for RHEL 6 Server RPMs"   "https://cdn.redhat.com/content/dist/rhel/server/6/6Server/x86_64/hpn/os"
add_repo "rhel6-x86_64" "RHEL Load Balancer for RHEL 6 Server EUS"                  "https://cdn.redhat.com/content/eus/rhel/server/6/6Server/x86_64/loadbalancer/os"
add_repo "rhel6-x86_64" "RHEL Load Balancer for RHEL 6 Server RPMs"                 "https://cdn.redhat.com/content/dist/rhel/server/6/6Server/x86_64/loadbalancer/os" ### 25 packages
add_repo "rhel6-x86_64" "RHEL Resilient Storage for RHEL 6 Server EUS RPMs"         "https://cdn.redhat.com/content/eus/rhel/server/6/6Server/x86_64/resilientstorage/os"
add_repo "rhel6-x86_64" "RHEL Resilient Storage for RHEL 6 Server RPMs"             "https://cdn.redhat.com/content/dist/rhel/server/6/6Server/x86_64/resilientstorage/os"
add_repo "rhel6-x86_64" "RHEL Scalable File System for RHEL 6 Server - EUS RPMs"    "https://cdn.redhat.com/content/eus/rhel/server/6/6Server/x86_64/scalablefilesystem/os"
add_repo "rhel6-x86_64" "RHEL Scalable File System RHEL 6 Server RPMs"              "https://cdn.redhat.com/content/dist/rhel/server/6/6Server/x86_64/scalablefilesystem/os"



# Create related activation key for RH7
expect << EOF
spawn spacecmd -u ${SPACEWALK_USERNAME} -p ${SPACEWALK_PASSWORD} activationkey_create
expect -exact "Name \(blank to autogenerate\): "
send -- "\r"
expect -exact "Description \[None\]: "
send -- "PatchManagement-RHEL7\r"
expect -exact "Base Channel (blank for default): "
send -- "rhel7-x86_64\r"
expect -exact "virtualization_host Entitlement \[y/N\]: "
send -- "y\r"
expect -exact "Universal Default \[y/N\]: "
send -- "n\r"
expect eof
EOF

# Create related activation key for RH6
expect << EOF
spawn spacecmd -u ${SPACEWALK_USERNAME} -p ${SPACEWALK_PASSWORD} activationkey_create
expect -exact "Name \(blank to autogenerate\): "
send -- "\r"
expect -exact "Description \[None\]: "
send -- "PatchManagement-RHEL6\r"
expect -exact "Base Channel (blank for default): "
send -- "rhel6-x86_64\r"
expect -exact "virtualization_host Entitlement \[y/N\]: "
send -- "y\r"
expect -exact "Universal Default \[y/N\]: "
send -- "n\r"
expect eof
EOF


echo "
#################################################################################
Installation is done...
URL: https://${SERVER_IP_OR_DOMAIN}
SPACEWALK_USERNAME: ${SPACEWALK_USERNAME}
SPACEWALK_PASSWORD: ${SPACEWALK_PASSWORD}
---
PSQL_UNAME: ${PSQL_DB_USERNAME}
PSQL_UPASS: ${PSQL_DB_PASSWORD}
#################################################################################
"


# Setup this after you initialy sync manualy packages from steps above
mkdir -p  /var/satellite/SCRIPTS
cat > /var/satellite/SCRIPTS/sync-repo.sh <<'EOF'
#!/bin/bash
# Results are logged in /var/log/rhn/reposync. Remove "--lastest".
# If you want to sync all packages, and not just the latest
/usr/bin/spacewalk-repo-sync --channel rhel7-x86_64 --latest 2>&1
/usr/bin/spacewalk-repo-sync --channel rhel6-x86_64 --latest 2>&1
EOF
chmod +x /var/satellite/SCRIPTS/sync-repo.sh

crontab -l > crontab_list
echo "# Spacewalk sync" >> crontab_list
echo "00 01 * * 0 /var/satellite/SCRIPTS/sync-repo.sh" >> crontab_list
crontab crontab_list
rm -f crontab_list

  
  
##############################################################################
exit 0
