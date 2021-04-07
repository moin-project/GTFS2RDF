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


After cloning and building the Github project, we use the CLI

```bash
java -jar "$CWD/rmlmapper.jar" -v -f "$CWD/functions_moin.ttl" -m "$CWD/gtfsde-rml2.ttl"

```


### Download Wikidata Geospatial station data


### Geo-Matching the GTFS and Wikidata entities


