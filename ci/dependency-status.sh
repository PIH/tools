#!/usr/bin/env bash
set -e

hasChanged=0

# Determine the modules for which the dependency report will be run and needs to be checked
echo "List of modules to check for dependency changes:"
moduleBuildDirs=$(mvn -q --also-make exec:exec -Dexec.executable="echo" -Dexec.args='${project.build.directory}')
echo "$moduleBuildDirs"

# Execute a local build to clean target directories and generate up-to-date dependency reports
echo "Compile the latest version of the dependency report"
mvn --batch-mode --no-transfer-progress clean process-resources -U

# Iterate over each module to compare each dependency report
for moduleBuildDir in ${moduleBuildDirs}; do
  moduleBuildDir=$(echo "${moduleBuildDir}" | sed 's/\\/\//g')
  pomFile=$(dirname "${moduleBuildDir}")/pom.xml

  # Get the groupId, artifactId, and version
  groupId=$(mvn help:evaluate -Dexpression=project.groupId -q -DforceStdout -f "${pomFile}")
  artifactId=$(mvn help:evaluate -Dexpression=project.artifactId -q -DforceStdout -f "${pomFile}")
  version=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout -f "${pomFile}")
  classifier=$(mvn help:evaluate -Dexpression=dependencyReportClassifier -q -DforceStdout -f "${pomFile}")
  artifact="${groupId}":"${artifactId}":"${version}":txt:"${classifier}"
  filename="${artifactId}-${version}-${classifier}.txt"
  newDependencyReportPath="${moduleBuildDir}/${filename}"
  remoteDependencyReportDir="${moduleBuildDir}/remote-dependency-report"
  remoteDependencyReportPath="${remoteDependencyReportDir}/${filename}"

  if [ ! -f "${newDependencyReportPath}" ]; then
    echo "No dependency report generated at '${newDependencyReportPath}'"
  else
    # Fetch the remote dependency report
    echo "Fetch remote dependency report ${artifact}..."
    set +e
    mvn --batch-mode --no-transfer-progress org.apache.maven.plugins:maven-dependency-plugin:3.6.0:get -Dartifact=${artifact} -Dtransitive=false -U
    mvn --batch-mode --no-transfer-progress org.apache.maven.plugins:maven-dependency-plugin:3.6.0:copy -Dartifact=${artifact} -DoutputDirectory="${remoteDependencyReportDir}/"  -Dmdep.useBaseVersion=true
    set -e

    # If no dependency report was fetched, then this is a change
    if [ ! -f "${remoteDependencyReportPath}" ]; then
      echo "No matching remote dependency report found."
      hasChanged=1
    else
      # Compare the 2 files. Will exit with 0 if no change, 1 if changes
      echo "Compare both dependency reports..."
      set +e
      diff "${newDependencyReportPath}" "${remoteDependencyReportPath}"
      diff_rc=$?
      if [ $diff_rc -eq 0 ]; then
        echo "No dependency change"
      elif [ $diff_rc -eq 1 ]; then
        echo "One or more dependency has changed"
        hasChanged=1
      else
        echo "Unknown error occurred."
      fi
    fi
  fi
done

if [ ${hasChanged} -eq 0 ]; then
  echo "Check completed: No changes detected"
else
  echo "Check completed: Dependency changes detected"
fi

exit ${hasChanged}