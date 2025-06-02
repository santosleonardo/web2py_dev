#!/bin/sh
set -e

# shellcheck disable=SC1091
. /usr/local/bin/prestart.sh

# start the app set in CMD
exec "$@"