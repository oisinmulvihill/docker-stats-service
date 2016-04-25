#!/bin/bash
#
#
echo "Recovering deps:"
cd /home/stats

export SERVER_ENV=development
export DK_CONFIG_FILE=/home/stats/dk_config.yaml

export VENV=/app/scpenv
export BIN=$VENV/bin

# Ready to roll:
#
cd /home/stats/stats-service

source $BIN/activate
$BIN/py.test -sv
if [ "$?" == 1 ];
then
    echo "FAILED: py.test run!"
    exit 1
fi
