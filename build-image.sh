#!/bin/bash

# Copyright (c) 2018, Arm Limited and affiliates.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    SELF="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$SELF/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done

MYDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

function print_usage() {
    echo "build-image.sh IMAGEID IMAGE_NAME_IN_REPO"
    echo "options:"
    echo " -i       Invalidate the cache. docker build --no-cache"
    echo " -t TAG   Tag with something other than 'latest'"
    echo " -n       No force rebuild. Might just use current image to push. (might)"
    echo " -p       Pretend. But don't do it."
}

pushd $MYDIR > /dev/null

REGISTRY_PREFIX="docker-registry.wigwag.io:5000"

while getopts "inpt:" opt; do
    case $opt in
    i) 
        NO_CACHE="--no-cache"
        ;;
    t)
        TAG_NAME="${OPTARG}"
        ;;
    n)
       NO_FORCE_REBUILD="1"
        ;;
    p)
        PRETEND="1"
        ;;
    esac
done

shift "$((OPTIND - 1))"


if [ "$#" -gt 0 ]; then    

    IMAGE_NAME=$1
#    IMAGE_ID=$1
    
    if [ ! -d "$IMAGE_NAME" ]; then
	echo "No directory for image $IMAGE_NAME"
	exit 1
    fi

    cd $IMAGE_NAME

#    USERNAME=`whomai`
#    chown -R $USERNAME:$USERNAME *
    
    if [ -z "$NO_FORCE_REBUILD" ]; then
	echo ""
	echo "Will git pull & rebuild..."
	echo ""
	rm -f .build-date
	echo "# Built $1 @ `date`" > .build-date
    fi

#    if [ -e build-wwcontainer.sh ]; then
#	cp build-wwcontainer.sh exec-build-wwcontainer.sh	
#	cat .build-date >> exec-build-wwcontainer.sh
#	chmod a+x exec-build-wwcontainer.sh
#    else
#	echo "WARNING: no build-wwcontainer.sh found"
#    fi

    echo "Building..."
    IMAGE_ID="$( docker build ${NO_CACHE} . 2>&1 | tee /dev/tty | tee ./push-image.build.log | grep "Successfully built" | awk '{ print $3 }' )"

    echo "*********************"
    cat ./push-image.build.log
    echo "*********************"
    echo "IMAGE ID: $IMAGE_ID ready"
    
    STORE_AS="$REGISTRY_PREFIX/$IMAGE_NAME"

    if [ ! -z "$TAG_NAME" ]; then
	STORE_AS="$STORE_AS:$TAG_NAME"
    fi
    
    if [ ! -z "$1" ]; then
	echo "Push image: $IMAGE_ID ----->  $STORE_AS - press enter to begin (CTRL-C to abort)" 
	read
    fi

    if [ ! -z "$IMAGE_ID" ]; then
	if [ ! -z "$PRETEND" ]; then
	    echo "PRETEND: docker tag $STORE_AS"
	    echo "PRETNED: docker push $STORE_AS"
	else
	    docker tag $IMAGE_ID $STORE_AS
	    docker push $STORE_AS
	fi
	echo "Pushed. Clealing up..."
	rm ./push-image.build.log
	docker rmi $IMAGE_NAME
    else
	echo "Image build failed!!!"
	echo "see `pwd`/push-image.build.log"
	docker rmi $IMAGE_NAME
    fi
    
else
    print_usage
fi

popd > /dev/null
