#!/usr/bin/perl

use JSON;
    use Data::Dumper;

$geojsonfile = shift;
$bbox = shift;
$size = shift;
@bbox = split /,/, $bbox;
@size = split /,/, $size;

open JSON, $geojsonfile;
$geojson = decode_json(join '', <JSON>);
close JSON;

$nbcoords = $#{$geojson->{'features'}[0]{'geometry'}{'coordinates'}[0]};
for($i = 0 ; $i <= $nbcoords ; $i++) {
	$geojson->{'features'}[0]{'geometry'}{'coordinates'}[0][$i][0] = ($geojson->{'features'}[0]{'geometry'}{'coordinates'}[0][$i][0]/$size[0])*($bbox[2]-$bbox[0])+$bbox[0];
	$geojson->{'features'}[0]{'geometry'}{'coordinates'}[0][$i][1] = (($size[1]-$geojson->{'features'}[0]{'geometry'}{'coordinates'}[0][$i][1])/$size[1])*($bbox[1]-$bbox[3])+$bbox[3];
}
open JSON, ">$geojsonfile";
print JSON encode_json($geojson) . "\n";
close JSON;

