FROM docker-registry.wigwag.io:5000/ww-cloud-mongo-base
ENV PATH=$PATH:/wigwag:/opt/bin
RUN groupadd -g 501 -r wigwag && useradd -r -g wigwag -u 501 -m -d /home/wigwag wigwag
RUN mkdir -p /home/wigwag/.ssh
ADD start-wwcontainer.sh /
ADD ssh-config/config /home/wigwag/.ssh
RUN chmod 600 /home/wigwag/.ssh/config
RUN chown wigwag:wigwag /home/wigwag/.ssh/config
RUN chown -R wigwag:wigwag /home/wigwag/.ssh
ENTRYPOINT /start-wwcontainer.sh
