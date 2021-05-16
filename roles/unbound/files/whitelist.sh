#!/bin/ksh

set -euo pipefail
IFS=$'\n\t'

# Download Anudeep's commonly safelisted domains [0] and allow Unbound lookups to them.
#
#   [0]: https://github.com/anudeepND/whitelist
curl -fLoSs https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt |
  sort -u |                                                # Remove any duplicates
  awk '{print "local-zone: \""$1".\" always_transparent"}' # Convert to Unbound configuration
