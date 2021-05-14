# insert the connection data
PREFIX moin: <http://moin-project.org/data/>
PREFIX moino: <http://moin-project.org/ontology/>

PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

PREFIX url: <http://jsa.aksw.org/fn/url/>
PREFIX json: <http://jsa.aksw.org/fn/json/>

PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX wdt: <http://www.wikidata.org/prop/direct/>
PREFIX wikibase: <http://wikiba.se/ontology#>
PREFIX p: <http://www.wikidata.org/prop/>
PREFIX wdref: <http://www.wikidata.org/reference/>
PREFIX wdv: <http://www.wikidata.org/value/>
PREFIX ps: <http://www.wikidata.org/prop/statement/>
PREFIX psv: <http://www.wikidata.org/prop/statement/value/>
PREFIX psn: <http://www.wikidata.org/prop/statement/value-normalized/>
PREFIX pq: <http://www.wikidata.org/prop/qualifier/>
 
PREFIX geo: <http://www.opengis.net/ont/geosparql#>
PREFIX geof: <http://www.opengis.net/def/function/geosparql/>

INSERT {
	?src moino:connectedTo ?target .
		
	<<?src moino:connectedTo ?target>> moino:drivingDuration ?drivingDuration ;
		                           moino:drivingDistance ?drivingDistance ; 
		                           moino:transportType ?transportType ;
		                           moino:route ?routeWkt ;
		                           
} WHERE {
	BIND(moino:car as ?transportType)

	<https://project.nes.uni-due.de/moin/data/driving-summary-100.json> url:text ?text . 
	BIND(STRDT(?text, xsd:json) AS ?json)

	BIND(json:path(?json, "$.cities") AS ?cityArr1)
	BIND(json:path(?json, "$.cities") AS ?cityArr2)
	BIND(json:path(?json, "$.routes") AS ?routesArr)

    	# Unnest routes
	?routesArr json:unnest (?routeTargetsArr ?i) .
	?routeTargetsArr json:unnest (?route ?j) .

	FILTER(BOUND(?route)) # omit unbound routes which happens for src and target being the same

	BIND(strdt(concat("PT", str(json:path(?route, "$.drivingDuration")), "S"), xsd:duration) AS ?drivingDuration)
	BIND(json:path(?route, "$.drivingDistance") AS ?drivingDistance)
	BIND(json:path(?route, "$.distance") AS ?distance)
	BIND(json:path(?route, "$.drivingRoute") AS ?routeGooglePolyline)
	BIND(geof:parsePolyline(?routeGooglePolyline) as ?routeWkt)
 
	?cityArr1 json:unnest (?city1 ?i) .
	BIND(json:path(?city1, "$.names.local") AS ?name1)

	?cityArr2 json:unnest (?city2 ?j) .
	BIND(json:path(?city2, "$.names.local") AS ?name2)


	BIND(iri(concat(str(moin:), encode_for_uri(?name1))) as ?src)
	BIND(iri(concat(str(moin:), encode_for_uri(?name2))) as ?target)
}



# insert Wikidata entity links
INSERT {
	?city 	owl:sameAs ?item ;
		rdfs:label ?label ;
		a geo:Feature ;
		geo:defaultGeometry [a geo:Point ; geo:asWKT ?coordinate] .
	?item 
	 	wdt:P625 ?coordinate ;
	 	wdt:P1082 ?population ;
	 	wdt:P2046 ?area
	 	
} WHERE {
	<https://project.nes.uni-due.de/moin/data/driving-summary-100.json> url:text ?text . 
	BIND(STRDT(?text, xsd:json) AS ?json)

	BIND(json:path(?json, "$.cities") AS ?cityArr)
	?cityArr json:unnest (?cityEntry ?i) .
	BIND(json:path(?cityEntry, "$.names.local") AS ?name)
	BIND(strlang(?name, "de") as ?label)

	BIND(iri(concat(str(moin:), encode_for_uri(?name))) as ?city)

	BIND(COALESCE(strafter(json:path(?cityEntry, "$.wikipedia"), "de:"), ?name) as ?fragment)
	BIND(IRI(CONCAT("https://de.wikipedia.org/wiki/", encode_for_uri(?fragment))) AS ?sitelink)
	

	BIND(if(bound(?sitelink), ?sitelink, <b>) as ?in)
	OPTIONAL {
		SERVICE <https://query.wikidata.org/sparql> {
			?in schema:about ?item ;
			    schema:isPartOf <https://de.wikipedia.org/> .
				OPTIONAL {?item wdt:P625 ?coordinate}
			 	OPTIONAL {?item wdt:P1082 ?population}
            			OPTIONAL {?item p:P2046 [ a wikibase:BestRank ; psv:P2046 [ wikibase:quantityAmount ?area ; wikibase:quantityUnit ?unit ]]}
		 
		}
	}

}


# dump triples
CONSTRUCT WHERE {?s ?p ?o}

