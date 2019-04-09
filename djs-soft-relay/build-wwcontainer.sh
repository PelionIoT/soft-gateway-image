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

echo "WigWag Soft-Relay Build"
echo "----------------------"
 
WIGWAG_CLOUD_REPO="WigWagCo/wigwag-cloud.git"
WIGWAG_CLOUD_BRANCH="production"

DEVICEDB_CLOUD_REPO="WigWagCo/devicedb-cloud.git"
DEVICEDB_CLOUD_BRANCH="master"

DEVICEJS_CLOUD_REPO="WigWagCo/devicejs-cloud.git"
DEVICEJS_CLOUD_BRANCH="site-support"

MAESTRO_REPO="WigWagCo/maestro.git"
MAESTRO_BRANCH="master"

WIGWAG_CLOUD_PROXY_REPO="WigWagCo/wigwag-cloud-proxy.git"
WIGWAG_CLOUD_PROXY_BRANCH="master"

DEVICEJS_REPO="WigWagCo/devicejs-ng.git"  # include the devicedb we want
DEVICEJS_BRANCH="v0.2.0-rc26"

DEVICEJS_CORE_MODULES_REPO="WigWagCo/devicejs-core-modules.git"
DEVICEJS_CORE_MODULES_BRANCH="maestroRunner"  # or tag

WIGWAG_CORE_MODULES_REPO="WigWagCo/wigwag-core-modules.git"
WIGWAG_CORE_MODULES_BRANCH="development"

WIGWAG_DEVJS_UTILS_REPO="WigWagCo/devjs-utils.git"
WIGWAG_DEVJS_UTILS_BRANCH="master"

BASE_DIR="/wigwag"

apt-get --assume-yes install nano            # tight editor
apt-get --assume-yes install inetutils-ping  # ping command 
apt-get --assume-yes install net-tools       # netstat command
apt-get --assume-yes install authbind libavahi-compat-libdnssd-dev
apt-get --assume-yes install procps psmisc   # killall command

# add go to PATH
export PATH=$PATH:/opt/go/bin
export GOROOT=/opt/go

if [ -e /wigwag/repo_path_overrides ]; then
    . /wigwag/repo_path_overrides
fi

# KEEP_GIT="1" # this would keep git file
 
PREF="[ww]>> "
ERROR_PREF="[ERROR ww]>> "

CONFIG_RECORD_FILE="/wigwag/container-config"

rm -f $CONFIG_RECORD_FILE
touch $CONFIG_RECORD_FILE

chown -R wigwag:wigwag /wigwag
cd /wigwag

mkdir -p /config
mkdir -p /apps
mkdir -p /userdata
mkdir -p /userdata/etc/devicejs/db
mkdir -p /log
mkdir -p /wigwag/tools
mkdir -p /wigwag/system/bin
mkdir -p /wigwag/system/lib
chown -R wigwag:wigwag /config
chown -R wigwag:wigwag /apps
chown -R wigwag:wigwag /userdata
chown -R wigwag:wigwag /log
chown -R wigwag:wigwag /wigwag/tools

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

cd ${BASE_DIR}

CONSOLIDATOR=/wigwag/devjs-production-tools/consolidator

# override the devjs-configurator for now, to use the maestroRunner version
cat > /tmp/overrides.json <<EOF
{
    "devjs-configurator": "https://github.com/WigWagCo/devjs-configurator#maestroRunner",
    "netkit": "git+ssh://git@github.com:WigWagCo/node-netkit.git#development"
}
EOF

clone_and_checkout ${DEVICEJS_REPO} ${DEVICEJS_BRANCH} devicejs-ng
clone_and_checkout ${WIGWAG_CORE_MODULES_REPO} ${WIGWAG_CORE_MODULES_BRANCH} wigwag-core-modules
clone_and_checkout ${DEVICEJS_CORE_MODULES_REPO} ${DEVICEJS_CORE_MODULES_BRANCH} devicejs-core-modules
clone_and_checkout ${MAESTRO_REPO} ${MAESTRO_BRANCH} maestro
clone_and_checkout WigWagCo/devjs-production-tools "" devjs-production-tools
clone_and_checkout WigWagCo/wwrelay-utils "development" wwrelay-utils

cd tools
clone_and_checkout ${WIGWAG_DEVJS_UTILS_REPO} ${WIGWAG_DEVJS_UTILS_BRANCH} devjs-utils
cd ${BASE_DIR}

# some of these modules need some extras: 
#apt-get install --assume-yes libusb-1.0-0-dev 
#apt-get install --assume-yes libudev-dev

# need m4 for build of maestro
apt-get --assume-yes install m4
 
GOWORKSPACE="/wigwag/go-workspace"

mkdir -p ${GOWORKSPACE}
mkdir -p ${GOWORKSPACE}/src/github.com/WigWagCo
mkdir -p ${GOWORKSPACE}/bin

echo "*****************************"
echo "Building maestro..."
mv maestro ${GOWORKSPACE}/src/github.com/WigWagCo

cd /wigwag/go-workspace/src/github.com/WigWagCo/maestro/vendor/github.com/WigWagCo/greasego/deps/src/greaseLib/deps/
cd libuv-v1.10.1
if [ ! -d build ]; then
	git clone https://chromium.googlesource.com/external/gyp.git build/gyp
fi
cd ..
echo "Building deps for greaseLib"
./install-deps.sh

cd /wigwag/go-workspace/src/github.com/WigWagCo/maestro/vendor/github.com/WigWagCo/greasego
echo "Building deps for greaseGo"
./build-deps.sh
PATH=$PATH:/opt/go/bin GOROOT=/opt/go GOPATH=/wigwag/go-workspace DEBUG=1 DEBUG2=1 ./build.sh

cd ${GOWORKSPACE}/src/github.com/WigWagCo/maestro

PATH=$PATH:/opt/go/bin GOROOT=/opt/go GOPATH=/wigwag/go-workspace DEBUG=1 DEBUG2=1 ./build.sh

if [ ! -e ${GOWORKSPACE}/bin/maestro ]; then
	echo "!!!!!!!!!!!!!!!!"
	echo "ERROR - maestro did not build"
	echo "!!!!!!!!!!!!!!!!"
	exit 255
else
	cp ${GOWORKSPACE}/bin/maestro /wigwag/system/bin
	cp -a /wigwag/go-workspace/src/github.com/WigWagCo/maestro/vendor/github.com/WigWagCo/greasego/deps/lib/* /wigwag/system/lib	
fi

# LD_LIBRARY_PATH=/wigwag/system/lib ./maestro

#rm -rf /wigwag/go-workspace  # remove about 330M of stuff

cd ${BASE_DIR}

cd devicejs-ng
echo "*****************************" 
echo "Building devicejs-ng & devicedb..."

./build.sh
ww-su-exec wigwag npm install
cd /usr/bin

ln -s /wigwag/devicejs-ng/bin/devicejs .
ln -s /wigwag/devicejs-ng/bin/devjs-npm .
ln -s /wigwag/devicejs-ng/deps/devicedb/bin/devicedb .
cd ${BASE_DIR}

cd devjs-production-tools
ww-su-exec wigwag npm install
cd ${BASE_DIR}

cd wwrelay-utils/I2C
echo "*****************************"
echo "Installing wwrelay-utils npm modules..."
ww-su-exec wigwag npm install
ww-su-exec wigwag cp template.config.json /wigwag
cd ..
remove_git_stuff
cd ${BASE_DIR}

cd wigwag-core-modules
echo "*****************************"
echo "Running consolidator on wigwag-core-module npm modules..."
ww-su-exec wigwag ${CONSOLIDATOR} -O /tmp/overrides.json -d devjs-configurator-server *
#ww-su-exec wigwag npm install
remove_git_stuff
cd ${BASE_DIR}

cd devicejs-core-modules
echo "*****************************"
echo "Installing devicejs-core-module + wigwag-core-modules npm modules..."
# skip installing the dhclient npm (a WigWag module) b/c we don't need it, and it
# breaks easily on build
rm -rf Runner
# drop Runner - no longer needed
ww-su-exec wigwag ${CONSOLIDATOR} -O /tmp/overrides.json -d devjs-configurator-server -d dhclient ../wigwag-core-modules/* *
ww-su-exec wigwag npm install
#cd Runner
#ww-su-exec wigwag devjs-npm install 
#cd ..
remove_git_stuff  # TEMP TEMP only FIXME
cd ${BASE_DIR}

cd tools/devjs-utils
echo "*****************************"
echo "Installing tools/devjs-utils"
ww-su-exec wigwag npm install
remove_git_stuff
cd ${BASE_DIR}

echo "****************************"
echo "Installing pairRelay util modules"
cd /wigwag
chown -R wigwag:wigwag pairRelay
cd pairRelay
ww-su-exec wigwag npm install

# final additions
mkdir -p /wigwag/etc/devicejs/modules
chown -R wigwag:wigwag /wigwag


# if [ ! -d devicejs-ng ]; then
#     echo $PREF"Doing initial clone of repo github.com:${DEVICEJS_REPO}"
#     gosu wigwag git clone git@wigwagcloud_github.com:${DEVICEJS_REPO}
# fi

# if [ ! -d wigwag-core-modules ]; then
#     echo $PREF"Doing initial clone of repo github.com:${WIGWAG_CORE_MODULES_REPO}"
#     gosu wigwag git clone git@wigwagcloud_github.com:${WIGWAG_CORE_MODULES_REPO}
# fi

# if [ ! -d devicejs-core-modules ]; then
#     echo $PREF"Doing initial clone of repo github.com:${DEVICEJS_CORE_MODULES_REPO}"
#     gosu wigwag git clone git@wigwagcloud_github.com:${DEVICEJS_CORE_MODULES_REPO}
# fi


# if [ -d devicejs-ng ]; then
#     cd devicejs-ng
#     if [ ! -z "${DEVICEJS_CLOUD_BRANCH}" ]; then
# 	echo $PREF"checking out branch: ${DEVICEJS_CLOUD_BRANCH}"
# 	gosu wigwag git checkout ${DEVICEJS_CLOUD_BRANCH}
# 	echo "Branch: ${DEVICEJS_CLOUD_BRANCH}" >> $CONFIG_RECORD_FILE
#     fi
#     cd ..
# else
#     echo "FAILED TO clone repo: ${DEVICEJS_CLOUD_BRANCH}"
#     exit -1    
# fi





#if [ ! -d devicejs-ng ]; then
#    echo $PREF"Doing initial clone of repo github.com:${DEVICEJS_REPO}"
#    gosu wigwag git clone git@wigwagcloud_github.com:${DEVICEJS_REPO}
#fi





# while [ "$ROLES" ] ;do
#     role=${ROLES%%,*}
#     echo $PREF"ROLE: $role"
#     echo "----------------------"

#     echo "----------------------" >> $CONFIG_RECORD_FILE
#     echo "ROLE: $role" >> $CONFIG_RECORD_FILE
    
#     if [ "$role" == "devicejs-cloud" ]; then
# 	cd /home/wigwag

# 	if [ ! -d devicejs-cloud ]; then
# 	    echo $PREF"Doing initial clone of repo github.com:${DEVICEJS_CLOUD_REPO}"
# 	    gosu wigwag git clone git@wigwagcloud_github.com:${DEVICEJS_CLOUD_REPO}
# 	fi

# 	cd /home/wigwag/devicejs-cloud

# 	if [ ! -e package.json ]; then
# 	    echo $ERROR_PREF"Failed to checkout repo - missing package.json at root. Check keys / repo"
# 	    exit 1
# 	fi

# 	if [ ! -z "${DEVICEJS_CLOUD_BRANCH}" ]; then
# 	    echo $PREF"checking out branch: ${DEVICEJS_CLOUD_BRANCH}"
# 	    gosu wigwag git checkout ${DEVICEJS_CLOUD_BRANCH}
# 	    echo "Branch: ${DEVICEJS_CLOUD_BRANCH}" >> $CONFIG_RECORD_FILE
# 	fi
	
# 	echo $PREF"Updating via git pull"
# 	gosu wigwag git pull

# 	git log -1 | grep commit >> $CONFIG_RECORD_FILE
	
# 	echo $PREF"Running npm installs"
# 	gosu wigwag npm install

# 	remove_git_stuff
#     fi

#     if [ "$role" == "devicedb-cloud" ]; then
# 	cd /home/wigwag

# 	if [ ! -d devicedb-cloud ]; then
# 	    echo $PREF"Doing initial clone of repo github.com:${DEVICEDB_CLOUD_REPO}"
# 	    gosu wigwag git clone git@wigwagcloud_github.com:${DEVICEDB_CLOUD_REPO}
# 	fi

# 	cd /home/wigwag/devicedb-cloud

# 	if [ ! -e package.json ]; then
# 	    echo $ERROR_PREF"Failed to checkout repo - missing package.json at root. Check keys / repo"
# 	    exit 1
# 	fi

# 	if [ ! -z "${DEVICEDB_CLOUD_BRANCH}" ]; then
# 	    echo $PREF"checking out branch: ${DEVICEDB_CLOUD_BRANCH}"
# 	    gosu wigwag git checkout ${DEVICEDB_CLOUD_BRANCH}
# 	    echo "Branch: ${DEVICEDB_CLOUD_BRANCH}" >> $CONFIG_RECORD_FILE
# 	fi

# 	echo $PREF"Updating via git pull"
# 	gosu wigwag git pull

# 	git log -1 | grep commit >> $CONFIG_RECORD_FILE
	
# 	echo $PREF"Running npm installs"
# 	gosu wigwag npm install

# 	remove_git_stuff	
#     fi
#     if [ "$role" == "wigwag-cloud" ]; then

# 	cd /home/wigwag

# 	if [ ! -d wigwag-cloud ]; then
# 	    echo $PREF"Doing initial clone of repo github.com:${WIGWAG_CLOUD_REPO}"
# 	    gosu wigwag git clone git@wigwagcloud_github.com:${WIGWAG_CLOUD_REPO}
# 	fi

# 	cd /home/wigwag/wigwag-cloud

# 	if [ ! -e package.json ]; then
# 	    echo $ERROR_PREF"Failed to checkout repo - missing package.json at root. Check keys / repo"
# 	    exit 1
# 	fi

# 	if [ ! -z "${WIGWAG_CLOUD_BRANCH}" ]; then
# 	    echo $PREF"checking out branch: ${WIGWAG_CLOUD_BRANCH}"
# 	    gosu wigwag git checkout ${WIGWAG_CLOUD_BRANCH}
# 	    echo "Branch: ${WIGWAG_CLOUD_BRANCH}" >> $CONFIG_RECORD_FILE
# 	fi

# 	echo $PREF"Updating via git pull"
# 	gosu wigwag git pull

# 	git log -1 | grep commit >> $CONFIG_RECORD_FILE
	
# 	echo $PREF"Running npm installs"
# 	gosu wigwag npm install

# 	remove_git_stuff
#     fi


# # get next comma separated value:   
#     [ "$ROLES" = "$role" ] && \
# 	ROLES='' || \
# 	ROLES="${ROLES#*,}"
# done

echo "************************" >> $CONFIG_RECORD_FILE

echo "removing SSH keys"
rm -f /wigwag/wigwag_devops_cloud_github_latest

echo "WigWag Soft-Relay Build Done"
echo "------------------------"


#again



