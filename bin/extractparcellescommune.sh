#!/bin/bash
CODE=$1
COMMUNE=$2
if ! test "$CODE" || ! test "$COMMUNE" ; then
	echo "USAGE: $0 <CODE POSTAL> <COMMUNE>"
	exit 1
fi
DEP="0"$(echo $CODE | sed 's/...$//')
BASEDIR=..
mkdir -p cache
cd cache
if ! test -s $CODE"-"$COMMUNE".pdf" && ! test -s $CODE"-"$COMMUNE".bbox" ; then
    $BASEDIR/qadastre2osm/Qadastre2OSM --download $DEP $CODE $COMMUNE
fi
if ! test -s $CODE"-"$COMMUNE"-lands.osm" ; then
    $BASEDIR/qadastre2osm/Qadastre2OSM --convert-with-lands $CODE $COMMUNE
fi
if ! test -s $CODE"-"$COMMUNE"-lands.geojson"; then
   osmtogeojson $CODE"-"$COMMUNE"-lands.osm"  > $CODE"-"$COMMUNE"-lands.geojson" ;
fi
if ! test -s $CODE"-"$COMMUNE"-lands.points"; then
    python $BASEDIR/bin/pointinpolygon.py $CODE"-"$COMMUNE"-lands.geojson" > $CODE"-"$COMMUNE"-lands.points"
fi
PROJ=$(cat $CODE"-"$COMMUNE".bbox" | sed 's/:.*//')
cat $CODE"-"$COMMUNE"-lands.points" | while read line ; do
        LINEID=$(printf "%09d" $(echo $line | sed 's/.*geojson : //' | sed 's/ :.*//'))
	if ! test -s $CODE"-"$COMMUNE"-"$LINEID".meta" ; then
	    WAYID=$(echo $line | sed 's/.*geojson : [0-9]* : //' | sed 's/ :.*//')
	    LATLONG=$(echo $line | sed 's/.* : //' | sed 's/ .*//')
	    IGNCOORD=$(bash $BASEDIR/bin/latlong2ign.sh $PROJ $LATLONG)
	    LATLONG2=$(echo $line | sed 's/.* : //' | sed 's/.* //')
	    IGNCOORD2=$(bash $BASEDIR/bin/latlong2ign.sh $PROJ $LATLONG2)
	    if ! bash $BASEDIR/bin/igncoord2parcelleinfo.sh $DEP $COMMUNE $IGNCOORD > $CODE"-"$COMMUNE"-"$LINEID".meta" 2> /dev/null; then
		if ! bash $BASEDIR/bin/igncoord2parcelleinfo.sh $DEP $COMMUNE $IGNCOORD2 > $CODE"-"$COMMUNE"-"$LINEID".meta" ; then
		    rm $CODE"-"$COMMUNE"-"$LINEID".meta"
		    continue;
		fi
		IGNCOORD=$IGNCOORD2
		LATLONG=$LATLONG2
	    fi
	    echo "parcelle_lineid: $LINEID" >> $CODE"-"$COMMUNE"-"$LINEID".meta"
	    echo "parcelle_ign_coords: $IGNCOORD" >> $CODE"-"$COMMUNE"-"$LINEID".meta"
	    echo "parcelle_latlong: $LATLONG" >> $CODE"-"$COMMUNE"-"$LINEID".meta"
	    echo "parcelle_wayid: $WAYID" >> $CODE"-"$COMMUNE"-"$LINEID".meta"
	    echo "parcelle_commune: $COMMUNE" >>  $CODE"-"$COMMUNE"-"$LINEID".meta"
	    echo "parcelle_departement: $DEP" >> $CODE"-"$COMMUNE"-"$LINEID".meta"
	fi
	PARCELLEID=$(cat $CODE"-"$COMMUNE"-"$LINEID".meta" | grep parcelle_id | sed 's/.*: //')
	if ! test -s $CODE"-"$COMMUNE"-"$PARCELLEID".geojson"; then
	    python $BASEDIR/bin/extractpolygonfromgeojsonandaddtags.py $CODE"-"$COMMUNE"-lands.geojson" $CODE"-"$COMMUNE"-"$LINEID".meta" > $CODE"-"$COMMUNE"-"$PARCELLEID".geojson"
	fi
done
cd -
mkdir -p data
cp cache/*geojson data/
