#!/bin/bash
###################################################################################################
#                    Instalacija Icinga monitoring softvera na CentOS 7
#
# Skripta za automatsku instalaciju Icinga monitoringa i prateceg softvera na sveze instaliranom 
# CentOS 7 serveru u minimal varijanti. 
#
##################################################################################################
#
#-------------------------------------------------------------------------------------------------
#-- Naziv skripte       : Install_Icinga_on_CentOS7.sh
#-- Kreirano            : 14/05/2017
#-- Autor               : Darko Drazovic (kompjuteras.com)
#-------------------------------------------------------------------------------------------------
# Parametri
#-------------------------------------------------------------------------------------------------

DB_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
DB_ICINGA_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)

#-------------------------------------------------------------------------------------------------

# Da li je ovo CentOS 7
if [ $(grep "CentOS Linux release 7" /etc/redhat-release 2>/dev/null | wc -l) -ne 1 ]
  then echo "Nije ti ovo CentOS 7, izlazim" ; exit 1
fi
	

# Instalacija potrebnih repoa i update
yum install epel-release centos-release-scl -y
yum install -y https://packages.icinga.com/epel/icinga-rpm-release-7-latest.noarch.rpm
yum update -y

# Instalacija potrebnog softvera
yum install httpd mariadb mariadb-server php php-gd php-intl php-ldap php-ZendFramework  php-ZendFramework-Db-Adapter-Pdo-Mysql rh-php71-php-fpm sclo-php71-php-pecl-imagick-devel icinga2 mailx nagios-plugins-all icinga2-selinux vim-icinga2 icinga2-ido-mysql icingaweb2 icingacli vim -y

# Potrebne izmene u fajlovima
DATE="$(date +%Y%m%d%H%M%S)"
cp -p /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome_conf_${DATE}
cp -p /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd_conf_${DATE}
cp -p /etc/icinga2/features-available/ido-mysql.conf /etc/icinga2/features-available/ido-mysql_conf_${DATE}
sed -i 's/^/###########&/g' /etc/httpd/conf.d/welcome.conf
sed -i "s/Options Indexes FollowSymLinks/Options FollowSymLinks/g" /etc/httpd/conf/httpd.conf
sed -i s/"\/\/"/""/g /etc/icinga2/features-available/ido-mysql.conf
sed -i "s/password = \"icinga\"/password = \"${DB_ICINGA_PASSWORD}\"/g" /etc/icinga2/features-available/ido-mysql.conf


# Dodavanje firewall pravila za http
firewall-cmd --add-service=http
firewall-cmd --permanent --add-service=http

# mysql_secure_installation i pravljenje baze za icinga
systemctl start mariadb.service
mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_PASSWORD}') WHERE User='root';"
mysql -u root -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -u root -e "DROP DATABASE IF EXISTS test;"
mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -u root -e "CREATE DATABASE icinga;"
mysql -u root -e "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icinga.* TO icinga@localhost IDENTIFIED BY '${DB_ICINGA_PASSWORD}';"
mysql -u root icinga < /usr/share/icinga2-ido-mysql/schema/mysql.sql
mysql -u root -e "FLUSH PRIVILEGES;"

# Dodaavanje potrebnih modula i config web patha
icinga2 feature enable ido-mysql
icinga2 feature enable command
usermod -a -G icingacmd apache
usermod -a -G icingaweb2 apache
icingacli setup config webserver apache --document-root /usr/share/icingaweb2/public

# Izrada tokena za web install kroz browser
icingacli setup token create > ~/icinga_token.txt
cat ~/icinga_token.txt
chmod +w /etc/icingaweb2
chcon -R -t httpd_sys_content_rw_t /etc/icingaweb2
echo '<meta http-equiv="refresh" content="0; URL='/icingaweb2'" />' > /var/www/html/index.html
sed -i s/";date.timezone ="/"date.timezone = Europe\/Belgrade"/g /etc/opt/rh/rh-php71/php.ini

# Selinux podesavanja za Icinga
systemctl start icinga2.service
/usr/share/doc/icinga2-selinux-*/icinga2.sh

# Promena e-mail adrese za notifikacije sa Icinge
if [ $# -eq 1 ]
then
  sed -i "s/icinga@localhost/$1/g" /etc/icinga2/conf.d/users.conf
fi

# Pokretanje servisa potrebnih za icinga i postavljanje da se dizu sa sistemom
systemctl enable icinga2.service rh-php71-php-fpm.service httpd.service mariadb.service
systemctl restart icinga2.service rh-php71-php-fpm.service httpd.service mariadb.service

# Info za install
clear
echo "-------------------------------------------------------------------------------
Sad sa browserom idite na : http://IP_ADRESA_SERVERA za inicijalni setup
Root DB uname/upass       : root   /   ${DB_ROOT_PASSWORD}
Icinga uname/upass        : icinga /   ${DB_ICINGA_PASSWORD}
-------------------------------------------------------------------------------
(imate sve ove info u fajlu $(echo ~/icinga_token.txt)" >> ~/icinga_token.txt
cat ~/icinga_token.txt
