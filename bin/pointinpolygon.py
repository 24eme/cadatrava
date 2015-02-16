import json
import sys
import numpy as np
from shapely.geometry import shape, Point

f = open(sys.argv[1], 'r')
js = json.load(f)
f.close()

lineid = 0;
for feature in js['features']:
    feature['geometry']['type'] = 'Polygon'
    feature['geometry']['coordinates'] = [feature['geometry']['coordinates']]
    try:
       polygon = shape(feature['geometry'])
    except AssertionError:
       continue
    except ValueError:
       continue
    selectedpoint1 = None
    selectedpoint2 = None
    for x in np.arange(polygon.bounds[0], polygon.bounds[2], (polygon.bounds[2] - polygon.bounds[0]) / 10):
        for y in np.arange(polygon.bounds[1], polygon.bounds[3], (polygon.bounds[3] - polygon.bounds[1]) / 10):
            point = Point(x, y)
            if polygon.contains(point):
                if selectedpoint1:
                    selectedpoint2 = point
                else:
                    selectedpoint1 = point
                break
        if selectedpoint2:
            break
    if selectedpoint2:
        print "%s : %d : %s : %f,%f %f,%f" % (sys.argv[1], lineid, feature['id'], selectedpoint1.x, selectedpoint1.y, selectedpoint2.x, selectedpoint2.y)
    elif selectedpoint1:
        print "%s : %d : %s : %f,%f" % (sys.argv[1], lineid, feature['id'], selectedpoint1.x, selectedpoint1.y)        
    else:
        print >> sys.stderr, "%s : %d : %s : no point found :-(" % (sys.argv[1], lineid, feature['id'])
    lineid = lineid + 1
