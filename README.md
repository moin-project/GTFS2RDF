# GTFS2RDF

### Download GTFS dump


### Convert GTFS data to RDF
Given that the GTFS data is in CSV format, we use RML as mapping language.

As conversion tool we use the Java based [RMLMapper](https://github.com/RMLio/rmlmapper-java).

The mappings are contained in the file [gtfsde-rml.ttl](https://github.com/moin-project/GTFS2RDF/blob/main/rml/gtfsde-rml.ttl)

Moreover, we make use of custom functions during the mappings process:
- the GTFS data for `departure_time` and `arrival_time` of the `stop_times.txt` file an have invalid data w.r.t. to e.g. `xsd:time` datatype, see the [specs](https://developers.google.com/transit/gtfs/reference#stop_timestxt):

> For times occurring after midnight on the service day, enter the time as a value greater than 24:00:00 in HH:MM:SS local time for the day on which the trip schedule begins.

This means, there can be time data like `25:12:12` when the departure time is on the next day after the arrival time. This in fact leads to invalid for a time literal and makes triple stores fail when loading the data. Therefore, we use a custom function which normalizes the values, i.e. the former examples becomes `01:12:12`


After cloning and building the Github project, we use the CLI to generate the RDF data from the GTFS CSV data:

```bash
java -jar "$CWD/rmlmapper.jar" -v -f "$CWD/functions_moin.ttl" -m "$CWD/gtfsde-rml2.ttl"

```


### Download Wikidata Geospatial station data

For linking the stop locations to Wikidata there are different opportunities:
1. Wikidata itself does have a GeoSpatial index which makes it possible to search for places nearby given coordinates:

```sparql
SELECT ?place ?placeLabel ?location ?dist WHERE {
  SERVICE wikibase:around { 
      ?place wdt:P625 ?location . 
      bd:serviceParam wikibase:center "POINT(6.04541 50.731915)"^^geo:wktLiteral . 
      bd:serviceParam wikibase:radius "0.5" . 
      bd:serviceParam wikibase:distance ?dist.
  } 
  # optionally, check if the entity is a station
  # FILTER EXISTS { ?place wdt:P31/wdt:P279* wd:Q12819564 }
  SERVICE wikibase:label {
    bd:serviceParam wikibase:language "de" . 
  }
} ORDER BY ASC(?dist)

```

The main problem here is the amount of GTFS stops we have:

```bash
awk -vFPAT='([^,]*)|("[^"]+")' -vOFS=, '{ print $2 }' $DIR/stops.txt | sort -u | wc -l
```
The GTFS.de dump of 08 March:

| Dataset | #stop ids | #stop names | #lat/long |
| --- | ---: | ---: | ---: |
| Fernverkehr | 1,349 | 514 | 513 |
| Regionalverkehr | 14,191 | 7,336 | 7,685 |
| Nahverkehr | 456,786 | 281,463 | 409,985 |

Sending thousands of single requests is rather slow and might lead to being blocked by the server.

As an alternative, we could gather the station data from Wikidata with the following query. Currently there are `6281` German transport stops with coordinates in Wikidata:

```sparql
SELECT (count(distinct ?place) as ?cnt) {
  ?place wdt:P31/(wdt:P279)* wd:Q548662 ;
         wdt:P17 wd:Q183 ;
         wdt:P625 ?location 
 }
```
To get the appropriate triples with WKT serialization we can run

```sparql
PREFIX bd: <http://www.bigdata.com/rdf#>
PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX wdt: <http://www.wikidata.org/prop/direct/>
PREFIX wikibase: <http://wikiba.se/ontology#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX geo: <http://www.opengis.net/ont/geosparql#>

 CONSTRUCT {
 ?place 
             geo:hasGeometry [ a geo:Geometry ; geo:asWKT ?location ] ;
           rdfs:label ?placeLabel ;
             #wdt:P31 ?type
             #rdfs:comment ?placeDescription ;
             #skos:altLabel ?placeAltLabel
 } WITH {  
    SELECT DISTINCT ?place where {      
    	?place wdt:P31/(wdt:P279)* wd:Q548662 ;            
               wdt:P17 wd:Q183 ;
     }
  } AS %places
   WHERE {
    
   INCLUDE %places
   ?place wdt:P625 ?location .
          #wdt:P31 ?type 
   #BIND(bnode(str(?location)) as ?geom)
   #hint:Query hint:queryEngineChunkHandler "Managed"
   hint:Query hint:constructDistinctSPO false . 
   SERVICE wikibase:label { bd:serviceParam wikibase:language "de,en". }                  
 }

```
There seems to be some issue with the `CONSTRUCT` optimizer, in particular, without the query hint this query is missing triples randomly in the result on each execution, for example the location of `wd:Q681785` isn't contained in the triples. 

The previous query does only return transport stop data for Germany, the GTFS dataset for _Fernverkehr_ will need additional data from other European countries:

TODO

This data can be loaded into a local triple store with GeoSPARQL support in addition to the GTFS data we converted in the previous step.

### Geo-Matching the GTFS and Wikidata entities

Then, a SPARQL query with GeoSPARQL can be used to find matching candidates based on the coordinates:

```sparql
PREFIX geo: <http://www.opengis.net/ont/geosparql#>
PREFIX geof: <http://www.opengis.net/def/function/geosparql/>
PREFIX unit: <http://qudt.org/vocab/unit#>
PREFIX uom: <http://www.opengis.net/def/uom/OGC/1.0/>
PREFIX wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>

SELECT DISTINCT ?wdEntity ?wdEntityLabel ?wdPoint ?stop ?stopName ?stopPoint where {
  ?wdEntity geo:hasGeometry ?wdGeom ;
            rdfs:label ?wdEntityLabel .
  ?wdGeom geo:asWKT ?wdPoint .
  
  ?stop geo:hasGeometry ?stopGeom ;
        foaf:name ?stopName .
 ?stopGeom geo:asWKT ?stopPoint .
 
 ?wdGeom geof:nearby (?stopPoint 1 unit:Kilometer)
}
order by ?wdEntityLabel ?stop
```
Depending on the max. nearby distance given, there might be multiple matches per stop. In that case we could a) simply use the nearest Wikidata entity or b) add compute some additional similarity measure based on the names.

#### LIMES
If we're doing a more sophisticated interlinking, LIMES would be the first choice here. It allows to combine multiple metrics and provides for string similarity measure as well as geospatial measures.

Usage: Download latest LIMES from [here](https://github.com/dice-group/LIMES/releases)

```
java -jar limes-core-1.7.4.jar limes_config.xml
```
The config file contains either a path to the files containing both datasets or the SPARQL endpoint URL. If we load all data into a single SPARQL endpoint  - as we did in our case - we can add some additional graph pattern to distinguish the source and target entities.

TODO show config
TODO process output

### Reverse Geocoding
We also apply reverse geocoding by using OSM data via nominatim to gather address data. While there is a public Nominatim service, it's not meant to be used heavily, thus, we setup our local Nominatim with OSM data for Germany. Luckily, there is a Docker setup that basically does what we need, thus, we only have to setup Docker and run

```
docker run -it --rm \
  -e PBF_URL=https://download.geofabrik.de/europe/germany-latest.osm.pbf \
  -e REPLICATION_URL=https://download.geofabrik.de/europe/germany-updates/ \
  -e IMPORT_WIKIPEDIA=true \
  -p 8888:8080 \
  --name nominatim \
  -v nominatim-data:/var/lib/postgresql/12/main \
  mediagis/nominatim:3.6
```
This takes "some" time ... 
Afterwards, the service will be available at port 8888 - change it if this port is already been used.

#### Call Nominatim from SPARQL
We can use Apache Jena custom Javascript based functions to call Nominatim directly from SPARQL and add RDF triples to the existing dataset:
```
update --data data.nt --set arq:logExec=FINE --set arq:js-library=arq-functions.js --update GTFS2RDF/queries/add_osm_address_data.ru --dump > data_with_osm.nt
```



## Simplifying Polygons

The following example shows how to compute a convex hull in SPARQL using spatial extensions.
The [RDF Processing Toolkit](https://github.com/SmartDataAnalytics/RdfProcessingToolkit/) is a convenient tool for that purpose.


```bash
java -jar rpt.jar integrate gtfs.nt hull.sparql
```

```sparql
#hull.sparql

PREFIX wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX spatialF: <http://jena.apache.org/function/spatial#>
SELECT
  ?points
  (geof:convexHull(?points) AS ?convexHull)
{
  SELECT (geof:collect(?point) AS ?points) {
    []
      wgs:lat ?lat ;
      wgs:long ?lon ;
    .

    BIND(spatialF:convertLatLon(?lat, ?lon) AS ?point)
  }
}
```

![Raw data points](images/2021-05-07-gtfs.de-international-railways-raw.png)
![Convex hull](images/2021-05-07-gtfs.de-international-railways-convex-hull.png)

