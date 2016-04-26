#!/bin/bash
#
#
echo "Recovering deps:"
cd /home/stats

export DK_CONFIG_FILE=/home/stats/dk_config.yaml


# These are available when the box is running:
#
export DKInfluxDB_UseENV=yes
export DKInfluxDB_PORT=$INFLUXDB_PORT_8086_TCP_PORT
export DKInfluxDB_HOST=$INFLUXDB_PORT_8086_TCP_ADDR
export DKInfluxDB_USER=root
export DKInfluxDB_PASSWORD=root
export DKInfluxDB_DB=test_analytics

echo "DKInfluxDB_UseENV: $DKInfluxDB_UseENV"
echo "DKInfluxDB_PORT: $DKInfluxDB_PORT"
echo "DKInfluxDB_HOST: $DKInfluxDB_HOST"
echo "DKInfluxDB_USER: $DKInfluxDB_USER"
echo "DKInfluxDB_PASSWORD: $DKInfluxDB_PASSWORD"
echo "DKInfluxDB_DB: $DKInfluxDB_DB"

export VENV=/app/pyenv
export BIN=$VENV/bin

# Ready to roll:
#
cd /home/stats/stats-service

source $BIN/activate
$BIN/py.test -sv --cov=stats --pdb
if [ "$?" == 1 ];
then
    echo "FAILED: py.test run!"
    exit 1
fi
