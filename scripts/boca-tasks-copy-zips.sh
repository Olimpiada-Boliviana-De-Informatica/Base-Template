#!/bin/bash

rm -rf boca/zips
mkdir -p boca/zips

for dir in ./tasks/*; do
  echo "$dir"
  folder_name=$(basename "$dir")
  cp "$dir/$folder_name.zip" boca/zips/
done
