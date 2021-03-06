#
# Based on official https://hub.docker.com/_/python/
#
FROM python:2.7-slim

MAINTAINER Oisin Mulvihill <oisin.mulvihill@gmail.com>

RUN apt-get update -y && apt-get install -y \
        bash \
        gcc \
        git-core \
        netcat \
        ca-certificates \
        openssh-client \
        libyaml-dev libssl-dev libffi-dev \
    --no-install-recommends && rm -rf /var/lib/apt/lists/*

# This will be mounted so can host different set ups:
RUN mkdir /config
RUN mkdir /data
RUN mkdir /logs
RUN mkdir /app

VOLUME ["/config"]
VOLUME ["/logs"]
VOLUME ["/data"]

EXPOSE 20080

# Set up the stats user
RUN useradd --create-home --home-dir /home/stats stats
WORKDIR /home/stats

USER root

RUN pip install virtualenv

# Install the keys which will allow us to checkout code from bitbucket:
RUN mkdir -p /home/stats/.ssh/authorized_keys
RUN chmod 600 /home/stats/.ssh/authorized_keys
RUN chown -R stats: /home/stats

ADD ./config/dk_config.yaml /home/stats/dk_config.yaml
ADD ./config/setup_env.sh /bin/setup_env.sh
ADD ./config/run_tests.sh /bin/run_tests.sh

ADD ./config/gitrev.sh /bin/gitrev.sh
RUN chmod 755 /bin/gitrev.sh
ADD ./config/runserver.sh /bin/runserver.sh
RUN chmod 755 /bin/runserver.sh
ADD ./config/render_config.py /bin/render_config.py
ADD ./config/server.ini.template /etc/server.ini.template

WORKDIR /home/stats
USER stats

ENV CONFIG /config/server.ini
ENV SERVER /home/stats/pyenv/bin/pserve

ENV influxdb_host localhost
ENV influxdb_port 8086
ENV influxdb_user root
ENV influxdb_password root
ENV influxdb_db stats_dev

# auth details to prevent general access via the web:
ENV access_json /data/access.json

ENV bind_interface 0.0.0.0
ENV bind_port 20080

# Each of the checkouts will  record the URL, Branch and Commit to this file:
RUN echo > /home/stats/commit_versions.txt

# Checkout the third-party open source repos I'm using:
#
WORKDIR /home/stats
RUN git clone https://github.com/oisinmulvihill/evasion-common.git
WORKDIR /home/stats/evasion-common
RUN /bin/gitrev.sh >> /home/stats/commit_versions.txt

WORKDIR /home/stats
RUN git clone https://github.com/oisinmulvihill/docker-testingaids.git
WORKDIR /home/stats/docker-testingaids
RUN /bin/gitrev.sh >> /home/stats/commit_versions.txt

WORKDIR /home/stats
RUN git clone https://github.com/oisinmulvihill/pytest-docker-service-fixtures.git
WORKDIR /home/stats/pytest-docker-service-fixtures
RUN /bin/gitrev.sh >> /home/stats/commit_versions.txt

WORKDIR /home/stats
RUN git clone https://github.com/oisinmulvihill/apiaccesstoken.git
WORKDIR /home/stats/apiaccesstoken
RUN /bin/gitrev.sh >> /home/stats/commit_versions.txt

WORKDIR /home/stats
RUN git clone https://github.com/oisinmulvihill/stats-client.git
WORKDIR /home/stats/stats-client
RUN /bin/gitrev.sh >> /home/stats/commit_versions.txt

WORKDIR /home/stats
RUN git clone https://github.com/oisinmulvihill/stats-service.git
WORKDIR /home/stats/stats-service
RUN /bin/gitrev.sh >> /home/stats/commit_versions.txt

# Ready to run tests:
#
# I need to run as root user to access/write to the /data folder
# in run_tests.sh. I don't like this generally, build for testing I'll let
# this go.
#
USER root
WORKDIR /home/stats
RUN cp /home/stats/commit_versions.txt /app

# Configure the webapp:
RUN /bin/bash /bin/setup_env.sh

RUN /bin/echo -e "Built: $(date +%Y-%m-%d:%H:%M:%S)\n" > /app/BUILD.txt

ENTRYPOINT ["/bin/bash"]

#CMD ["-l", "/bin/runserver.sh"]
