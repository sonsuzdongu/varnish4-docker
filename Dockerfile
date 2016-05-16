FROM ubuntu:14.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		curl \
		vim-gnome \
		screen \
        tmux \
        sudo \
        build-essential \
        apt-transport-https

RUN curl https://repo.varnish-cache.org/ubuntu/GPG-key.txt | apt-key add -

RUN echo "deb https://repo.varnish-cache.org/ubuntu/ trusty varnish-4.0" >> /etc/apt/sources.list.d/varnish-cache.list

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		varnish

ADD scripts /docker/scripts
#ADD data/varnish.config /etc/varnish/default.vcl

#VOLUME ["/etc/varnish/default.vcl"]

CMD ["/docker/scripts/run.sh"]
