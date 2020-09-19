FROM azul/zulu-openjdk-alpine:8-jre

ENV ACTIVEMQ_VERSION=5.16.0
ENV ACTIVEMQ_HOME=/opt/activemq

ENV ACTIVEMQ_SHA512=999928176e57b0805e8a53834e7f4eb648baf271a0c60de31ebd95fa63f2b089aa41c2ef7353790835e2e8cc39c4b778f535b38e6dc0c67a79c3c1da335c4a0a 

RUN addgroup -g 9999 -S activemq \
    && adduser -u 9999 -S -D -G activemq -H -h ${ACTIVEMQ_HOME} activemq \
    && mkdir -p ${ACTIVEMQ_HOME} 


RUN wget -O apache-activemq.tar.gz "https://downloads.apache.org/activemq/${ACTIVEMQ_VERSION}/apache-activemq-${ACTIVEMQ_VERSION}-bin.tar.gz" \
    && echo "${ACTIVEMQ_SHA512} *apache-activemq.tar.gz" | sha512sum -c - \
    && tar -xzf apache-activemq.tar.gz -C ${ACTIVEMQ_HOME} --strip-components 1 \
    && rm apache-activemq.tar.gz \
    && chown -R activemq:activemq ${ACTIVEMQ_HOME}

ENV PATH=${ACTIVEMQ_HOME}/bin:${PATH}

USER activemq
WORKDIR ${ACTIVEMQ_HOME}

VOLUME ${ACTIVEMQ_HOME}/conf
VOLUME ${ACTIVEMQ_HOME}/data

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 8161 61616

CMD ["activemq", "console"]