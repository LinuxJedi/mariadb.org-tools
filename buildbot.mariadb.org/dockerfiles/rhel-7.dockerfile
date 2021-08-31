#
# Builbot worker for building MariaDB
#
# Provides a base RHEL-7 image with latest buildbot worker installed
# and MariaDB build dependencies

FROM       registry.access.redhat.com/rhel7
LABEL maintainer="MariaDB Buildbot maintainers"

RUN subscription-manager register --username %s --password %s --auto-attach

RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

RUN subscription-manager repos --enable "rhel-*-optional-rpms" --enable "rhel-*-extras-rpms"  --enable "rhel-ha-for-rhel-*-server-rpms"

RUN sed -i '/baseurl/s/^#//g' /etc/yum.repos.d/epel.repo
RUN sed -i '/metalink/s/^/#/g' /etc/yum.repos.d/epel.repo

# Install updates and required packages
RUN yum -y install epel-release && \
    yum -y upgrade && \
    yum -y groupinstall 'Development Tools' && \
    yum -y install git ccache subversion \
    python-devel libffi-devel openssl-devel jemalloc-devel \
    python-pip redhat-rpm-config curl wget && \
    # install MariaDB dependencies
    yum-builddep -y mariadb-server

# Create buildbot user
RUN useradd -ms /bin/bash buildbot && \
    mkdir /buildbot && \
    chown -R buildbot /buildbot && \
    curl -o /buildbot/buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac
WORKDIR /buildbot

# upgrade pip and install buildbot
RUN pip install -U pip virtualenv && \
    pip install --upgrade setuptools && \
    pip install buildbot-worker && \
    pip --no-cache-dir install 'twisted[tls]'

# Test runs produce a great quantity of dead grandchild processes.  In a
# non-docker environment, these are automatically reaped by init (process 1),
# so we need to simulate that here.  See https://github.com/Yelp/dumb-init
RUN curl -Lo /tmp/dumb.rpm https://cbs.centos.org/kojifiles/packages/dumb-init/1.1.3/17.el7/x86_64/dumb-init-1.1.3-17.el7.x86_64.rpm && yum -y localinstall /tmp/dumb.rpm

ENV CRYPTOGRAPHY_ALLOW_OPENSSL_102=1

RUN wget https://cmake.org/files/v3.19/cmake-3.19.0-Linux-x86_64.sh
RUN mkdir -p /opt/cmake
RUN sh cmake-3.19.0-Linux-x86_64.sh --prefix=/opt/cmake --skip-license
RUN ln -sf /opt/cmake/bin/cmake /usr/local/bin/cmake

RUN yum -y install cracklib cracklib-dicts cracklib-devel boost-devel curl-devel libxml2-devel lz4-devel snappy-devel check-devel scons

RUN subscription-manager unregister

USER buildbot
CMD ["dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
