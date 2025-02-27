#!/bin/bash
# This script polls for the status of the latest github action workflows for the given workflow
# By default, this will query for actions executed for the repository and latest commit from the execution directory
# A specific repository can be queried by passing in the owner and repo (eg. -o PIH -r openmrs-module-pihcore)
# A specific commit has can be queried by passing this in with the -s argument
# The workflow should be specified as the name of the workflow file without the yml extension (eg. deploy)
# This will return either a success or failure based on the success or failure of the workflow associated with the input arguments
#
# Example:  ./github-action-status.sh -o PIH -r openmrs-module-pihcore

# Variables from input arguments
GHA_BASE_URL="https://api.github.com/repos"
FREQUENCY=10  # Check status every X seconds, defaults to 10 seconds
TIMEOUT=1800  # Return with timeout result if no conclusion in X seconds, defaults to 1800 (30 minutes)
WORKFLOW="deploy"

ARGUMENTS_OPTS="o:r:w:s:f:t:"
while getopts "$ARGUMENTS_OPTS" opt; do
     case $opt in
        o  ) OWNER=$OPTARG;;
        r  ) REPO=$OPTARG;;
        w  ) WORKFLOW=$OPTARG;;
        s  ) SHA=$OPTARG;;
        f  ) FREQUENCY=$OPTARG;;
        t  ) TIMEOUT=$OPTARG;;
        \? ) echoerr "Unknown option: -$OPTARG"; exit 1;;
        :  ) echoerr "Missing option argument for -$OPTARG"; exit 1;;
        *  ) echoerr "Unimplemented option: -$OPTARG"; exit 1;;
     esac
done

if [ -z "${OWNER}" ] && [ -z "${REPO}" ] && [ -z "${SHA}" ]; then
  ORIGIN_URL=$(git remote get-url origin)
  OWNER=$(echo ${ORIGIN_URL} | cut -d/ -f4- | cut -d/ -f1)
  REPO=$(basename -s .git "${ORIGIN_URL}")
  SHA=$(git rev-parse HEAD)
fi

if [ -z "${OWNER}" ] || [ -z "${REPO}" ]; then
  echo "Unable to determine github repository"
  exit 1
fi

check_status() {
  GHA_WORKFLOW_RUNS_URL="${GHA_BASE_URL}/${OWNER}/${REPO}/actions/runs?head_sha=${SHA}"
  WORKFLOW_RUNS_RESPONSE=$(curl -Ls "${GHA_WORKFLOW_RUNS_URL}"  2>/dev/null)
  WORKFLOW_RUN=$(echo ${WORKFLOW_RUNS_RESPONSE} | jq '.workflow_runs | map(select(.path == ".github/workflows/'${WORKFLOW}'.yml")) | .[0]')
  STATUS_OUTPUT=$(echo "${WORKFLOW_RUN}" | jq "{
    path: .path,
    head_branch: .head_branch,
    head_sha: .head_sha,
    created_at: .created_at,
    updated_at: .updated_at,
    status: .status,
    conclusion: .conclusion
  }")
  echo "${STATUS_OUTPUT}"
}

BUILD_STATUS=""
while [ -z "${BUILD_STATUS}" ] && [ ${TIMEOUT} -gt 0 ]
do
  CURRENT_DATE=$(date '+%Y-%m-%d-%H-%M-%S')
  CURRENT_STATUS=$(check_status)
  echo "${CURRENT_DATE}"
  echo "${CURRENT_STATUS}"
  BUILD_STATUS=$(echo "${CURRENT_STATUS}" | jq -r '.conclusion')
  if [ "${BUILD_STATUS}" == "null" ]; then
    BUILD_STATUS=""
  fi
  if [ -z "${BUILD_STATUS}" ]; then
    echo "Remaining timeout: ${TIMEOUT}"
    sleep ${FREQUENCY}
    TIMEOUT=$((TIMEOUT - FREQUENCY))
  fi
done

if [ "$BUILD_STATUS" == "success" ]; then
  echo "Build Successful"
  exit 0;
elif [ -z "$BUILD_STATUS" ]; then
  echo "Build timed out"
  exit 1;
else
  echo "Build Failed with status: ${BUILD_STATUS}"
  exit 1;
fi
