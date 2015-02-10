#!/bin/bash

if test $1 = "RGF93CC48" ; then
	PROJARGS="+proj=lcc +lat_1=47.25 +lat_2=48.75 +lat_0=48 +lon_0=3 +x_0=1700000 +y_0=7200000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
else
	echo "Unsupported projection id";
	exit 1;
fi

echo "$2" | sed 's/,/ /' | proj $PROJARGS | sed 's/\t/,/'

