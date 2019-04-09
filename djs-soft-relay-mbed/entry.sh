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
# defailt config file out of the pair.js utility
CONFIG=".softRelaySetup.json"

echo "---------------------"
echo "deviceJS Soft Relay"
echo "(c) 2017 WigWag Inc."
echo "---------------------"

function print_usage () {
    echo "Usage djs-soft-relay [-c config] [-d] COMMAND [arguments ...]"
    echo "  NOTE: default config is [VOLUME:/config]/clientConfig.json"
    echo "Typical Docker launches:"
    echo "  Start a shell:"
    echo "    docker run -v /home/user/config/example-config:/config --rm -it djs-cloud-client -c clientConfig.json shell"
    echo "               ^ Above, 'clientConfig.json' would be located in /home/user/config/example-config"
    echo ""
    echo "  Start one or more apps:"
    echo ""
    echo "Container options:"
    echo "  -d         Debug container"
    echo "  -c CONFIG  Config file to use"
    echo ""
    echo "Command types are:"
    echo "  start (default)    start the soft Relay"
    echo "  shell              open a deviceJS shell to Relay (only works if Relay running)"
    if [ ! -z ${DEBUG_CONTAINER} ]; then
	cat $CONFIG_RECORD_FILE
    fi
    
}

PAIR_UTIL_OPTS=""

while getopts "dc:" opt; do
    case $opt in
	c)
	    CONFIG="${OPTARG}"
	    ;;
	d)
        PAIR_UTIL_OPTS="-v"
	    DEBUG_CONTAINER="1"
	;;
    esac
done

shift "$((OPTIND - 1))"

CMD="${1}"

#if [ "$#" -lt 1 ]; then
#    print_usage
#    exit 1
#fi

if [ -z "${CMD}" ]; then
    CMD="start"
fi

#if [ ! -e "/config/${CONFIG}" ]; then
#    echo "Config file required. Can't find file: ${CONFIG} (inside container as /config/${CONFIG})"
#    echo "Does the container know where your configuration file is?"
#    exit 1
#fi

# correct location in container for node.js is here:
NODE_EXEC=/opt/bin/node


if [ ! -z ${DEBUG_CONTAINER} ]; then
    cat $CONFIG_RECORD_FILE
fi
 
function init_relay() {
    # run soft-relay setup using EEPROM reader util
    echo "Setting up Relay..."
    echo "=================================="
#    chown -R wigwag:wigwag /wigwag
    ww-su-exec wigwag mkdir -p /wigwag/outputConfigFiles
    ww-su-exec wigwag mkdir -p /wigwag/outputConfigFiles/ssl
    # make sure we have access to /userdata
    mkdir -p /userdata/etc/devicejs
 
    chown -R wigwag:wigwag /userdata
    chown -R wigwag:wigwag /config

    if [ ! -e /config/${CONFIG} ]; then
        echo "No config file found at path: /config/${CONFIG}"
        echo "Running setup util..."
        # use the default softRelaySetup.json if non-existant
        if [ ! -e /config/softRelaySetup.json ]; then
            cp /wigwag/softRelaySetup.json /config/softRelaySetup.json
        fi
        cd /wigwag/pairRelay
        if [ -e "/config/${CONFIG}" ]; then
            ww-su-exec wigwag $NODE_EXEC ${PAIR_UTIL_OPTS} pair.js -c "/config/${CONFIG}"
        else
            ww-su-exec wigwag $NODE_EXEC ${PAIR_UTIL_OPTS} pair.js
        fi
    fi

    # copy a valid logger config file in
    # 'start' uses the TTY
    # everything else should use the file logger.
    if [ -e /config/relay_logger.conf.json ]; then
        echo "OK. Override relay_logger.conf.json"
    	cp /config/relay_logger.conf.json /wigwag/outputConfigFiles
    else
        if [ ${CMD} == "start" ]; then
            cp /wigwag/relay_logger-tty.conf.json /wigwag/outputConfigFiles/relay_logger.conf.json
        else
            cp /wigwag/relay_logger-file.conf.json /wigwag/outputConfigFiles/relay_logger.conf.json
        fi            
    	# echo "No relay_logger.conf.json - using defaults"
     #    cp /wigwag/relay_logger.conf.json /wigwag/outputConfigFiles
    fi
    chown wigwag:wigwag /wigwag/outputConfigFiles/relay_logger.conf.json
    
    if [ -e /config/template.devicejs.conf ]; then
    	echo "NOTE ==> Overriding template.devicejs.conf"
    	cp /config/template.devicejs.conf /wigwag/testConfigFiles
        chown wigwag:wigwag /wigwag/outputConfigFiles/template.devicejs.conf
    fi
        
    if [ -e /config/runner.config.json ]; then
        echo "NOTE ==> Overriding runner.config.json template"
        cp /config/runner.config.json /wigwag
        chown wigwag:wigwag /wigwag/runner.config.json
    fi

    cd /wigwag/wwrelay-utils/I2C

    ww-su-exec wigwag $NODE_EXEC ww_eeprom_reader.js -c "/config/${CONFIG}"
    ww-su-exec wigwag touch /wigwag/.setup-done

}

echo "COMMAND: ${CMD}"
setcap 'cap_net_bind_service=+ep' /opt/bin/node

# start logs everything to the console
if [ ${CMD} == "start" ] || [ ${CMD} == "daemon" ]; then
    init_relay

    echo "Starting...."
    echo "=================================="

# note used any more - in the maestro config file:
#    ww-su-exec wigwag cp /wigwag/relay_logger-tty.conf.json /wigwag/relay_logger.conf.json

    # start our friends (avahi needed for mdns, dbus needed for avahi)
    dbus-daemon --system
    # below will output to syslog
    avahi-daemon -D

    # we need to bind to low ports:
    
    chown -R wigwag:wigwag /log 

    shift
    echo "remaining opts: $@"
#    cd /wigwag/devicejs-core-modules/Runner
    touch /wigwag/.running
# ww-su-exec wigwag - removed
#    NODE_EXEC=/opt/bin/node NODE_PATH=/wigwag/devicejs-ng/node_modules:/wigwag/devicejs-core-modules/Runner/node_modules \
#	      ./start -v3 -c /wigwag/outputConfigFiles/relay.config.json
    LD_LIBRARY_PATH=/wigwag/system/lib /wigwag/system/bin/maestro -config /wigwag/etc/softrelay-config.yaml
    rm -f /wigwag/.running    
fi

if [ ${CMD}  == "version" ]; then
    echo "container config:"
    cat $CONFIG_RECORD_FILE
    echo ""
    echo "devicedb version: `ww-su-exec wigwag devicedb -version`"
fi

if [ ${CMD} == "info" ]; then
    if [ -e "/config/.softRelayPairLog.log" ]; then
        echo "----------------------------"
        cat /config/.softRelayPairLog.log
        echo "----------------------------"
    else 
        echo "Relay not paired or log file missing. Check your /config VOLUME"
    fi
fi

if [ ${CMD} == "run" ]; then
    shift
    if [ ! -e /wigwag/.running ]; then
        echo "Is this soft Relay running??? Marker file missing."
    fi
    /wigwag/devicejs-ng/bin/devicejs run --config=/wigwag/outputConfigFiles/softrelaydevicejs.conf $@
fi

if [ ${CMD} == "shell" ]; then
    shift
    if [ ! -e /wigwag/.running ]; then
        echo "Is this soft Relay running??? Marker file missing."
    fi
    /wigwag/devicejs-ng/bin/devicejs shell --config=/wigwag/outputConfigFiles/softrelaydevicejs.conf $@
fi


if [ ${CMD} == "logs" ]; then
    shift
    less -R /log/relay.log
fi

if [ ${CMD} == "init" ]; then
    rm -f /wigwag/.running
    init_relay
fi

if [ ${CMD} == "get-config-templates" ]; then
    if [ ! -e /config/runner.config.json ]; then
        cp /wigwag/runner.config.json /config
    else
        echo "ERROR: /config/runner.config.json already exists. Will not overwrite. move / delete file to proceed."
    fi
    if [ ! -e /config/relay_logger.conf.json ]; then
        cp /wigwag/relay_logger-file.conf.json /config/relay_logger.conf.json
    else
        echo "ERROR: /config/relay_logger.conf.json already exists. Will not overwrite. move / delete file to proceed."
    fi
fi

if [ ${CMD} == "pair" ]; then
    if [ ! -e "/config/${CONFIG}" ]; then
        echo "Relay not initialized. Initialize first and check that your config volume is correct."
        exit 1
    fi
    echo "Pair Relay"
    echo "=================================="
    cd /wigwag/pairRelay
    # interactive allows pairing of Relay    
    ww-su-exec wigwag $NODE_EXEC ./pair.js ${PAIR_UTIL_OPTS} -c "/config/${CONFIG}" --justpair 
fi




# run the server as 'wigwag' user

