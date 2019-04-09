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

echo "---------------------------"
echo "WigWag rabbit MQ container"
echo "(c) 2017 WigWag Inc."
echo "---------------------------"

function print_usage () {
    echo "Usage wigwag-rabbitmq [-c config] [-d] COMMAND [arguments ...]"
    echo "  NOTE: default config is [VOLUME:/config]/clientConfig.json"
    echo "Typical Docker launches:"
    echo "  Start a rabbit MQ:"
    echo "    docker run -v /home/user/config/example-config:/config \ "
    echo "               -v /home/user/place-logs-here:/exposed-logs \ "
    echo "               -p 5672:5672 -d  wigwag-rabbitmq start"
    echo ""
    echo "Container options:"
    echo "  -d         Debug container"
    echo ""
    echo "Command types are:"
    echo "  start       start rabbit mq server"
    if [ ! -z ${DEBUG_CONTAINER} ]; then
	cat $CONFIG_RECORD_FILE
    fi
    
}

#CONFIG="clientConfig.json"

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

#if [ "$#" -lt 1 ]; then
#    print_usage
#    exit 1
#fi

CMD=$1

#if [ ! -e "/config/${CONFIG}" ]; then
#    echo "Config file required. Can't find file: ${CONFIG} (inside container as /config/${CONFIG})"
#    echo "Does the container know where your configuration file is?"
#    exit 1
#fi

# correct location in container for node.js is here:
#NODE_EXEC=/opt/bin/node
# run the server as 'wigwag' user
#cd /home/wigwag/devicejs-cloud/bin
if [ ! -z ${DEBUG_CONTAINER} ]; then
    cat $CONFIG_RECORD_FILE
    echo "container running>> $NODE_EXEC devicejs-node $@ --config=/config/${CONFIG}"
fi
#gosu wigwag $NODE_EXEC devicejs-node $@ --config=/config/${CONFIG}

if [ ! -e /config/rabbitmq.env ]; then
    echo "Warning: no rabbitmq.env in VOLUME /config found. Will use defaults" 
else
    . /config/rabbitmq.env
fi

mkdir -p /exposed-logs/${HOSTNAME}
chown -R rabbitmq:rabbitmq /exposed-logs/${HOSTNAME}
export RABBITMQ_LOG_BASE=/exposed-logs/${HOSTNAME}

if [ "${CMD}" == "start" ]; then
    echo "Starting rabbitmq server"
    gosu rabbitmq /usr/sbin/rabbitmq-server
else
    echo "$CMD is unimplemented"
fi

if [ ! -z ${DEBUG_CONTAINER} ]; then
    echo "<<rabbitmq stopped."
fi
