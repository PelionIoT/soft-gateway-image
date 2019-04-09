FROM docker-registry.wigwag.io:5000/ww-ubuntu-base-node6
MAINTAINER devops@wigwag.com
ENV PATH=$PATH:/wigwag:/opt/bin
RUN groupadd -g 501 -r wigwag && useradd -r -g wigwag -u 501 -m -d /home/wigwag wigwag && mkdir -p /home/wigwag/.ssh && mkdir -p /wigwag && chown wigwag:wigwag /wigwag
ADD wigwag_devops_cloud_github_latest /wigwag
#	# add github.com to known_hosts so that git won't go interactive with Yes/No question
RUN chown wigwag:wigwag /wigwag/wigwag_devops_cloud_github_latest && gosu wigwag ssh-keyscan -t rsa github.com > /home/wigwag/.ssh/known_hosts
ADD ssh-config/config /home/wigwag/.ssh
ADD build-all.sh /root
RUN chmod 600 /home/wigwag/.ssh/config && chown wigwag:wigwag /home/wigwag/.ssh/config && chown -R wigwag:wigwag /home/wigwag/.ssh && mkdir -p /wigwag/pairRelay && chown wigwag:wigwag -R /wigwag
RUN bash /root/build-all.sh
VOLUME "/output"
ENTRYPOINT [ "/home/wigwag/entry.sh" ]

# remove keys
RUN rm /wigwag/wigwag_devops_cloud_github_latest
#	ADD pairRelay/pair.js /wigwag/pairRelay
#	ADD pairRelay/package.json /wigwag/pairRelay
#	ADD example-config/softRelaySetup.json /wigwag/softRelaySetup.json
#	ADD build-prereqs.sh /wigwag
#	# need this here, to ensure a new pull is really done on each build
#	ADD .build-date /wigwag
#	ADD build-wwcontainer.sh /wigwag
#	ADD relay_logger-tty.conf.json /wigwag
#	ADD relay_logger-file.conf.json /wigwag
#	RUN /wigwag/build-prereqs.sh 
#	RUN /wigwag/build-wwcontainer.sh
##	ADD devicejs-run /wigwag
#	ADD devicejs-shell /wigwag
#	ADD relay-logs /wigwag
#	ADD relay-info /wigwag
#	ADD relay-version /wigwag
#	# override the default of the devicedb.conf file to the one we have here
#	# this template file will be used when the actual devicedb config file is generated
#	ADD example-config/template.devicedb.yaml /wigwag/wwrelay-utils/I2C/testConfigFiles/template.devicedb.conf
#	# add the entrypoint script
#	VOLUME "/config" "/apps" "/userdata" "/log"
#	ADD entry.sh /home/wigwag
#	RUN chown wigwag:wigwag /home/wigwag/entry.sh && chmod a+x /home/wigwag/entry.sh
#	ENTRYPOINT [ "/home/wigwag/entry.sh" ]
#	#CMD /home/wigwag/entry.sh
#	#CMD /home/wigwag/entry.sh
#	ADD example-config/runner.config.json /wigwag/runner.config.json
#	RUN chown wigwag:wigwag -R /wigwag
#	# Relay internal web server is on 443
#	# mDNS runs on 5353
#	EXPOSE 4443 5353