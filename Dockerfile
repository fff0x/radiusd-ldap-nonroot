##
## MAIN
##

FROM alpine:3.12.1

##
## MAIN
##

LABEL maintainer="Max Buelte <ff0x@tif.cat>"
LABEL name="radiusd-ldap-nonroot" version="0.0.5"
LABEL description="Alpine Linux based container image for Kubernetes running freeradius with ldap plugin prepared for Google Workspace Secure LDAP"

##
## CONFIGURATION
##

ARG ARCH
ENV DAEMON_USR="radius" \
    DAEMON_GRP="radius" \
    DAEMON_GID=10000 \
    DAEMON_UID=10000

##
## PREPARATION
##

RUN addgroup -S -g "$DAEMON_GID" "$DAEMON_GRP" && \
    adduser -S -u "$DAEMON_UID" -h "/var/lib/${DAEMON_USR}" -s /sbin/nologin -G "$DAEMON_GRP" -D "$DAEMON_USR"

RUN apk upgrade --update --no-cache && \
    apk add --no-cache curl tzdata && \
    rm -rf /tmp/* /var/cache/apk/* /etc/localtime && \
    cp /usr/share/zoneinfo/Europe/Berlin /etc/localtime && \
    echo "Europe/Berlin" > /etc/timezone && \
    mkdir -p "/var/run/${DAEMON_USR}/" && \
    chown -R "${DAEMON_USR}":"${DAEMON_GRP}" "/var/run/${DAEMON_USR}"

RUN apk add --update --no-cache rsync freeradius freeradius-ldap && \
    chown -R "${DAEMON_USR}":"${DAEMON_GRP}" /etc/raddb

COPY ep /ep
COPY --chown=${DAEMON_USR}:${DAEMON_GRP} conf/default /etc/raddb/sites-available/default
COPY --chown=${DAEMON_USR}:${DAEMON_GRP} conf/ldap /etc/raddb/mods-available/ldap
COPY --chown=${DAEMON_USR}:${DAEMON_GRP} conf/clients.conf /etc/raddb/clients.conf
COPY --chown=${DAEMON_USR}:${DAEMON_GRP} conf/proxy.conf /etc/raddb/proxy.conf

##
## ENVIRONMENT
##

USER "${DAEMON_USR}"
WORKDIR "/var/lib/${DAEMON_USR}"

##
## PORTS
##

EXPOSE 1812/udp

##
## INIT
##

# Radiusd args:
# -f  Run as a foreground process, not a daemon.
# -X  Turn on full debugging (similar to -tfxxl stdout).

ENTRYPOINT [ "/ep" ]
CMD ["radiusd", "-f"]
