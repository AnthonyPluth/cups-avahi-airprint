FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# Must register i386 BEFORE the first apt-get update
RUN dpkg --add-architecture i386

# Now update and install everything in one shot
RUN apt-get update && apt-get install -y \
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
      libpaper-dev \
      libavahi-client-dev \
      libgnutls28-dev \
      libssl-dev \
      libpam0g-dev \
      zlib1g-dev \
      libusb-1.0-0-dev \
    && rm -rf /var/lib/apt/lists/*

# Build and install CUPS 2.4.16 from source
RUN wget https://github.com/OpenPrinting/cups/releases/download/v2.4.16/cups-2.4.16-source.tar.gz && \
    tar xzf cups-2.4.16-source.tar.gz && \
    cd cups-2.4.16 && \
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
                --libdir=/usr/lib/x86_64-linux-gnu && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd .. && \
    rm -rf cups-2.4.16 cups-2.4.16-source.tar.gz

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
RUN cat > /etc/cups/cupsd.conf <<'EOF'
LogLevel warn
MaxLogSize 0
ErrorPolicy retry-job

Listen 0.0.0.0:631
Browsing On
BrowseLocalProtocols dnssd

DefaultAuthType Basic
WebInterface Yes
ServerAlias *
DefaultEncryption Never

ReadyPaperSizes A4,TA4,4X6FULL,T4X6FULL,2L,T2L,A6,A5,B5,L,TL,INDEX5,8x10,T8x10,4X7,T4X7,Postcard,TPostcard,ENV10,EnvDL,ENVC6,Letter,Legal
DefaultPaperSize Letter
pdftops-renderer ghostscript

<Location />
  Order allow,deny
  Allow All
</Location>

<Location /admin>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow All
</Location>

<Location /admin/conf>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow All
</Location>

<Location /admin/log>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
</Location>

<Policy default>
  JobPrivateAccess default
  JobPrivateValues default
  SubscriptionPrivateAccess default
  SubscriptionPrivateValues default

  <Limit Create-Job Print-Job Print-URI Validate-Job>
    Order deny,allow
  </Limit>

  <Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Jobs Set-Job-Attributes Create-Job-Subscription Renew-Subscription Cancel-Subscription Get-Notifications Reprocess-Job Cancel-Current-Job Suspend-Current-Job Resume-Job Cancel-My-Jobs Close-Job CUPS-Move-Job>
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit CUPS-Get-Document>
    AuthType Default
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit CUPS-Add-Modify-Printer CUPS-Delete-Printer CUPS-Add-Modify-Class CUPS-Delete-Class CUPS-Set-Default CUPS-Get-Devices>
    AuthType Default
    Require user @SYSTEM
    Order deny,allow
  </Limit>

  <Limit Pause-Printer Resume-Printer Enable-Printer Disable-Printer Pause-Printer-After-Current-Job Hold-New-Jobs Release-Held-New-Jobs Deactivate-Printer Activate-Printer Restart-Printer Shutdown-Printer Startup-Printer Promote-Job Schedule-Job-After Cancel-Jobs CUPS-Accept-Jobs CUPS-Reject-Jobs>
    AuthType Default
    Require user @SYSTEM
    Order deny,allow
  </Limit>

  <Limit Cancel-Job CUPS-Authenticate-Job>
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit All>
    Order deny,allow
  </Limit>
</Policy>
EOF
RUN sed -i 's/.*enable\-dbus=.*/enable\-dbus\=no/' /etc/avahi/avahi-daemon.conf

EXPOSE 631

VOLUME /config
VOLUME /services

ADD root /
RUN chmod +x /root/*

CMD ["/root/run_cups.sh"]
