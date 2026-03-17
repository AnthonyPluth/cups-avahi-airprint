FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# Must register i386 BEFORE the first apt-get update
RUN dpkg --add-architecture i386

# Add OpenPrinting PPA for newer CUPS
RUN apt-get update && \
    apt-get install -y \
      software-properties-common \
      gnupg \
      ca-certificates && \
    add-apt-repository ppa:openprinting/stable && \
    apt-get update

# Now update and install everything in one shot
RUN apt-get update && apt-get install -y \
      cups \
      libcups2 \
      cups-pdf \
      cups-client \
      cups-filters \
      libcups2-dev \
      ghostscript \
      hplip \
      avahi-daemon \
      qpdf \
      inotify-tools \
      python3 \
      python3-dev \
      build-essential \
      wget \
      rsync \
      python3-cups \
      perl \
      git \
      cmake \
      unzip \
      pkg-config \
      iproute2 \
      autoconf \
      automake \
      libtool \
      libreadline-dev \
      libstdc++6:i386 \
      libcupsimage2-dev \
      libcupsimage2:i386 \
      libcups2:i386 \
      libc6:i386 \
      python3-lxml \
    && rm -rf /var/lib/apt/lists/*

# Build and install brlaser from source
RUN git clone https://github.com/pdewacht/brlaser.git && \
    cd brlaser && \
    cmake . && \
    make && \
    make install && \
    cd .. && \
    rm -rf brlaser

# Build and install gutenprint from source
RUN wget -O gutenprint-5.3.5.tar.xz https://sourceforge.net/projects/gimp-print/files/gutenprint-5.3/5.3.5/gutenprint-5.3.5.tar.xz/download && \
    tar -xJf gutenprint-5.3.5.tar.xz && \
    cd gutenprint-5.3.5 && \
    find src/testpattern -type f -exec sed -i 's/\bPAGESIZE\b/GPT_PAGESIZE/g' {} + && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf gutenprint-5.3.5 gutenprint-5.3.5.tar.xz && \
    sed -i '1s|.*|#!/usr/bin/perl|' /usr/sbin/cups-genppdupdate

# Download and install the Xerox Phaser 6000/6010 driver
RUN wget -O /tmp/xerox-phaser-6000-6010.zip \
      "https://web.archive.org/web/20220705230937if_/https://download.support.xerox.com/pub/drivers/6000/drivers/linux/en_GB/6000_6010_deb_1.01_20110210.zip" && \
    unzip /tmp/xerox-phaser-6000-6010.zip -d /tmp/xerox && \
    cd /tmp/xerox/deb_1.01_20110210 && \
    ar x xerox-phaser-6000-6010_1.0-1_i386.deb && \
    mkdir -p /usr/lib/cups/filter \
             /usr/share/cups/Xerox/dlut \
             /usr/share/ppd/Xerox \
             /usr/share/doc/xerox-phaser-6000-6010 && \
    tar xzf data.tar.gz -C / && \
    chmod 755 /usr/lib/cups/filter/xrhkaz* && \
    cd / && rm -rf /tmp/xerox /tmp/xerox-phaser-6000-6010.zip

# Baked-in config file changes
RUN sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf && \
    sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf && \
    sed -i 's/IdleExitTimeout/#IdleExitTimeout/' /etc/cups/cupsd.conf || true && \
    sed -i 's/<Location \/>/<Location \/>\n  Allow All/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin>/<Location \/admin>\n  Allow All\n  Require user @SYSTEM/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin\/conf>/<Location \/admin\/conf>\n  Allow All/' /etc/cups/cupsd.conf && \
    sed -i 's/.*enable\-dbus=.*/enable\-dbus\=no/' /etc/avahi/avahi-daemon.conf && \
    echo "ServerAlias *" >> /etc/cups/cupsd.conf && \
    echo "DefaultEncryption Never" >> /etc/cups/cupsd.conf && \
    echo "ReadyPaperSizes A4,TA4,4X6FULL,T4X6FULL,2L,T2L,A6,A5,B5,L,TL,INDEX5,8x10,T8x10,4X7,T4X7,Postcard,TPostcard,ENV10,EnvDL,ENVC6,Letter,Legal" >> /etc/cups/cupsd.conf && \
    echo "DefaultPaperSize Letter" >> /etc/cups/cupsd.conf && \
    echo "pdftops-renderer ghostscript" >> /etc/cups/cupsd.conf

EXPOSE 631

VOLUME /config
VOLUME /services

ADD root /
RUN chmod +x /root/*

CMD ["/root/run_cups.sh"]
