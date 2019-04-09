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

echo "WigWag rabbitmq build"
echo "----------------------"

# KEEP_GIT="1" # this would keep git file

PREF="[ww]>> "
ERROR_PREF="[ERROR ww]>> "

mkdir -p /wigwag

CONFIG_RECORD_FILE="/wigwag/container-config"

rm -f $CONFIG_RECORD_FILE
touch $CONFIG_RECORD_FILE



cd /wigwag

mkdir -p /config
chown -R wigwag:wigwag /config
chown -R wigwag:wigwag /wigwag

CONFIG_RECORD_FILE="/wigwag/container-config"

# make sure to call this one from the right directory!
function remove_git_stuff () {
    if [ -z ${KEEP_GIT} ]; then
	echo "Removing .git and other artifacts"
	( find . -type d -name ".git" \
      && find . -name ".gitignore" \
      && find . -name ".gitmodules" ) | xargs rm -rf
    fi
}


# setup rabbitmq


#deb http://www.rabbitmq.com/debian/ testing main
#add rabbitMQ repo to /etc/apt/sources.list
wget https://www.rabbitmq.com/rabbitmq-signing-key-public.asc
apt-key add rabbitmq-signing-key-public.asc
apt-get update
apt-get install --assume-yes rabbitmq-server

mkdir -p /exposed-logs
chown -R rabbitmq:rabbitmq /exposed-logs


echo "************************" >> $CONFIG_RECORD_FILE

echo "WigWag Cloud - rabbitmq setup done"
echo "------------------------"





