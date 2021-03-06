#!/bin/bash

COOKIEFILE=/tmp/.cookies.$$

cd $(dirname $0)"/.."

if ! test "$1"  || ! test "$2" || ! test "$3" || ! test "$4" ; then
	echo "USAGE: $0 <commune> <section de la parcelle> <numero de la parcelle> <code postal de la commune>" >&2
	exit 1
fi

DEP=$(echo $4 | sed 's/\(..\).*/\1/');

CACHE="cache/"$DEP"_"$1"_"$2"_"$3".txt"

if test -s $CACHE; then
	if grep ERROR $CACHE > /dev/null; then
	        echo "Parcelle ERROR ($1 $2 $3 $4)";
		exit 1;
	fi
	echo -n "Parcelle OK ($1 $2 $3 $4) : ";
        PARCELLE_REF=$(grep REFERENCE $CACHE | sed 's/.*: //')
	PARCELLE_SUPERFICIE=$(grep SUPERFICIE $CACHE | sed 's/.*: //')
	PARCELLE_ADRESSES=$(grep ADRESSES $CACHE | sed 's/.*: //')
	PARCELLE_ID=$(grep _ID $CACHE | sed 's/.*: //')
	echo "$PARCELLE_REF $PARCELLE_SUPERFICIE $PARCELLE_ID ($PARCELLE_ADRESSES)"
	exit 0;
fi

curl -s -k -c $COOKIEFILE http://www.cadastre.gouv.fr/scpc/accueil.do > /dev/null

#Soumission du formulaire de recherche de parcelle
echo -n "<?php echo urlencode(iconv('UTF-8', 'ASCII//TRANSLIT','" > /tmp/.ville.$$.php ; echo -n $1 >> /tmp/.ville.$$.php ; echo "'));" >> /tmp/.ville.$$.php
curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: http://www.cadastre.gouv.fr/' -X POST -d 'ville='$(php /tmp/.ville.$$.php)'&codePostal=&codeDepartement=0'$DEP'&rechercheType=1&prefixeParcelle=000&sectionLibelle='$2'&numeroParcelle='$3'&prefixeFeuille=000&feuilleLibelle=&nbResultatParPage=10&x=38&y=2' http://www.cadastre.gouv.fr/scpc/rechercherParReferenceCadastrale.do  > /tmp/parcellaire.$$.html
rm /tmp/.ville.$$.php

#Vérifie que la parcelle existes
if ! grep afficherCarteParcelle.do /tmp/parcellaire.$$.html > /dev/null ; then
	echo "Parcelle ERROR ($1 $2 $3 $4)";
	echo ERROR > $CACHE
	exit 1;
fi
echo -n "Parcelle OK ($1 $2 $3 $4) : ";

#Depuis le résultats de recherche de la parcelle, ouvre la popup de carto
URL=$(cat /tmp/parcellaire.$$.html | grep afficherCarteParcelle.do | sed 's/.*afficherCarteParcelle.do/afficherCarteParcelle.do/'| sed "s/','.*//" | sed 's/amp;//');
PARCELLE_ID=$(echo $URL | sed 's/.*p=//' | sed 's/&f=.*//')
if test -s $PARCELLE_ID".txt" ; then
        PARCELLE_REF=$(grep REFERENCE $PARCELLE_ID".txt"  | sed 's/.*: //')
        PARCELLE_SUPERFICIE=$(grep SUPERFICIE $PARCELLE_ID".txt" | sed 's/.*: //')
        PARCELLE_ADRESSES=$(grep ADRESSES $PARCELLE_ID".txt" | sed 's/.*: //')
        PARCELLE_ID=$(grep _ID $PARCELLE_ID".txt" | sed 's/.*: //')
	echo "$PARCELLE_REF $PARCELLE_SUPERFICIE $PARCELLE_ID ($PARCELLE_ADRESSES)"
        cp $PARCELLE_ID".txt" $CACHE
	exit;
fi
curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: http://www.cadastre.gouv.fr/scpc/rechercherParReferenceCadastrale.do' "http://www.cadastre.gouv.fr/scpc/"$URL > /tmp/parcellaire.$$.html
#Récupère les coordonnées Lamber de la parcelle (et ajoute un peu de marge)
PARCELLE_BBOX=$(echo -n $(grep -A 4 GeoBox /tmp/parcellaire.$$.html  | head -n 10 | tail -n 4 | sed 's/)//') | sed 's/ //g' | sed 's/,$//'| perl -e '@bbox = split ",", <STDIN>; print $bbox[0]-1; print ",";print $bbox[1]-1; print ","; print $bbox[2]+1; print "," ; print $bbox[3]+1;')
#Demande les données géographique de la parcelle
curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: http://www.cadastre.gouv.fr/scpc/'$URL -H 'Content-Type: application/xml; charset=UTF-8' -X POST -d '<PARCELLES><PARCELLE>'$PARCELLE_ID'</PARCELLE></PARCELLES>' http://www.cadastre.gouv.fr/scpc/afficherInfosParcelles.do > /tmp/parcellaire.$$.html
PARCELLE_REF=$(grep strong /tmp/parcellaire.$$.html | head -n 1 | sed 's/.*<strong>//' | sed 's/<.*//')
PARCELLE_SUPERFICIE=$(grep "tres carr" /tmp/parcellaire.$$.html  | sed 's/[^0-9]*//' | sed 's/ m.*/m2/' | sed 's/[^0-9m]//g')
PARCELLE_ADRESSES=$(tr '\n' ' ' < /tmp/parcellaire.$$.html | sed 's/<strong>/\n/g' | grep 'Adresse'  | sed 's/Adresse de la parcelle.*//' | sed 's/<[^>]*>//g' | sed 's/\t*//g' | tr '\n' ';')
echo "$PARCELLE_REF $PARCELLE_SUPERFICIE	$PARCELLE_ID ($PARCELLE_ADRESSES)"
#Convertion des coordonnées lamber vers lat,long
PARCELLE_LATLONG_X=$(echo $PARCELLE_BBOX | sed 's/,/ /' | sed 's/,.*//' | invproj +proj=lcc +lat_1=47.25 +lat_2=48.75 +lat_0=48 +lon_0=3 +x_0=1700000 +y_0=7200000 +units=m +to +proj=latlong +units=m -f '%.20f' | sed 's/ *//' | sed 's/\t/,/')
PARCELLE_LATLONG_Y=$(echo $PARCELLE_BBOX | sed 's/,/ /' |sed 's/[^,]*,//' | sed 's/,/ /' | invproj +proj=lcc +lat_1=47.25 +lat_2=48.75 +lat_0=48 +lon_0=3 +x_0=1700000 +y_0=7200000 +units=m +to +proj=latlong +units=m -f '%.12f' | sed 's/ *//' | sed 's/\t/,/')
#Conserve les méta données dans un fichier texte
echo "COMMUNE: $1" > $PARCELLE_ID.txt.tmp
echo "PARCELLE_REFERENCE: $PARCELLE_REF" >> $PARCELLE_ID.txt.tmp
echo "PARCELLE_SUPERFICIE: $PARCELLE_SUPERFICIE" >> $PARCELLE_ID.txt.tmp
echo "PARCELLE_ADRESSES: $PARCELLE_ADRESSES" >> $PARCELLE_ID.txt.tmp
echo "PARCELLE_ID: $PARCELLE_ID" >> $PARCELLE_ID.txt.tmp
echo "PARCELLE_BBOX_IGN: $PARCELLE_BBOX" >> $PARCELLE_ID".txt.tmp"
echo "PARCELLE_BBOX_LATLONG: "$PARCELLE_LATLONG_X","$PARCELLE_LATLONG_Y >>  $PARCELLE_ID".txt.tmp"
mv $PARCELLE_ID".txt.tmp" $CACHE
cp $CACHE $PARCELLE_ID".txt"
exit
#Demande l'image de la parcelle
curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: http://www.cadastre.gouv.fr/scpc/'$URL -X GET "http://www.cadastre.gouv.fr/scpc/wms?version=1.1&request=GetMap&layers=CDIF:PARCELLE&format=image/png&bbox="$PARCELLE_BBOX"&width=1000&height=500&exception=application/vnd.ogc.se_inimage&styles=PARCELLE_90&selection=PARCELLE_90,null,PARCELLE_SELECTION_90,PARCELLE,"$PARCELLE_ID > /tmp/parcellaire.$$.png
mv /tmp/parcellaire.$$.png $PARCELLE_ID.png
#Convertion de la parcelle en un polygone rouge
convert $PARCELLE_ID.png -compress none $PARCELLE_ID"_"$PARCELLE_BBOX.ppm
convert $PARCELLE_ID"_"$PARCELLE_BBOX.ppm -fill red -draw 'color '$(perl bin/centerit.pl < $PARCELLE_ID"_"$PARCELLE_BBOX.ppm)' floodfill' -compress none  $PARCELLE_ID"_"$PARCELLE_BBOX.filled.ppm
perl bin/redonly.pl < $PARCELLE_ID"_"$PARCELLE_BBOX.filled.ppm > $PARCELLE_ID"_"$PARCELLE_BBOX.red.ppm
mogrify -color 2 $PARCELLE_ID"_"$PARCELLE_BBOX.red.ppm
potrace -t 5 -u 100 -O 1 -s $PARCELLE_ID"_"$PARCELLE_BBOX.red.ppm -o $PARCELLE_ID.svg
potrace -t 5 -u 100 -O 1 -b geojson $PARCELLE_ID"_"$PARCELLE_BBOX.red.ppm -o $PARCELLE_ID.geojson
#Convertion du geojson contenant les coordonnées du polygone dans l'image en geojson lat,long
perl bin/geojsonconvertxy2latlong.pl $PARCELLE_ID.geojson $PARCELLE_LATLONG_X","$PARCELLE_LATLONG_Y 1000,500
rm $PARCELLE_ID*ppm $COOKIEFILE  $COOKIEFILE".2" /tmp/parcellaire.$$.html

