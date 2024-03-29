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

get_collection_version() {
    JSON=$(curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request GET $OCL_API_URL/orgs/PIH/collections/PIHEMR_Concepts/1.0.0/?includeConcepts=true&includeMappings=true&includeRetired=true&limit=0)
    echo $JSON | jq '.'
}

get_collection_references() {
    JSON=$(curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request GET $OCL_API_URL/orgs/PIH/collections/PIHEMR_Concepts/HEAD/references/3284283/)
    echo $JSON | jq '.'
}

get_collection_export() {
    JSON=$(curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request GET $OCL_API_URL/orgs/PIH/collections/PIHEMR_Concepts/1.0.0/export/?includeConcepts=true&includeMappings=true&includeRetired=true&limit=0)
    echo $JSON | jq '.'
}

get_task() {
  JSON=$(curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request GET $OCL_API_URL/tasks/$1/)
  echo $JSON | jq '.'
}

create_pihemr_concept_set_in_ocl() {
  CONCEPT_JSON=$(jq -n \
            --arg id "10000" \
            --arg concept_class "ConvSet" \
            --arg datatype "N/A" \
            --argjson names '[{"name": "PIHEMR Concept Set", "locale": "en", "locale_preferred": "true", "name_type": "FULLY_SPECIFIED"}]' \
            --argjson extras '{"is_set": 1}' \
             '$ARGS.named')

  curl --silent \
      -H "Authorization: Token $OCL_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --request POST \
      --data "${CONCEPT_JSON}" \
      $OCL_API_URL/orgs/PIH/sources/PIH/concepts/
}

add_concept_to_pihemr_concept_set_in_ocl() {
  CONCEPT_TO_ADD=${1}
  MAPPING_JSON=$(jq -n \
            --arg map_type "CONCEPT-SET" \
            --arg from_concept_url "/orgs/PIH/sources/PIH/concepts/10000/" \
            --arg to_concept_url "$CONCEPT_TO_ADD" \
             '$ARGS.named')

  curl --silent \
      -H "Authorization: Token $OCL_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --request POST \
      --data "${MAPPING_JSON}" \
      $OCL_API_URL/orgs/PIH/sources/PIH/mappings/
}