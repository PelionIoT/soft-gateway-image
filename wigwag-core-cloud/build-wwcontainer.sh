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

echo "WigWag Cloud Client Build"
echo "----------------------"

WIGWAG_CLOUD_REPO="WigWagCo/wigwag-cloud.git"
WIGWAG_CLOUD_BRANCH="sites-support"

DEVICEDB_CLOUD_REPO="WigWagCo/devicedb-cloud.git"
DEVICEDB_CLOUD_BRANCH="master"

DEVICEJS_CLOUD_REPO="WigWagCo/devicejs-cloud.git"
DEVICEJS_CLOUD_BRANCH="site-support"

WIGWAG_CLOUD_PROXY_REPO="WigWagCo/wigwag-cloud-proxy.git"
WIGWAG_CLOUD_PROXY_BRANCH="master"

if [ -e /wigwag/repo_path_overrides ]; then
    . /wigwag/repo_path_overrides
fi

# KEEP_GIT="1" # this would keep git file

PREF="[ww]>> "
ERROR_PREF="[ERROR ww]>> "

CONFIG_RECORD_FILE="/wigwag/container-config"

rm -f $CONFIG_RECORD_FILE
touch $CONFIG_RECORD_FILE

cd /wigwag

mkdir -p /config
mkdir -p /apps
chown -R wigwag:wigwag /config
chown -R wigwag:wigwag /apps

if [ ! -e wigwag_devops_cloud_github_latest ]; then
    echo $ERROR_PREF"Missing cloud github key for checkout. need /wigwag/wigwag_devops_cloud_github_latest"
    exit 1
fi




# potential roles for this container:
#ROLES="devicejs-cloud,devicedb-cloud,wigwag-cloud,wigwag-cloud-proxy,mongodb,mysql"
ROLES="$1"

# make sure to call this one from the right directory!
function remove_git_stuff () {
    if [ -z ${KEEP_GIT} ]; then
	echo "Removing .git and other artifacts"
	( find . -type d -name ".git" \
      && find . -name ".gitignore" \
      && find . -name ".gitmodules" ) | xargs rm -rf
    fi
}


while [ "$ROLES" ] ;do
    role=${ROLES%%,*}
    echo $PREF"ROLE: $role"
    echo "----------------------"

    echo "----------------------" >> $CONFIG_RECORD_FILE
    echo "ROLE: $role" >> $CONFIG_RECORD_FILE
    
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
	    echo "Branch: ${DEVICEJS_CLOUD_BRANCH}" >> $CONFIG_RECORD_FILE
	fi
	
	echo $PREF"Updating via git pull"
	gosu wigwag git pull

	git log -1 | grep commit >> $CONFIG_RECORD_FILE
	
	echo $PREF"Running npm installs"
	gosu wigwag npm install

	remove_git_stuff
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
	    echo "Branch: ${DEVICEDB_CLOUD_BRANCH}" >> $CONFIG_RECORD_FILE
	fi

	echo $PREF"Updating via git pull"
	gosu wigwag git pull

	git log -1 | grep commit >> $CONFIG_RECORD_FILE
	
	echo $PREF"Running npm installs"
	gosu wigwag npm install

	remove_git_stuff	
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
	    echo "Branch: ${WIGWAG_CLOUD_BRANCH}" >> $CONFIG_RECORD_FILE
	fi

	echo $PREF"Updating via git pull"
	gosu wigwag git pull

	git log -1 | grep commit >> $CONFIG_RECORD_FILE
	
	echo $PREF"Running npm installs"
	gosu wigwag npm install

	remove_git_stuff
    fi


# get next comma separated value:   
    [ "$ROLES" = "$role" ] && \
	ROLES='' || \
	ROLES="${ROLES#*,}"
done

echo "************************" >> $CONFIG_RECORD_FILE

echo "removing SSH keys"
rm -f /wigwag/wigwag_devops_cloud_github_latest

echo "WigWag Cloud Build Done"
echo "------------------------"





