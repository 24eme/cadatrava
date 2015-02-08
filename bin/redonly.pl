#!/bin/perl

while (<STDIN>) {
	if (!/[0-9]+ [0-9]+ [0-9]+ /) {
		print ;
		next;
	}
	while (/([0-9]+) ([0-9]+) ([0-9]+)( |$)/g) {
		if (($1 + $2 + $3) == 765) {
			print"255 255 255$4";
		}elsif($1 > $2 && $1 > $3) {
			print "255 0 0$4";
		}else{
			print"255 255 255$4";
		}
	}
	print "\n";
}
