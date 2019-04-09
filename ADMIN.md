# Using the WigWag Stock Docker Images

### DeviceJS Cloud Server: `devicejs-cloud`

**Installation:**

The images are in WigWag's docker registry.

*Requirements:*
- You will need Docker installed. [Directions here](https://docs.docker.com/engine/installation/linux/ubuntulinux/) for Ubuntu. DO NOT use the Ubuntu repository for Docker.
- Once installed ensure the `docker` daemon is running.
- If you do not add your user to the `docker` group, then you will need to preface your docker commands with `sudo` - so that your commands can talk to the Docker daemon.

Login and enter your provided registry login credentials. (these will be saved in your home directory)
```
$ docker login docker-registry.wigwag.io:5000
Username: [username]
Password: [password]
```
Pull down the latest `djs-cloud-client` image.
```
$ docker pull docker-registry.wigwag.io:5000/djs-cloud-client
```

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
This will make your `/home/user/example-config` directory be the directory deviceJS will look for your config file. The default config file name is `clientConfig.json` for the djs-cloud-client container. 

**```-v `pwd`/example-config:/config```**
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

### DeviceJS Cloud Server: `wigwag-rabbitmq`

**Installation:**

```
$ docker pull docker-registry.wigwag.io:5000/wigwag-rabbitmq
```

**Usage:**

```
docker run -v /home/user/config/example-config:/config \
           -v /home/user/place-logs-here:/exposed-logs \
           -p 5672:5672 -d  wigwag-rabbitmq start
```

rabbitmq runs on 5672 by default. This is exposed in the container. 

The `/config` volume can contain a `rabbitmq.env` file. This is a bash file which will get sourced, to provide the following variables:

```
RABBITMQ_MNESIA_BASE
RABBITMQ_NODENAME
RABBITMQ_NODE_IP_ADDRESS
```

Refere to `rabbitmq-server` [docs](https://www.rabbitmq.com/man/rabbitmq-server.1.man.html) for more info.

`RABBITMQ_LOG_BASE` will always be overridden to use the `/exposed-logs` volume. The logs will be placed in a subdirectory of `exposed-logs` with the container's ID

### DeviceJS Cloud Server: `wigwag-mysql`

**Background**

MySQL handles portions of the devicedb cloud data storage role. This MySQL container runs MySQL in the fashion required by DCS. *Currently uses MySQL 5.7 with an Ubuntu 16.04 base*

**Installation:**

```
$ docker pull docker-registry.wigwag.io:5000/wigwag-mysql
```

**Usage:**

The container provides VOLUMES for
* log output `/exposed-logs`
* MySQL data storage `/var/lib/mysql`
* config directory for the `mysql.env` file `/config`

Let's say you have a directory structure like:

```
ROOT DIR ┐
          /mysqlconfig   --> for your mysql.env file
          /mysqllogs      --> mysql error logs will go here
          /mysqldata     --> the location of the MySQL data
```

The following command will map the folders in your current working directory to the container's appropriate folders:

```
docker run -v `pwd`/mysqlconfig:/config \ 
           -v `pwd`/mysqllogs:/exposed-logs \ 
           -v `pwd`/mysqldata:/var/lib/mysql \ 
           -p 3306:3306 -p 33060:33060 -d  docker.wigwag.io:5000/wigwag-mysql start
```

MySQL ports 3306 and 33060 are exposed in the container.

The `/config` volume can contain a `mysql.env` file. This is a bash file which will get sourced, to provide the following variables:

```
MYSQL_ROOT_PASSWORD or MYSQL_ALLOW_EMPTY_PASSWORD or MYSQL_RANDOM_ROOT_PASSWORD
MYSQL_DATABASE="some_database_name"
MYSQL_USER="username" 
MYSQL_PASSWORD="passwordforuserabove"
```

This container is built off the official MySQL container, but uses Ubuntu instead of oracle-linux. [Here](https://github.com/mysql/mysql-docker) for more.

#### Updates

To update the image, run:

```
$ docker pull docker-registry.wigwag.io:5000/djs-cloud-client
Using default tag: latest
latest: Pulling from djs-cloud-client
Digest: sha256:178d6e477e455ebd7e9a4730ec1cd4c375b9c2eb14aa5efaec080a31dae22a64
Status: Image is up to date for docker-registry.wigwag.io:5000/djs-cloud-client:latest
```
