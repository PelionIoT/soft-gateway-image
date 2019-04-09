FROM docker-registry.wigwag.io:5000/djs-soft-relay
MAINTAINER devops@wigwag.com
ENV PATH=$PATH:/wigwag:/opt/bin
# RUN groupadd -g 501 -r wigwag && useradd -r -g wigwag -u 501 -m -d /home/wigwag wigwag && mkdir -p /home/wigwag/.ssh && mkdir -p /wigwag && chown wigwag:wigwag /wigwag
ADD wigwag_devops_cloud_github_latest /wigwag
# # add github.com to known_hosts so that git won't go interactive with Yes/No question
RUN chown -R wigwag:wigwag /wigwag && chown wigwag:wigwag /wigwag/wigwag_devops_cloud_github_latest && ww-su-exec wigwag ssh-keyscan -t rsa github.com > /home/wigwag/.ssh/known_hosts
ADD ssh-config/config /home/wigwag/.ssh
RUN chmod 600 /home/wigwag/.ssh/config && chown wigwag:wigwag /home/wigwag/.ssh/config && chown -R wigwag:wigwag /home/wigwag/.ssh && chown wigwag:wigwag -R /wigwag
ADD example-config/softrelay-config.yaml /wigwag/etc
# # add the entrypoint script
VOLUME "/config" "/apps" "/userdata" "/log"
# ADD entry.sh /home/wigwag
# RUN chown wigwag:wigwag /home/wigwag/entry.sh && chmod a+x /home/wigwag/entry.sh
ADD build-mbed.sh /wigwag
RUN build-mbed.sh
ADD mbed-devicejs-bridge-config.json /wigwag/mbed-devicejs-bridge/config.json
ENTRYPOINT [ "/home/wigwag/entry.sh" ]
#CMD /home/wigwag/entry.sh
#CMD /home/wigwag/entry.sh
# ADD example-config/runner.config.json /wigwag/runner.config.json
# RUN chown wigwag:wigwag -R /wigwag
# Relay internal web server  is on 443
# mDNS runs on 5353
RUN rm -rf /var/lib/apt/lists/*
EXPOSE 4443 5353 
