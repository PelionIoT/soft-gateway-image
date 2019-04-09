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

CONFIG_RECORD_FILE="/wigwag/container-config"

echo "---------------------"
echo "deviceJS Cloud Server"
echo "(c) 2017 WigWag Inc."
echo "---------------------"

function print_usage () {
    echo "Usage devicejs-cloud [-c config] [-d] COMMAND [arguments ...]"
    echo "  NOTE: default config is [VOLUME:/config]/defaultConfig.json"
    echo "Typical Docker launches:"
    echo "  Start process:"
    echo "    docker run -v /home/user/config/example-config:/config --rm -it devicejs-cloud -c testConfig.json start"
    echo "               ^ Above, 'testConfig.json' would be located in /home/user/config/example-config"
    echo ""
    echo "  Start one or more apps:"
    echo ""
    echo "Container options:"
    echo "  -d         Debug container"
    echo "  -c CONFIG  Config file to use"
    echo ""
    echo "Command types are:"
    echo "  modules     install, uninstall, enable, disable and see the status of installed modules"
    echo "  start       start a devicejs server"
    echo "  stop        stop a devicejs server"
    echo "  run         run a devicejs script"
    echo "  shell       run a devicejs interactive shell"
    if [ ! -z ${DEBUG_CONTAINER} ]; then
	cat $CONFIG_RECORD_FILE
    fi
    
}

CONFIG="defaultConfig.json"

while getopts "dc:" opt; do
    case $opt in
	c)
	    CONFIG="${OPTARG}"
	    ;;
	d)
	    DEBUG_CONTAINER="1"
	;;
    esac
done

shift "$((OPTIND - 1))"

if [ "$#" -lt 1 ]; then
    print_usage
    exit 1
fi


if [ ! -e "/config/${CONFIG}" ]; then
    echo "Config file required. Can't find file: ${CONFIG} (inside container as /config/${CONFIG})"
    echo "Does the container know where your configuration file is?"
    exit 1
fi

# correct location in container for node.js is here:
NODE_EXEC=/opt/bin/node
# run the server as 'wigwag' user
cd /home/wigwag/devicejs-cloud/bin
if [ ! -z ${DEBUG_CONTAINER} ]; then
    cat $CONFIG_RECORD_FILE
    echo "container running>> $NODE_EXEC devicejs-node $@ --config=/config/${CONFIG}"
fi
gosu wigwag $NODE_EXEC devicejs-node $@ --config=/config/${CONFIG}
if [ ! -z ${DEBUG_CONTAINER} ]; then
    echo "<<container command done."
fi
