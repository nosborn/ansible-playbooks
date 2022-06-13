#!/bin/bash

set -o errexit
set -o nounset

cookie_jar="$(mktemp)"
readonly cookie_jar
trap 'rm -f "${cookie_jar}"' EXIT

# TODO
