#!/bin/bash
# This script polls for the status of a Bamboo plan
#
# Example:  Get the result of the latest Address Hierarchy Module build in OpenMRS CI
# export OPENMRS_BAMBOO_API_KEY=XXXXXXXXXXXXXX
# ./bamboo-job-status.sh -h ci.openmrs.org -k ADDRHIER-ADDRHIER -v OPENMRS_BAMBOO_API_KEY

BAMBOO_HOST=""
BAMBOO_PROJECT_KEY=""
FREQUENCY=10  # Check status every X seconds, defaults to 10 seconds
TIMEOUT=1800  # Return with timeout result if no conclusion in X seconds, defaults to 1800 (30 minutes)
API_KEY_ENV_VAR_NAME="BAMBOO_API_KEY"

ARGUMENTS_OPTS="h:k:f:t:v:"
while getopts "$ARGUMENTS_OPTS" opt; do
     case $opt in
        h     ) BAMBOO_HOST=$OPTARG;;
        k     ) BAMBOO_PROJECT_KEY=$OPTARG;;
        f     ) FREQUENCY=$OPTARG;;
        t     ) TIMEOUT=$OPTARG;;
        v     ) API_KEY_ENV_VAR_NAME=$OPTARG;;
        \?    ) echoerr "Unknown option: -$OPTARG"; help; exit 1;;
        :     ) echoerr "Missing option argument for -$OPTARG"; help; exit 1;;
        *     ) echoerr "Unimplemented option: -$OPTARG"; help; exit 1;;
     esac
done

BAMBOO_REST_URL="https://${BAMBOO_HOST}/rest/api/latest/result/${BAMBOO_PROJECT_KEY}?max-results=1&includeAllStates=true"
STATUS_FILE="build-status.json"
echo "Checking ${BAMBOO_REST_URL}"
echo "Writing to ${STATUS_FILE}"

LIFECYCLE_STATE=""
BUILD_STATE=""
CHECK_COMPLETE="FALSE"

while [ "${CHECK_COMPLETE}" == "FALSE" ]
do
  # Save the latest build result as a file
  curl -Ls "${BAMBOO_REST_URL}" --header "Accept: application/json" --header "Authorization: Bearer $(printenv ${API_KEY_ENV_VAR_NAME})" | jq > ${STATUS_FILE} 2>/dev/null

  echo "Checking build status: $(date '+%Y-%m-%d-%H-%M-%S')"
  cat ${STATUS_FILE}
  echo ""

  # Get the status of the build
  NUM_RESULTS=$(jq -r '.results.result | length' ${STATUS_FILE})
  LIFECYCLE_STATE=$(jq -r '.results.result[0].lifeCycleState' ${STATUS_FILE})
  BUILD_STATE=$(jq -r '.results.result[0].buildState' ${STATUS_FILE})
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
