# convert wgs lat and long coordinates to WKT format for spatial index

PREFIX schema: <https://schema.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX geo: <http://www.opengis.net/ont/geosparql#>

INSERT {
?s geo:hasGeometry [a geo:Geometry ; geo:asWKT ?point] ;
}
WHERE {
?s wgs:lat ?lat ;
   wgs:long ?long 
BIND(STRDT(CONCAT("POINT(", str(?long)," ", str(?lat), ")"), geo:wktLiteral) AS ?point)
}
