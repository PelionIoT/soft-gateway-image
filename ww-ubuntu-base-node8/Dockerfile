FROM blitznote/debootstrap-amd64:16.04
MAINTAINER devops@wigwag.com
RUN groupadd -g 501 -r wigwag && useradd -r -g wigwag -u 501 -m -d /home/wigwag wigwag && mkdir -p /home/wigwag/.ssh && mkdir -p /wigwag && chown wigwag:wigwag /wigwag
ADD build-node8.sh /home/wigwag
ADD c++config.h /home/wigwag
RUN /home/wigwag/build-node8.sh
ENTRYPOINT [ "/bin/bash" ]
