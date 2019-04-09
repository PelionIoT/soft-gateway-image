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

BUCKET_NAME="core-server1-backup"
BUCKET_FOLDER="backups"
AWS_SECRET_KEY="+azFMcmbspyhSeNjRuSjkl7dpknqphGrzlUrLP8F"
AWS_ACCESS_KEY="AKIAJTBBYIN46QXMRDTA"

DUPLICITY_PASS_PHRASE="w1gg1dyWag91ka19"

rawurlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
	c=${string:$pos:1}
	case "$c" in
	    [-_.~a-zA-Z0-9] ) o="${c}" ;;
	    * )               printf -v o '%%%02x' "'$c"
	esac
	encoded+="${o}"
    done
    echo "${encoded}"    # You can either set a return variable (FASTER)
    REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}



BACKUP_DIR="$1"


if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 [directory-path]"
    exit 1
fi

BACKUP_DIR_BASE=`dirname $BACKUP_DIR`
BACKUP_DIR_NAME=`basename $BACKUP_DIR`

BACKUP_PREFIX=$( rawurlencode "$BACKUP_DIR" )

#echo "Backing up directory: $BACKUP_DIR_NAME from $BACKUP_DIR_BASE"

duplicati-cli \
  --aws_secret_access_key=\"${AWS_SECRET_KEY}\" \
  --aws_access_key_id=\"${AWS_ACCESS_KEY}\" \
  --s3-ext-signatureversion=4 \
  --passphrase=$DUPLICITY_PASS_PHRASE \
  --use-ssl \
  --s3-location-constraint=us-east-1 \
  --prefix=$BACKUP_PREFIX \
  delete s3://${BUCKET_NAME}/${BUCKET_FOLDER} --version 0


# the   --s3-ext-signatureversion=4  is needed if the bucket is in a newer region.
