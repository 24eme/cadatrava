import json
import sys
import numpy as np
from shapely.geometry import shape, Point

f = open(sys.argv[1], 'r')
js = json.load(f)
f.close()

tags = {}
f = open(sys.argv[2], 'r')
for line in f.readlines():
    tag = line.split(': ')
    tags[tag[0]] = tag[1][:-1]

#for feature in js['features']:
i = int(tags['parcelle_lineid'])
feature = js['features'][i]
while feature['properties']['id'] != tags['parcelle_wayid']:
    i += 1
    try:
       feature = js['features'][i]
    except:
       print >> sys.stderr, "ERROR: wayid %s doesnot match with meta file (%s)" % (feature['properties']['id'], tags['parcelle_wayid'])
       sys.exit(1)
for tag in tags.keys():
    feature['properties'][tag] = tags[tag]
        
feature['geometry']['type'] = 'Polygon'
feature['geometry']['coordinates'] = [feature['geometry']['coordinates']]

js['features'] = [feature]

print json.dumps(js);
