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

# build tools for simulator

TOOLS_REPO="WigWagCo/enterprise-tools.git"
TOOLS_BRANCH="master"

CONFIG_RECORD_FILE="/wigwag/container-config"

chmod 600 /wigwag/wigwag_devops_cloud_github_latest

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


echo "build enterprise-tools"
echo "------------------------------"

cd /wigwag

clone_and_checkout ${TOOLS_REPO} ${TOOLS_BRANCH} enterprise-tools
cd enterprise-tools
ww-su-exec wigwag npm install
