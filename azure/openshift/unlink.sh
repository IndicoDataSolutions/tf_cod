#!/bin/bash

linked_files=$(ls -la | grep ^l | awk '{print $9}')
echo $linked_files
for lf in $linked_files
do
  echo unlinking $lf
  cp --remove-destination "$(readlink $lf)" $lf
done

