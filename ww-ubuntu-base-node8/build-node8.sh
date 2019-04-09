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
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done

THIS_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

#DISTRO="8.9.3"
DISTRO="8.4.0"
#https://nodejs.org/download/release/v8.4.0/node-v8.4.0.tar.gz
cd /tmp

apt-get update
apt-get -y install wget python build-essential git openssl libssl-dev zlib1g-dev
#wget --no-check-certificate "https://nodejs.org/dist/v8.9.3/node-v${DISTRO}.tar.gz"
wget --no-check-certificate "https://nodejs.org/download/release/v${DISTRO}/node-v${DISTRO}.tar.gz"
tar xvzf "node-v${DISTRO}.tar.gz"

# there is currently a build bug issue in latest node on newer ubuntu
# read more here: /usr/include/x86_64-linux-gnu/c++/7/bits/c++config.h
# and: https://github.com/voidlinux/void-packages/issues/7324#issuecomment-321241340
if [ ! -d "/usr/include/x86_64-linux-gnu/c++/7/bits" ]; then
    echo "ERROR - need to fix our build script. ubuntu has changed paths / compilers."
    exit 1
fi
cp /usr/include/x86_64-linux-gnu/c++/7/bits/c++config.h /usr/include/x86_64-linux-gnu/c++/7/bits/c++config.h.bak
cp /home/wigwag/c++config.h /usr/include/x86_64-linux-gnu/c++/7/bits/c++config.h

if [ -d "node-v${DISTRO}" ]; then
    cd "node-v${DISTRO}"
    ./configure --dest-cpu=x64 --shared-zlib --shared-openssl --without-inspector --with-intl=small-icu --prefix=/usr
    make -j 6
else
    echo "Failed to download / expand node"
        exit 1
fi
 
make install

cp /usr/include/x86_64-linux-gnu/c++/7/bits/c++config.h.bak /usr/include/x86_64-linux-gnu/c++/7/bits/c++config.h

cd /tmp
rm -rf "node-v${DISTRO}" "node-v${DISTRO}.tar.gz"
# now let's get golang 1.8
# 
#GOLANGTAR="go1.8.5.linux-amd64"
wget --no-check-certificate https://redirector.gvt1.com/edgedl/go/go1.8.5.linux-amd64.tar.gz

tar xvfz go1.8.5.linux-amd64.tar.gz

mv go /opt

rm -rf go1.8.5.linux-amd64.tar.gz

cd /tmp
git clone https://github.com/WigWagCo/su-exec.git
cd su-exec
make
cp su-exec /usr/bin/ww-su-exec
cd /tmp
rm -rf su-exec
