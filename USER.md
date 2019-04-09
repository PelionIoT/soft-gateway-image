# Using the WigWag Stock Docker Images

*Requirements:*
- You will need Docker installed. [Directions here](https://docs.docker.com/engine/installation/linux/ubuntulinux/) for Ubuntu. DO NOT use the Ubuntu repository for Docker. (We recommend using Docker 1.12.3 or later)
- Once installed ensure the `docker` daemon is running.
- If you do not add your user to the `docker` group, then you will need to preface your docker commands with `sudo` - so that your commands can talk to the Docker daemon.

Login and enter your provided registry login credentials. (these will be saved in your home directory)
```
$ docker login docker-registry.wigwag.io:5000
Username: [username]
Password: [password]
```

You are now ready to use these images:

### DeviceJS Cloud Client: `djs-cloud-client`

The `djs-cloud-client` container starts a deviceJS client instance, which can talk to the deviceJS cloud server It along with all services are collectively called, "Device Cloud Services" or DCS.

**Installation:**

The images are in WigWag's docker registry.

Pull down the latest `djs-cloud-client` image.
```
$ docker pull docker-registry.wigwag.io:5000/djs-cloud-client
```


After installation, you will see the image listed:

```
$ docker images
REPOSITORY                                        TAG      IMAGE ID          CREATED       SIZE
docker-registry.wigwag.io:5000/djs-cloud-client   latest   25d80951dc70      4 hours ago   868.6 MB
```

Ensure the image will work:
```
$ docker run --rm -it docker-registry.wigwag.io:5000/djs-cloud-client
---------------------
deviceJS Cloud Client
(c) 2017 WigWag Inc.
---------------------
Usage djs-cloud-client [-c config] [-d] COMMAND [arguments ...]
 ...
```
... The command will printout usage guidance.


**Usage:**

Let's say you will be running this container form `/home/user`

In this directory you might have the following layout:
```
/home/user ┐
           /example-config ┐
                           ca.cert.pem
                           intermediate.cert.pem
                           clientConfig.json
           /test-scripts ┐
                         hello.js                 
```

From `/home/user` run:

```
docker run -v `pwd`/example-config:/config -v `pwd`/test-scripts:/apps --rm -it docker-registry.wigwag.io:5000/djs-cloud-client
```
..will printout the usage for the deviceJS cloud client command.

Each switch explained:

**```-v `pwd`/example-config:/config```**
This will make your `/home/user/example-config` directory be the directory deviceJS will look for your config file. The default config file name is `clientConfig.json` for the djs-cloud-client container. Also note that ``` `pwd` ``` is just short hand for getting the current directory ('print working directory') instead of typing it all out. This command would work anywhere you had the correct `test-scripts` and `example-config` directories. 

**```-v `pwd`/test-scripts:/apps```**
The `/home/user/test-scripts` directory will be the main /apps directory in the container. You can use this with the `run` command.

**`--rm`** Remove the container image when done. This just cleans up things. Since all saved work would be in `test-scripts` you don't need to keep the image hanging around.

**`-it`** Starts a TTY and makes the session interactive. During development you will need this to enter credentials and see output.

**`djs-cloud-client`** is the name of the image to run.

**This container's options**

`-d`  Place the container in debug mode. Will produce more output on startup, and provide version information.

`-c CONFIG_FILE`  Use an alternate config file name


**Examples:**

Start the deviceJS cloud client shell
```
docker run -v `pwd`/example-config:/config -v `pwd`/test-scripts:/apps --rm -it docker-registry.wigwag.io:5000/djs-cloud-client shell
```

Run the script hello.js
```
docker run -v `pwd`/example-config:/config -v `pwd`/test-scripts:/apps --rm -it docker-registry.wigwag.io:5000/djs-cloud-client run /apps/hello.js
```

Get version info about this container. The deviceJS commit number, etc.
```
docker run --rm -it docker-registry.wigwag.io:5000/djs-cloud-client -d
```

Run the script hello.js, but use `newConfig.json` as the config file, which should be in the `example-config` directory.
```
docker run -v `pwd`/example-config:/config -v `pwd`/test-scripts:/apps --rm -it \
                                           docker-registry.wigwag.io:5000/djs-cloud-client -c newConfig.json run /apps/hello.js
```

### DeviceJS Soft Relay: `djs-soft-relay`

The deviceJS Soft Relay allows a developer to have a full deviceJS Relay, with out having to install the various prerequisties on their own machine.  This container exposes a `/config` directory (more below), a `/apps` for running your appplications and a `/userdata` for storing deviceBD data. 

By keeping your `/apps` and `/userdata` in Docker volumes, out of the container, you can restart the soft-relay without having to keep it's container entact. 

**Installation:**

The images are in WigWag's docker registry.

Pull down the latest `djs-soft-relay` image.
```
$ docker pull docker-registry.wigwag.io:5000/djs-soft-relay
```


**Usage:**

Let's say you will be running this container form `/home/user`

In this directory you might have the following layout:
```
/home/user ┐
           /log
           /example-config ┐
                           ca.cert.pem
                           intermediate.cert.pem
                           clientConfig.json
           /test-scripts ┐
                         hello.js                 
           /data
```

From `/home/user` run:

```
docker run -v `pwd`/log:/log -v `pwd`/example-config:/config -v `pwd`/test-scripts:/apps --rm -it docker-registry.wigwag.io:5000/djs-soft-relay
```
..will printout the usage for the deviceJS cloud client command.

Each switch explained:

**```-v `pwd`/example-config:/config```**
This will make your `/home/user/example-config` directory be the directory deviceJS will look for your config file. The default config file name is `clientConfig.json` for the djs-cloud-client container. Also note that ``` `pwd` ``` is just short hand for getting the current directory ('print working directory') instead of typing it all out. This command would work anywhere you had the correct `test-scripts` and `example-config` directories. 

**```-v `pwd`/test-scripts:/apps```**
The `/home/user/test-scripts` directory will be the main /apps directory in the container. You can use this with the `run` command.

**```-v `pwd`/data:/userdata```** 
This `djs-soft-relay` container stores stateful information using deviceDB. This information will be stored inside the container if this volume is not mounted. Providing this volume means the container does not have to remain on disk when shutdown.

**`--rm`** Remove the container image when done. This just cleans up things. Since all saved work would be in `test-scripts` you don't need to keep the image hanging around.

**`-it`** Starts a TTY and makes the session interactive. During development you will need this to enter credentials and see output.

**`djs-soft-relay`** is the name of the image to run.

**Exec Commands**

These commands can be used with `docker exec` while the container is running:

*Assuming your running djs-soft-relay container is "relay"...*

**`docker exec -i -t relay relay-version`** Prints out the version information of the Relay, including internal software versions & devicedb version

**`docker exec -i -t relay relay-info`** Prints out the Relay pairing information about the container.

**`docker exec -i -t relay relay-logs`** Live view of the logs from the Relay. Uses `less`. To watch the latest logs enter capital `F`

**`docker exec -i -t relay devicejs-shell`** Starts the deviceJS shell inside the container - will connect to the deviceJS runtime of the Relay.

**`docker exec -i -t relay devicejs-run SCRIPT [arguments...]`** Runs a script using the deviceJS runtime of the Relay

#### Updates

To update an image, run:

```
$ docker pull docker-registry.wigwag.io:5000/djs-cloud-client
Using default tag: latest
latest: Pulling from djs-cloud-client
Digest: sha256:178d6e477e455ebd7e9a4730ec1cd4c375b9c2eb14aa5efaec080a31dae22a64
Status: Image is up to date for docker-registry.wigwag.io:5000/djs-cloud-client:latest
```

##### References & Helpful Docs

###### Docker on Linode
* http://lukeberndt.com/2016/getting-docker-up-on-linode-with-ubuntu-16-04/
