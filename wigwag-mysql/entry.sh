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

echo "--------------------------------"
echo "WigWag DCS: MySQL 5.7 container"
echo "(c) 2017 WigWag Inc."
echo "--------------------------------"

function print_usage () {
    echo "Usage wigwag-mysql [-c config] [-d] COMMAND [arguments ...]"
    echo "  NOTE: default config is [VOLUME:/config]/clientConfig.json"
    echo "Typical Docker launches:"
    echo "  Start a DCS MySQL instance:"
    echo "    docker run -v /home/user/config/example-config:/config \ "
    echo "               -v /home/user/place-logs-here:/exposed-logs \ "
    echo "               -v /home/user/mysql-data:/var/lib/mysql \ "
    echo "               -p 3306:3306 -p 33060:33060 -d  wigwag-mysql start"
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

if [ ! -e /config/mysql.env ]; then
    echo "Warning: no mysql.env in VOLUME /config found. Will use defaults" 
else
    . /config/mysql.env
fi

mkdir -p /exposed-logs/${HOSTNAME}
chown -R mysql:mysql /exposed-logs/${HOSTNAME}
export MYSQL_LOGS=/exposed-logs/${HOSTNAME}

#if [ "${CMD}" == "start" ]; then
#    echo "Starting MySQL 5.7 server"
#    gosu mysql /usr/sbin/mysqld
#else
#    echo "$CMD is unimplemented"
#fi


# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
#	set -- mysqld "$@"
	set -- start "$@"
fi


if [ "$1" = 'start' ]; then
    shift
    EXEC_COMMAND="mysqld $@"
    echo "EXEC_COMMAND=${EXEC_COMMAND}"
    # Test we're able to startup without errors. We redirect stdout to /dev/null so
	# only the error messages are left.
	result=0
	output=$($EXEC_COMMAND --verbose --help 2>&1 > /dev/null) || result=$?
	if [ ! "$result" = "0" ]; then
		echo >&2 'error: could not run mysql. This could be caused by a misconfigured my.cnf'
		echo >&2 "$output"
		exit 1
	fi

	# Get config
	#DATADIR="$("$EXEC_COMMAND" --verbose --help --log-bin-index=/tmp/tmp.index 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
	DATADIR="$(mysqld --verbose --help --log-bin-index=/tmp/tmp.index 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

	echo "DATADIR is $DATADIR"
	
	if [ ! -d "$DATADIR/mysql" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and password option is not specified '
			echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
			exit 1
		fi
		# If the password variable is a filename we use the contents of the file
		if [ -f "$MYSQL_ROOT_PASSWORD" ]; then
			MYSQL_ROOT_PASSWORD="$(cat $MYSQL_ROOT_PASSWORD)"
		fi
		mkdir -p "$DATADIR"
		chown -R mysql:mysql "$DATADIR"

		echo 'Initializing database'
		$EXEC_COMMAND --initialize-insecure=on
		echo 'Database initialized'

		$EXEC_COMMAND --skip-networking &
		pid="$!"

		mysql=( mysql --protocol=socket -uroot )

		for i in {30..0}; do
			if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
				break
			fi
			echo 'MySQL init process in progress...'
			sleep 1
		done
		if [ "$i" = 0 ]; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		mysql_tzinfo_to_sql /usr/share/zoneinfo | "${mysql[@]}" mysql
		
		if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			MYSQL_ROOT_PASSWORD="$(pwmake 128)"
			echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
		fi
		if [ -z "$MYSQL_ROOT_HOST" ]; then
			ROOTCREATE="ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"
		else
			ROOTCREATE="ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; \
			CREATE USER 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; \
			GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION ;"
		fi
		"${mysql[@]}" <<-EOSQL
			-- What's done in this file shouldn't be replicated
			--  or products like mysql-fabric won't work
			SET @@SESSION.SQL_LOG_BIN=0;
			DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost');
			${ROOTCREATE}
			DROP DATABASE IF EXISTS test ;
			FLUSH PRIVILEGES ;
		EOSQL
		if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
			mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
		fi

		if [ "$MYSQL_DATABASE" ]; then
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
			mysql+=( "$MYSQL_DATABASE" )
		fi

		if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
			echo "CREATE USER '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PASSWORD"' ;" | "${mysql[@]}"

			if [ "$MYSQL_DATABASE" ]; then
				echo "GRANT ALL ON \`"$MYSQL_DATABASE"\`.* TO '"$MYSQL_USER"'@'%' ;" | "${mysql[@]}"
			fi

			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi
		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)  echo "$0: running $f"; . "$f" ;;
				*.sql) echo "$0: running $f"; "${mysql[@]}" < "$f" && echo ;;
				*)     echo "$0: ignoring $f" ;;
			esac
			echo
		done

		if [ ! -z "$MYSQL_ONETIME_PASSWORD" ]; then
			"${mysql[@]}" <<-EOSQL
				ALTER USER 'root'@'%' PASSWORD EXPIRE;
			EOSQL
		fi
		if ! kill -s TERM "$pid" || ! wait "$pid"; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		echo
		echo 'MySQL init process done. Ready for start up.'
		echo
	fi

	chown -R mysql:mysql "$DATADIR"

	rm -f /etc/mysql/my.cnf
	cp /wigwag/template.my.cnf /etc/mysql/my.cnf
	
	echo "[mysqld_safe]" >> /etc/mysql/my.cnf
	echo "log_error=/exposed-logs/$HOSTNAME/mysql_error.log" >> /etc/mysql/my.cnf
	echo "[mysqld]" >> /etc/mysql/my.cnf
	echo "log_error=/exposed-logs/$HOSTNAME/mysql_error.log" >> /etc/mysql/my.cnf

	gosu mysql $EXEC_COMMAND
	#exec $EXEC_COMMAND


else
    echo "No command specified."
    print_usage
fi



#if [ ! -z ${MYSQL_ROOT_PASSWORD} ]; then
#    mysqladmin -u root password "${MYSQL_ROOT_PASSWORD}"
#fi


if [ ! -z ${DEBUG_CONTAINER} ]; then
    echo "<<wigwag-mysql container stopped."
fi
