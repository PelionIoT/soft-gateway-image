FROM docker-registry.wigwag.io:5000/ww-ubuntu-base-node8:latest
MAINTAINER devops@wigwag.com
ENV PATH=$PATH:/wigwag:/opt/bin
#RUN groupadd -g 501 -r wigwag && useradd -r -g wigwag -u 501 -m -d /home/wigwag wigwag && mkdir -p /home/wigwag/.ssh && mkdir -p /wigwag/templates && chown -R wigwag:wigwag /wigwag
RUN mkdir -p /wigwag/templates && chown -R wigwag:wigwag /wigwag
ADD wigwag_devops_cloud_github_latest /wigwag
ADD template-softrelay.devicejs.conf /wigwag/templates
ADD template-softrelay.devicedb.conf /wigwag/templates
# add github.com to known_hosts so that git won't go interactive with Yes/No question
RUN chown wigwag:wigwag /wigwag/wigwag_devops_cloud_github_latest && ww-su-exec wigwag ssh-keyscan -t rsa github.com > /home/wigwag/.ssh/known_hosts
ADD ssh-config/config /home/wigwag/.ssh
RUN chmod 600 /home/wigwag/.ssh/config && chown wigwag:wigwag /home/wigwag/.ssh/config && chown -R wigwag:wigwag /home/wigwag/.ssh && mkdir -p /wigwag/pairRelay && chown wigwag:wigwag -R /wigwag
ADD pairRelay/pair.js /wigwag/pairRelay
ADD pairRelay/package.json /wigwag/pairRelay
ADD example-config/softRelaySetup.json /wigwag/softRelaySetup.json
ADD build-prereqs.sh /wigwag
# need this here, to ensure a new pull is really done on each build
ADD .build-date /wigwag
ADD build-wwcontainer.sh /wigwag
ADD modhosts.js /wigwag
ADD relay_logger-tty.conf.json /wigwag
ADD relay_logger-file.conf.json /wigwag
RUN /wigwag/build-prereqs.sh 
RUN /wigwag/build-wwcontainer.sh
ADD devicejs-run /wigwag
ADD devicejs-shell /wigwag
ADD relay-logs /wigwag
ADD relay-info /wigwag
ADD relay-version /wigwag
ADD dump-meta-vars /wigwag
# override the default of the devicedb.conf file to the one we have here
# this template file will be used when the actual devicedb config file is generated
ADD example-config/relayterm_template.config.json /wigwag/wwrelay-utils/I2C/testConfigFiles/relayterm_template.config.json
ADD example-config/softrelay-config.yaml /wigwag/etc
# add the entrypoint script
VOLUME "/config" "/apps" "/userdata" "/log"
ADD entry.sh /home/wigwag
RUN chown wigwag:wigwag /home/wigwag/entry.sh && chmod a+x /home/wigwag/entry.sh
ENTRYPOINT [ "/home/wigwag/entry.sh" ]
#CMD /home/wigwag/entry.sh
#CMD /home/wigwag/entry.sh
ADD example-config/runner.config.json /wigwag/runner.config.json
RUN chown wigwag:wigwag -R /wigwag
# cleanup
# apt-get remove --purge -y $BUILD_PACKAGES $(apt-mark showauto)
RUN rm -rf /var/lib/apt/lists/* && rm -rf /opt/go && rm -rf /wigwag/go-workspace
# Relay internal web server  is on 443
# mDNS runs on 5353
EXPOSE 4443 5353 
