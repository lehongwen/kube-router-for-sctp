FROM alpine:3.10.3

RUN apk add \
      iptables \
      ip6tables \
      ipset \
      iproute2 \
      conntrack-tools \
      curl \
      bash \
      gcc g++ \
      gdb \
      make \
      libnl libnl3 libnl3-dev \
      popt popt-dev linux-headers\
      musl && \
      mkdir -p /var/lib/gobgp && \
      mkdir -p /usr/local/share/bash-completion

# Install ipvsadm  

COPY ipvsadm-1.30.tar.gz /home

RUN cd /home && \
    tar -xvf ipvsadm-1.30.tar.gz && \
    cd /home/ipvsadm-1.30 && make && make install && cd /home/ && rm -rf ipvsadm-1.30*

RUN apk del \
    make 

ADD image-assets/bash-completion /usr/local/share/bash-completion/

ADD image-assets/bashrc /root/.bashrc
ADD image-assets/profile /root/.profile
ADD image-assets/vimrc /root/.vimrc

ADD image-assets/motd-kube-router.sh /etc/motd-kube-router.sh
ADD image-assets/kube-router image-assets/gobgp /usr/local/bin/
RUN cd && \
    /usr/local/bin/gobgp --gen-cmpl --bash-cmpl-file /var/lib/gobgp/gobgp-completion.bash

WORKDIR "/root"
ENTRYPOINT ["/usr/local/bin/kube-router"]

#CMD ["bash"]
