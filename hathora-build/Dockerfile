FROM ubuntu:24.04

RUN echo "get hathora to not use cached layer"

# Dependencies
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN apt-get install -y wget
RUN dpkg --add-architecture i386
RUN mkdir -pm755 /etc/apt/keyrings
RUN wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
RUN wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources
RUN add-apt-repository ppa:dotnet/backports
RUN apt-get update
RUN apt-get install -y wget
RUN apt-get install -y unzip
RUN apt-get install -y dotnet-sdk-6.0 dotnet-sdk-8.0
RUN apt-get install -y --install-recommends winehq-stable
RUN apt-get install -y jq
RUN apt-get install -y net-tools
RUN apt-get install -y xvfb
RUN apt-get install -y sudo
RUN apt-get install -y nftables
RUN apt-get install -y bind9-host

# Add the `user` user and provide permissions
RUN adduser --gecos "" --disabled-password --home /home/user --uid 1001 user
RUN usermod -aG sudo user
RUN chown -R user:user /home/user

RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN mkdir -p /app

RUN chown -R user:user /app

COPY uba-wine64.sh /usr/bin/uba-wine64.sh
RUN chmod +x /usr/bin/uba-wine64.sh

# Switch to the non-root user
USER user

# Horde Agent
COPY --chown=user:group HordeAgent /app/HordeAgent

COPY --chmod=755 startup.sh /app/startup.sh

WORKDIR /app/HordeAgent

WORKDIR /app

ENTRYPOINT [ "/app/startup.sh" ]