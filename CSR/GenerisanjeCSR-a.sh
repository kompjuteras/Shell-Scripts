#!/bin/bash
###################################################################################################
#             Interkativna skripta za generisanje CSR-a na bilo kom Linux serveru
#
# Skripta za generisanje CSR-a i kljuca, potrebnih za kupovinu SSL/TLS sertifikata
#
##################################################################################################
#
#-------------------------------------------------------------------------------------------------
#-- Naziv skripte       : GenerisanjeCSR-a.sh
#-- Kreirano            : 16/05/2018
#-- Autor               : Darko Drazovic (kompjuteras.com)
#-------------------------------------------------------------------------------------------------
# Parametri
#-------------------------------------------------------------------------------------------------
 
# Provera da li je instaliran openssl potreban za generisanje CRS-a
if [ `hash openssl 2>/dev/null  ; echo $?` -gt 0 ] ; then 
	echo "Fali ti openssl, instaliraj prvo to pa onda pokreni ovo" ; else
		#--------------------------- INPUT ----------------------------#
		unset CSR_DOMEN ; unset CSR_DRZAVA ; unset CSR_ADMIN_EMAIL ; unset CSR_OU ; unset ORG ; \
		unset CSR_ORGANIZACIJA ; unset CSR_COUNTRY_CODE ; unset CSR_GRAD ; unset CSR_NA_MAIL ; \
		clear ; \
		read -p "Vas Domen (npr: kompjuteras.com): " CSR_DOMEN ; \
		read -p "Drzava (npr: Serbia): " CSR_DRZAVA ; \
		read -p "Grad (npr: Belgrade): " CSR_GRAD ; \
		read -p "Skracenica za drzavu (2 slova, npr: RS): " CSR_COUNTRY_CODE ; \
		read -p "Kompanija ili organizacija (npr: Kompjuteras d.o.o): " CSR_ORGANIZACIJA ; \
		read -p "Organizaciona jedinica (ako ne znate samo pritisnite enter): " CSR_OU ; \
		read -p "E-mail adresa (npr: mail@example.com): " CSR_ADMIN_EMAIL 
		#--------------------------------------------------------------#
		
		rm -f ${CSR_DOMEN}.csr 
		rm -f ${CSR_DOMEN}.key
		if [ `echo ${CSR_OU} | wc -c` -gt 1 ] ; then ORG="OU=${CSR_OU}" ; fi
 
		# Generisanje CSR-a
		openssl req -new -sha256 -nodes -out ${CSR_DOMEN}.csr -newkey rsa:2048 -keyout ${CSR_DOMEN}.key -config <(
		cat <<-EOF
		[req]
		default_bits = 2048
		prompt = no
		default_md = sha256
		req_extensions = req_ext
		distinguished_name = dn
		 
		[ dn ]
		C="${CSR_COUNTRY_CODE}"
		ST="${CSR_DRZAVA}"
		L="${CSR_GRAD}"
		O="${CSR_ORGANIZACIJA}"
        ${ORG}
		emailAddress="${CSR_ADMIN_EMAIL}"
		CN="${CSR_DOMEN}"
		 
		[ req_ext ]
		subjectAltName = @alt_names
		 
		[ alt_names ]
		DNS.1 = "${CSR_DOMEN}"
		DNS.2 = "www.${CSR_DOMEN}"
		EOF
		) 
 
		# Provera
		echo "#-----------------------------------------------------"
		openssl req -noout -text -in ${CSR_DOMEN}.csr
		echo "#-----------------------------------------------------"
		echo "CSR fajl je      : ${PWD}/${CSR_DOMEN}.csr"
		echo "Privatni kljuc je: ${PWD}/${CSR_DOMEN}.key"
		echo "#-----------------------------------------------------"
fi
