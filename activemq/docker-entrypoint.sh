#!/usr/bin/env sh

main() {

    if [ -n "${ACTIVEQM_HOST}" ]; then
        echo "Setting up correct hostname"
        sed -i -e "s|127.0.0.1|$ACTIVEQM_HOST|g" "${ACTIVEMQ_HOME}/conf/jetty.xml"
    fi

    exec "$@"
}

main "$@"