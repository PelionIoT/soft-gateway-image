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

echo "WigWag Cloud Startup"
echo "----------------------"

WIGWAG_CLOUD_REPO="WigWagCo/wigwag-cloud.git"
WIGWAG_CLOUD_BRANCH="production"

DEVICEDB_CLOUD_REPO="WigWagCo/devicedb-cloud.git"
DEVICEDB_CLOUD_BRANCH="master"

DEVICEJS_CLOUD_REPO="WigWagCo/devicejs-cloud.git"
DEVICEJS_CLOUD_BRANCH="master"

WIGWAG_CLOUD_PROXY_REPO="WigWagCo/wigwag-cloud-proxy.git"
WIGWAG_CLOUD_PROXY_BRANCH="master"

if [ -e /wigwag/repo_path_overrides ]; then
    . /wigwag/repo_path_overrides
fi

PREF="[ww]>> "
ERROR_PREF="[ERROR ww]>> "

cd /wigwag


if [ ! -e wigwag_devops_cloud_github_latest ]; then
    echo $ERROR_PREF"Missing cloud github key for checkout. need /wigwag/wigwag_devops_cloud_github_latest"
    exit 1
fi


# potential roles for this container:
#ROLES="devicejs-cloud,devicedb-cloud,wigwag-cloud,wigwag-cloud-proxy,mongodb,mysql"
ROLES="$1"

while [ "$ROLES" ] ;do
    role=${ROLES%%,*}
    echo $PREF"ROLE: $role"
    echo "----------------------"

    if [ "$role" == "devicejs-cloud" ]; then
	cd /home/wigwag

	if [ ! -d devicejs-cloud ]; then
	    echo $PREF"Doing initial clone of repo github.com:${DEVICEJS_CLOUD_REPO}"
	    gosu wigwag git clone git@wigwagcloud_github.com:${DEVICEJS_CLOUD_REPO}
	fi

	cd /home/wigwag/devicejs-cloud

	if [ ! -e package.json ]; then
	    echo $ERROR_PREF"Failed to checkout repo - missing package.json at root. Check keys / repo"
	    exit 1
	fi

	if [ ! -z "${DEVICEJS_CLOUD_BRANCH}" ]; then
	    echo $PREF"checking out branch: ${DEVICEJS_CLOUD_BRANCH}"
	    gosu wigwag git checkout ${DEVICEJS_CLOUD_BRANCH}
	fi

	echo $PREF"Updating via git pull"
	gosu wigwag git pull

	echo $PREF"Running npm installs"
	gosu wigwag npm install

    fi

    if [ "$role" == "devicedb-cloud" ]; then
	cd /home/wigwag

	if [ ! -d devicedb-cloud ]; then
	    echo $PREF"Doing initial clone of repo github.com:${DEVICEDB_CLOUD_REPO}"
	    gosu wigwag git clone git@wigwagcloud_github.com:${DEVICEDB_CLOUD_REPO}
	fi

	cd /home/wigwag/devicedb-cloud

	if [ ! -e package.json ]; then
	    echo $ERROR_PREF"Failed to checkout repo - missing package.json at root. Check keys / repo"
	    exit 1
	fi

	if [ ! -z "${DEVICEDB_CLOUD_BRANCH}" ]; then
	    echo $PREF"checking out branch: ${DEVICEDB_CLOUD_BRANCH}"
	    gosu wigwag git checkout ${DEVICEDB_CLOUD_BRANCH}
	fi

	echo $PREF"Updating via git pull"
	gosu wigwag git pull

	echo $PREF"Running npm installs"
	gosu wigwag npm install
	
    fi
    if [ "$role" == "wigwag-cloud" ]; then

	cd /home/wigwag

	if [ ! -d wigwag-cloud ]; then
	    echo $PREF"Doing initial clone of repo github.com:${WIGWAG_CLOUD_REPO}"
	    gosu wigwag git clone git@wigwagcloud_github.com:${WIGWAG_CLOUD_REPO}
	fi

	cd /home/wigwag/wigwag-cloud

	if [ ! -e package.json ]; then
	    echo $ERROR_PREF"Failed to checkout repo - missing package.json at root. Check keys / repo"
	    exit 1
	fi

	if [ ! -z "${WIGWAG_CLOUD_BRANCH}" ]; then
	    echo $PREF"checking out branch: ${WIGWAG_CLOUD_BRANCH}"
	    gosu wigwag git checkout ${WIGWAG_CLOUD_BRANCH}
	fi

	echo $PREF"Updating via git pull"
	gosu wigwag git pull

	echo $PREF"Running npm installs"
	gosu wigwag npm install
	
    fi


# get next comma separated value:   
    [ "$ROLES" = "$role" ] && \
	ROLES='' || \
	ROLES="${ROLES#*,}"
done


echo "WigWa Cloud Startup Done"
echo "------------------------"





