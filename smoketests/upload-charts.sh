#!/bin/bash

set -e

find . -name 'Chart.lock' -type f -delete
find . -name '*.tgs' -type f -delete
find . -name 'requirements.lock' -type f -delete

if [ -f ".dependencies" ]; then
  rm .dependencies
else 
  touch .dependencies
fi


if [ -f ".indico-charts" ]; then
  rm .indico-charts
fi


for fullpath in $(find . -name Chart.yaml | sort)
do
  echo $fullpath >> .dependencies
done


# only push charts that have the marker indico.chart and a Chart.yaml file in it.
for fullpath in $(find . -name indico.chart | sort)
do
  dirname=$(dirname $fullpath)
  if [ -f "$dirname/Chart.yaml" ]; then
    echo "$dirname/Chart.yaml" >> .indico-charts
  fi
done


echo "Fetching Chart Dependencies"
cat .dependencies | parallel --halt-on-error 1 -k --joblog .dependent-results -j 16 ./build_helm_dependencies.sh {}
echo "Finished Dependencies"
cat .dependent-results

if [ -f ".pushed" ]; then
  rm .pushed
else 
  touch .pushed
fi

echo "Packaging Charts"
cat .dependencies | parallel --halt-on-error 1 -k --joblog .package-results -j 16 ./package_helm_chart.sh {} "$1"
echo "Finished Packaging"
cat .package-results

jobs_parallel_pushed=1
echo "Pushing Charts $jobs_parallel_pushed way"
cat .indico-charts | parallel --halt-on-error 1 -k --joblog .push-results -j $jobs_parallel_pushed ./push_helm_chart.sh {} "$1"
echo "Finished Chart Uploads"
cat .push-results

cat .pushed
