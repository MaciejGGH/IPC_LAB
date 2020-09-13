FROM oraclelinux:7-slim as base-os

ENV ORACLE_BASE=/opt/oracle \
    ORACLE_HOME=/opt/oracle/product/12.2.0.1/dbhome_1 \
    ORACLE_SID="ORACDB" \
    SOFTWARE_DIR=/tmp/software \
    ZIP_FILE="linuxx64_12201_database.zip"


ENV PATH=$ORACLE_HOME/bin:${PATH}

RUN yum install -y oracle-database-server-12cR2-preinstall openssl unzip \
        https://yum.oracle.com/repo/OracleLinux/OL7/addons/x86_64/getPackage/pigz-2.3.4-1.el7.x86_64.rpm \
    && rm -rf /var/cache/yum

RUN mkdir -p ${ORACLE_HOME} \
    && chown -R oracle:dba ${ORACLE_BASE}



#######################################
#   Builder layer
#######################################
FROM base-os as builder
COPY --chown=oracle:oracle --from=ipc_lab/oracle-software:12.2.0.1 ${SOFTWARE_DIR} ${SOFTWARE_DIR}
USER oracle

RUN cd ${SOFTWARE_DIR} \
    && unzip -q ${ZIP_FILE} \
    && rm ${ZIP_FILE}

 RUN ${SOFTWARE_DIR}/database/runInstaller -silent -showProgress \
        -ignoreSysPrereqs -ignorePrereq -waitforcompletion \
        -responseFile ${SOFTWARE_DIR}/database/response/db_install.rsp \
            oracle.install.option=INSTALL_DB_SWONLY \
            UNIX_GROUP_NAME=dba \
            INVENTORY_LOCATION=${ORACLE_BASE}/oraInventory \
            ORACLE_HOME=${ORACLE_HOME} \
            ORACLE_BASE=${ORACLE_BASE} \
            oracle.install.db.InstallEdition=EE \
            oracle.install.db.OSDBA_GROUP=dba \
            oracle.install.db.OSOPER_GROUP=dba \
            oracle.install.db.OSBACKUPDBA_GROUP=dba \
            oracle.install.db.OSDGDBA_GROUP=dba \
            oracle.install.db.OSKMDBA_GROUP=dba \
            oracle.install.db.OSRACDBA_GROUP=dba \
            SECURITY_UPDATES_VIA_MYORACLESUPPORT=false \
            DECLINE_SECURITY_UPDATES=true

RUN rm -rf ${ORACLE_HOME}/apex \
    && rm -rf ${ORACLE_HOME}/ords \
    && rm -rf ${ORACLE_HOME}/sqldeveloper \
    && rm -rf ${ORACLE_HOME}/ucp \
    && rm -rf ${ORACLE_HOME}/lib/*.zip \
    && rm -rf ${ORACLE_HOME}/inventory/backup/* \
    && rm -rf ${ORACLE_HOME}/network/tools/help \
    && rm -rf ${ORACLE_HOME}/assistants/dbua \
    && rm -rf ${ORACLE_HOME}/dmu \
    && rm -rf ${ORACLE_HOME}/install/pilot \
    && rm -rf ${ORACLE_HOME}/suptools

USER root
RUN rm -rf /tmp/* \
    && ${ORACLE_BASE}/oraInventory/orainstRoot.sh \
    && ${ORACLE_HOME}/root.sh

COPY --chown=oracle:oracle scripts/install.rsp scripts/createDB.sh /tmp/
USER oracle
RUN /tmp/createDB.sh


#######################################
#   Final layer
#######################################
FROM base-os as final

USER oracle
WORKDIR /home/oracle

COPY --chown=oracle:dba --from=builder $ORACLE_BASE $ORACLE_BASE
COPY --chown=oracle:oracle scripts/startDB.sh /tmp/

RUN mkdir -p /home/oracle/volume-data


CMD exec /tmp/startDB.sh