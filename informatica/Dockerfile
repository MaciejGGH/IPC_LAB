# Stage: ipc:base-os
#
# Operating system with base libraries required to install Informatica Server
FROM centos:8 as base-os

RUN groupadd -r -g 6005 ipc_lab && useradd -r -g ipc_lab -m -u 6005 ipc_lab

RUN echo "install_weak_deps=False" >> /etc/dnf/dnf.conf \
    && dnf install -y glibc-langpack-en e2fsprogs-libs \
        keyutils-libs libselinux libsepol libidn libnsl \
        unzip which ncurses-libs ncurses-compat-libs wget \
    && dnf upgrade -y \
    && dnf clean all \
    && rm -rf /var/cache/dnf



# Stage: ipc:final-os
#
# base-os with all additional libraries required to run Informatica (ie. database client)
FROM base-os as final-os

RUN wget -P /tmp/oracle https://download.oracle.com/otn_software/linux/instantclient/19600/oracle-instantclient19.6-basic-19.6.0.0.0-1.x86_64.rpm \
    && wget -P /tmp/oracle https://download.oracle.com/otn_software/linux/instantclient/19600/oracle-instantclient19.6-sqlplus-19.6.0.0.0-1.x86_64.rpm \
    && dnf install -y /tmp/oracle/* \
    && dnf clean all \
    && rm -rf /var/cache/dnf /tmp/oracle



# Stage: installer
FROM base-os as installer

ENV SOFTWARE_DIR=/tmp/software \
    AUTO_INSTALL="autoInstall.sh" \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN mkdir -p /opt/Informatica && chown -R ipc_lab:ipc_lab /opt/Informatica
COPY --chown=ipc_lab:ipc_lab --from=ipc_lab/ipc:software ${SOFTWARE_DIR} ${SOFTWARE_DIR}



# Stage: installed
FROM installer as installed
USER ipc_lab
COPY ${AUTO_INSTALL} /tmp
RUN /tmp/${AUTO_INSTALL} && rm -rf ${SOFTWARE_DIR}



# Stage: ipc:final
FROM final-os as final
USER ipc_lab
COPY --chown=ipc_lab:ipc_lab --from=installed /opt/Informatica /opt/Informatica

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    ORACLE_HOME=/usr/lib/oracle/19.6/client64 \
    NLS_LANG=AMERICAN_AMERICA.AL32UTF8 \
    INFA_HOME=/opt/Informatica

ENV INFA_DOMAINS_FILE=$INFA_HOME/domains.infa \
    IFCONTENTMASTER_HOME=$INFA_HOME/DataTransformation/ \
    ODBCHOME=$INFA_HOME/ODBC7.1 \
    ODBCINI=$INFA_HOME/ODBC7.1/odbc.ini

ENV LD_LIBRARY_PATH=$INFA_HOME/server/bin:$ODBCHOME/lib:$INFA_HOME/services/shared/bin:$ORACLE_HOME/lib:/usr/lib:/usr/lib64

COPY ./entrypoint.sh /usr/local/bin
WORKDIR /home/ipc_lab
 HEALTHCHECK --interval=1m --start-period=3m \
    CMD $INFA_HOME/isp/bin/infacmd.sh ping -dn $IPC_DOMAIN_NAME >/dev/null || exit 1
 CMD ["/usr/local/bin/entrypoint.sh"]