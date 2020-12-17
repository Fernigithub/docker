FROM tomcat:jdk11-openjdk-slim

ARG GEOSERVER_VERSION=2.18.1

ARG WAR_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GEOSERVER_VERSION}/geoserver-${GEOSERVER_VERSION}-war.zip
ARG STABLE_PLUGIN_URL=https://sourceforge.net/projects/geoserver/files/GeoServer/${GEOSERVER_VERSION}/extensions

ARG CORS_ENABLED=false
ARG CORS_ALLOWED_ORIGINS=*
ARG CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,HEAD,OPTIONS
ARG CORS_ALLOWED_HEADERS=*

# environment variables
ENV GEOSERVER_VERSION=${GEOSERVER_VERSION} \
    GEOSERVER_DIR=${CATALINA_HOME}/webapps/geoserver \
    STABLE_PLUGIN_URL=${STABLE_PLUGIN_URL} \
    INITIAL_MEMORY=2G \
    MAXIMUM_MEMORY=4G \
    JAIEXT_ENABLED=true \
    DOWNLOAD_EXTENSIONS=false \
    STABLE_EXTENSIONS='' \
    DEBIAN_FRONTEND=noninteractive \
    ADDITIONAL_LIBS_DIR=/opt/additional_libs/ \
    GEOSERVER_DATA_DIR=/opt/geoserver_data/ \
    GEOWEBCACHE_CACHE_DIR=/opt/geowebcache_data/

RUN mkdir ${ADDITIONAL_LIBS_DIR} ${GEOSERVER_DATA_DIR} ${GEOWEBCACHE_CACHE_DIR}

# install required dependencies
# also clear the initial webapps
RUN apt update && \
    apt install -y curl wget openssl zip fontconfig libfreetype6 && \
    rm -rf ${CATALINA_HOME}/webapps/*

# install geoserver
RUN wget --progress=bar:force:noscroll -c --no-check-certificate "${WAR_URL}" -O /tmp/geoserver.zip && \
    unzip /tmp/geoserver.zip geoserver.war -d ${CATALINA_HOME}/webapps && \
    mkdir -p ${GEOSERVER_DIR} && \
    unzip -q ${CATALINA_HOME}/webapps/geoserver.war -d ${GEOSERVER_DIR} && \
    rm ${CATALINA_HOME}/webapps/geoserver.war

# configure CORS (inspired by https://github.com/oscarfonts/docker-geoserver)
RUN if [ "$CORS_ENABLED" = "true" ]; then \
      sed -i "\:</web-app>:i\ \
      <filter>\n\ \
        <filter-name>CorsFilter</filter-name>\n\ \
        <filter-class>org.apache.catalina.filters.CorsFilter</filter-class>\n\ \
        <init-param>\n\ \
            <param-name>cors.allowed.origins</param-name>\n\ \
            <param-value>${CORS_ALLOWED_ORIGINS}</param-value>\n\ \
        </init-param>\n\ \
        <init-param>\n\ \
            <param-name>cors.allowed.methods</param-name>\n\ \
            <param-value>${CORS_ALLOWED_METHODS}</param-value>\n\ \
        </init-param>\n\ \
        <init-param>\n\ \
          <param-name>cors.allowed.headers</param-name>\n\ \
          <param-value>${CORS_ALLOWED_HEADERS}</param-value>\n\ \
        </init-param>\n\ \
      </filter>\n\ \
      <filter-mapping>\n\ \
        <filter-name>CorsFilter</filter-name>\n\ \
        <url-pattern>/*</url-pattern>\n\ \
      </filter-mapping>" "${GEOSERVER_DIR}/WEB-INF/web.xml"; \
    fi

# copy scripts
COPY scripts /scripts
RUN chmod +x /scripts/*.sh

# cleanup
RUN apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR ${CATALINA_HOME}

CMD ["/bin/sh", "/scripts/entrypoint.sh"]
