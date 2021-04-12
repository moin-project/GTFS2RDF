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

One of the limitations of RML seems to be that we can't generate


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
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
prefix geo: <http://www.opengis.net/ont/geosparql#>

 CONSTRUCT {
 ?place 
             geo:hasGeometry [a geo:Geometry ; geo:asWKT ?location] ;
             rdfs:label ?placeLabel ;
             #rdfs:comment ?placeDescription ;
             #skos:altLabel ?placeAltLabel
 } WHERE {
    
    	?place wdt:P31/(wdt:P279)* wd:Q548662 ; # transport stop
             wdt:P625 ?location ;
             wdt:P17 wd:Q183 # in Germany
            
    SERVICE wikibase:label { bd:serviceParam wikibase:language "de,en". }
 }

```
For whatever reason, this query is missing triples in the result, for example the location of `wd:Q681785` isn't contained in the triples. Not sure what happens here ... it does return the label "Bahnhof Berlin Zoologischer Garten"@de, but maybe the `SERVICE` clause is doing weird things ...

We do have another SPARQL query which seems to work:
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
 ?place rdfs:label ?placeLabel ;
 	#rdfs:comment ?placeDescription ;
        #skos:altLabel ?placeAltLabel ;
             #geo:hasGeometry [ a geo:Geometry ; geo:asWKT ?location ] ;
             geo:hasGeometry ?geom . ?geom a geo:Geometry ; geo:asWKT ?location .
           
 #?place wdt:P31 ?type
             
 } WITH {  
    SELECT DISTINCT ?place ?placeLabel WHERE {
    	?place wdt:P31/(wdt:P279)* wd:Q548662 ;            
               wdt:P17 wd:Q183 ;
               rdfs:label ?placeLabel
               Filter(lang(?placeLabel) = 'de')
                  
     }
  } AS %places
   WHERE {
    
   INCLUDE %places
   ?place wdt:P625 ?location ;
          #wdt:P31 ?type ;
   BIND(bnode(str(?location)) as ?geom)                 
 }
```

This data can be loaded into a local triple store with GeoSPARQL support in addition to the GTFS data we converted in the previous step.

Then, a SPARQL query with GeoSPARQL can be used:

```sparql

```

### Geo-Matching the GTFS and Wikidata entities


