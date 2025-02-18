#!/usr/bin/env bash
set -e

echoWithDate() {
  CURRENT_DATE=$(date '+%Y-%m-%d-%H-%M-%S')
  echo "${CURRENT_DATE}: ${1}"
}

hasChecked=0
hasChanged=0
needsRecheck=0
recheckDelay=0 # If set to a value > 0, this will result in multiple checks at this delay interval, until 2 consecutive checks match
mavenProjectDir="$(pwd)"

ARGUMENTS_OPTS="r:d:"
while getopts "$ARGUMENTS_OPTS" opt; do
     case $opt in
        r  ) recheckDelay=$OPTARG;;
        d  ) mavenProjectDir=$OPTARG;;
        \? ) echoerr "Unknown option: -$OPTARG"; exit 1;;
        :  ) echoerr "Missing option argument for -$OPTARG"; exit 1;;
        *  ) echoerr "Unimplemented option: -$OPTARG"; exit 1;;
     esac
done

mavenArgs="-f ${mavenProjectDir}/pom.xml"

declare -A local_dependency_filenames=()
declare -A local_dependencies=()
declare -A remote_dependencies=()

# Determine the modules for which the dependency report will be run and needs to be checked
echoWithDate "List of modules to check for dependency changes:"
moduleBuildDirs=$(mvn ${mavenArgs} -q --also-make exec:exec -Dexec.executable="echo" -Dexec.args='${project.build.directory}')
echoWithDate "$moduleBuildDirs"

build_dependency_report() {
  echoWithDate "Building the latest version of the dependency report"
  mvn ${mavenArgs} --batch-mode --no-transfer-progress clean process-resources -U
}

# Build the initial dependency report, which also provides build directories for each module
build_dependency_report

# Get the latest remote dependency report for each module
for moduleBuildDir in ${moduleBuildDirs}; do
  echoWithDate "Checking module at ${moduleBuildDir}"
  module=$(dirname "${moduleBuildDir}")
  moduleBuildDir=$(echo "${moduleBuildDir}" | sed 's/\\/\//g')
  pomFile=$(dirname "${moduleBuildDir}")/pom.xml
  groupId=$(mvn help:evaluate -Dexpression=project.groupId -q -DforceStdout -f "${pomFile}")
  artifactId=$(mvn help:evaluate -Dexpression=project.artifactId -q -DforceStdout -f "${pomFile}")
  version=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout -f "${pomFile}")
  classifier=$(mvn help:evaluate -Dexpression=dependencyReportClassifier -q -DforceStdout -f "${pomFile}")
  artifact="${groupId}":"${artifactId}":"${version}":txt:"${classifier}"
  filename="${artifactId}-${version}-${classifier}.txt"
  if [ -f "${moduleBuildDir}/${filename}" ]; then
    remoteDependencyReportDir="${moduleBuildDir}/remote-dependency-report"
    remoteDependencyReportPath="${remoteDependencyReportDir}/${filename}"
    echoWithDate "Downloading remote dependency report for ${artifact}"
    mvn ${mavenArgs} --batch-mode --no-transfer-progress dependency:get -Dartifact=${artifact} -Dtransitive=false -U
    mvn ${mavenArgs} --batch-mode --no-transfer-progress dependency:copy -Dartifact=${artifact} -DoutputDirectory="${remoteDependencyReportDir}/"  -Dmdep.useBaseVersion=true
    if [ -f "${remoteDependencyReportPath}" ]; then
      remote_dependencies[${module}]=$(md5sum ${remoteDependencyReportPath} | awk '{ print $1 }')
      echoWithDate "Computed md5 for remote dependency: ${remote_dependencies[${module}]}"
    fi
    local_dependency_filenames[${module}]="${moduleBuildDir}/${filename}"
  else
    echoWithDate "No dependency report for this module, skipping"
  fi
done

while [ ${hasChecked} -eq 0 ] || [ ${needsRecheck} -eq 1 ]
do
  needsRecheck=0
  for moduleBuildDir in ${moduleBuildDirs}; do
    module=$(dirname "${moduleBuildDir}")
    echoWithDate "Checking module: ${module}"
    local_dependency_file=${local_dependency_filenames[${module}]}

    if [ -f "${local_dependency_file}" ]; then

      remote_dependency_checksum=${remote_dependencies[${module}]}
      echoWithDate "Remote checksum: ${remote_dependency_checksum}"

      # Compare the latest generated report with the remote report, to see if there are local changes
      local_dependency_checksum=$(md5sum "${local_dependency_file}" | awk '{ print $1 }')
      echoWithDate "Local checksum: ${local_dependency_checksum}"
      if [ "${remote_dependency_checksum}" != "${local_dependency_checksum}" ]; then
        hasChanged=1
      fi

      # If there are local changes, then see if this is a recheck by comparing the latest saved local checksums
      if [ ${hasChanged} -eq 1 ]; then
        previous_local_checksum="${local_dependencies[${module}]}"
        echoWithDate "Previous local checksum: ${previous_local_checksum}"
        if [ "${previous_local_checksum}" != "${local_dependency_checksum}" ]; then
          needsRecheck=1
        fi
      fi

      local_dependencies[${module}]="${local_dependency_checksum}"

    fi
  done

  if [ ${recheckDelay} -le 0 ]; then
    needsRecheck=0
  fi

  if [ ${hasChanged} -eq 1 ] && [ ${needsRecheck} -eq 1 ] ; then
    echoWithDate "Dependencies have changed.  Re-checking for additional changes in ${recheckDelay} seconds."
    sleep ${recheckDelay}
    build_dependency_report
  fi

  hasChecked=1
done

if [ ${hasChanged} -eq 0 ]; then
  echoWithDate "Check completed: No changes detected"
else
  echoWithDate "Check completed: Dependency changes detected"
fi

export DEPENDENCIES_CHANGED="${hasChanged}"
