FROM ghcr.io/epicgames/horde-server:5.5

RUN apt-get update
RUN apt-get install -y lsb-release curl gpg
RUN curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
RUN chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list
RUN apt-get update
RUN apt-get install -y redis supervisor

# Create supervisor configuration
RUN mkdir -p /etc/supervisor/conf.d
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY redis.conf /etc/supervisor/conf.d/redis.conf

ENV Horde__RedisConnectionConfig="localhost:6379"
ENV Horde__HttpPort="13340"
ENV Horde__Http2Port="13342"

# Use supervisor as the entrypoint
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]