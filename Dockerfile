#
# Based on official https://hub.docker.com/_/python/
#
FROM python:2.7-slim

MAINTAINER Oisin Mulvihill <oisin.mulvihill@gmail.com>

RUN apt-get update -y && apt-get install -y \
        gcc \
        gettext \
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

ADD ./config/dk_config.yaml /home/scp/dk_config.yaml
ADD ./config/setup_env.sh /bin/setup_env.sh
ADD ./config/run_tests.sh /bin/run_tests.sh

ADD ./config/runserver.sh /bin/runserver.sh
ADD ./config/render_config.py /bin/render_config.py
ADD ./config/access.json.jinja /etc/access.json.jinja
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

RUN echo "bitbucket.org,104.192.143.3 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAubiN81eDcafrgMeLzaFPsw2kNvEcqTKl/VqLat/MaB33pZy0y3rJZtnqwR2qOOvbwKZYKiEO1O6VqNEBxKvJJelCq0dTXWT5pbO2gDXC6h6QDXCaHo6pOHGPUy+YBaGQRGuSusMEASYiWunYN0vCAI8QaXnWMXNMdFP3jHAJH0eDsoiGnLPBlBp4TNm6rYI74nMzgz3B9IikW4WVK+dc8KZJZWYjAuORU3jc1c/NPskD2ASinf8v3xnfXeukU0sJ5N6m5E8VLjObPEO+mN2t/FZTMZLiFqPWc/ALSqnMnnhwrNi2rbfg/rd/IpL8Le3pSBne8+seeFVBoGqzHM9yXw==" >> ~/.ssh/known_hosts

# Each of the checkouts will  record the URL, Branch and Commit to this file:
RUN echo > /home/stats/commit_versions.txt

# Checkout the third-party open source repos I'm using:
#
WORKDIR /home/stats
RUN git clone https://github.com/oisinmulvihill/evasion-common.git
WORKDIR /home/evasion-common
RUN echo "project_url:$(git config --get remote.origin.url),branch:$(git rev-parse --abbrev-ref HEAD),commit:$(git rev-parse --verify $(git rev-parse --abbrev-ref HEAD))" >> /home/stats/commit_versions.txt

WORKDIR /home/stats
RUN git clone https://github.com/oisinmulvihill/pytest-docker-service-fixtures.git
WORKDIR /home/pytest-docker-service-fixtures
RUN echo "project_url:$(git config --get remote.origin.url),branch:$(git rev-parse --abbrev-ref HEAD),commit:$(git rev-parse --verify $(git rev-parse --abbrev-ref HEAD))" >> /home/stats/commit_versions.txt

WORKDIR /home/stats
RUN git clone https://github.com/oisinmulvihill/apiaccesstoken.git
WORKDIR /home/apiaccesstoken
RUN echo "project_url:$(git config --get remote.origin.url),branch:$(git rev-parse --abbrev-ref HEAD),commit:$(git rev-parse --verify $(git rev-parse --abbrev-ref HEAD))" >> /home/stats/commit_versions.txt

WORKDIR /home/stats
RUN git clone https://github.com/oisinmulvihill/stats-client.git
WORKDIR /home/stats-client
RUN echo "project_url:$(git config --get remote.origin.url),branch:$(git rev-parse --abbrev-ref HEAD),commit:$(git rev-parse --verify $(git rev-parse --abbrev-ref HEAD))" >> /home/stats/commit_versions.txt

WORKDIR /home/stats
RUN git clone https://github.com/oisinmulvihill/stats-service.git
WORKDIR /home/stats-service
RUN echo "project_url:$(git config --get remote.origin.url),branch:$(git rev-parse --abbrev-ref HEAD),commit:$(git rev-parse --verify $(git rev-parse --abbrev-ref HEAD))" >> /home/stats/commit_versions.txt

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

CMD ["-l", "/bin/runserver.sh"]
