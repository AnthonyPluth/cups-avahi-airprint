FROM ubuntu:22.04

# Must register i386 BEFORE the first apt-get update
RUN dpkg --add-architecture i386

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
      libcups2:i386 \
      libcupsimage2:i386 \
      libc6:i386 \
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
    dpkg -i /tmp/xerox/xerox-phaser-6000-6010_1.0-1_i386.deb && \
    rm -rf /tmp/xerox /tmp/xerox-phaser-6000-6010.zip

# Baked-in config file changes
RUN sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf && \
    sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf && \
    sed -i 's/IdleExitTimeout/#IdleExitTimeout/' /etc/cups/cupsd.
