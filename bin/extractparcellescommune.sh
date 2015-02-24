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
if ! test -s $CODE"-"$COMMUNE".pdf" || ! test -s $CODE"-"$COMMUNE".bbox" ; then
    $BASEDIR/qadastre2osm/Qadastre2OSM --download $DEP $CODE $COMMUNE
fi
if ! test -s $CODE"-"$COMMUNE"-lands.osm" ; then
    $BASEDIR/qadastre2osm/Qadastre2OSM --convert-with-lands $CODE $COMMUNE
fi
if ! test -s $CODE"-"$COMMUNE"-lands.osm" ; then
    echo "ERROR: OSM not generated"
    echo "INFO: cleaning"
    rm $CODE"-"$COMMUNE"-lands.osm" $CODE"-"$COMMUNE".pdf" 
    exit 1
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
	    echo "parcelle_lineid: $LINEID" >> $CODE"-"$COMMUNE"-"$LINEID".meta"
	    echo "parcelle_ign_coords: $IGNCOORD $IGNCOORD2" >> $CODE"-"$COMMUNE"-"$LINEID".meta"
	    echo "parcelle_latlong: $LATLONG $LATLONG2" >> $CODE"-"$COMMUNE"-"$LINEID".meta"
	    echo "parcelle_wayid: $WAYID" >> $CODE"-"$COMMUNE"-"$LINEID".meta"
	    echo "parcelle_commune: $COMMUNE" >>  $CODE"-"$COMMUNE"-"$LINEID".meta"
	    echo "parcelle_departement: $DEP" >> $CODE"-"$COMMUNE"-"$LINEID".meta"
	fi
done
if ! test -s $CODE"-"$COMMUNE"-lands.coords"; then
    grep parcelle_ign_coords $CODE"-"$COMMUNE*meta | sed 's/:parcelle_ign_coords://' > $CODE"-"$COMMUNE"-lands.coords.tmp"
    python $BASEDIR/bin/coordinate_solver.py $DEP $COMMUNE $CODE"-"$COMMUNE"-lands.coords.tmp"
    mv $CODE"-"$COMMUNE"-lands.coords.tmp" $CODE"-"$COMMUNE"-lands.coords"
fi
ls $CODE"-"$COMMUNE"-"*meta | while read meta ; do
	PARCELLEID=$(cat $meta | grep parcelle_id | sed 's/.*: //')
	if ! test -s $CODE"-"$COMMUNE"-"$PARCELLEID".geojson"; then
	    python $BASEDIR/bin/extractpolygonfromgeojsonandaddtags.py $CODE"-"$COMMUNE"-lands.geojson" $meta > $CODE"-"$COMMUNE"-"$PARCELLEID".geojson"
	fi
done
cd -
mkdir -p data
cp cache/*geojson data/
