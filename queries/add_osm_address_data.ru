PREFIX wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX js: <http://jena.apache.org/ARQ/jsFunction#>
PREFIX osmm: <https://www.openstreetmap.org/meta/>
 
INSERT {
?s osmm:address ?addr
} WHERE {
?s wgs:lat ?lat ;
   wgs:long ?lon
   BIND(js:nominatim('http://localhost:8088', ?lat, ?lon) as ?addr)
}
