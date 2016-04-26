#!/bin/bash
#
# Set up the environment and install the stats-service ready to run and/or
# testing.
#
# Oisin Mulvihill
# 2016-04-25
#
cd /home/stats

export VENV=/app/pyenv
export BIN=$VENV/bin

# create a fresh isolated env:
echo "Creating env: $VENV"
virtualenv --clear --system-site-packages $VENV
if [ "$?" == 1 ];
then
    echo "Unable to create virtualenv!"
    exit 1
fi

# Copy in build cache from previous runs to aid setup:
if [ -d /data/wheel_cache ];
then
    echo "copying in wheel cache:"
    mkdir -p ~/.cache
    cp -R /data/wheel_cache/* ~/.cache/*
fi

# Extras needed for testing or the environment on container:
$BIN/easy_install -U pytest jinja2 pytest-cov
if [ "$?" == 1 ];
then
    echo "Unable to install bootstrap dependancies!"
    exit 1
fi

# Set up the 3rd party deps in order:re
PRJS="apiaccesstoken evasion-common docker-testingaids pytest-docker-service-fixtures stats-client stats-service"
for i in $PRJS; do cd /home/stats/$i ; $BIN/python setup.py develop ; done

echo "copying out build cache:"
mkdir -p /data/wheel_cache
cp -R ~/.cache/* /data/wheel_cache/
