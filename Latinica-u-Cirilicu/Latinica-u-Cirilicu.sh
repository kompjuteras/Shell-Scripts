#/bin/bash

############################################################################
# Skripta sklepana za konverziju latinicnih u cirilicne karaktere, uz force 
# odredjenih stringova koji ne bi trebali da budu cirilicni (tipa ДХЦП)
# ili koji bi trebali da se preimenuju drugacije nekeko, tipa WordPress
# u Вордпрес (te izuzetke pakujemo u fajl stringovi-za-force.txt.
# Sem preslovljavanja, radi 'ignore' linkova (href i src) kao i 
# ignorisanje u preslovljavanju reci koje sadrze YXQW slova. 
# 
# Okidanje: ./Latinica-u-Cirilicu.sh tekst-za-preslovljavanje.txt
# --------------------------------------------------------------------------
# Autor: Darko Drazovic | kompjuteras.com
# Datum: 20.07.2018
############################################################################

FAJL=$1

MALA_SLOVA_DUAL="lj:љ nj:њ dž:џ "
VELIKA_SLOVA_DUAL="LJ:Љ NJ:Њ DŽ:Џ Lj:Љ Nj:Њ Dž:Џ"
VELIKA_SLOVA_MONO="A:А B:Б V:В G:Г D:Д Đ:Ђ E:Е Ž:Ж Z:З I:И J:Ј K:К L:Л  M:М N:Н O:О P:П R:Р S:С T:Т Ć:Ћ U:У F:Ф H:Х C:Ц Č:Ч Š:Ш"
MALA_SLOVA_MONO="a:а b:б v:в g:г d:д đ:ђ e:е ž:ж z:з i:и j:ј k:к l:л  m:м n:н o:о p:п r:р s:с t:т ć:ћ u:у f:ф h:х c:ц č:ч š:ш A:А B:Б V:В G:Г D:Д Đ:Ђ E:Е Ž:Ж Z:З I:И J:Ј K:К L:Л  M:М N:Н O:О P:П R:Р S:С T:Т Ć:Ћ U:У F:Ф H:Х C:Ц Č:Ч Š:Ш"

echo
echo " | ПРЕСЛОВЉАВАЊЕ -------------------------------------------------------"
for i in ${MALA_SLOVA_DUAL} ${VELIKA_SLOVA_DUAL} ${VELIKA_SLOVA_MONO} ${MALA_SLOVA_MONO}
do 
	LATINICA="$(echo $i | cut -d ':' -f 1)"
	CIRILICA="$(echo $i | cut -d ':' -f 2)"
	sed -i s/"$LATINICA"/"$CIRILICA"/g $FAJL
done


echo " | РЕВЕРТ РЕЧИ СА СЛОВИМА QWYX -----------------------------------------"
rm -f /tmp/privremeno_linkovi.txt
rm -f /tmp/ignorisati.txt
rm -f /tmp/temp_12332.txt
rm -f /tmp/izvrsi.sh
rm -f /tmp/izvrsi.txt
for i in $(cat $FAJL)
 do
  if [ $(echo ${i} | grep [qwxyQWXY] | grep -v '#' | grep -v 'блоцкqуоте' | wc -l) -gt 0 ] ; then
	echo ${i} | cut -d '=' -f1 >> /tmp/privremeno_linkovi.txt
  fi
done

cat /tmp/privremeno_linkovi.txt | sort -u > /tmp/ignorisati.txt


while read -r line
do
	U_TEXTU="$line"
	echo "$U_TEXTU" > /tmp/temp_12332.txt
	  for slova in ${MALA_SLOVA_DUAL} ${VELIKA_SLOVA_DUAL} ${VELIKA_SLOVA_MONO} ${MALA_SLOVA_MONO}
	  do 
		LATINICA="$(echo $slova | cut -d ':' -f 1)"
		CIRILICA="$(echo $slova | cut -d ':' -f 2)"
		sed -i s#"${CIRILICA}"#"${LATINICA}"#g /tmp/temp_12332.txt
	  done
	A_TREBA=$(cat /tmp/temp_12332.txt)
	echo "sed -i s#\"${U_TEXTU}\"#\"${A_TREBA}\"#g $FAJL" >> /tmp/izvrsi.txt
done < /tmp/ignorisati.txt
tr -d '\015' < /tmp/izvrsi.txt > /tmp/izvrsi.sh # Remove ^M
chmod +x /tmp/izvrsi.sh &>/dev/null
bash /tmp/izvrsi.sh 


echo " | РЕВЕРТ СТАТИЧКИХ СТРИНГОВА ------------------------------------------"
rm -f /tmp/privremeno
while read -r line
do
	U_TEXTU="$(echo $line | cut -d ':' -f 1)"
	A_TREBA="$(echo $line | cut -d ':' -f 2)"
	echo "sed -i 's#${U_TEXTU}#${A_TREBA}#g' $FAJL" >> /tmp/privremeno
done < stringovi-za-force.txt
chmod +x /tmp/privremeno
unset IFS
bash /tmp/privremeno 
 

echo " | РЕВЕРТ ЛИНКОВА ------------------------------------------------------"
rm -f /tmp/Linkovi.txt
for i in $(cat $FAJL)
 do
  if [ $(echo $i | grep 'href\|src' | wc -l ) -gt 0 ] ; then
	echo $i | cut -d '=' -f2- | cut -d '>' -f1 | tr --delete '"' >> /tmp/Linkovi.txt
  fi
done

LINKOVI=$(cat /tmp/Linkovi.txt | tr --delete \" | xargs)
  
for i in ${LINKOVI}
do
 CIRILICA_LINK="$i"
 echo $i > /tmp/privremeno-za-translate.text
	for slova in ${MALA_SLOVA_DUAL} ${VELIKA_SLOVA_DUAL} ${VELIKA_SLOVA_MONO} ${MALA_SLOVA_MONO}
	do 
		LATINICA="$(echo $slova | cut -d ':' -f 2)"
		CIRILICA="$(echo $slova | cut -d ':' -f 1)"
		sed -i s#"${LATINICA}"#"${CIRILICA}"#g /tmp/privremeno-za-translate.text
	done
 LATINICA_LINK="$(cat /tmp/privremeno-za-translate.text)"
  echo "sed -i s#\"${CIRILICA_LINK}\"#\"${LATINICA_LINK}\"#g $FAJL" >> ~/IZVRSI.txt
done

cat ~/IZVRSI.txt | sort -r > ~/IZVRSI.txt.sh
chmod +x ~/IZVRSI.txt.sh
bash ~/IZVRSI.txt.sh
rm -f ~/IZVRSI.txt.sh ~/IZVRSI.txt /tmp/privremeno-za-translate.text /tmp/Linkovi.txt
 
echo " | ГОТОВО --------------------------------------------------------------"
echo
cat $FAJL
 
exit 0
