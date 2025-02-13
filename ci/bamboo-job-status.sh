#!/bin/bash
# This script polls for the status of a Bamboo plan
# This will return either a success or failure based on the success or failure of the workflow associated with the input arguments

# Example:  Get the result of the latest Address Hierarchy Module build in OpenMRS CI
# export OPENMRS_BAMBOO_API_KEY=XXXXXXXXXXXXXX
# ./bamboo-job-status.sh -h ci.openmrs.org -k ADDRHIER-ADDRHIER -v OPENMRS_BAMBOO_API_KEY

BAMBOO_HOST=""
BAMBOO_PROJECT_KEY=""
SHA=""
FREQUENCY=10  # Check status every X seconds, defaults to 10 seconds
TIMEOUT=1800  # Return with timeout result if no conclusion in X seconds, defaults to 1800 (30 minutes)
API_KEY_ENV_VAR_NAME="BAMBOO_API_KEY"

ARGUMENTS_OPTS="h:k:s:f:t:v:"
while getopts "$ARGUMENTS_OPTS" opt; do
     case $opt in
        h     ) BAMBOO_HOST=$OPTARG;;
        k     ) BAMBOO_PROJECT_KEY=$OPTARG;;
        s     ) SHA=$OPTARG;;
        f     ) FREQUENCY=$OPTARG;;
        t     ) TIMEOUT=$OPTARG;;
        v     ) API_KEY_ENV_VAR_NAME=$OPTARG;;
        \?    ) echoerr "Unknown option: -$OPTARG"; help; exit 1;;
        :     ) echoerr "Missing option argument for -$OPTARG"; help; exit 1;;
        *     ) echoerr "Unimplemented option: -$OPTARG"; help; exit 1;;
     esac
done

LIFECYCLE_STATE=""
BUILD_STATE=""
CHECK_COMPLETE="FALSE"
API_KEY=$(printenv ${API_KEY_ENV_VAR_NAME})

check_status() {
  if [ -z "${SHA}" ]; then
    BAMBOO_REST_URL="https://${BAMBOO_HOST}/rest/api/latest/result/${BAMBOO_PROJECT_KEY}?max-results=1&includeAllStates=true"
    API_RESPONSE=$(curl -Ls "${BAMBOO_REST_URL}" --header "Accept: application/json" --header "Authorization: Bearer ${API_KEY}" 2>/dev/null)
    PLAN_RESULT=$(echo "${API_RESPONSE}" |  jq '.results.result')
    echo "${PLAN_RESULT}"
  else
    BAMBOO_REST_URL="https://${BAMBOO_HOST}/rest/api/latest/result/byChangeset/${SHA}"
    API_RESPONSE=$(curl -Ls "${BAMBOO_REST_URL}" --header "Accept: application/json" --header "Authorization: Bearer ${API_KEY}" 2>/dev/null)
    PLAN_RESULT=$(echo "${API_RESPONSE}" |  jq '.results.result | map(select(.plan.key == "'${BAMBOO_PROJECT_KEY}'"))')
    echo "${PLAN_RESULT}"
  fi
}

while [ "${CHECK_COMPLETE}" == "FALSE" ]
do
  CURRENT_DATE=$(date '+%Y-%m-%d-%H-%M-%S')
  CURRENT_STATUS=$(check_status)
  echo "${CURRENT_DATE}"
  echo "${CURRENT_STATUS}"

  # Get the status of the build
  NUM_RESULTS=$(echo "${CURRENT_STATUS}" | jq -r '.[] | length')
  LIFECYCLE_STATE=$(echo "${CURRENT_STATUS}" | jq -r '.[0].lifeCycleState')
  BUILD_STATE=$(echo "${CURRENT_STATUS}" | jq -r '.[0].buildState')
  if [ "${LIFECYCLE_STATE}" == "Finished" ] || ((NUM_RESULTS == 0)) || ((TIMEOUT <= 0)); then
    CHECK_COMPLETE="TRUE"
  fi

  if [ "${CHECK_COMPLETE}" != "TRUE" ] ; then
    echo "LIFECYCLE_STATE=${LIFECYCLE_STATE}, BUILD_STATE=${BUILD_STATE}, TIMEOUT=${TIMEOUT}, FREQUENCY=${FREQUENCY}"
    sleep ${FREQUENCY}
    TIMEOUT=$((TIMEOUT - FREQUENCY))
  fi
done

echo "LIFECYCLE_STATE=${LIFECYCLE_STATE}, BUILD_STATE=${BUILD_STATE}"

if [ "${BUILD_STATE}" == "Successful" ]; then
  echo "Build Successful"
  exit 0;
elif [ -z "${BUILD_STATE}" ]; then
  echo "Build timed out"
  exit 1;
else
  echo "Build Failed with status: ${BUILD_STATE}"
  exit 1;
fi
