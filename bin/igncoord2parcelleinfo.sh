#!/bin/bash
COOKIEFILE=/tmp/.cookies
CURLOUTPUT=/tmp/parcelle.html

DEP=$1
COMMUNE=$2
COORDINATES=$3

curl -s -k -c $COOKIEFILE "http://www.cadastre.gouv.fr/scpc/accueil.do" > /dev/null
echo -n "<?php echo urlencode(iconv('UTF-8', 'ASCII//TRANSLIT','" > /tmp/.ville.$$.php ; echo -n $COMMUNE >> /tmp/.ville.$$.php ; echo "'));" >> /tmp/.ville.$$.php
curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: http://www.cadastre.gouv.fr/scpc/acueil.do'  -X POST -d 'ville='$(php /tmp/.ville.$$.php)'&numeroVoie=&indiceRepetition=&nomVoie=&lieuDit=&codePostal=&codeDepartement='$DEP'&nbResultatParPage=10&x=153&y=6' http://www.cadastre.gouv.fr/scpc/rechercherPlan.do > $CURLOUTPUT
COMMUNEID=$(grep afficherCarteCommune.do $CURLOUTPUT | sed 's/.*afficherCarteCommune.do?c=//' | sed "s/'.*//")
curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: http://www.cadastre.gouv.fr/scpc/rechercherPlan.do' "http://www.cadastre.gouv.fr/scpc/afficherCarteCommune.do?c=$COMMUNEID" > $CURLOUTPUT
curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: 'http://www.cadastre.gouv.fr/scpc/afficherCarteCommune.do?c=$COMMUNEID -X POST -d '<?xml version="1.0" encoding="UTF-8"?><wfs:GetFeature service="WFS" version="1.0.0" outputFormat="XML-alcer" xmlns:topp="http://www.openplans.org/topp" xmlns:wfs="http://www.opengis.net/wfs" xmlns:ogc="http://www.opengis.net/ogc" xmlns:gml="http://www.opengis.net/gml" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.opengis.net/wfs http://schemas.opengis.net/wfs/1.0.0/WFS-basic.xsd" maxFeatures="2000"><wfs:Query typeName="CDIF:PARCELLE"><ogc:Filter><ogc:And><ogc:PropertyIsEqualTo><ogc:PropertyName>COMMUNE_IDENT</ogc:PropertyName><ogc:Literal>'$COMMUNEID'</ogc:Literal></ogc:PropertyIsEqualTo><ogc:Intersects><ogc:PropertyName>GEOM</ogc:PropertyName><gml:MultiPoint srsName="http://www.opengis.net/gml/srs/epsg.xml#3948"><gml:PointMember><gml:Point><gml:coordinates>'$COORDINATES'</gml:coordinates></gml:Point></gml:PointMember></gml:MultiPoint></ogc:Intersects></ogc:And></ogc:Filter></wfs:Query></wfs:GetFeature>' http://www.cadastre.gouv.fr/scpc/wfs > $CURLOUTPUT
if ! grep PARCELLE. $CURLOUTPUT > /dev/null; then
    echo "ERROR: $0 $*: no parcelle found" 1>&2
    exit 1
fi
PARCELLE_ID=$(cat $CURLOUTPUT | sed 's/.*PARCELLE\.//' | sed 's/".*//')
curl -s -k -b $COOKIEFILE -c $COOKIEFILE".2" -H 'Referer: http://www.cadastre.gouv.fr/scpc/afficherCarteCommune.do?c='$COMMUNEID -H 'Content-Type: application/xml; charset=UTF-8' -X POST -d '<PARCELLES><PARCELLE>'$PARCELLE_ID'</PARCELLE></PARCELLES>' http://www.cadastre.gouv.fr/scpc/afficherInfosParcelles.do  > $CURLOUTPUT
PARCELLE_REF=$(grep strong $CURLOUTPUT | head -n 1 | sed 's/.*<strong>//' | sed 's/<.*//')
PARCELLE_SUPERFICIE=$(grep "tre[s ]*carr" $CURLOUTPUT  | sed 's/[^0-9]*//' | sed 's/ m.*/m2/' | sed 's/[^0-9m]//g')
echo "parcelle_id: "$PARCELLE_ID
echo "parcelle_reference: "$PARCELLE_REF
echo "parcelle_superficie: "$PARCELLE_SUPERFICIE
rm $COOKIEFILE $COOKIEFILE".2" $HTMLFILE
