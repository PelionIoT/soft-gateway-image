/*
 * Copyright (c) 2018, Arm Limited and affiliates.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var argv = process.argv;
var n = 0;

var re_findNode = /^(?:.*[^a-zA-Z]+)?node/;
var found_node = false;
var host_add = null;
var re_hostParse = /^\s*(.*)\s+([a-zA-z0-9\_\-]+)\.(.*)\s*$/;

while(argv[n]) {
    if(!found_node) {
        var m = re_findNode.exec(argv[n])
        if(m[0]) {
            found_node = true;
        } 
    } else {
        host_add = argv[n];
    }
    n++;
}

if(host_add) {
    var m = re_hostParse.exec(host_add)
    if (m && m.length > 3) {
        console.log("%s    %s.%s",m[1],m[2],m[3])
        console.log("%s    %s-devicejs.%s",m[1],m[2],m[3])
        console.log("%s    %s-devicedb.%s",m[1],m[2],m[3])
        console.log("%s    %s-relaymq.%s",m[1],m[2],m[3])
    } else {
        console.error("Malformed host add parameter.")
    }
} else {
    console.error("modhosts.js needs a valid parameter")
}