#!/bin/bash

#######################################################################
# Skripta ubija IP adrese koje drze vise od 100 konekcija 
# i salje na mail info uz logovanje u VestaCP. Koristim uz 
# VestaCP i iptables, kroz crontab koji je okida svake tri minute.
# Napravljeno iz zezanja ne znam gde se moze iskoristiti.
# ---------------------------------------------------------------------
# Autor: Darko Drazovic | kompjuteras.com
# Datum: 11.03.2018
#######################################################################

netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n | grep -v $(hostname -i) | grep -v '127.0.0.1' | grep -v [a-z] | tail -1 > /tmp/mnogo_konekcija.txt
KONEKCIJA=$(cat /tmp/mnogo_konekcija.txt | awk '{print $1}' )
SMARAC=$(cat /tmp/mnogo_konekcija.txt | awk '{print $2}' )
MAX_BROJ_KONEKCIJA="100"
ARHIVA='smaraci.txt'
MAIL_TO="noreply@kompjuteras.com"

if [ ${KONEKCIJA} -gt ${MAX_BROJ_KONEKCIJA} ]
        then
        if [ $( /usr/sbin/iptables -L -n | grep ${SMARAC} | wc -l ) -eq 0 ]
        then
                # Vesta nacin -------------------------
                if [ "$(cat /usr/local/vesta/data/firewall/rules.conf | grep ${SMARAC} | grep -v grep | wc -l )" -eq "0" ]
				 then
                  /usr/local/vesta/bin/v-add-firewall-rule drop ${SMARAC} 80,443 tcp SMARAC_${KONEKCIJA}
                  echo "/usr/local/vesta/bin/v-add-firewall-rule drop ${SMARAC} 80,443 tcp SMARAC_${KONEKCIJA}" >> ${ARHIVA}.vesta
                  # IPtables ubij odmah -----------------
                  /usr/sbin/iptables -t filter -I INPUT 1 -p tcp -m tcp -s ${SMARAC} -j DROP
                  echo "iptables -t filter -I INPUT 1 -p tcp -m tcp -s ${SMARAC} -j DROP" >> ${ARHIVA}.iptables
                  # Obavestenje -------------------------
                  echo "$(cat /tmp/mnogo_konekcija.txt)" | mutt -s "Novi smarac ${SMARAC} sa preko ${MAX_BROJ_KONEKCIJA} konekcija" ${MAIL_TO}
                fi
        fi
fi

exit 0
