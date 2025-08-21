#!/bin/bash

# Si se pasa un patrón como argumento se usa el patrón. Si no, usa '*'
pattern="${1:-*}"

for dir in ./tasks/$pattern; do
  [[ -d "$dir" ]] || continue
  
  echo "$dir"
  folder_name=$(basename "$dir")
  bash ./scripts/task-gen-cases.sh "$folder_name"
done