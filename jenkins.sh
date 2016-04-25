#!/bin/bash
#
#set -x
JENKINS_USER=${JENKINS_USER:=jenkins}
ROOT_DIR=${ROOT_DIR:=`pwd`}
SCP_DB_DIR=${SCP_DB_DIR:=$ROOT_DIR}
BOX_VERSION=${BOX_VERSION:=1.0.0}
BOX_NAME=${BOX_NAME:=stats_service}
SCP_API_IMAGE=oisinmulvihill/$BOX_NAME:$BOX_VERSION
IMAGE_NAME=oisinmulvihill/$BOX_NAME:$BOX_VERSION
NO_CACHE=${NO_CACHE:=}
ON_DEVBOX=${ON_DEVBOX:=}
INTERACTIVE=${INTERACTIVE:=}
# where build dir is to cache speeding up build times
BUILD_DIR=${BUILD_DIR:=/tmp/stats_service_build}


function setup() {

    if [ "$BOX_VERSION" = "0.0.0" ]; then
        echo "Error: BOX_VERSION not set in the environment. Please do so."
        return 1
    else
        echo "The container version to build is: v$BOX_VERSION"
    fi

    echo "ROOT_DIR: $ROOT_DIR"
    echo "BUILD_DIR: $BUILD_DIR"
    echo "BOX_VERISON: $BOX_VERSION"
    echo "BOX_NAME: $BOX_NAME"
    echo "IMAGE_NAME: $IMAGE_NAME"

    # stop and remove if there is a old/failed container hanging around:
    docker stop $BOX_NAME 2>/dev/null ; docker rm -f $BOX_NAME 2>/dev/null

    return 0
}



function tear_down() {
    # clean up:
    docker stop $BOX_NAME >/dev/null ; docker rm -f $BOX_NAME >/dev/null
    echo "clean-up done."

    return 0
}


function print_stage() {
    # Make it easier to see which stage stdout output belongs to.
    echo
    echo "---------------------------------------------------------------------"
    echo
    echo -e $1
    echo
    echo "---------------------------------------------------------------------"
    echo
}


function build_container() {
    echo "Creating build caching directory: $BUILD_DIR"
    mkdir -p $BUILD_DIR

    # build, use --no-cache for clean build each time:
    docker build --force-rm $NO_CACHE -t $IMAGE_NAME .
    if [ "$?" == 1 ];
    then
        echo "Box build failure!"
        return 1
    fi
}


function run_tests() {

    docker stop INFLUXDB >/dev/null ; docker rm -f INFLUXDB >/dev/null

    docker run -d -t \
        --name INFLUXDB \
        tutum/influxdb
    if [ "$?" == 1 ];
    then
        echo "Failed to start test InfluxDB."
        return 1
    fi

    docker run \
        --link INFLUXDB:influxdb \
        --name $BOX_NAME \
        -v $BUILD_DIR:/data \
        $INTERACTIVE \
        -t $IMAGE_NAME \
        /bin/bash /bin/run_tests.sh
    if [ "$?" == 1 ];
    then
        echo "Test run failure."
        return 1
    fi

    # Clean up:
    docker stop INFLUXDB >/dev/null ; docker rm -f INFLUXDB >/dev/null
}


function main() {
    # Don't continue a step in fails.
    print_stage "Set Up Environment."
    setup
    if [ "$?" == 1 ];
    then
        return 1
    fi

    print_stage "Building the test container."
    build_container
    if [ "$?" == 1 ];
    then
        echo "Building the container failed!"
        return 1
    fi

    print_stage "Running tests."
    run_tests
    if [ "$?" == 1 ];
    then
        echo "Testing container failed!"
        return 1
    fi

    print_stage "Tear Down Clean Up."
    tear_down
}

main
