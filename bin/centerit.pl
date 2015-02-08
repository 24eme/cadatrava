#!/bin/perl

$in =  -1;
$out = 1;
$i = 0;
while (<STDIN>) {
	if (/^([0-9]+) ([0-9]+)$/g) {
		$sizex = $1;
		$sizey = $2;
		next;
	}
	while (/([0-9]+) ([0-9]+) ([0-9]+)( |$)/g) {
		$i++;
		if ($i > $sizex * $sizey / 2 ) {
			if ($1 > $2 && $1 > $3) {
				print $i - $sizex * $sizey / 2 + 20;
				print ",";
				print $sizey / 2;
				exit;
			}
		}
	}
}
