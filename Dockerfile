#############################################################################
# Stage 1 - Build custom event-store input and output logstash java plugins #
#############################################################################

ARG LS_VERSION=8.4.3
FROM logstash:${LS_VERSION} AS build

ARG LS_VERSION
ARG CS_OUTPUT_VERSION=1.2.2
ARG CS_INPUT_VERSION=1.2.3
ARG ELAPSED_VERSION=1.2.0

ENV JAVA_HOME /usr/share/logstash/jdk
ENV PATH $PATH:$JAVA_HOME
ENV SRC /tmp/src
ENV LS_PLUGINS /tmp/logstash-plugins
ENV LS_HOME ${SRC}/logstash
ENV LOGSTASH_SOURCE 1
ENV LOGSTASH_PATH ${LS_HOME}
ENV OSS true

USER root

RUN apt update && apt install -y git

# Get logstash source
RUN mkdir -p ${SRC} ${LS_PLUGINS}
RUN git clone --branch v${LS_VERSION} --single-branch https://github.com/elastic/logstash.git ${LS_HOME}
WORKDIR ${LS_HOME}

# Build logstash-core
RUN chmod +x ./gradlew && ./gradlew clean && ./gradlew --no-daemon assemble && ./gradlew jar && find ${LS_HOME}/logstash-core -name logstash-core.jar

# Get logstash-output-cs-eventstore source
RUN git clone --branch ${CS_OUTPUT_VERSION} --single-branch https://github.com/VasilijP/logstash-output-cs-eventstore.git ${SRC}/logstash-output-cs-eventstore

# Build logstash-output-cs-eventstore source
WORKDIR ${SRC}/logstash-output-cs-eventstore
RUN echo "LOGSTASH_CORE_PATH=${LS_HOME}/logstash-core" > ./gradle.properties
RUN chmod +x ./gradlew && ./gradlew clean && ./gradlew --no-daemon gem && cp *.gem ${LS_PLUGINS}/

# Get logstash-input-cs-eventstore source
RUN git clone --branch ${CS_INPUT_VERSION} --single-branch https://github.com/VasilijP/logstash-input-cs-eventstore.git ${SRC}/logstash-input-cs-eventstore

# Build logstash-input-cs-eventstore source
WORKDIR ${SRC}/logstash-input-cs-eventstore
RUN echo "LOGSTASH_CORE_PATH=${LS_HOME}/logstash-core" > ./gradle.properties
RUN chmod +x ./gradlew && ./gradlew clean && ./gradlew --no-daemon gem && cp *.gem ${LS_PLUGINS}/

# Get logstash-filter-elapsed source
RUN git clone --branch ${ELAPSED_VERSION} --single-branch https://github.com/VasilijP/logstash-filter-elapsed.git ${SRC}/logstash-filter-elapsed

# TODO: replace with https://www.elastic.co/guide/en/logstash/current/plugins-filters-elapsed.html && pipeline.workers=1
# Build logstash-filter-elapsed source
WORKDIR ${SRC}/logstash-filter-elapsed
RUN echo "LOGSTASH_CORE_PATH=${LS_HOME}/logstash-core" > ./gradle.properties
RUN chmod +x ./gradlew && ./gradlew clean && ./gradlew --no-daemon gem && cp *.gem ${LS_PLUGINS}/

RUN ls -la ${LS_PLUGINS}/*.gem


######################################
# Stage 2 - base image for pipelines #
######################################

FROM logstash:${LS_VERSION}

ENV LS_PLUGINS /tmp/logstash-plugins
ENV LS_HOME /usr/share/logstash

# Run logstash as interactive process
USER root
RUN sed -i -e "s|exec logstash|exec logstash -f ${LS_HOME}/pipeline/logstash.conf|" /usr/local/bin/docker-entrypoint
USER 1000

RUN mkdir -p ${LS_PLUGINS}
COPY --from=build ${LS_PLUGINS}/*.gem ${LS_PLUGINS}
RUN ls -la ${LS_PLUGINS}

WORKDIR ${LS_HOME}/bin

# Add custom logstash java plugins
RUN ls -1 ${LS_PLUGINS}/*.gem | xargs ./logstash-plugin install --no-verify --local	
RUN rm -rf ${LS_PLUGINS}

# Add standard logstash plugins
RUN ./logstash-plugin install logstash-filter-alter logstash-filter-json_encode logstash-filter-elapsed logstash-output-gelf

# Add mssql-jdbc driver
ADD --chown=logstash:root https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/11.2.1.jre17/mssql-jdbc-11.2.1.jre17.jar ${LS_HOME}/logstash-core/lib/jars/

RUN ls -laR ${LS_HOME}/logstash-core/lib/jars

# Open ports (inhereted from the base image): 9600, 5044

# In derived images:
# * Mount-bind the pipeline definition file to /usr/share/logstash/pipeline/logstash.conf
# * Configure logstash using environment variables: https://github.com/elastic/logstash-docker/blob/master/build/logstash/env2yaml/env2yaml.go#L50-L108
