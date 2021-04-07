#!/bin/bash

DATA=$1
OUT=$2

CWD=$(pwd)
cd $DATA

RMLDIR="$CWD/../rml"

java -jar "$RMLDIR/rmlmapper.jar" -v -f "$RMLDIR/functions_moin.ttl" -m "$RMLDIR/gtfsde-rml.ttl"

cd $CWD
