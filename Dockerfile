FROM redis/redis-stack-server:7.0.0-edge AS redis-stack-server
FROM redis:7.0.5-bullseye

LABEL maintainer="Johan Andersson <Grokzen@gmail.com>"

# Some Environment Variables
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -yqq \
      net-tools supervisor ruby rubygems locales gettext-base wget gcc make g++ build-essential libc6-dev tcl && \
    apt-get clean -yqq

# # Ensure UTF-8 lang and locale
RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

# Necessary for gem installs due to SHA1 being weak and old cert being revoked
ENV SSL_CERT_FILE=/usr/local/etc/openssl/cert.pem

RUN gem install redis -v 4.1.3

# This will always build the latest release/commit in the 6.0 branch
ARG redis_version=7.0

RUN wget -qO redis.tar.gz https://github.com/redis/redis/tarball/${redis_version} \
    && tar xfz redis.tar.gz -C / \
    && mv /redis-* /redis

RUN (cd /redis && make)

RUN mkdir /redis-conf && mkdir /redis-data

COPY redis-cluster.tmpl /redis-conf/redis-cluster.tmpl
COPY redis.tmpl         /redis-conf/redis.tmpl
COPY sentinel.tmpl      /redis-conf/sentinel.tmpl

# Add startup script
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Add script that generates supervisor conf file based on environment variables
COPY generate-supervisor-conf.sh /generate-supervisor-conf.sh

RUN chmod 755 /docker-entrypoint.sh

COPY --from=redis-stack-server /opt/redis-stack/lib/redisbloom.so /bin/redisbloom.so
COPY --from=redis-stack-server /opt/redis-stack/lib/redisearch.so /bin/redisearch.so
COPY --from=redis-stack-server /opt/redis-stack/lib/redisgraph.so /bin/redisgraph.so
COPY --from=redis-stack-server /opt/redis-stack/lib/redistimeseries.so /bin/redistimeseries.so
COPY --from=redis-stack-server /opt/redis-stack/lib/rejson.so /bin/rejson.so

EXPOSE 7000 7001 7002 7003 7004 7005 7006 7007 5000 5001 5002

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["redis-cluster"]
