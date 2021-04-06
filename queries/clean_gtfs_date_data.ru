# the GTFS dates are in yyyymmdd format, but xsd:date expects yyyy-mm.dd
PREFIX schema: <https://schema.org/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

DELETE {?s schema:startDate ?d}
INSERT {?s schema:startDate ?dd}
WHERE {
?s schema:startDate ?d .
bind(strdt(replace(str(?d), '^(\\d{4})(\\d{2})(\\d{2})$', '$1-$2-$3'), xsd:date) as ?dd)
}
