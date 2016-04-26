#!/bin/bash
#
# Run the analytics service stats-service.
#
# Oisin Mulvihill
# 2016-04-25
#
export VENV=/app/pyenv
export BIN=$VENV/bin

echo "PSERVE_ARGS: '$PSERVE_ARGS'"
echo "CONFIG: '$CONFIG'"

function logmsg() {
    echo -e "** $(date +%Y-%m-%d:%H:%M:%S): $@\n"
}

source $BIN/activate
cd /home/stats/stats-service

test -e "$access_json"
if [ "$?" == 0 ];
then
    logmsg "Existing access.json found '$access_json'. Not generating."
else
    logmsg "access.json '$access_json' NOT found. Generating."
    $BIN/accesshelper --access_json=$access_json
fi

logmsg "Rendering configuration."
$BIN/python /bin/render_config.py

logmsg "Server running"
$BIN/pserve $PSERVE_ARGS $CONFIG

logmsg "Server exited."
