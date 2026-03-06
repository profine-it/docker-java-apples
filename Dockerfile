FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

# Use Yandex mirror for apt
RUN echo "deb http://mirror.yandex.ru/ubuntu/ bionic main restricted universe multiverse\n\
deb http://mirror.yandex.ru/ubuntu/ bionic-updates main restricted universe multiverse\n\
deb http://mirror.yandex.ru/ubuntu/ bionic-security main restricted universe multiverse" > /etc/apt/sources.list \
    && apt-get update && apt-get install -y \
    xfce4 xfce4-goodies xfce4-terminal tightvncserver wget curl gnupg2 sudo \
    openjdk-8-jre icedtea-netx \
    libasound2 libgtk2.0-0 libdbus-glib-1-2 libxt6 libxss1 libnss3 libxrender1 libxcomposite1 \
    libxrandr2 libxi6 libxcursor1 libxinerama1 xvfb gtk2-engines-pixbuf autocutsel \
    alsa-utils pulseaudio \
    build-essential autoconf automake libtool pkg-config \
    && apt-get clean

RUN apt-get purge -y gvfs gvfs-backends gvfs-daemons

# Create a user
RUN useradd -s /bin/bash -m docker && echo "docker:docker" | chpasswd && adduser docker sudo

# Setup Java env
RUN echo "PATH=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/tmp/jdk1.8.0_202/bin/\"" > /etc/environment
RUN echo "MOZ_PLUGIN_PATH=/home/docker/.mozilla/plugins" >> /etc/environment

RUN mkdir -p /home/docker/.java/deployment /home/docker/.java/deployment/security/
COPY java_config/deployment.properties /home/docker/.java/deployment/
COPY java_config/exception.sites /home/docker/.java/deployment/security/

RUN touch /home/docker/.Xauthority && chown docker:docker /home/docker/.Xauthority

# Create Firefox shotcut
RUN mkdir /home/docker/.icons/ /home/docker/Desktop
COPY firefox_theme/firefox.desktop /home/docker/Desktop
COPY firefox_theme/firefox.png /home/docker/.icons/
RUN chown -R docker:docker /home/docker/ \
    && chmod +x /home/docker/Desktop/firefox.desktop

USER docker
WORKDIR /home/docker

# Set up VNC
RUN mkdir -p /home/docker/.vnc && \
    echo "docker" | vncpasswd -f > /home/docker/.vnc/passwd && \
    chmod 600 /home/docker/.vnc/passwd && \
    echo '#!/bin/sh\nautocutsel -fork &' > /home/docker/.vnc/xstartup && \
    echo '\nstartxfce4 &' >> /home/docker/.vnc/xstartup && \
    chmod +x /home/docker/.vnc/xstartup

# Download and install Firefox 45 ESR from Mozilla archive (ftp.mozilla.org often fails in Docker)
RUN mkdir -p /home/docker/firefox45 && \
    wget -q --no-check-certificate --tries=3 -O /tmp/firefox-45.9.0esr.tar.bz2 \
        https://archive.mozilla.org/pub/firefox/releases/45.9.0esr/linux-x86_64/en-US/firefox-45.9.0esr.tar.bz2 && \
    tar -xjf /tmp/firefox-45.9.0esr.tar.bz2 -C /home/docker/firefox45 --strip-components=1 && \
    rm /tmp/firefox-45.9.0esr.tar.bz2

# Set USER env var for VNC
ENV USER=docker

# Set PATH to use our Firefox build
ENV PATH="/home/docker/firefox45:${PATH}"

# Download and extract Oracle JRE inside image
RUN wget -q --no-check-certificate --tries=3 -O /tmp/jdk-8u202-linux-x64.tar.gz https://mirrors.huaweicloud.com/java/jdk/8u202-b08/jdk-8u202-linux-x64.tar.gz \
    && echo "0029351f7a946f6c05b582100c7d45b7  /tmp/jdk-8u202-linux-x64.tar.gz" | md5sum -c - \
    && tar -xzf /tmp/jdk-8u202-linux-x64.tar.gz -C /tmp \
    && rm /tmp/jdk-8u202-linux-x64.tar.gz

ENV JAVA_HOME=/tmp/jdk1.8.0_202/jre/
ENV PATH=$JAVA_HOME/bin:$PATH

# Create plugin directory and symlink
RUN mkdir -p /home/docker/.mozilla/plugins \
    && ln -s $JAVA_HOME/lib/amd64/libnpjp2.so /home/docker/.mozilla/plugins/libnpjp2.so

RUN echo 'ulimit -c unlimited' >> /home/docker/.bashrc

# Expose VNC port
EXPOSE 5901

# Start VNC server safely and keep container alive
CMD bash -c "rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 && vncserver :1 -geometry 1280x800 -depth 24 && tail -F /home/docker/.vnc/*.log"
