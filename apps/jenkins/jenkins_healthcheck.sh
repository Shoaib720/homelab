#!/bin/sh

# set -euo pipefail

if nc -z localhost 80; then
	exit 0
fi

exit 1