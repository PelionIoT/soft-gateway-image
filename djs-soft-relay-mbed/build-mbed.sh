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

echo "Build mbed-cloud-edge daemon"
echo "----------------------"
 
MBED_EDGE_REPO="WigWagCo/mbed-cloud-edge-confidential-w.git"
MBED_EDGE_BRANCH="fcc_kcm_patch_1.2.4"

MBED_DEVJS_BRIDGE_REPO="WigWagCo/mbed-devicejs-bridge.git"
MBED_DEVJS_BRIDGE_BRANCH="master"

MBED_EGDEJS_REPO="WigWagCo/mbed-cloud-edge-js.git"
MBED_EGDEJS_BRANCH="master"

# DEVICEJS_REPO="WigWagCo/devicejs-ng.git"  # include the devicedb we want
# DEVICEJS_BRANCH="arm-node8"

# DEVICEJS_CORE_MODULES_REPO="WigWagCo/devicejs-core-modules.git"
# DEVICEJS_CORE_MODULES_BRANCH="arm-node8"  # or tag

# WIGWAG_DEVJS_UTILS_REPO="WigWagCo/devjs-utils.git"
# WIGWAG_DEVJS_UTILS_BRANCH="master"

BASE_DIR="/wigwag"
PREF="[ww]>> "
ERROR_PREF="[ERROR ww]>> "

CONFIG_RECORD_FILE="/wigwag/container-config"

# NODE8_DIR="node8"
# NODE_DIR_NAME="node-v8.6.0-linux-x64"
NODE_EXEC_PATH="node"
NODE_EXEC_BINPATH="/usr/bin/node"

apt-get update
apt-get --assume-yes install cmake            # needs cmake for build
# required libs
apt-get --assume-yes install libjansson-dev libevent-dev 

# make sure to call this one from the right directory!
function remove_git_stuff () {
    if [ -z ${KEEP_GIT} ]; then
	echo "Removing .git and other artifacts"
	( find . -type d -name ".git" \
      && find . -name ".gitignore" \
      && find . -name ".gitmodules" ) | xargs rm -rf
    fi
}

#params: $1 REPO $2 BRANCH $3 target-dir
function clone_and_checkout () {
    echo "(((((((((((((((((((( ${3} ))))))))))))))))))))"
    echo "---------------------------" >> $CONFIG_RECORD_FILE
    echo "clone github.com:${1}" >> $CONFIG_RECORD_FILE
    if [ ! -d "$3" ]; then
	echo $PREF"Doing initial clone of repo github.com:${1}"
	ww-su-exec wigwag git clone git@wigwagcloud_github.com:${1}
    fi
    

    if [ -d "$3" ]; then
	cd $3
	if [ ! -z "${2}" ]; then
	    echo $PREF"checking out branch: ${2}"
	    ww-su-exec wigwag git checkout ${2}
	    echo "Branch: ${2}" >> $CONFIG_RECORD_FILE
	fi

	echo $PREF"Updating via git pull"
	ww-su-exec wigwag git pull
	git log -1 | grep commit >> $CONFIG_RECORD_FILE	
	cd ..
    else
	echo "FAILED TO clone repo: ${DEVICEJS_CLOUD_BRANCH}"
	exit -1
    fi
}

chmod 600 /wigwag/wigwag_devops_cloud_github_latest 
chown wigwag:wigwag /wigwag/wigwag_devops_cloud_github_latest 

CONSOLIDATOR=/wigwag/devjs-production-tools/consolidator

# mkdir ${BASE_DIR}/${NODE8_DIR}
# chown -R wigwag:wigwag ${BASE_DIR}/${NODE8_DIR}

# override the devjs-configurator for now, to use the maestroRunner version
cat > /tmp/overrides.json <<EOF
{
    "devjs-configurator": "http://github.com/WigWagCo/devjs-configurator#maestroRunner"
}
EOF

# cd /tmp

# wget https://nodejs.org/dist/v8.6.0/${NODE_DIR_NAME}.tar.xz
# tar xvfJ ${NODE_DIR_NAME}.tar.xz
# mv ${NODE_DIR_NAME} ${NODE_EXEC_PATH}

# echo "Node ${NODE_DIR_NAME} ready in ${NODE_EXEC_PATH}"
# echo "Node ${NODE_DIR_NAME} ready in ${NODE_EXEC_PATH}" >> $CONFIG_RECORD_FILE

cd ${BASE_DIR}

clone_and_checkout ${MBED_EDGE_REPO} ${MBED_EDGE_BRANCH} mbed-cloud-edge-confidential-w

cd mbed-cloud-edge-confidential-w

./build_mbed_edge.sh

echo "************************" >> $CONFIG_RECORD_FILE

EDGE_EXEC_DIR="/wigwag/mbed-cloud-edge-confidential-w/build/mcc-linux-x86/existing/bin"

if [ -e "${EDGE_EXEC_DIR}/edge-core" ]; then
    echo "mbed cloud edge built successfully"
    # this directory is needed for some reason, per conversation with Doug, 10/8/17
    mkdir -p ${EDGE_EXEC_DIR}/pal
    chmod 0777 ${EDGE_EXEC_DIR}/pal
else
    echo "FAILED TO BUILD mbed cloud edge"
    exit 255
fi

remove_git_stuff

cd ${BASE_DIR}

clone_and_checkout ${MBED_DEVJS_BRIDGE_REPO} ${MBED_DEVJS_BRIDGE_BRANCH} mbed-devicejs-bridge

cd mbed-devicejs-bridge

cp devicejs.json package.json
ww-su-exec wigwag npm install
remove_git_stuff

cd ${BASE_DIR}

clone_and_checkout ${MBED_EGDEJS_REPO} ${MBED_EGDEJS_BRANCH} mbed-cloud-edge-js

cd mbed-cloud-edge-js
ww-su-exec wigwag npm install
remove_git_stuff

# cd ${BASE_DIR}/${NODE8_DIR}

# clone_and_checkout ${DEVICEJS_REPO} ${DEVICEJS_BRANCH} devicejs-ng
# clone_and_checkout ${DEVICEJS_CORE_MODULES_REPO} ${DEVICEJS_CORE_MODULES_BRANCH} devicejs-core-modules
# clone_and_checkout WigWagCo/devjs-production-tools "" devjs-production-tools

# cd ${BASE_DIR}/${NODE8_DIR}
# cd devjs-production-tools
# PATH="${NODE_EXEC_BINPATH}:${PATH}" ww-su-exec wigwag npm install


# cd ${BASE_DIR}/${NODE8_DIR}
# cd devicejs-ng
# echo "*****************************" 
# echo "Building devicejs-ng & devicedb for node8..."

# ./build.sh
# PATH="${NODE_EXEC_BINPATH}:${PATH}" ww-su-exec wigwag npm install
# cd /usr/bin

# ln -s /wigwag/devicejs-ng/bin/devicejs .
# ln -s /wigwag/devicejs-ng/bin/devjs-npm .
# ln -s /wigwag/devicejs-ng/deps/devicedb/bin/devicedb .


# cd ${BASE_DIR}/${NODE8_DIR}
# cd devicejs-core-modules
# echo "*****************************"
# echo "Installing devicejs-core-module npm modules..."
# skip installing the dhclient npm (a WigWag module) b/c we don't need it, and it
# breaks easily on build
# PATH="${NODE_EXEC_BINPATH}:${PATH}" ww-su-exec wigwag ${CONSOLIDATOR} -O /tmp/overrides.json -d dhclient *
# PATH="${NODE_EXEC_BINPATH}:${PATH}" ww-su-exec wigwag npm install
# cd ..
#remove_git_stuff  # TEMP TEMP only FIXME

# we only need maestroRunner
# cd maestroRunner
# cp devicejs.json package.json
# # see: https://stackoverflow.com/questions/45022048/why-does-npm-install-rewrite-package-lock-json
# # We want the --from-lock-file
# # https://github.com/npm/npm/issues/18286
# # When available
# PATH="${NODE_EXEC_BINPATH}:${PATH}" ww-su-exec wigwag npm install


echo "removing SSH keys"
rm -f /wigwag/wigwag_devops_cloud_github_latest

echo "WigWag Soft-Relay-mbed Build Done"
echo "------------------------"



#again



