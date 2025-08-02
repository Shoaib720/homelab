FROM alpine:3.16 as install
WORKDIR /opt
RUN apk update && apk add wget
RUN wget https://downloads.mysql.com/archives/get/p/3/file/mysql-connector-j-8.0.31.tar.gz
RUN tar -xvzf mysql-connector-j-8.0.31.tar.gz
RUN ls -la


FROM quay.io/keycloak/keycloak:latest as builder

# Enable health and metrics support
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Configure a database vendor
ENV KC_DB=mysql
COPY --from=install /opt/mysql-connector-j-8.0.31/mysql-connector-j-8.0.31.jar /opt/keycloak/providers/mysql-connector-j-8.0.31.jar

WORKDIR /opt/keycloak
# for demonstration purposes only, please make sure to use proper certificates in production instead
RUN keytool -genkeypair -storepass password -storetype PKCS12 -keyalg RSA -keysize 2048 -dname "CN=keycloak.hadiya.ml" -alias server -ext "SAN:c=DNS:localhost,DNS:keycloak.hadiya.ml,DNS:keycloak.hadiya.local,IP:127.0.0.1" -keystore conf/server.keystore
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:latest
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# change these values to point to a running postgres instance
ENV KC_DB=mysql
ENV KC_PROXY=edge
# ENV KC_DB_URL=database.hadiya.ml
# ENV KC_DB_USERNAME=shoaib
# ENV KC_DB_PASSWORD=Shoaib123
# ENV KC_HOSTNAME=keycloak.hadiya.ml
ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start"]