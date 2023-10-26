#!/bin/bash

set -e
fullpath=$1
BRANCH_NAME=$2  # e.g: "main-xxxxxx"

dir=$(dirname $fullpath)
name=$(helm show chart $dir | yq '.name')
version=$(helm show chart $dir | yq '.version')

echo ""
echo "-------------------------------------------------------------------------------------------"

branch=${BRANCH_NAME//\//\-} # replace slashes with -
branch=${branch//_/\-} # replace underscores with -

if [ ! -z "$DRONE_TAG" ]; then
  version=$version-${DRONE_TAG}
else
  version=$version-$branch
fi

num_charts=$((num_charts+1))

echo "Working on Chart $name, Version: $version"

if [ -d "$dir/tests" ]
then
  for testfile in $(find $dir/tests -name '*.yaml')
  do
    testname=$(basename "$testfile")
    echo "Running test with $testfile"
  
    echo helm template ./$dir --dependency-update --name-template $testname --namespace default --kube-version 1.25 --values $testfile --include-crds --debug > /dev/null
    helm template ./$dir --dependency-update --name-template $testname --namespace default --kube-version 1.25 --values $testfile --include-crds --debug > /dev/null
      

    echo "Linting chart"
    helm lint ./$dir --values $testfile

    echo "Images referenced"
    helm template ./$dir --dependency-update --name-template $testname --namespace default --kube-version 1.25 --values $testfile --include-crds | yq '..|.image? | select(.)' | sort -u
  done
fi

#Push chart, check if it succeeded, if not, retry.
pushed="false"
retry_attempts=10
push_flags="--timeout 120"

until [ $pushed == "true" ] || [ $retry_attempts -le 0 ]
do
  chart_name="harborprod/${name}:${version}"
  if [ $retry_attempts -ne 10 ]; then
    push_flags="--timeout 120"
    echo "Retry push ${chart_name} [$retry_attempts]"
    sleep 10
  fi

  set +e
  echo "helm cm-push $dir --version $version harborprod ${push_flags} [$retry_attempts]"
  if helm cm-push $dir --version "$version" harborprod ${push_flags}; then
    echo "Succcess, Pushed: harborprod/${chart_name}"
    echo "\t--> harborprod/${name}:${version}\n" >> .pushed
    pushed="true"
  else
    pushed="false"
  fi

  #echo "helm cm-push $dir --version $version indicocm ${push_flags} [$retry_attempts]"
  #if helm cm-push $dir --version "$version" indicocm ${push_flags}; then
  #  echo "Succcess, Pushed: indicocm/${chart_name}"
  #  echo "\t--> indicocm/${name}:${version}\n" >> .pushed
  #  pushed="true"
  #else
  #  pushed="false"
  #fi
  
  set -e
  ((retry_attempts--))
done

set -e
# double-check that the chart was pushed.
if [ $retry_attempts -le 0 ]; then
  echo "Error: Unable to push $harborprod/${name}:${version}"
  exit 1
fi








