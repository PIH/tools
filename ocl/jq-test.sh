#!/bin/bash

OCL_API_URL=https://api.staging.openconceptlab.org

get_collections() {
  COLLECTIONS_JSON=$(curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request GET $OCL_API_URL/orgs/PIH/collections/)
  COLLECTION_URLS=$(echo $COLLECTIONS_JSON | jq '.[] | .url')
  for URL in ${COLLECTION_URLS}
  do
    echo $URL
  done
}

get_concept() {
  CONCEPT_JSON=$(curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request GET $OCL_API_URL/orgs/PIH/sources/PIH/concepts/12557/)
  echo $CONCEPT_JSON | jq '.'
}

get_mappings_for_concept() {
  CONCEPT_JSON=$(curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request GET $OCL_API_URL/orgs/PIH/sources/PIH/concepts/12557/mappings/)
  echo $CONCEPT_JSON | jq '.'
}

get_mappings_for_concept