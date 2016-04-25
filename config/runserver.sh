#!/bin/bash
#
# Run the analytics service stats-service.
#
# Oisin Mulvihill
# 2016-04-25
#
echo "PSERVE: '$PSERVE'"
echo "PSERVE_ARGS: '$PSERVE_ARGS'"
echo "CONFIG: '$CONFIG'"

function logmsg() {
    echo -e "** $(date +%Y-%m-%d:%H:%M:%S): $@\n"
}

logmsg "rendering configuration."
/home/stats/pyenv/bin/python /bin/render_config.py

logmsg "Server running"
$PSERVE $PSERVE_ARGS $CONFIG

logmsg "Server exited."
