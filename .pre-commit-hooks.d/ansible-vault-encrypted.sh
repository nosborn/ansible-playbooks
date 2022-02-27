#!/bin/bash

set -o errexit
set -o nounset

result=0

for file in "$@"; do
  if [[ $(head -n 1 "${file}") != '$ANSIBLE_VAULT;1.1;AES256' ]]; then
    printf '%s is not encrypted\n' "${file}" >&2
    result=1
  fi
done

exit ${result}
