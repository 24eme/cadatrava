# -*- coding: utf8 --*
import eventlet
import urllib
from eventlet.green import urllib2
from cookielib import CookieJar
import re
import sys

global coordinates

def coordinate_xml_solver(opener, codeCommune, coords, metafile):
    xml = '<?xml version="1.0" encoding="UTF-8"?><wfs:GetFeature service="WFS" version="1.0.0" outputFormat="XML-alcer" xmlns:topp="http://www.openplans.org/topp" xmlns:wfs="http://www.opengis.net/wfs" xmlns:ogc="http://www.opengis.net/ogc" xmlns:gml="http://www.opengis.net/gml" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.opengis.net/wfs http://schemas.opengis.net/wfs/1.0.0/WFS-basic.xsd" maxFeatures="2000"><wfs:Query typeName="CDIF:PARCELLE"><ogc:Filter><ogc:And><ogc:PropertyIsEqualTo><ogc:PropertyName>COMMUNE_IDENT</ogc:PropertyName><ogc:Literal>'+codeCommune+'</ogc:Literal></ogc:PropertyIsEqualTo><ogc:Intersects><ogc:PropertyName>GEOM</ogc:PropertyName><gml:MultiPoint srsName="http://www.opengis.net/gml/srs/epsg.xml#3948"><gml:PointMember><gml:Point><gml:coordinates>'+coords+'</gml:coordinates></gml:Point></gml:PointMember></gml:MultiPoint></ogc:Intersects></ogc:And></ogc:Filter></wfs:Query></wfs:GetFeature>'
    body = opener.open("http://www.cadastre.gouv.fr/scpc/wfs", xml)
    page = body.read()
    m = re.search('fid="PARCELLE\.([^"]+)"', page)
    if m == None:
        print "ERROR: not found for "+coords
        return False
    parcelleid = m.group(1)
    xml = '<PARCELLES><PARCELLE>'+parcelleid+'</PARCELLE></PARCELLES>'
    opener.addheaders = [('Content-Type', 'application/xml; charset=UTF-8')]
    req = urllib2.Request('http://www.cadastre.gouv.fr/scpc/afficherInfosParcelles.do', data=xml,
                          headers={'Content-Type': 'application/xml; charset=UTF-8'})
    body = opener.open(req)
    page = body.read()
    m = re.search('\t([^\t]+) m.egrave;tres? carr.eacute;', page)
    if m == None:
        mcarres = "0"
    else:
        mcarres = m.group(1).replace(' ', '')
    m = re.search('<strong>([^<]+)</strong>', page)
    parcelle = m.group(1)
    info = {}
    for line in open(metafile):
        line = line.strip()
        (key, value) = line.split(': ')
        info[key] = value
    info['parcelle_id'] = parcelleid
    info['parcelle_superficie'] = mcarres
    info['parcelle_reference'] = parcelle
    f = open(metafile, 'w')
    for key in info:
        f.write(key+": "+info[key]+"\n")
    return True


def coordinate_solver(id):
    global coordinates
    global coordinates_id
    global commune
    global departement

    mycid = 0
    s = eventlet.semaphore.Semaphore(1)
    cj = CookieJar()
    opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cj))
    body = opener.open("http://www.cadastre.gouv.fr/scpc/accueil.do")
    page = body.read()
    data = {'ville': commune, 'codeDepartement': departement}
    body = opener.open("http://www.cadastre.gouv.fr/scpc/rechercherPlan.do", urllib.urlencode(data))
    page = body.read()
    m = re.search("afficherCarteCommune.do.c=([^']+)'", page)
    codeCommune = None
    if m:
        codeCommune = m.group(1)
    else:
        m = re.search('select name="codeCommune" id="codeCommune" class="long erreur"><option value="">Choisir</option><option value="([^"]+)"', page)
        if m:
            codeCommune = m.group(1)
            data = {"codeCommune": codeCommune, 'codeDepartement': departement, 'nbResultatParPage': 10, 'x':153, 'y':6}
            body = opener.open("http://www.cadastre.gouv.fr/scpc/rechercherPlan.do", urllib.urlencode(data))
            page = body.read()
    if codeCommune == None:
        print "commune: ERROR"
        return "ERROR"
    body = opener.open("http://www.cadastre.gouv.fr/scpc/afficherCarteCommune.do?c="+codeCommune)
    page = body.read()
    if re.search("Impossible d'initialiser", page):
        print "carte: ERROR"
        return "ERROR"
    while True:
        with s:
            mycid = coordinates_id
            coordinates_id += 1
        if mycid >= len(coordinates):
            break
        coordargs = coordinates[mycid]
        m = re.search('^([^ ]+) ([^ ]+) ([^ ]+)$', coordargs)
        if coordinate_xml_solver(opener, codeCommune, m.group(2), m.group(1)) == False:
            print "New tests for coords"
            coordinate_xml_solver(opener, codeCommune, m.group(3), m.group(1))

pool = eventlet.GreenPool()
coordinates_id = 0
departement = sys.argv[1]
commune = sys.argv[2]
coordinates = [line.strip() for line in open(sys.argv[3])]
for res in pool.imap(coordinate_solver, range(0, 1)):
    True
