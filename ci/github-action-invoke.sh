#!/bin/bash
# This script invokes a github action workflow
# Example:  ./github-action-invoke.sh -o PIH -r openmrs-module-pihcore

set -e

# Variables from input arguments
GHA_BASE_URL="https://api.github.com/repos"
WORKFLOW="deploy"
API_KEY_ENV_VAR_NAME="GITHUB_API_KEY"

ARGUMENTS_OPTS="o:r:w:v:"
while getopts "$ARGUMENTS_OPTS" opt; do
     case $opt in
        o  ) OWNER=$OPTARG;;
        r  ) REPO=$OPTARG;;
        w  ) WORKFLOW=$OPTARG;;
        v  ) API_KEY_ENV_VAR_NAME=$OPTARG;;
        \? ) echoerr "Unknown option: -$OPTARG"; exit 1;;
        :  ) echoerr "Missing option argument for -$OPTARG"; exit 1;;
        *  ) echoerr "Unimplemented option: -$OPTARG"; exit 1;;
     esac
done

if [ -z "${OWNER}" ] || [ -z "${REPO}" ]; then
  echo "Please specify github owner and repository"
  exit 1
fi

WORKFLOW_URL="${GHA_BASE_URL}/${OWNER}/${REPO}/actions/workflows/${WORKFLOW}.yml/dispatches"
API_KEY=$(printenv ${API_KEY_ENV_VAR_NAME})

curl --request POST \
  --url "${WORKFLOW_URL}" \
  --user "YOUR_CLIENT_ID:YOUR_CLIENT_SECRET" \
  --header "X-GitHub-Api-Version: 2022-11-28" \
  --header "Authorization: Bearer ${API_KEY}" \
  --data '{"ref":"master"}'

echo "${WORKFLOW_URL} invoked"

