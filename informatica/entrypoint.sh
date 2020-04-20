#!/usr/bin/env bash

INFA_CONFIG="$HOME/ipc_config"

log(){
  echo "$1"
}

log_warning(){
  log "WARNING: $1"
}

log_error(){
  log ''
  log "ERROR: $1"
  log ''
}

log_header(){
  echo "
==================================================================
      ${1^^}
=================================================================="
}

exit_on_fail(){
    if [[ $? -ne 0 ]]; then
        log_error "$1"
        exit 1
    fi
}

ln_missing(){
    local source=$1
    local target=$2

    local sourcPath="$(realpath "$source")"
    local targetPath="$(realpath "$target")"

    if [[ ! -L $target || $sourcPath != $targetPath ]]; then
        log "Creating SymLink for: ${target}"
        rm -rf $target
        ln -sfn $source $target
    fi
}

mv_existing(){
    local source=$1
    local target=$2

    if [[ -f $source || -d $source ]]; then
        log "Movig ${source} to ${target}"
        mv $source $target
    fi
}

moveConfigFiles(){
    log_header "Moving config files..."

    if [ ! -d $INFA_CONFIG ]; then
        log "Creating ipc_config directories"
        mkdir -p $INFA_CONFIG
        mkdir -p $INFA_CONFIG/isp/config
        mkdir -p $INFA_CONFIG/isp/config/keys
        mkdir -p $INFA_CONFIG/services/shared
        mkdir -p $INFA_CONFIG/tomcat/conf/
    fi;

    mv_existing $INFA_HOME/isp/config/nodemeta.xml $INFA_CONFIG/isp/config/nodemeta.xml
    mv_existing $INFA_HOME/isp/config/keys/siteKey $INFA_CONFIG/isp/config/keys/siteKey
    mv_existing $INFA_HOME/services/shared/security $INFA_CONFIG/services/shared
    mv_existing $INFA_HOME/tomcat/conf/Default.keystore $INFA_CONFIG/tomcat/conf/Default.keystore
    mv_existing $INFA_HOME/tomcat/conf/server.xml $INFA_CONFIG/tomcat/conf/server.xml
    mv_existing $INFA_HOME/domains.infa $INFA_CONFIG/domains.infa

    symLinkConfigFiles
}



symLinkConfigFiles(){
    log_header "Creating SymLinks..."

    ln_missing $INFA_CONFIG/isp/config/nodemeta.xml $INFA_HOME/isp/config/nodemeta.xml
    ln_missing $INFA_CONFIG/isp/config/keys/siteKey $INFA_HOME/isp/config/keys/siteKey
    ln_missing $INFA_CONFIG/services/shared/security $INFA_HOME/services/shared/security
    ln_missing $INFA_CONFIG/tomcat/conf/Default.keystore $INFA_HOME/tomcat/conf/Default.keystore
    ln_missing $INFA_CONFIG/tomcat/conf/server.xml $INFA_HOME/tomcat/conf/server.xml
    ln_missing $INFA_CONFIG/domains.infa $INFA_HOME/domains.infa
}

generateEncryptionKey(){
    log_header "Generating Encryption key..."

    $INFA_HOME/isp/bin/infasetup.sh generateEncryptionKey \
    -kw ${IPC_ENCRYPTION_KEY} \
    -dn ${IPC_DOMAIN_NAME}

    exit_on_fail "Could not create encryption key!"
}

prepareNode(){    
    local count=$(sqlplus -s ${IPC_DOMAIN_USER}/${IPC_DOMAIN_PASSWORD}@oracle <<END
set pagesize 0 feedback off verify off heading off echo off;
select count(1) from user_tables
exit;
END
)

    err=$(echo ${count} | grep -ic error)

    if [[ $err -gt 0 ]]; then
        log_error "Cant access domain schema!"
        exit 1
    fi

    if [[ $count -gt 0 ]]; then
        defineGatewayNode
    else
        defineDomain
    fi

}

defineGatewayNode(){
    log_header "Defining Gateway Node..."

    $INFA_HOME/isp/bin/infasetup.sh defineGatewayNode \
    -dt ORACLE -cs "jdbc:informatica:oracle://oracle:1521;ServiceName=${ORACLE_PDB}" \
    -du ${IPC_DOMAIN_USER} -dp ${IPC_DOMAIN_PASSWORD} \
    -dn ${IPC_DOMAIN_NAME} \
    -nn node01 -na ipc.${BASE_URL}:6005 \
    -ld /opt/Informatica/isp/log/ \
    -rf /opt/Informatica/isp/bin/nodeoptions.xml \
    -sv 6007 -ap 6008 -asp 6009

    exit_on_fail "Could not define gateway node!"
}

defineDomain(){
    log_header "Defining domain..."
    
    $INFA_HOME/isp/bin/infasetup.sh defineDomain \
    -dt ORACLE -cs "jdbc:informatica:oracle://oracle:1521;ServiceName=${ORACLE_PDB}" \
    -du ${IPC_DOMAIN_USER} -dp ${IPC_DOMAIN_PASSWORD} \
    -dn ${IPC_DOMAIN_NAME} \
    -nn node01 -na ipc.${BASE_URL}:6005 \
    -ad ${IPC_ADMIN_USER} -pd ${IPC_ADMIN_PASSWORD} \
    -ld $INFA_HOME/isp/log \
    -rf $INFA_HOME/isp/bin/nodeoptions.xml \
    -kd $INFA_HOME/isp/config/keys \
    -mi 6013 -ma 6113 \
    -sv 6007 -ap 6008 -asp 6009

    exit_on_fail "Could not define domain!"
}

waitForOracle(){
    log_header "Waiting for Oracle..."

    local timeout=60
    local result
   
    for i in $(seq 1 ${timeout}); do
        echo "QUIT" | sqlplus -L "${IPC_DOMAIN_USER}/${IPC_DOMAIN_PASSWORD}@oracle" | grep "Connected to:" > /dev/null 2>&1
        result=$?

        if [[ ${result} -eq 0 ]] ; then
            log "Oracle became avaliable after ${i} seconds"
            break
        fi


        log_warning "Oracle was not avaliable after ${i} seconds."
        snore 1
    done

    if [[ ! ${result} -eq 0 ]] ; then
        log_error "Oracle was not avaliable!"
        exit 1
    fi
}

stop() {
    log_header 'terminating ...'

    $INFA_HOME/tomcat/bin/infaservice.sh shutdown
    
    # TODO
    # replace with check if server has been shutdown
    snore 10
    log_header 'terminated'
    exit 0
}


init_trap() {
  trap stop SIGTERM SIGINT SIGKILL
}

snore() {
    local IFS
    [[ -n "${_snore_fd:-}" ]] || exec {_snore_fd}<> <(:)
    read ${1:+-t "$1"} -u $_snore_fd || :
}

hangout() {
  log_header 'Ready'

  while :; do snore 30 & wait; done
}

init_trap

if [[ ! -f $INFA_CONFIG/isp/config/keys/siteKey ]]; then
    generateEncryptionKey
fi

waitForOracle
if [[ ! -f $INFA_CONFIG/isp/config/nodemeta.xml && ! -f $INFA_CONFIG/tomcat/conf/server.xml ]]; then
    prepareNode
fi

if [[ -d $INFA_CONFIG ]]; then
    symLinkConfigFiles
else
    moveConfigFiles
fi

log_header "Starting server..."
$INFA_HOME/tomcat/bin/infaservice.sh startup
# TODO
# add startup veryfication

hangout