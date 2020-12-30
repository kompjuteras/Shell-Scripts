#!/bin/bash
##################################################################################################
#      UPUTSTVO/SKRIPTA za pripremu masine za instalaciju Oracle softvera na CentOS 7 
#      ------------------------------------------------------------------------------
#
# Skripta za pripremu servera za instalaciju Oracle softvera, a u pripremu spada instalacija svih 
# potrebnih paketa, modifikacije sistema i kernela, postavljanje raznih limita i varijabli i slicno. 
# Odradice se instalacija svega i restartovace se server - a posle instalaciju samog softvera radite
# kroz GUI rucno, kliktanjem do smrti. Bicete pitani na ORACLE_SID, putanju do instalacionih fajlova
# i jos ponesto kad pokrenete skriptu - ali i za potvrdu kad unesete sve, tako da ako ste nesto
# zajebali mozete da izadjete iz dalje instalacije.
#
# NAPOMENA: Nakon restarta masine morate da instalirate Oracle kroz GUI, ima na kraju ove skripte
# kako. Skripta je testirana (ali  koriscena zestoko) na sveze instaliranom CentOS 7 sistemu u 
# minimal varijanti, na masini gde nema nikakvog dodatnog softvera.
#
##################################################################################################
#
#-------------------------------------------------------------------------------------------------
#-- Naziv skripte       : Install-Oracle12c-on-CentOS7.sh
#-- Kreirano            : 07/08/2018
#-- Autor               : Darko Drazovic (kompjuteras.com)
#-------------------------------------------------------------------------------------------------

# Ako korisnik samo pritisne enter - dodeli mu neke default vrednosti
set_default_value () { 
VARIABLE_NAME=$1 
VARIABLE_DEFAULT_VALUE=$2 
VARIABLE_VALUE=$3 

if [[ $(echo -n "$VARIABLE_VALUE" | wc -c) -eq 0 ]] ; then
	export ${VARIABLE_NAME}="${VARIABLE_DEFAULT_VALUE}"
fi
}

clear ; read -n 1 -p "
--------------------------------------------------------------------------------
Pritiskom na enter bez unosenja parametara automatski ce biti odabrana vrednosti
koja se nalazi u zagradi []. 
--------------------------------------------------------------------------------
Pritisnice bilo sta za nastavak... " INFO


###############################################################################
#---------------------  Potvrda da je CentOS cist ----------------------------- 
###############################################################################
clear
read -n 1 -p "
--------------------------------------------------------------------------------
Potvrdjujete da je:
- Instaliran CentOS 7 u minimal install varijanti
- Nije instaliran nikakav dodatni softver na njemu
- Da nema vama bitnih fajlova na masini sem Oracle instalacionih fajlova
- Da znate da ce masina biti restartovana kad se priprema za instaciju zavrsi
- Da ovu pripremu servera za instalaciju radite na sopstvenu odgovornost
--------------------------------------------------------------------------------
Y taster pristisnite za potvrdu, a bilo sta ako niste sigurni [N]: " POTVRDA
set_default_value POTVRDA "N" ${POTVRDA} ; echo

if [ "${POTVRDA}" != "Y" ]
	then echo "Niste odabrali Y, izlazim" ; exit 1 
fi

###############################################################################
#-----------------  Jesu li tu fajlovi za instalaciju ------------------------- 
###############################################################################
clear
read -p "Na kojoj putanji vam se nalaze linuxamd64_12102_database_se2_1of2.zip i
linuxamd64_12102_database_se2_2of2.zip za instalaciju Oracle softvera?
--------------------------------------------------------------------------------
PUTANJA DO INSTALACIONIH FAJLOVA [/root]: " ZIP
set_default_value ZIP "/root" ${ZIP}

if [ ! -f ${ZIP}/linuxamd64_12102_database_se2_1of2.zip ]; then
	echo "Nedostaje: ${ZIP}/linuxamd64_12102_database_se2_1of2.zip" && exit 1
fi
if [ ! -f ${ZIP}/linuxamd64_12102_database_se2_2of2.zip ] ; then
	echo "Nedostaje: ${ZIP}/linuxamd64_12102_database_se2_2of2.zip" && exit 1
fi


###############################################################################
#-----------------     VARIJABLE (ulazni parametri)   ------------------------- 
############################################################################### 
read -p "
--------------------------------------------------------------------------------
ORACLE_SID je parametar koji je potreban kasnije za instalaciju i koriscenje 
baze (dbca). Za instalaciju oracle nije potreban. Ovaj info ce se nalaziti u 
fajlu /home/oracle/.bash_profile pa ga mozete promeniti ako treba.
--------------------------------------------------------------------------------
ORACLE_SID [orcl]: " SID
set_default_value SID "orcl" ${SID}

read -p "
--------------------------------------------------------------------------------
CHARACTERSET koji ce se koristiti na datoj bazi podataka. Ova info nije bitna za 
instalaciju Oracle softvera. I ova info ce biti u .bash_profile.
--------------------------------------------------------------------------------
CHARACTERSET [AMERICAN_AMERICA.AL32UTF8]: " CHARACTERSET
set_default_value CHARACTERSET "AMERICAN_AMERICA.AL32UTF8" ${CHARACTERSET}

read -p "
--------------------------------------------------------------------------------
Portovi koji ce biti otvoreni za javnost. Paznja, portovi se dodaju na public 
tako da ako ce vam server biti na nekoj javnoj mrezi moracete da se poigrate sa 
firewalld ili iptables podesavanjima, kako bi zabranili bas javni pristup.
Ako ima vise portova koje treba otvoriti javno, razdvojte iz razmakom (space-om)
--------------------------------------------------------------------------------
OTVORENI_PORTOVI [1521] :" OTVORENI_PORTOVI
set_default_value OTVORENI_PORTOVI "1521" ${OTVORENI_PORTOVI}

read -p "
--------------------------------------------------------------------------------
Lozinka za korisnika oracle na Linuxu. Ovu lozinku mozete promeniti i kasnije 
tako sto cete se ulogovati kao root pa okinuti komandu: passwd oracle
--------------------------------------------------------------------------------
ORACLE_LOZINKA [lozinka123]: " ORACLE_LOZINKA
set_default_value ORACLE_LOZINKA "lozinka123" ${ORACLE_LOZINKA}

read -p "
--------------------------------------------------------------------------------
Gde je plan da se drze Oracle related fajlovi? Najbolje je da to bude izdvojena 
partiticija ili disk u ne-LVMu. Obicno koristimo /u01
--------------------------------------------------------------------------------
ORACLE_RELATED_FILES [/u01]: " ORACLE_RELATED_FILES
set_default_value ORACLE_RELATED_FILES "/u01" ${ORACLE_RELATED_FILES}

read -p "
--------------------------------------------------------------------------------
Ostavljamo li selinux ili ne?
Ako se na ovom serveru planirate samo da imate Oracle bazu podataka koja ce
osluskivati na standardnom portu (1521) onda je preporuka da ostavite selinux
startovanim (u enforce modu) ali ako planirate jos nesto ovde da vrtite onda 
razmislite ili o podesavanju selinuxa ili njegovom gasenju. 
Ako pristisnete bilo sta drugo sem tastera ENTER ili Y, selinux ce ostati u 
enforce modu a ako pritisnete bilo sta drugo, selinux ce biti ugasen.
Ovo mozete i naknadno promeniti u fajlu /etc/selinux/config
--------------------------------------------------------------------------------
SELINUX_ENABLED [Y]: " SELINUX_ENABLED
set_default_value SELINUX_ENABLED "Y" ${SELINUX_ENABLED}

clear ; \
echo -e "Ovo su varijable koje ce se primeniti u ovoj instalaciji
--------------------------------------------------------------------------------
ORACLE_SID=${SID} 
CHARACTERSET=${CHARACTERSET}  
OTVORENI_PORTOVI=${OTVORENI_PORTOVI}
ORACLE_LOZINKA=${ORACLE_LOZINKA}  
ORACLE_RELATED_FILES=${ORACLE_RELATED_FILES}  "
echo -e "\e[31mPAZNJA: SERVER CE BITI RESTARTOVAN PRILIKOM INSTALACIJE\e[0m" ; 
read -n 1 -p "
--------------------------------------------------------------------------------
Pritisnite Y ako je sve ovo OK i bilo sta za prekid instalacije: " AGREE ; echo

if [ "${AGREE}" != "Y" ] ; then echo "Niste odabrali Y, izlazim" ; exit 1 ; else echo "Sve OK" ; fi

###############################################################################
#-------------  Priprema masine za Oracle install (start) --------------------- 
###############################################################################

echo "ORACLE_SID=${SID}
NLS_LANG=${CHARACTERSET}
OTVORENI PORTOVI NA SERVERU=${OTVORENI_PORTOVI}
ORACLE_LOZINKA=${ORACLE_LOZINKA}
PUTANJA ZA ORACLE BAZU I FAJLOVE=${ORACLE_RELATED_FILES}
HOSTNAME=$(hostname)" > ~/.oracle_install_env.txt

# Update sve nakon instalacije
yum update -y 


if [[ ${SELINUX_ENABLED} != "Y" ]] ; then
# Gasimo SElinux
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
fi

# Podesavanje FIREWALLa
for i in ${OTVORENI_PORTOVI} ; do firewall-cmd --permanent --add-port=$i/tcp ; done
firewall-cmd --reload

# Install GUI-ja
yum groupinstall gnome-desktop x11 fonts -y

# Install potrebnih paketa za oracle
yum install binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ glibc glibc-devel ksh libgcc libstdc++ libstdc++-devel libaio libaio-devel libXext libXtst libX11 libXau libxcb libXi make sysstat libXmu libXt libXv libXxf86dga libdmx libXxf86misc libXxf86vm xorg-x11-utils xorg-x11-xauth -y

# Install paketa koji ce nama trebati u radu (nije potrebno za Oracle)
yum install epel-release -y
yum install unzip tigervnc-server bc gcc gcc-c++ bzip2 p7zip vim -y

# Kernel parametri (preporuceni)
cp /etc/sysctl.conf ~/backup_sysctl.conf
echo "
######### ORACLE PARAMETRI ############
vm.swappiness = 1
vm.dirty_background_ratio = 3
vm.dirty_ratio = 80
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
kernel.shmmax = 4398046511104
kernel.shmall = 1073741824
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
fs.file-max = 6815744
fs.aio-max-nr = 1048576
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
kernel.panic_on_oops = 1
#######################################
" >> /etc/sysctl.conf

# Disable transparent huge pages on boot
cp /etc/default/grub /etc/default/OLD_grub.old
if [ $(grep 'transparent_hugepage' /etc/default/grub | wc -l) -eq 0 ] ; then 
sed -i s/"rhgb quiet"/"rhgb quiet transparent_hugepage=never"/g /etc/default/grub
fi

grub2-mkconfig -o /boot/grub2/grub.cfg


# Pravljenje korisnika
groupadd --gid 54321 oinstall
groupadd --gid 54322 dba
groupadd --gid 54323 asmdba
groupadd --gid 54324 asmoper
groupadd --gid 54325 asmadmin
groupadd --gid 54326 oper
groupadd --gid 54327 backupdba
groupadd --gid 54328 dgdba
groupadd --gid 54329 kmdba
useradd --uid 54321 --gid oinstall --groups dba,oper,asmdba,asmoper,backupdba,dgdba,kmdba oracle
echo "${ORACLE_LOZINKA}" | passwd oracle --stdin

# Limiti
touch /etc/security/limits.d/99-oracle-limits.conf
echo '# Oracle limits
oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536
oracle soft stack 10240
oracle hard stack 32768
'  >> /etc/security/limits.d/99-oracle-limits.conf
cat /etc/security/limits.d/99-oracle-limits.conf

# Dodati info za svaki slucaj da su limiti u drugom fajlu, da ne bi bilo zabune
cp /etc/security/limits.conf ~/backup_limits.conf
echo "
# Oracle limits are in file: limits.d/99-oracle-limits.conf
" >> /etc/security/limits.conf
cat /etc/security/limits.conf

# Podesavanje velicine /dev/shm-a na velicinu RAM-a
cp /etc/fstab ~/backup_fstab
TOTAL_RAM=$(free -b | sed -n '2p' | awk '{print $2}') 
cp -p /etc/fstab /root/fstab_$(date +%F-%H%M%s)_BKP
sed -i s/"tmpfs         "/"#tmpfs         "/g /etc/fstab
echo "tmpfs     /dev/shm     tmpfs     size=${TOTAL_RAM}     0 0" >> /etc/fstab
cat /etc/fstab
mount -o remount tmpfs
df -h /dev/shm # Total RAM size

# Ulimiti za Oracle usera
echo '# Setting the appropriate ulimits for oracle and grid user
if [ $USER = "oracle" ]; then
if [ $SHELL = "/bin/ksh" ]; then
ulimit -u 16384
ulimit -n 65536
else
ulimit -u 16384 -n 65536
fi
fi' > /etc/profile.d/oracle-user.sh
chmod +x /etc/profile.d/oracle-user.sh
cat /etc/profile.d/oracle-user.sh

# Pravljenje putanja za BAZU, download i instalacija. U ovom slucaju instalacija je na internom
# sajtu kako bi bila laksa za install kroz skripte, posto ne moze da se skine direktno sa 
# sajta Oracle-a nego trazi login pre downloada (download je besplatan). 
# Arhiva je, s obzirom da je javna, u 7-zip formatu i zasticena lozinkom
# mkdir -p ${ORACLE_RELATED_FILES}/app/oracle/oracle-software
# cd ${ORACLE_RELATED_FILES}/app/oracle/oracle-software


# Instalacioni fajlovi
mkdir -p ${ORACLE_RELATED_FILES}/app/oracle/oracle-software
mv ${ZIP}/linuxamd64_12102_database_se2_* ${ORACLE_RELATED_FILES}/app/oracle/oracle-software/
cd ${ORACLE_RELATED_FILES}/app/oracle/oracle-software/

# Provera da li je fajl dobar 
md5sum -c <<<"dadbf2cfbc9b53f92d0b07f6677af966 linuxamd64_12102_database_se2_1of2.zip" &> /dev/null 
[ $? -ne 0 ] && echo "linuxamd64_12102_database_se2_1of2.zip PROBLEM" && exit || echo "SVE OK" 
md5sum -c <<<"2bda8cd4883bbd3f892dc152e568fc9e linuxamd64_12102_database_se2_2of2.zip" &> /dev/null 
[ $? -ne 0 ] && echo "linuxamd64_12102_database_se2_2of2.zip PROBLEM" && exit || echo "SVE OK" 

#
# Raspakivanje
unzip linuxamd64_12102_database_se2_1of2.zip ; rm -f linuxamd64_12102_database_se2_1of2.zip
unzip linuxamd64_12102_database_se2_2of2.zip ; rm -f linuxamd64_12102_database_se2_2of2.zip
chown -R oracle:oinstall ${ORACLE_RELATED_FILES}


# Postavljanje Oracle varijabli
echo "
# ------------------------------------------------------------------
# ORACLE VARIABLES -------------------------------------------------
# ------------------------------------------------------------------
ORACLE_SID=${SID} 
NLS_LANG=${CHARACTERSET}
ORACLE_BASE=${ORACLE_RELATED_FILES}/app/oracle
ORACLE_HOSTNAME=$(hostname)" >> /home/oracle/.bash_profile
echo 'ORACLE_HOME="${ORACLE_BASE}/product/12.1.0/dbhome_1"
LD_LIBRARY_PATH=${ORACLE_HOME}/lib:/lib:/usr/lib:/usr/lib64
CLASSPATH=${ORACLE_HOME}/jlib:${ORACLE_HOME}/rdbms/jlib 
export ORACLE_SID NLS_LANG ORACLE_BASE ORACLE_HOME ORACLE_HOSTNAME LD_LIBRARY_PATH CLASSPATH
# ------------------------------------------
PATH=${ORACLE_HOME}/bin:$PATH ; export PATH
' >> /home/oracle/.bash_profile
cat /home/oracle/.bash_profile

# Samo info da ostane u /etc/hosts
cp -p /etc/hosts /root/hosts_$(date +%F-%H%M%s)_BKP
cp -p /etc/hostname /root/hostname_$(date +%F-%H%M%s)_BKP
echo "# If you change hostname, also change that info in ORACLE_HOSTNAME@/home/oracle/.bash_profile" >> /etc/hosts
echo "# If you change hostname, also change that info in ORACLE_HOSTNAME@/home/oracle/.bash_profile" >> /etc/hostname

# Smara za prihvat licence, nece proci precheck i pokazace runlevel problem koji nidje veze. Ovo 
# ce se desiti ako smo naknadno instalirali GUI na Minimal install
yum remove initial-setup initial-setup-gui -y

# Reboot da povuce sve, ako je bilo update kernela i slicno
reboot

###################################################################################################
#------------------------  Priprema masine za Oracle install (end) -------------------------------- 
###################################################################################################


#------------------------------------------------------------------------------
#                    Instalacija Oracle softvera 
#                        (ovo sad mora rucno)
#------------------------------------------------------------------------------

# Otvaramo port za VNC sa lokalne mreze (stavite svoju IP umesto opsega 192.168.0.0/16)
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.0.0/16" port protocol="tcp" port="5901" accept'

# Startuj VNC kao Oracle i pokreni instalaciju
# Adresa za VNC je IP_adresa:screen, tj npr 192.168.144.56:1
su - oracle
vncserver

# Pokreni kroz VNC viewer (koristi TightVNC). Putanja do donje komande zavisi od toga gde ste 
# raspakovali instalaciju (na nasem slucaju zavisi od varijable ORACLE_RELATED_FILES
${ORACLE_BASE}/oracle-software/database/runInstaller

# Posle instalacije i podizanja baze vise vam GUI nece trebati, tako da mozete 
# da ugasite VNCserver
vncserver -kill :1

# ...ulogujete se nazad kao root i ubijete VNC port
firewall-cmd --zone=public --remove-rich-rule='rule family="ipv4" source address="192.168.0.0/16" port protocol="tcp" port="5901" accept'
