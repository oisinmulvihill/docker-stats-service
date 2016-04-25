#!/bin/bash
#
#set -x
JENKINS_USER=${JENKINS_USER:=jenkins}
ROOT_DIR=${ROOT_DIR:=`pwd`}
SCP_DB_DIR=${SCP_DB_DIR:=$ROOT_DIR}
BOX_VERSION=${BOX_VERSION:=1.0.0}
BOX_NAME=${BOX_NAME:=scp_api_service}
SCP_API_IMAGE=supercarers/$BOX_NAME:$BOX_VERSION
IMAGE_NAME=supercarers/$BOX_NAME:$BOX_VERSION
NO_CACHE=${NO_CACHE:=}
ON_DEVBOX=${ON_DEVBOX:=}
INTERACTIVE=${INTERACTIVE:=}
# where build dir is to cache speeding up build times
BUILD_DIR=${BUILD_DIR:=/tmp/scp_api_service_build}


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

    # Login to the repository so we can publish new containers there:
    docker login -u docker -p d0ck3rc0ff33 docker.supercarers.com
    if [ "$?" == 1 ];
    then
        echo "Login to docker.supercarers.com FAILED."
        return 1
    else
        echo "Login to docker.supercarers.com OK."
    fi

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

    if [ "$ON_DEVBOX" = 1 ];
    then
        INTERACTIVE=-i
        echo "On DEVBOX! using interaction e.g INTERACTIVE=$INTERACTIVE"
        SCP_PG_IMAGE_VER="1.0.0"
        SCP_PG_IMAGE_TAG="supercarers/scp-postgres:$SCP_PG_IMAGE_VER"
        echo "On DEVBOX! Setting SCP_PG_IMAGE_VER=$SCP_PG_IMAGE_VER"
    else
        # The get latest scp_postgres version number we should use. This
        # will be available on our docker repo.
        SCP_PG_IMAGE_VER=$(/usr/bin/etcdctl get /docker/image/scp/postgres/latest)
        if [ "$?" = 1 ];
        then
            echo "Failed to recover version from /docker/image/scp/postgres/latest from etcd!"
            return 1
        fi
        SCP_PG_IMAGE_TAG=docker.supercarers.com/scp-postgres:1.0.0
        # SCP_PG_IMAGE_TAG=$(/usr/bin/etcdctl get /docker/image/scp/postgres/tag)
        # if [ "$?" = 1 ];
        # then
        #     echo "Failed to recover version from /docker/image/scp/postgres/tag from etcd!"
        #     return 1
        # fi
    fi

    docker stop SCPAPIDB >/dev/null ; docker rm -f SCPAPIDB >/dev/null
    docker stop SCPAPIRED >/dev/null ; docker rm -f SCPAPIRED >/dev/null

    docker run -d -t \
        --name SCPAPIDB \
        $SCP_PG_IMAGE_TAG
    if [ "$?" == 1 ];
    then
        echo "Failed to start test Postgres."
        return 1
    fi

    docker run -d -t \
        --name SCPAPIRED \
        redis
    if [ "$?" == 1 ];
    then
        echo "Failed to start test Redis."
        return 1
    fi

    docker run \
        --link SCPAPIDB:postgres \
        --link SCPAPIRED:redis \
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
    docker stop SCPAPIDB >/dev/null ; docker rm -f SCPAPIDB >/dev/null
    docker stop SCPAPIRED >/dev/null ; docker rm -f SCPAPIRED >/dev/null
}


function publish_container() {
    # tag to push to our docker repository:
    docker tag $SCP_API_IMAGE docker.supercarers.com/$SCP_API_IMAGE
    if [ "$?" == 1 ];
    then
        echo "Failed to tag image $SCP_API_IMAGE!"
        return 1
    fi

    # publish:
    docker push docker.supercarers.com/$SCP_API_IMAGE
    if [ "$?" == 1 ];
    then
        echo "Failed to push docker.supercarers.com/$SCP_API_IMAGE!"
        return 1
    fi

    # Setting the latest working version of the docker container:
    #
    /usr/bin/etcdctl set /docker/image/scp/api/latest $BOX_VERSION
    if [ "$?" == 1 ];
    then
        echo "Failed to set latest version number for docker.supercarers.com/$SCP_API_IMAGE!"
        return 1
    fi

    /usr/bin/etcdctl set /docker/image/scp/api/tag docker.supercarers.com/$SCP_API_IMAGE
    if [ "$?" == 1 ];
    then
        echo "Failed to set latest version number for docker.supercarers.com/$SCP_API_IMAGE!"
        return 1
    fi
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

    print_stage "Publishing the container: v$BOX_VERSION"
    publish_container
    if [ "$?" == 1 ];
    then
        echo "Building the container failed!"
        return 1
    fi

    print_stage "Tear Down Clean Up."
    tear_down
}

main
