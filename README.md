# cloud-installer

For instructions on using these containers, see [here](USER.md)

#### Logging in to the WigWag Docker registry

```
docker login docker-registry.wigwag.io:5000
```

###### Other useful docker tips:

List all repositories like this: `docker-ls repositories --registry https://docker-registry.wigwag.io:5000 --user wigwag --password wigwag123 --basic-auth` - you will need the [docker-ls utility](https://github.com/mayflower/docker-ls)

#### Updating a Docker image 

If you need to update a base images, such as installing new libraries, etc. The typical process is to:

* start that base image, and login to it interactive

```
docker pull docker-registry.wigwag.io:5000/ww-ubuntu-base-node
docker run docker-registry.wigwag.io:5000/ww-ubuntu-base-node -i -t
```

* Make whatever changes needed. 
* Next use `docker images` to find the image of the container you created and modified. Then commit and push. Here we commit changes in container `77270ba18a65` then tag its image and push.

```
docker ps -a
...
docker commit -m "added libavahi compat libs for mdns" 77270ba18a65
docker images
...
docker tag e9d2c5433a6b  docker-registry.wigwag.io:5000/ww-ubuntu-base-node
docker push docker-registry.wigwag.io:5000/ww-ubuntu-base-node
```


#### How we create the base CoreOS images

based on this: https://www.greglangford.co.uk/installing-coreos-kvm-using-virt-install/

Refer to the `cloud-config-basic.yml` file.

`virt-install --name vm103 --ram 2048 --disk path=./coreos.cow2,size=20 --network bridge=br0,model=virtio --noautoconsole --vcpus 2 --graphics none --boot kernel=./coreos_production_pxe.vmlinuz,initrd=./coreos_production_pxe_image.cpio.gz,kernel_args="console=ttyS0 coreos.autologin=ttyS0" --os-type=linux --os-variant=virtio26`

Get into the VM: `virsh console vm103`

Make a up a root password with `sudo passwd` and then `su`

```
bash-4.3# wget http://10.10.120.10:8080/cloud-config-basic.yml
--2016-12-06 19:19:42--  http://10.10.120.10:8080/cloud-config-basic.yml
Connecting to 10.10.120.10:8080... connected.
HTTP request sent, awaiting response... 200 OK
Length: unspecified [application/octet-stream]
Saving to: 'cloud-config-basic.yml'

cloud-config-basic.     [ <=>                ]   3.36K  --.-KB/s    in 0s

2016-12-06 19:19:42 (167 MB/s) - 'cloud-config-basic.yml' saved [3438]

bash-4.3# ls
cloud-config-basic.yml
```
also `wget http://10.10.120.10:8080/cloud-config-basic.ignition.json`
`coreos-install -d /dev/vda -c cloud-config-basic.yml -i cloud-config-basic.ignition.json`

It will install CoreOS onto /dev/vda, which in this example is the image `coreos.cow2`...

```
bash-4.3# coreos-install -d /dev/vda -c cloud-config-basic.yml
2016/12/06 19:27:28 Checking availability of "local-file"
2016/12/06 19:27:28 Fetching user-data from datasource of type "local-file"
Downloading the signature for https://stable.release.core-os.net/amd64-usr/1185.3.0/coreos_production_image.bin.bz2...
2016-12-06 19:27:29 URL:https://stable.release.core-os.net/amd64-usr/1185.3.0/coreos_production_image.bin.bz2.sig [543/543] -> "/tmp/coreos-install.iVSvUoD0ki
/coreos_production_image.bin.bz2.sig" [1]
Downloading, writing and verifying coreos_production_image.bin.bz2...
2016-12-06 19:28:16 URL:https://stable.release.core-os.net/amd64-usr/1185.3.0/coreos_production_image.bin.bz2 [258950835/258950835] -> "-" [1]
[  740.997608] GPT:Primary header thinks Alt. header is not at the end of the disk.
[  741.001454] GPT:9289727 != 41943039
[  741.001774] GPT:Alternate GPT header not at the end of the disk.
[  741.002338] GPT:9289727 != 41943039
[  741.002651] GPT: Use GNU Parted to correct GPT errors.
[  741.003150]  vda: vda1 vda2 vda3 vda4 vda6 vda7 vda9
gpg: Signature made Tue Nov  1 06:17:09 2016 UTC using RSA key ID 2E16137F
gpg: key 93D2DCB4 marked as ultimately trusted
gpg: checking the trustdb
gpg: 3 marginal(s) needed, 1 complete(s) needed, PGP trust model
gpg: depth: 0  valid:   1  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 1u
gpg: Good signature from "CoreOS Buildbot (Offical Builds) <buildbot@coreos.com>" [ultimate]
[  741.089868] GPT:Primary header thinks Alt. header is not at the end of the disk.
[  741.090991] GPT:9289727 != 41943039
[  741.091532] GPT:Alternate GPT header not at the end of the disk.
[  741.092428] GPT:9289727 != 41943039
[  741.092943] GPT: Use GNU Parted to correct GPT errors.
[  741.093712]  vda: vda1 vda2 vda3 vda4 vda6 vda7 vda9
[  753.206711] EXT4-fs (vda9): mounted filesystem with ordered data mode. Opts: (null)
Installing cloud-config...
Success! CoreOS stable 1185.3.0 is installed on /dev/vda
```
-- Any custom commands here --

Now shutdown and reboot into the actual partition

`shutdown -h now`

Get rid of this VM:

```
wigwag@core-server1:/vm/tmp$ virsh destroy vm103
error: Failed to destroy domain vm103
error: Requested operation is not valid: domain is not running

wigwag@core-server1:/vm/tmp$ virsh undefine vm103
Domain vm103 has been undefined
```

OK - now import that new `.cow2` as a new VM:

*going with 8GB or RAM and 4 CPUs*

`virt-install --import --name vm103 --ram 8192 --disk path=./coreos.cow2,bus=virtio --network bridge=br0,model=virtio --noautoconsole --vcpus 4 --graphics none --os-type=linux --os-variant=virtio26`


##### Introspecting a container

- Pull the latest container, here will are using the `djs-soft-relay` container
- Enter it like, with needed options, for instance:
```
sudo docker run -v `pwd`/config:/config -v `pwd`/userdata:/userdata \
  -v `pwd`/apps:/apps -it --entrypoint bash a34a79fb8a75
```
Where `a34a79fb8a75` is the image name or tag name - could be `docker-registry.wigwag.io:5000/djs-soft-relay`  

In this case we bypassed the Dockerfile's entry point, and are just running bash

- Modify `Dockerfile` after you figure out what to do



##### Troubleshooting

* When using CoreOS and the [Fedora-based toolbox](https://coreos.com/os/docs/latest/install-debugging-tools.html) you may run into a bug where a KILL signal kills the entire container, when running `yum`. See [here](https://github.com/coreos/bugs/issues/1676). Use the work around: `rpm --import /etc/pki/rpm-gpg/RPM*` inside the toolbox so you can succesfully install stuff.

###### References
* http://kimh.github.io/blog/en/docker/gotchas-in-writing-dockerfile-en/
* http://serverfault.com/questions/627238/kvm-libvirt-how-to-configure-static-guest-ip-addresses-on-the-virtualisation-ho
* https://coreos.com/os/docs/latest/booting-with-libvirt.html
* https://coreos.com/docs/launching-containers/launching/getting-started-with-systemd/
* https://coreos.com/os/docs/latest/cloud-config.html#sshauthorizedkeys
* https://coderwall.com/p/dqhncq/how-to-investigate-failed-units-for-coreos
* https://futurestud.io/tutorials/coreos-run-your-node-js-app-on-cluster
* https://support.realvnc.com/knowledgebase/article/View/407/2/cannot-connect-to-vnc-server-using-built-in-viewer-on-mac-os-x

###### Docker on Linode:
* http://lukeberndt.com/2016/getting-docker-up-on-linode-with-ubuntu-16-04/
