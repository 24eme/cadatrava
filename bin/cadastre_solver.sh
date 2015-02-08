#!/bin/bash

COOKIEFILE=/tmp/.cookies.$$

curl -s -k -c $COOKIEFILE http://www.cadastre.gouv.fr/scpc/accueil.do > /dev/null

DEP=$(echo $4 | sed 's/\(..\).*/\1/');

echo -n "<?php echo urlencode(iconv('UTF-8', 'ASCII//TRANSLIT','" > /tmp/.ville.$$.php
echo -n $1 >> /tmp/.ville.$$.php
echo "'));" >> /tmp/.ville.$$.php
curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: http://www.cadastre.gouv.fr/' -X POST -d 'ville='$(php /tmp/.ville.$$.php)'&codePostal=&codeDepartement=0'$DEP'&rechercheType=1&prefixeParcelle=000&sectionLibelle='$2'&numeroParcelle='$3'&prefixeFeuille=000&feuilleLibelle=&nbResultatParPage=10&x=38&y=2' http://www.cadastre.gouv.fr/scpc/rechercherParReferenceCadastrale.do  > /tmp/parcellaire.$$.html
rm /tmp/.ville.$$.php
if grep afficherCarteParcelle.do /tmp/parcellaire.$$.html > /dev/null ; then
	echo -n "Parcelle OK ($1 $2 $3 $4) : ";
	URL=$(cat /tmp/parcellaire.$$.html | grep afficherCarteParcelle.do | sed 's/.*afficherCarteParcelle.do/afficherCarteParcelle.do/'| sed "s/','.*//" | sed 's/amp;//');
	PARCELLE_ID=$(echo $URL | sed 's/.*p=//' | sed 's/&f=.*//')
	curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: http://www.cadastre.gouv.fr/scpc/rechercherParReferenceCadastrale.do' "http://www.cadastre.gouv.fr/scpc/"$URL > /tmp/parcellaire.$$.html
	PARCELLE_BBOX=$(echo -n $(grep -A 4 GeoBox /tmp/parcellaire.$$.html  | head -n 5 | tail -n 4 | sed 's/)//') | sed 's/ //g' | sed 's/,$//'| perl -e '@bbox = split ",", <STDIN>; print $bbox[0]-1; print ",";print $bbox[1]-1; print ","; print $bbox[2]+1; print "," ; print $bbox[3]+1;')
	curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: http://www.cadastre.gouv.fr/scpc/'$URL -X GET "http://www.cadastre.gouv.fr/scpc/wms?version=1.1&request=GetMap&layers=CDIF:PARCELLE&format=image/png&bbox="$PARCELLE_BBOX"&width=1000&height=500&exception=application/vnd.ogc.se_inimage&styles=PARCELLE_90&selection=PARCELLE_90,null,PARCELLE_SELECTION_90,PARCELLE,"$PARCELLE_ID > /tmp/parcellaire.$$.png
	curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: http://www.cadastre.gouv.fr/scpc/'$URL -H 'Content-Type: application/xml; charset=UTF-8' -X POST -d '<PARCELLES><PARCELLE>'$PARCELLE_ID'</PARCELLE></PARCELLES>' http://www.cadastre.gouv.fr/scpc/afficherInfosParcelles.do > /tmp/parcellaire.$$.html
	PARCELLE_REF=$(grep strong /tmp/parcellaire.$$.html | head -n 1 | sed 's/.*<strong>//' | sed 's/<.*//')
	PARCELLE_SUPERFICIE=$(grep "tres carr" /tmp/parcellaire.$$.html  | sed 's/[^0-9]*//' | sed 's/ m.*/m2/' | sed 's/[^0-9m]//g')
	echo $PARCELLE_REF $PARCELLE_SUPERFICIE	$PARCELLE_ID 
	mv /tmp/parcellaire.$$.png $PARCELLE_ID.png
	convert $PARCELLE_ID.png -compress none $PARCELLE_ID"_"$PARCELLE_BBOX.ppm
	perl bin/redonly.pl < $PARCELLE_ID"_"$PARCELLE_BBOX.ppm > $PARCELLE_ID"_"$PARCELLE_BBOX.red.ppm
	convert $PARCELLE_ID"_"$PARCELLE_BBOX.red.ppm  -fill red -draw 'color '$(perl bin/centerit.pl < $PARCELLE_ID"_"$PARCELLE_BBOX.red.ppm)' floodfill' $PARCELLE_ID"_"$PARCELLE_BBOX.filled.ppm
	potrace -s $PARCELLE_ID"_"$PARCELLE_BBOX.filled.ppm -o $PARCELLE_ID.svg
	potrace -b geojson $PARCELLE_ID"_"$PARCELLE_BBOX.filled.ppm -o $PARCELLE_ID.geojson
	PARCELLE_LATLONG_X=$(echo $PARCELLE_BBOX | sed 's/,/ /' | sed 's/,.*//' | invproj +proj=lcc +lat_1=47.25 +lat_2=48.75 +lat_0=48 +lon_0=3 +x_0=1700000 +y_0=7200000 +units=m +to +proj=latlong +units=m -f '%.20f' | sed 's/ *//' | sed 's/\t/,/')
	PARCELLE_LATLONG_Y=$(echo $PARCELLE_BBOX | sed 's/,/ /' |sed 's/[^,]*,//' | sed 's/,/ /' | invproj +proj=lcc +lat_1=47.25 +lat_2=48.75 +lat_0=48 +lon_0=3 +x_0=1700000 +y_0=7200000 +units=m +to +proj=latlong +units=m -f '%.12f' | sed 's/ *//' | sed 's/\t/,/')
	perl bin/geojsonconvertxy2latlong.pl $PARCELLE_ID.geojson $PARCELLE_LATLONG_X","$PARCELLE_LATLONG_Y 1000,500
	echo "COMMUNE: $1" > $PARCELLE_ID.txt
	echo "PARCELLE_REFERENCE: $PARCELLE_REF" >> $PARCELLE_ID.txt
	echo "PARCELLE_SUPERFICIE: $PARCELLE_SUPERFICIE" >> $PARCELLE_ID.txt
	echo "PARCELLE_ID: $PARCELLE_ID" >> $PARCELLE_ID.txt
	echo "PARCELLE_BBOX_IGN: $PARCELLE_BBOX" >> $PARCELLE_ID".txt"
	echo "PARCELLE_BBOX_LATLONG: "$PARCELLE_LATLONG_X","$PARCELLE_LATLONG_Y >>  $PARCELLE_ID".txt"
	rm $PARCELLE_ID*ppm
	exit 0;
else
	echo "Parcelle ERROR ($1 $2 $3 $4)";
	exit 1;
fi
#rm $COOKIEFILE
