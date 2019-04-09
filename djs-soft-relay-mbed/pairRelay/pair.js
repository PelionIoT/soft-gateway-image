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

/**
WigWag Pair Utility 
WigWag Inc. (c) 2017
**/

var util = require('util');
var path = require('path');
var jsonminify = require('jsonminify');
var fs = require('fs');
var path = require('path');
var moment = require('moment');
var tmp = require('tmp');
var cursor = require('ansi')(process.stdout);
var errCursor = require('ansi')(process.stderr);
var chalk = require('chalk');
var argv = require('minimist')(process.argv.slice(2));

var request = require('request');
var userJar = request.jar();  // cookie 'jars' for user vs. admin
var adminJar = request.jar();
//var request = request.default({jar:true});
var rlSync = require('readline-sync');

//var validCloudURL = /^(http|https)\:\/\/[\-_A-Za-z0-9]+(?:\.[\-_a-zA-Z0-9]+)+(?:\:[0-9]+)?(?:\/.*)?/;
var validCloudURL = /^(https)\:\/\/([\-_A-Za-z0-9]+)((?:\.[\-_a-zA-Z0-9]+)+(?:\:[0-9]+)?(?:\/.*)?)/;
var validRelayPrefix = /^W[WD][A-Z]{2}$/;


var SOFT_RELAY_PREFIX = 'WWSR'; // the default

var CONFIG_DIR='/config';

var OUTPUT_PAIR_LOG='.softRelayPairLog.log';
var output_to_log="";

 
var usage = function() {
    console.log(" -c CONFIG_FILE              template config file to be used by utility to build output file.");
    console.log(" --cloud URL                 if no config file is stated, with credentials you can get everything from the cloud");
    console.log(" -r RELAY_BATCH_FILE         a batch file from the cloud, stating the keys/ids for a deviceJS Relay");
    console.log(" --id RELAY_ID               (if more than one Relay in batch file)");
    console.log(" --dontpair                  don't pair the soft-relay.");
    console.log(" --justpair                  just pair, don't do anything else. (assumes files are already generated)");
    console.log(" --muted                     no interactive input. use with --startupconfig")
    console.log(" --startupconfig FILE        use these defaults on creating a new soft Relay")
    console.log("");
    console.log("----advanced----")
    console.log(" --pre CODE                  If allocating a new Relay ID, this as the prefix code. Default:"+SOFT_RELAY_PREFIX);
    console.log(" --output FILE_PATH          (default is "+OUTPUT_CONFIG_FILE+")");
    console.log(" --outputlog FILE_PATH       (default is "+OUTPUT_PAIR_LOG+")");
}

if(argv.v) console.dir(argv);

if(argv.pre) {
	if(validRelayPrefix.test(argv.pre)) {
		SOFT_RELAY_PREFIX = argv.pre;		
	} else {
		errorOut("Relay prefix must meet this regex: /^W[WD][A-Z]{2}$/");
		process.exit(-1);
	}
}

if(argv.confdir) CONFIG_DIR=argv.confdir;

if(argv.outputlog) OUTPUT_PAIR_LOG=argv.outputlog;

var OUTPUT_CONFIG_FILE=path.join(CONFIG_DIR,'.softRelaySetup.json');

if(argv.output) OUTPUT_CONFIG_FILE=argv.output;

var new_output_dir=path.dirname(OUTPUT_CONFIG_FILE); // non-null if the .softRelaySetup.json file already existed.

if(argv.h || argv.help) {
	usage();
	process.exit(0);
}


var okOut = function() {
	var s= util.format.apply(util.format,arguments);
	cursor.write('   '); cursor.bold(); cursor.write('✓ OK'); cursor.reset(); cursor.write(' ');
	cursor.write(s); cursor.write('\n');
}

var verboseOut = function() {
	if(argv.v) {
		var s= util.format.apply(util.format,arguments);
		cursor.write(' '); cursor.bold(); cursor.write('>>'); cursor.reset(); cursor.write(' ');
		cursor.write(s); cursor.write('\n');
	}
}

var errorOut = function() {
	var s= util.format.apply(util.format,arguments);
	errCursor.bold(); errCursor.write('! ERROR ');
	errCursor.reset(); errCursor.write(s); errCursor.write('\n');
}

var warnOut = function() {
	var s= util.format.apply(util.format,arguments);
	cursor.write('   '); errCursor.bold(); errCursor.write('WARN ');
	errCursor.reset(); errCursor.write(s); errCursor.write('\n');
}

var logRecord = function() {
	output_to_log += util.format.apply(util.format,arguments) + '\n';	
}


var readJSONFile = function(fname,byLine){
    // conver to absolute path if not one
    if(!path.isAbsolute(fname)) {
		fname = path.join(__dirname,fname);
    }

    return new Promise((resolve,reject) => {
	fs.readFile(fname,'utf8',(err,data) => {
	    // this parse each line as a separate JSON object
	    // and put it into an array. This i needed b/c the cloud's current batch generator hands out line by line objects, not real JSON.
	    if(!err) {
 		if(byLine) {
		    var ret = [];
		    var i = 0;
		    var linen = 1;
		    while (i < data.length)
		    {
				var j = data.indexOf("\n", i);
				if (j == -1) j = data.length;
	//					    console.log(">>",data.substr(i, j-i));
				var line = data.substr(i, j-i);
				if(line.length > 1) {
				    try {
	//			    var rawjson = jsonminify(line);
					var linedata = JSON.parse(line);
					ret.push(linedata);
				    //			    resolve(data);
				    } catch(err) {
					if(typeof err == 'object') {
					    err.filename = fname;
					    err.linenumber = linen;
					}
					reject(err);
				    }
				}
				i = j+1;
				linen++;
		    }
		    resolve({fname:fname,d:ret});
		} else {		    
		    try {
			var rawjson = jsonminify(data);
			var data = JSON.parse(rawjson);
			resolve({fname: fname, d:data});
		    } catch(err) {
			if(typeof err == 'object') err.filename = fname;
			reject(err);
		    }
		}
	    } else {
		if(typeof err == 'object') err.filename = fname;
		reject(err);
	    }
	    
	});
    })
    
}

var pairedFileName = function(relayID) {
    return ".paired-"+relayID;
}

var checkMarkerFile = function(relayID) {
    fs.open(path.join(__dirname,pairedFileName), 'wx', (err, fd) => {
	if (err) {
	    if (err.code === "EEXIST") {
		console.error('myfile already exists');
		return;
	    } else {
		throw err;
	    }
	}

	writeMyData(fd);
    });
}

var writeMarketFile = function() {
}

var templateSetup = {
    //Specify the cloud URL path from which this relay is generated
//    "cloudURL": "https://cloud.wigwag.io",                         // ASK
    "cloudURL": null,                         // ASK

    //Specify the devicejs cloud URL path
    "devicejsCloudURL": "https://devicejs.wigwag.io",                // ASK

    //Specify the devicedb cloud URL path
    "devicedbCloudURL": "https://devicedb.wigwag.io",                   // ASK

    //Specify the devicedb cloud URL path
    "relaymqCloudURL": "https://relaymq.wigwag.io",                   // ASK

    //Template file with handlebars for relay.config.json
//    "relayTemplateFilePath": "./testConfigFile/template.config.json",       // static for container
    "relayTemplateFilePath": "/wigwag/runner.config.json",       // static for container

    //Template file with handlebars for config.json (of the relay-term)
    "relaytermTemplateFilePath": "./testConfigFiles/relayterm_template.config.json",

    //Config file used by relay-term
    "relaytermConfigFilePath": "/wigwag/wigwag-core-modules/relay-term/config/config.json",

    //Config file used by Runner
    "relayConfigFilePath": "/wigwag/outputConfigFiles/relay.config.json",    // static for container

    //Template file with handlebars to setup radio profile of this relay
    "rsmiTemplateFilePath": "./testConfigFiles/radioProfile.template.json",  // static for container

    //RSMI config file used by Radio Status Monitoring Interface
    "rsmiConfigFilePath": "/wigwag/outputConfigFiles/radioProfile.config.json",// static for container

    //Template file with handlebars to setup devicejs conf
    "devicejsTemplateFilePath": "./testConfigFiles/template.devicejs.conf",// static for container

    //Devicejs conf file used on devicejs start
    "devicejsConfigFilePath": "/wigwag/outputConfigFiles/softrelaydevicejs.conf",  // static for container

    //Template file with handlebars to setup devicedb conf
    "devicedbTemplateFilePath": "./testConfigFiles/template.devicedb.conf", // static for container

    //Devicedb conf file used on devicedb start
    "devicedbConfigFilePath": "/wigwag/outputConfigFiles/softrelaydevicedb.yaml", // should be auto-created

    //Local port on which database will run
    "devicedbLocalPort": 9000,                                             // should be 443 by default, can ask

    //Rewrite the config files
    "overwriteConfig": true,

    //Rewrite ssl certs to boot partition
    "overwriteSSL": true,

    //To generate soft relay specify EEPROM/HardwareConfig file
//    "eepromFile": "/config/fsg-WWRL000003.json",                          // will be handed to us or generated
	"eepromFile":null,
    //Mount partition where ssl certs will be saved
    "certsMountPoint": "/mnt/.boot/",

    //Source point on mount partition
    "certsSourcePoint": ".ssl",

    //Memory block to mount
    "certsMemoryBlock": "/dev/mmcblk0p1",

    //Output directory where all the certs will be saved
    "certsOutputDirectory": "/wigwag/outputConfigFiles/ssl",

    //Directory where local database will be stored
    "localDatabaseDirectory": "/userdata/etc/devicejs/db",                  // static for container

    //Version file path which describes the software version running on the relay
    "relayFirmwareVersionFile": "/wigwag/etc/versions.json"
}



// 1) read config to get cloud server
// 2) get creds from user

console.log("-----------------------");
console.log("soft-relay setup utility");
console.log("WigWag Inc. (c) 2017");
console.log("-----------------------");


// if(!argv.c) {
//     console.error("Need a stated config file");
//     process.exit(-1);
// }

var readFileProms = []; 
var config = null;
var relay_config = null;
var relay_config_filename = null;
var relaysById= {};
var relayList = "";
var no_config_file_given = false;
var silent_mode = false; // if true, don't ask for user input

if(argv.s) {
    silent_mode = true;
}

if(argv.justpair && !argv.c) {
	verboseOut("Using default output config file:",OUTPUT_CONFIG_FILE);
	argv.c = OUTPUT_CONFIG_FILE;
}


if(argv.r)  {
    readFileProms.push(readJSONFile(""+argv.r,true).then(function(o){
    	relay_config_filename = o.fname;
		relay_config=o.d;
    }));
}

if(argv.c) {
    readFileProms.push(readJSONFile(""+argv.c).then(function(o){
		config = o.d;
    }));
} else {
    no_config_file_given = true;
    console.log("   No config file. Using defaults...");
    config = templateSetup;
}

if(argv.cloud) {
	if(validCloudURL.test(argv.cloud)) {
		config.cloudURL = argv.cloud;		
	} else {
		errorOut("Invalid cloud URL specified. format: https://server.abc.com[:PORT]")
		process.exit(-1);
	}
}


// var tryAuth = function(creds,cookieJar) {
//     return new Promise(function(resolve,reject){
//         console.log("   Authenticating to",config.cloudURL+"/auth/token","...");
//         request.post({
//         url: config.cloudURL+"/auth/token",
//         json: true,     
//         jar: cookieJar,
//         body: {
//             username: creds.email,
//             password: creds.pass,
//             grant_type: "password",
//             client_id: ""
//         }
//         }, (err,response,body) => {
//         if(err) {
//             reject(err);
//         } else {
//             if(response.statusCode != 200) {
//                 console.error("Got back:",response.statusCode,body);
//             reject('Bad authentication. Check password/username');
//                 } else {
//     //          console.log("callback---------",body);
//     //          console.log("got back:",body);
//                 if(body && body.access_token) {
//                     okOut("Successful auth.");
//                     resolve(body.access_token);
//                 } else {
//                     errorOut("Got back?: ",body);
//                     reject("Got malformed response. Check URL.");
//                 }
//             }
//         }
//         });
//     });
// }

var re_authTokenFromCookie = /\s*access_token\=([^\s\;]+)/;

var getAuthToken = function(cookieheader) {
    var m = re_authTokenFromCookie.exec(cookieheader);
    if(m && m.length > 1) {
        return m[1];
    } else {
        return null;
    }
}

var tryAuth = function(creds,cookieJar) {
// application/x-www-form-urlencoded
    return new Promise(function(resolve,reject){
        console.log("   Authenticating to",config.cloudURL+"/auth/login","...");
        var url = config.cloudURL+"/auth/login";
        request.post({
        url: url,
        // json: true,     
        jar: cookieJar,
        form: {
            username: creds.email,
            password: creds.pass
        }
        // body: {
        //     username: creds.email,
        //     password: creds.pass,
        //     grant_type: "password",
        //     client_id: ""
        // }
        }, (err,response,body) => {
        if(err) {
            reject(err);
        } else {
            if(response.statusCode != 200 && response.statusCode != 302) {
                console.error("Got back:",response.statusCode,body);
            reject('Bad authentication. Check password/username');
                } else {
    //          console.log("callback---------",body);
//              console.log("got back:",response.headers['set-cookie']);
                var token = getAuthToken(response.headers['set-cookie']);
//              console.log("cookies:",cookieJar.getCookies(url))
//              var cookies = cookie.parse(response.headers['set-cookie'])
                if(body && token) {
                    okOut("Successful auth.",response);
                    resolve(token);
                } else {
                    errorOut("Got back?: ",body);
                    reject("Got malformed response. Check URL.");
                }
            }
        }
        });
    });
}


var makeTokenCookie = function(token) {
	return "Cookie: access_token="+token+";"
}
    
var pairRelay = function(relayID, cookieJar) {
	// POST cloudURL+'/api/relays/'+pairingCode+'/bindToAccount'
	return new Promise((resolve,reject) => {
	    var pairingCode = (relaysById[relayID]) ? relaysById[relayID].pairingCode : null;
	    if(!pairingCode) {
	    	errorOut("Bad / missing pairing code.");
			reject("No pairing code for Relay");
	    } else {
		request.post({
		    url: config.cloudURL+'/api/relays/'+pairingCode+'/bindToAccount',
		    json: true,
		    jar: cookieJar,
		    body: {
		    }
		}, (err,response,body) => {
		    if(err) {
				reject(err);
		    } else {
//			console.log("response:",err,body);
//			console.log("response detail:",response.statusCode,response);
				if(response.statusCode != 200) {
				    errorOut("Got back:",response.statusCode,body);
				    reject('Pairing failure.');
				} else {
	//			    console.log("Got back:",body); // nothing is returned
				    okOut("   Paired.");
				    resolve();
				}
		    }
		});
	    }
	});		
}    


var getBatchFile = function(prefix,cookieJar) {
// POST cloudURL+/apps/admin/relayBatch?config={"prefix":"WWSR","count":1,"url":null,"loading":true}
    var query = {
	prefix: prefix,
	count: 1,
	url: null,        // not sure what these were for originally
	loading: true     // may just be left over
    };
    return new Promise((resolve,reject) => {
	var url = config.cloudURL+'/apps/admin/relayBatch?config='+encodeURIComponent(JSON.stringify(query));
	verboseOut("URL:",url);
	request.get({
	    url: url,
	    json: true,
	    jar: cookieJar
	}, (err,response,body) => {
	    if(err) {
		reject(err);
	    } else {
		//			console.log("response:",err,body);
		//			console.log("response detail:",response.statusCode,response);
		if(response.statusCode != 200) {
		    console.error("Got back:",response.statusCode,body);
		    reject('Relay allocation request failure:'+body);
		} else {
		    //			    console.log("Got back:",body); // nothing is returned		    
		   	verboseOut("   Got batch response:",body);
		    if(body && body.json  && body.json.length > 0 && body.json[0].relayID) {
//			console.log("resolve:",body.json[0]);
				logRecord("Relay batch generated by cloud",config.cloudURL,"on",moment().format('MM/DD/YY @ HH:mm'));
				logRecord("  Batch: ",body.batch);
				resolve(body.json[0]);
		    } else {
//			throw "Malformed response from server.";
				reject('Malformed response');
		    }
		}
	    }
	});
    });		
}    

// rlSync.setDefaultOptions({
// 	print: function(display, encoding)
//     { console.log(chalk.bold(display)) },
// });

 
var getCreds = function() {
	var email = rlSync.questionEMail("Email address: ");
	var pass = rlSync.question("Password: ",{
	    hideEchoBack: true,
	    mask: chalk.bold('*')
	});
	return { email: email, pass: pass };
}


var pairStep = function(creds) {
	return tryAuth(creds,userJar).then(function(ret){
	    //console.log("Got:",ret);
//	    console.log("   ...Successful auth.");
	    return true;
	},function(err){
		writeoutLog();
	    errorOut("Bad authentication:",err);
	    process.exit(-1);
	}).then(function(){
	    var keyz = Object.keys(relaysById);
	    var defaultRelay = keyz[0];
	    if(argv.id) defaultRelay = argv.id;
	    var relay = null;
	    if(keyz.length > 1) { 
		    while(!relay) {
				relay = rlSync.question("Which Relay? ["+defaultRelay+"]: ");
				if(!relay || relay.length < 1) {
				    relay = defaultRelay;
				}
				if(!relaysById[relay]) {
				    relay = null;
				    console.log("Don't have that Relay code. Relays we have pairing codes for: "+relayList);
				}
		    }
		} else {
			relay = defaultRelay;
		}
	    
	    console.log("   Pairing soft relay... ["+relay+"]");
	    return pairRelay(relay,userJar).then(function(){
	    	logRecord("Relay",relay,"paired on",moment().format('MM/DD/YY @ HH:mm'));	
	    });
	}).then(function(){
	    verboseOut("   Generating soft-relay config files...");
	    //	fs.writeFileSync
	    // next: mark relay as paired with hidden file in config directory.
	    // write out finalized yash-tool config file (softRelaySetup.json) as hidden file
	    // write out certs for yash-tool 
	    okOut("Pair complete.");
	});
}

// always resolves()
var writeoutLog = function() {
	return new Promise((resolve,reject) => {
		var name = OUTPUT_PAIR_LOG;	
		if(!path.isAbsolute(OUTPUT_PAIR_LOG)) {
			if(new_output_dir) {
				name = path.join(new_output_dir,path.basename(OUTPUT_PAIR_LOG));
			}
		}
		var data = output_to_log;
		output_to_log="";
		fs.appendFile(name,data,(err) => {
			if(err) {
				errorOut("Could not write out:"+name);
				console.log("Log was: ",data);
			} else {
				verboseOut("Updated log @:",name);				
			}
			resolve();
		});
	});
}

// read config(s) file... and proceed
Promise.all(readFileProms)
.then(function(){
	// if we are 'just pairing' then the Relay has already been allocated
	// in this case, the main config file, has a 'eepromFile' key which is a Relay
	// batch .json file with its unique settings.
	// Let's grab this
	if(argv.justpair && !relay_config) {
		if(!config.eepromFile) {
			errorOut("no 'eepromFile' key in the config file. state your relay config file with -r");
			process.exit(-1);
		}
		verboseOut("config file references Relay .json:",config.eepromFile);
	    return readJSONFile(config.eepromFile,true).then(function(o){
	    	relay_config_filename = o.fname;
			relay_config=o.d;
	    });		
	}

})
.then(function(){


	// Sort out the cloud URLs
	if(relay_config && relay_config[0]) {
		if(!config.cloudURL) config.cloudURL = relay_config[0].cloudURL;
		if(!config.devicejsCloudURL) config.devicejsCloudURL = relay_config[0].devicejsCloudURL;
		if(!config.devicedbCloudURL) config.devicedbCloudURL = relay_config[0].devicedbCloudURL;
		if(!config.relaymqCloudURL) config.relaymqCloudURL = relay_config[0].relaymqCloudURL;
	}

	if(argv.justpair) return true;
    // Step 1 - we must have a valud cloudURL to do anything.
    // This either came from a passed in config file (already parsed above)
    // or we need to get it from the user. Default values will be the object above.
    if(!argv.cloud && !silent_mode) {
    	var new_base_url = false; var base_url_proto, base_server, base_domain_and_port;
    	var orig_cloud_url = config.cloudURL;
		var validURL = false;
		console.log("Press [Enter] to keep default");
		while(!validURL) {	
		    var url = rlSync.question("current cloud API URL ["+config.cloudURL+"]:");
		    if(url && url.length > 0) {
		    	var m = validCloudURL.exec(url);
				if(m && m.length > 0) {
				    validURL = url;
				    base_url_proto = m[1];
				    base_server = m[2];
				    base_domain_and_port = m[3];
				} else {
				    console.log("This is not a valid cloud URL");
				}
		    } else {
				validURL = config.cloudURL;
		    }
		}
		config.cloudURL = validURL;

		if(relay_config || !no_config_file_given) {
			// just mark if they change this, to make the defaults
			// more sensible
			if(config.cloudURL != orig_cloud_url) { 
				new_base_url = true; 
				config.devicejsCloudURL = base_url_proto + '://' + base_server+'-devicejs' + base_domain_and_port;
				config.devicedbCloudURL = base_url_proto + '://' + base_server+'-devicedb' + base_domain_and_port;
				config.relaymqCloudURL = base_url_proto + '://' + base_server+'-relaymq' + base_domain_and_port;				
			}

			var validURL = false;
			while(!validURL) {	
			    var url = rlSync.question("current deviceJS Cloud URL ["+config.devicejsCloudURL+"]:");
			    if(url && url.length > 0) {
				if(validCloudURL.test(url)) {
				    validURL = url;
				} else {
				    console.log("This is not a valid cloud URL");
				}
			    } else {
				validURL = config.devicejsCloudURL;
			    }
			}
			config.devicejsCloudURL = validURL;

			var validURL = false;
			while(!validURL) {	
			    var url = rlSync.question("current deviceJS Cloud URL ["+config.devicedbCloudURL+"]:");
			    if(url && url.length > 0) {
					if(validCloudURL.test(url)) {
					    validURL = url;
					} else {
					    console.log("This is not a valid cloud URL");
					}
			    } else {
				validURL = config.devicedbCloudURL;
			    }
			}
			config.devicedbCloudURL = validURL;

			var validURL = false;
			while(!validURL) {
			    var url = rlSync.question("current relayMQ Cloud URL ["+config.relaymqCloudURL+"]:");
			    if(url && url.length > 0) {
					if(validCloudURL.test(url)) {
					    validURL = url;
					} else {
					    console.log("This is not a valid cloud URL");
					}
			    } else {
				validURL = config.relaymqCloudURL;
			    }
			}
			config.relaymqCloudURL = validURL;

		}
    }

    if(!config.cloudURL) {
		console.log("Need a cloudURL setting. Check config file.");
		process.exit(-1);
    }
    return true;
})
.then(function(){
    // Step 2 - We must have a generated Relay 'batch' JSON file from the cloud
    // This was either passed on on the command line, or we need to retrieve
    // one from the cloud as an Administrator.
    if(!relay_config) {
	// we did not get a relay config file. So let's get one from cloud.
	console.log("A relay config file was not provided.");
	cursor.write("Using cloud "); cursor.bold(); cursor.write(config.cloudURL); cursor.reset(); cursor.write('\n');

	if(!silent_mode) {
	    if(rlSync.keyInYN("Allocate a new soft relay from cloud?")) {
	  	SOFT_RELAY_PREFIX = rlSync.question("Relay prefix ["+SOFT_RELAY_PREFIX+"] ",{ defaultInput: SOFT_RELAY_PREFIX, limit: validRelayPrefix });
		// yes
		console.log("Enter you cloud *administrator* credientials");
		var adminCreds = getCreds();
		return tryAuth(adminCreds,adminJar).then(function(){
		    // get batch file
		    return getBatchFile(SOFT_RELAY_PREFIX,adminJar).then(function(obj){
				okOut("New Relay allocated by cloud:",obj.relayID);
				verboseOut("Got back object",obj);
				return new Promise((resolve,reject) => {
				    relay_config = obj;
				    var savename = path.join(CONFIG_DIR,obj.relayID+'-config.json');
				    fs.writeFile(savename,JSON.stringify(obj),{
				    	flag: 'wx',
				    	encoding: 'utf8'
				    },(err) => {
				    	if(err) {
				    	    if(err.code == 'EEXIST') {
					    		console.error("A relay config file already exists with this name!:",savename);
				    	    }
				    	    throw err;
				    	} else {
				    	    okOut("Saved relay data as:",savename);
				    	    logRecord("  Data saved as: ",savename);
				    	    relay_config_filename = savename;
						    relay_config = [obj];
						    relay_config[0].relayID = obj.relayID;
				    	    resolve(obj);
				    	}
				    });
				});
		    })
		});
	    } else {
		// No, oh well.
	    }	    
	}	
    } else {
	return relay_config;
    }
})
.then(function(){
	// Step 3 - Make sure we have a valid Relay object from the cloud / file provided
	// This means we need some mandatory fields, including a 'relayID'
    if(!relay_config || relay_config.length < 1) {
		// occurs if a config file was passed, but it's screwed up
		console.log("Need a valid relay config file");
		process.exit(-1);
    } else {
		for(var n=0;n<relay_config.length;n++) {
		    if(relay_config[n].relayID) {
				relaysById[relay_config[n].relayID] = relay_config[n];
				if(n > 0) relayList += ", ";
	 				relayList += relay_config[n].relayID;
			    } else {
				console.error("Invalid line for Relay,", argv.r, "line:",n); 
		    }
		}
		verboseOut("Read in Relay data:",relayList);
//		return true;
		if(config.cloudURL && relay_config[0].cloudURL != config.cloudURL) {
			warnOut("Note, cloud returned new 'cloudURL' in batch:",relay_config[0].cloudURL);
		}		
    }    

	if(relay_config[0].cloudURL) config.cloudURL = relay_config[0].cloudURL;
	if(relay_config[0].devicejsCloudURL) config.devicejsCloudURL = relay_config[0].devicejsCloudURL;
	if(relay_config[0].devicedbCloudURL) config.devicedbCloudURL = relay_config[0].devicedbCloudURL;

})
.then(function(){
	verboseOut("cloudURL:",config.cloudURL);
	verboseOut("devicejs URL:",config.devicejsCloudURL);
	verboseOut("devicedb URL:",config.devicedbCloudURL);
	verboseOut("relaymq URL:",config.relaymqCloudURL);

	// Step 4: We have a Relay config, and a good set of template information
	// So let's write it to disk in the form of some JSON (this will be used 
	// by the deviceOS eeprom setup script)
	config.eepromFile = relay_config_filename;

	var out = JSON.stringify(config,null,4); // put some space in so you can see the output easy

	return new Promise((resolve,reject) => {
		var writeOut = function(name) {
			if(!name) name = OUTPUT_CONFIG_FILE;
			fs.writeFile(name,out,{
				flag: 'wx',
				encoding: 'utf8'
			},(err) => {
				if(err) {
					if(err.code == 'EEXIST') {
						warnOut("file",OUTPUT_CONFIG_FILE,"already exists.");
						// so, the normal file exists, let's try to create a directory under it's
						// directory to place the file
						tmp.dir({template:path.dirname(OUTPUT_CONFIG_FILE)+'/config-XXXXXX'},function _tempDirCreated(err, folder) {
							if(!err) {
								var newname = path.join(folder,path.basename(OUTPUT_CONFIG_FILE));
								console.log("Will write to:",newname);
								new_output_dir = folder;
								writeOut(newname);
							} else {
								console.error("Can't save output file. Aborting.",err);
								console.log("CONFIG was:",out);
								process.exit(-1);
							}
						});
						// modern node.js version 5.0+
						// fs.mkdtemp(path.dirname(OUTPUT_CONFIG_FILE)+'/config-', (err,folder) => {
						// 	if(!err) {
						// 		var newname = path.join(folder,path.basename(OUTPUT_CONFIG_FILE));
						// 		console.log("Will write to:",newname);
						// 		writeOut(newname);
						// 	} else {
						// 		console.error("Can't save output file. Aborting.",err);
						// 		console.log("CONFIG was:",out);
						// 		process.exit(-1);
						// 	}
						// });
					} else {
						console.log("Error writing out config file",OUTPUT_CONFIG_FILE,err);
						console.log("CONFIG was:",out);
						process.exit(-1);
					}					
				} else {
					logRecord("Config file: ",name);
					okOut("   Wrote master config file to:",name);
					resolve(); // next...	
					writeoutLog();
				}
			});			
		}
		writeOut();
	})
})
.then(function(){
	if(!argv.dontpair) {
//    console.log("Press [Enter] to keep default");
//    
		console.log("-------------------");    
		console.log("    Pair Relay");
		console.log("-------------------");    
	    console.log("Enter cloud login credential for the account for this soft-relay.");
	    var creds = getCreds();
	    
	    return pairStep(creds);    		
	}
})
.then(function(){
	return writeoutLog();
})
.then(function(){
	okOut("Tool finished.")	
})
.catch(function(e){
    errorOut("Tool failed:",e);
    if(e.stack) errorOut("Here:",e.stack);
});

