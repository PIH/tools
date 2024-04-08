#!/bin/bash

# The goal of this script is to lay out the steps and commands necessary to load all concepts from PIH-EMR MDS packages into OCL
# This follows the steps laid out here:  https://wiki.openmrs.org/display/projects/Migrating+to+OCL%3A+PIH+Use+Case
# Ideally, this script would be able to be run via automation.
# One should be able to uncomment all steps at the bottom of the file, and execute this from start to finish
# In the event that issues are encountered, each step can be run piecemeal to step through components of the process
# Dependencies:  mvn, git, docker, jq, curl

if [ -z "$OCL_API_TOKEN" ]
then
      echo "You must have an OCL_API_TOKEN environment variable defined"
fi

PROJECT_NAME=oclexport
MYSQL_DOCKER_CONTAINER_NAME=mysql-oclexport
MYSQL_DOCKER_CONTAINER_PORT=3309
SDK_TOMCAT_PORT=8080
SDK_DEBUG_PORT=5000
OCL_API_URL=https://api.staging.openconceptlab.org
# OCL_API_URL=https://api.openconceptlab.org

SDK_DIR=~/openmrs/$PROJECT_NAME
CODE_DIR=$SDK_DIR/code

setup_mysql_docker_container() {
  docker stop $MYSQL_DOCKER_CONTAINER_NAME || true
  sleep 5
  docker rm -v $MYSQL_DOCKER_CONTAINER_NAME || true
  sleep 5
  docker run \
    --name $MYSQL_DOCKER_CONTAINER_NAME \
    -d \
    -p $MYSQL_DOCKER_CONTAINER_PORT:3306 \
    -e MYSQL_ROOT_PASSWORD=root \
    mysql:5.6 \
    --character-set-server=utf8 \
    --collation-server=utf8_general_ci \
    --max_allowed_packet=1G \
    --innodb-buffer-pool-size=2G
  sleep 10
}

setup_mysql_db() {
  docker exec -i ${MYSQL_DOCKER_CONTAINER_NAME} sh -c "exec mysql -u root -proot -e 'drop database if exists ${PROJECT_NAME};'"
  sleep 5
  docker exec -i ${MYSQL_DOCKER_CONTAINER_NAME} sh -c "exec mysql -u root -proot -e 'create database ${PROJECT_NAME} default charset utf8;'"
}

setup_sdk() {
  rm -fR $SDK_DIR
  mvn openmrs-sdk:setup \
      -DserverId=$PROJECT_NAME \
      -Ddistro=org.openmrs.distro:pihemr:2.0.0-SNAPSHOT \
      -DjavaHome=/usr/lib/jvm/java-8-openjdk-amd64 \
      -Dpih.config=mirebalais,mirebalais-humci \
      -DdbDriver=com.mysql.cj.jdbc.Driver \
      -DdbUri=jdbc\:mysql\://localhost\:${MYSQL_DOCKER_CONTAINER_PORT}/${PROJECT_NAME}?autoReconnect\=true\&useUnicode\=true\&characterEncoding\=UTF-8\&sessionVariables\=default_storage_engine%3DInnoDB \
      -DdbUser=root \
      -Ddebug=${SDK_DEBUG_PORT} \
      -DdbPassword=root \
      -DdbReset=true \
      -DbatchAnswers="${SDK_TOMCAT_PORT}"
}

install_config() {
  # Create a configuration that contains all of the MDS packages
  rm -fR $CODE_DIR && mkdir $CODE_DIR && pushd $CODE_DIR
  git clone https://github.com/PIH/openmrs-config-pihemr.git
  git clone https://github.com/PIH/openmrs-config-zl.git
  git clone https://github.com/PIH/openmrs-config-pihliberia.git && cp openmrs-config-pihliberia/configuration/pih/concepts/*.zip openmrs-config-pihemr/configuration/pih/concepts
  git clone https://github.com/PIH/openmrs-config-pihsl.git && cp openmrs-config-pihsl/configuration/pih/concepts/*.zip openmrs-config-pihemr/configuration/pih/concepts
  git clone https://github.com/PIH/openmrs-config-ces.git && cp openmrs-config-ces/configuration/pih/concepts/*.zip openmrs-config-pihemr/configuration/pih/concepts
  popd
  pushd $CODE_DIR/openmrs-config-zl && ./install.sh $PROJECT_NAME && popd
}

run_sdk() {
  mvn openmrs-sdk:run -DserverId=$PROJECT_NAME -DMAVEN_OPTS="-Xmx4g -Xms1g" &
  echo $! > $SDK_DIR/mvn.pid
  sleep 10
  wget -O /dev/null -o /dev/null http://localhost:${SDK_TOMCAT_PORT}/openmrs
  sleep 10
  echo "Waiting for OpenMRS startup message..."
  tail -f ~/openmrs/oclexport/openmrs.log 2>&1 | grep -q "Distribution startup complete"
  RETURN_CODE=$?
  if [[ $RETURN_CODE != 0 ]]; then
      echo "OpenMRS started.  Return code: $RETURN_CODE"
  fi
  echo "Killing SDK process"
  pkill -F $SDK_DIR/mvn.pid
}

export_openmrs_db() {
  docker exec ${MYSQL_DOCKER_CONTAINER_NAME} mysqldump -u root --password=root --routines ${PROJECT_NAME} > ${SDK_DIR}/${PROJECT_NAME}.sql
}

wait_for_task_completion() {
    TASK_ID=$(jq -r '.task' $1)
    echo "Waiting for task completion $1: $TASK_ID"
    STATUS=UNKNOWN
    while [[ "$STATUS" != "SUCCESS" ]]
    do
      STATUS=$(curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request GET $OCL_API_URL/tasks/$TASK_ID/ | jq -r '.state')
      echo "Task $TASK_ID Status: $STATUS"
      if [ "$STATUS" != "SUCCESS" ] && [ "$STATUS" != "FAILURE" ]; then
        sleep 10
      fi
    done
    DATA=$(curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request GET $OCL_API_URL/tasks/$TASK_ID/)
    echo $DATA | jq
}

delete_existing_collections_from_ocl() {
    COLLECTIONS_JSON=$(curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request GET $OCL_API_URL/orgs/PIH/collections/)
    COLLECTION_URLS=$(echo $COLLECTIONS_JSON | jq -r '.[] | .url')
    for COLLECTION in ${COLLECTION_URLS}
    do
      DELETE_RESOURCE=${OCL_API_URL}${COLLECTION}?async=true
      echo "Deleting collection: $DELETE_RESOURCE"
      OUTPUT_FILE=${SDK_DIR}/delete_collection.json
      curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request DELETE ${DELETE_RESOURCE} > ${OUTPUT_FILE}
      wait_for_task_completion ${OUTPUT_FILE}
      rm ${OUTPUT_FILE}
      echo "Collection deleted: $COLLECTION"
    done
}

# TODO Remove step to delete the HL7 Medication Dispense Reason Source when it is no longer being created
delete_existing_sources_from_ocl() {
  echo "Deleting the OpenBoxes source"
  curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request DELETE $OCL_API_URL/orgs/PIH/sources/OpenBoxes/?async=true > ${SDK_DIR}/delete_openboxes_source.json
  wait_for_task_completion ${SDK_DIR}/delete_openboxes_source.json

  echo "Deleting the HL7 Medication Dispense Reason Source"
  curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request DELETE $OCL_API_URL/orgs/PIH/sources/HL7-MedicationDispenseStatusReason/?async=true > ${SDK_DIR}/delete_hl7_medication_dispense_reason_source.json
  wait_for_task_completion ${SDK_DIR}/delete_hl7_medication_dispense_reason_source.json

  echo "Deleting the PIH source"
  curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request DELETE $OCL_API_URL/orgs/PIH/sources/PIH/?async=true > ${SDK_DIR}/delete_pih_source.json
  wait_for_task_completion ${SDK_DIR}/delete_pih_source.json

  echo "Deleting the PIH-Malawi source"
  curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request DELETE $OCL_API_URL/orgs/PIH/sources/PIH-Malawi/?async=true > ${SDK_DIR}/delete_pih_malawi_source.json
  wait_for_task_completion ${SDK_DIR}/delete_pih_malawi_source.json

  echo "Deleting the LiberiaMOH source"
  curl --silent -H "Authorization: Token $OCL_API_TOKEN" --request DELETE $OCL_API_URL/orgs/PIH/sources/LiberiaMOH/?async=true > ${SDK_DIR}/delete_pih_liberia_moh.json
  wait_for_task_completion ${SDK_DIR}/delete_pih_liberia_moh_source.json

}

create_pih_source_in_ocl() {
  SOURCE_JSON=$(jq -n \
            --arg id "PIH" \
            --arg short_code "PIH" \
            --arg name "PIH" \
            --arg full_name "Partners In Health" \
            --arg description "Partners In Health Dictionary" \
            --arg source_type "Dictionary" \
            --arg custom_validation_schema "OpenMRS" \
            --arg default_locale "en" \
            --arg supported_locales "en,es,fr,ht" \
            --arg autoid_concept_mnemonic "sequential" \
            --arg autoid_mapping_mnemonic "sequential" \
            --arg autoid_concept_external_id "uuid" \
            --arg autoid_mapping_external_id "uuid" \
            --arg autoid_concept_mnemonic_start_from "20000" \
             '$ARGS.named')

  curl --silent \
      -H "Authorization: Token $OCL_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --request POST \
      --data "${SOURCE_JSON}" \
      $OCL_API_URL/orgs/PIH/sources/
}

create_openboxes_source_in_ocl() {
  curl --silent \
      -H "Authorization: Token $OCL_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --request POST \
      --data '{"id":"OpenBoxes","short_code":"OpenBoxes","name":"OpenBoxes","full_name":"OpenBoxes","description":"OpenBoxes Product Code for Drug Mappings","source_type":"External","default_locale":"en","supported_locales":"en"}' \
      $OCL_API_URL/orgs/PIH/sources/
}

# TODO: Remove this when this has been added to OCL in the HL7 organization
create_hl7_medication_dispense_status_reason_source_in_ocl() {
  curl --silent \
      -H "Authorization: Token $OCL_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --request POST \
      --data '{"id":"HL7-MedicationDispenseStatusReason","short_code":"HL7-MedicationDispenseStatusReason","name":"HL7 Medication Dispense Status Reason","source_type":"External","default_locale":"en","supported_locales":"en"}' \
      $OCL_API_URL/orgs/PIH/sources/
}

create_pih_malawi_source_in_ocl() {
  curl --silent \
      -H "Authorization: Token $OCL_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --request POST \
      --data '{"id":"PIH-Malawi","short_code":"PIHMalawi","name":"PIH Malawi","description":"(2015 or older) Partners In Health Malawi concept dictionary","source_type":"External","default_locale":"en","supported_locales":"en"}' \
      $OCL_API_URL/orgs/PIH/sources/
}

create_liberia_moh_source_in_ocl() {
  curl --silent \
      -H "Authorization: Token $OCL_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --request POST \
      --data '{"id":"LiberiaMOH","short_code":"LiberiaMOH","name":"Liberia MoH","full_name":"LiberiaMOH","description":"Liberia Ministry of Health disease codes","source_type":"External","default_locale":"en","supported_locales":"en"}' \
      $OCL_API_URL/orgs/PIH/sources/
}

# TODO: Update to the HL7 organization and/or remove HL7-MedicationDispenseStatusReason when added to OCL
export_concepts_to_json() {
  pushd ${CODE_DIR}
  rm -fR ocl_omrs
  git clone https://github.com/OpenConceptLab/ocl_omrs.git
  popd
  pushd ${CODE_DIR}/ocl_omrs

  # For OpenMRS 2.5, we do not name the allow_decimal as precise, remove this
  sed -i "s/db_column='precise'//g" omrs/models.py
  # Add custom source mappings
  TO_REPLACE="# Added for AMPATH dictionary import"
  DISPENSE_STATUS=",{'owner_type': 'org', 'owner_id': 'HL7', 'omrs_id': 'HL7-MedicationDispenseStatus','ocl_id': 'HL7-MedicationDispenseStatus'}"
  DISPENSE_STATUS_REASON=",{'owner_type': 'org', 'owner_id': 'PIH', 'omrs_id': 'HL7 Medication Dispense Status Reason','ocl_id': 'HL7-MedicationDispenseStatusReason'}"
  OPENBOXES=",{'omrs_id': 'OpenBoxes', 'ocl_id': 'OpenBoxes', 'owner_type': 'org', 'owner_id': 'PIH'}"
  sed -i "s/${TO_REPLACE}/${DISPENSE_STATUS}${DISPENSE_STATUS_REASON}${OPENBOXES}/g" omrs/management/commands/__init__.py

  cp ${SDK_DIR}/${PROJECT_NAME}.sql local/
  export USE_GOLD_MAPPINGS=1
  ./sql-to-json.sh local/${PROJECT_NAME}.sql PIH PIH staging
# ./sql-to-json.sh local/${PROJECT_NAME}.sql PIH PIH production
  popd
}

bulk_import_into_ocl() {
  curl --silent \
      -H "Authorization: Token $OCL_API_TOKEN" \
      -H 'Content-Type: multipart/form-data' \
      --request POST \
      -F update_if_exists=true \
      -F file=@"$CODE_DIR/ocl_omrs/local/oclexport.json;type=application/json"  \
      $OCL_API_URL/importers/bulk-import-parallel-inline/custom-queue/ > ${SDK_DIR}/bulk_import.json
  wait_for_task_completion ${SDK_DIR}/bulk_import.json
}

#--arg custom_validation_schema "OpenMRS" \
create_collection_in_ocl() {
  COLLECTION_NAME=$1
  COLLECTION_DATA=$(jq -n \
                    --arg id "$COLLECTION_NAME" \
                    --arg short_code "$COLLECTION_NAME" \
                    --arg name "$COLLECTION_NAME" \
                    --arg full_name "$COLLECTION_NAME" \
                    --arg preferred_source "PIH" \
                    --arg collection_type "Dictionary" \
                    --arg supported_locales "en,es,fr,ht" \
                    --argjson extras '{"source": "/orgs/PIH/sources/PIH/"}' \
                     '$ARGS.named')
  echo "$COLLECTION_DATA"
  curl --silent \
      -H "Authorization: Token $OCL_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --request POST \
      --data "$COLLECTION_DATA" \
      $OCL_API_URL/orgs/PIH/collections/
  echo "$COLLECTION_NAME Collection Created"
}

# Param 1: Collection Name, Param 2: Concepts included
add_references_to_collection_in_ocl() {
  COLLECTION_NAME=$1
  CONCEPT_ARRAY=$( jq --compact-output --null-input '$ARGS.positional' --args -- "${@:2}")
  EXPRESSIONS=$( jq -n --argjson expressions "$CONCEPT_ARRAY" '$ARGS.named' )
  CASCADE=$(jq -n --arg method "sourcetoconcepts" --arg cascade_levels "*" --arg map_types "Q-AND-A,CONCEPT-SET" --arg return_map_types "*" --arg include_retired "true" '$ARGS.named')
  REFERENCE_DATA=$( jq -n --argjson data "$EXPRESSIONS" --argjson cascade "$CASCADE" '$ARGS.named' )
  OUTPUT_FILE=${SDK_DIR}/add_references_output.json
  curl --silent \
      -H "Authorization: Token $OCL_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --request PUT \
      --data "$REFERENCE_DATA" \
      $OCL_API_URL/orgs/PIH/collections/$COLLECTION_NAME/references/?async=true > ${OUTPUT_FILE}
  wait_for_task_completion ${OUTPUT_FILE}
  rm ${OUTPUT_FILE}
}

# Param 1: Collection Name, Param 2: Concepts included
create_collection_and_add_references_in_ocl() {
  create_collection_in_ocl "$1"
  add_references_to_collection_in_ocl "$@"
}

# TODO: This does not work, getting server error
create_collection_version() {
  COLLECTION_NAME=$1
  COLLECTION_VERSION=$2
  VERSION_DATA=$(jq -n --arg id "$COLLECTION_VERSION" --arg description "$COLLECTION_NAME $COLLECTION_VERSION" --arg released "true" '$ARGS.named')
  echo "$VERSION_DATA"
  curl --silent \
      -H "Authorization: Token $OCL_API_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --request POST \
      --data "$VERSION_DATA" \
      $OCL_API_URL/orgs/PIH/collections/$COLLECTION_NAME/versions/
}

# Not planned to be used, but for experimentation
create_pihemr_concept_set_in_ocl() {
  CONCEPT_JSON=$(jq -n \
            --arg id "10001" \
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
            --arg from_concept_url "/orgs/PIH/sources/PIH/concepts/10001/" \
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

#delete_existing_collections_from_ocl
#delete_existing_sources_from_ocl
#create_pih_source_in_ocl
#create_openboxes_source_in_ocl
#create_hl7_medication_dispense_status_reason_source_in_ocl
#create_liberia_moh_source_in_ocl
#create_pih_malawi_source_in_ocl

#setup_mysql_docker_container
#setup_mysql_db
#setup_sdk
#install_config
#run_sdk
#export_openmrs_db
#export_concepts_to_json
#bulk_import_into_ocl

#create_collection_in_ocl "PIHEMR_Concepts"
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12754/" #Allergies
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12571/" #Clinical_Concepts
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12892/" #COVID_19
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12647/" #Dispensing_Concepts
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12656/" #Disposition_Concepts
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/10669/" #Emergency_Triage
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/10473/" #Exam
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/10562/" #History
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/10846/" #HIV
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12643/" #HUM_Radiology_Orderables_1
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/9531/"  #HUM_Radiology_Orderables_2
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/13631/" #Immunization
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12503/" #Labs
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/11662/" #Maternal_Child_Health
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12751/" #Medication
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12554/" #Mental_Health
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12752/" #Metadata
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12481/" #NCD
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/11676/" #Oncology
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/10773/" #Pathology
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/10563/" #Pediatric_Feeding
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/10573/" #Pediatric_Supplements
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/13604/" #PIH_Death
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/13657/" #Rehab
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/9362/"  #Scheduling
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/12616/" #Socio_Economics
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/9779/"  #Surgery_1
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/13678/" #Surgery_2
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/11397/" #Zika
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/1785/"  #Ebola
#add_references_to_collection_in_ocl "PIHEMR_Concepts" "/orgs/PIH/sources/PIH/concepts/15002/" #Diagnoses

#create_collection_and_add_references_in_ocl "Mexico_Concepts" "/orgs/PIH/sources/PIH/concepts/11723/"
#create_collection_and_add_references_in_ocl "Liberia_Concepts" "/orgs/PIH/sources/PIH/concepts/12568/"
#create_collection_and_add_references_in_ocl "Sierra_Leone_Concepts" "/orgs/PIH/sources/PIH/concepts/12557/"
#
#create_collection_version "PIHEMR_Concepts" "1.0.0"
#create_collection_version "Mexico_Concepts" "1.0.0"
#create_collection_version "Liberia_Concepts" "1.0.0"
#create_collection_version "Sierra_Leone_Concepts" "1.0.0"

# The below is not used, it was an alternative to setting up the collection based on set members

#create_pihemr_concept_set_in_ocl
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12754/" #Allergies
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12571/" #Clinical_Concepts
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12892/" #COVID_19
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12647/" #Dispensing_Concepts
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12656/" #Disposition_Concepts
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/10669/" #Emergency_Triage
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/10473/" #Exam
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/10562/" #History
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/10846/" #HIV
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12643/" #HUM_Radiology_Orderables_1
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/9531/"  #HUM_Radiology_Orderables_2
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/13631/" #Immunization
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12503/" #Labs
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/11662/" #Maternal_Child_Health
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12751/" #Medication
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12554/" #Mental_Health
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12752/" #Metadata
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12481/" #NCD
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/11676/" #Oncology
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/10773/" #Pathology
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/10563/" #Pediatric_Feeding
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/10573/" #Pediatric_Supplements
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/13604/" #PIH_Death
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/13657/" #Rehab
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/9362/" #Scheduling
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/12616/" #Socio_Economics
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/9779/" #Surgery_1
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/13678/" #Surgery_2
#add_concept_to_pihemr_concept_set_in_ocl "/orgs/PIH/sources/PIH/concepts/11397/" #Zika
#create_collection_and_add_references_in_ocl "PIHEMR_Concepts_From_Set" "/orgs/PIH/sources/PIH/concepts/10001/"
