#!/bin/bash
##################################################################################################
#                      Provera slobodnog prostora na masini
#
# Crontab skripta proverava koliko ima slobodnog prostora na particijima, te ako ima ispod 
# dozvoljenih vrednosti salje mail na definisanu email adresu. Prvo okinuti rucno kako bi se 
# testiralo (treba mu program mail(x), ima provera u samoj skripti). 
#
# Primer okidanja: ./Check-HDD-space.sh 95 someone@example.com
#
##################################################################################################
#
#-------------------------------------------------------------------------------------------------
#-- Naziv skripte       : Check-HDD-space.sh
#-- Autor               : Darko Drazovic | Kompjuteras.com
#-- Input parametri     : Broj od 0-99 (max dozvoljeno iskoriscenog prostora na particiji),
#--                       E-mail adresa(e) na koju ce da se salju mailovi ako bude belaja
#-------------------------------------------------------------------------------------------------
# Parametri
#-------------------------------------------------------------------------------------------------
if [ $# -lt 2 ] ; then
echo "Nedostaju ulazni parametri. Primer: ${0} 90 someone@example.com someone-else@example2.com"
exit 1
fi

# Env
if [ -f ~/.bash_profile ]; then
		. ~/.bash_profile
	else 
		. ~/.bashrc
fi

MAX_ALLOWED_USAGE_IN_PERCENTAGE=$1 ; shift
ALERT_SEND_TO="$*"

#-------------------------------------------------------------------------------------------------
# Provera
#-------------------------------------------------------------------------------------------------

# Je li instalirani potrebni programi -------------------------------
POTREBNI_PROGRAMI="mail"

for i in ${POTREBNI_PROGRAMI}
do
command -v ${i} 1>/dev/null 2>&1
if [ $? -ne 0 ] ; then
        echo "$(date) - Nije instaliran ${i}. Izlazim"
		exit 1
fi
done


# Provera prostora ---------------------------------------------------
HOSTNAME="$(hostname -s)"
ACTIVE_IP="$( ip addr | grep ',UP,' -A2 | grep 'inet ' | tail -n1 | awk '{print $2}' | cut -f1 -d'/')"
USED=$(df -P | awk '{print $5}' | grep [0-9] | sed 's/[^0-9]*//g' | sort -r | head -1)
 
if [ -n "$(df -P | awk "{ df=strtonum(\$5); if (df > ${MAX_ALLOWED_USAGE_IN_PERCENTAGE}) print; }")" ] ; then
        echo "$(df -Ph | awk "{ df=strtonum(\$5); if (df > ${MAX_ALLOWED_USAGE_IN_PERCENTAGE}) print; }")
		" | mail -s "${HOSTNAME} (${ACTIVE_IP}) - HDD space problem | Used ${USED}%" ${ALERT_SEND_TO}
fi

exit 0
