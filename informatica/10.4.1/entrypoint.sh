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


file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(<"${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
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

    local sourcePath
    sourcePath="$(realpath "$source")"

    local targetPath
    targetPath="$(realpath "$target")"

    if [[ ! -L "${target}" || "${sourcePath}" != "${targetPath}" ]]; then
        rm -vrf "${target}"
        ln -vsfn "${source}" "${target}"
    fi
}

mv_existing(){
    local source=$1
    local target=$2

    if [[ -f "${source}" || -d "${source}" ]]; then
        mv -v "${source}" "${target}"
    fi
}


moveConfigFiles(){
    log_header "Moving config files..."

    if [ ! -d "${INFA_CONFIG}" ]; then
        log "Creating ipc_config directories"
        mkdir -pv "${INFA_CONFIG}/isp/config/keys"
        mkdir -pv "${INFA_CONFIG}/services/shared"
        mkdir -pv "${INFA_CONFIG}/tomcat/conf/"
    fi;

    mv_existing "${INFA_HOME}/isp/config/nodemeta.xml" "${INFA_CONFIG}/isp/config/nodemeta.xml"
    mv_existing "${INFA_HOME}/isp/config/keys/siteKey" "${INFA_CONFIG}/isp/config/keys/siteKey"
    mv_existing "${INFA_HOME}/services/shared/security" "${INFA_CONFIG}/services/shared"
    mv_existing "${INFA_HOME}/tomcat/conf/Default.keystore" "${INFA_CONFIG}/tomcat/conf/Default.keystore"
    mv_existing "${INFA_HOME}/tomcat/conf/server.xml" "${INFA_CONFIG}/tomcat/conf/server.xml"
    mv_existing "${INFA_HOME}/domains.infa" "${INFA_CONFIG}/domains.infa"

    symlinkConfigFiles
}


symlinkConfigFiles(){
    log_header "Creating SymLinks..."

    ln_missing "${INFA_CONFIG}/isp/config/nodemeta.xml" "${INFA_HOME}/isp/config/nodemeta.xml"
    ln_missing "${INFA_CONFIG}/isp/config/keys/siteKey" "${INFA_HOME}/isp/config/keys/siteKey"
    ln_missing "${INFA_CONFIG}/services/shared/security" "${INFA_HOME}/services/shared/security"
    ln_missing "${INFA_CONFIG}/tomcat/conf/Default.keystore" "${INFA_HOME}/tomcat/conf/Default.keystore"
    ln_missing "${INFA_CONFIG}/tomcat/conf/server.xml" "${INFA_HOME}/tomcat/conf/server.xml"
    ln_missing "${INFA_CONFIG}/domains.infa" "${INFA_HOME}/domains.infa"
}

generateEncryptionKey() {
    log_header "Generating Encryption key..."

    "${INFA_HOME}/isp/bin/infasetup.sh" generateEncryptionKey \
        -kw "${DOMAIN_ENCRYPTION_KEY}" \
        -dn "${DOMAIN_NAME}"

    exit_on_fail "Could not create encryption key!"
}

defineGatewayNode() {
    log_header "Defining Gateway Node..."

    "${INFA_HOME}/isp/bin/infasetup.sh" defineGatewayNode \
        -DatabaseType "${DOMAIN_DB_TYPE}" \
        -DatabaseAddress "${DOMAIN_DB_HOST}:${DOMAIN_DB_PORT}" \
        -DatabaseServiceName "${DOMAIN_DB_SERVICE_NAME}" \
        -DatabaseUserName "${DOMAIN_DB_USERNAME}" \
        -DatabasePassword "${DOMAIN_DB_PASSWORD}" \
        -DomainName "${DOMAIN_NAME}" \
        -NodeName "${NODE_NAME}" \
        -NodeAddress "${HOSTNAME}:6005" \
        -LogServiceDirectory "${INFA_HOME}/isp/log" \
        -ResourceFile "${INFA_HOME}/isp/bin/nodeoptions.xml" \
        -ServerPort 6007 \
        -AdminconsolePort 6008 \
        -AdminconsoleShutdownPort 6009

    exit_on_fail "Could not define gateway node!"
}

defineDomain() {
    log_header "Defining domain..."

    local params=()

    # add license key if provided
    if [[ "${LICENSE_FILE_EXISTS}" == true ]]; then
        licenseFileName=$(basename "${LICENSE_KEY_FILE}")

        params+=(-LicenseKeyFile "${LICENSE_KEY_FILE}")
        params+=(-LicenseName "${licenseFileName}")
    fi

    "${INFA_HOME}/isp/bin/infasetup.sh" defineDomain \
        -DatabaseType "${DOMAIN_DB_TYPE}" \
        -DatabaseAddress "${DOMAIN_DB_HOST}:${DOMAIN_DB_PORT}" \
        -DatabaseServiceName "${DOMAIN_DB_SERVICE_NAME}" \
        -DatabaseUserName "${DOMAIN_DB_USERNAME}" \
        -DatabasePassword "${DOMAIN_DB_PASSWORD}" \
        -DomainName "${DOMAIN_NAME}" \
        -AdministratorName "${DOMAIN_ADMIN_USERNAME}" \
        -Password "${DOMAIN_ADMIN_PASSWORD}" \
        -NodeName "${NODE_NAME}" \
        -NodeAddress "${HOSTNAME}:6005" \
        -LogServiceDirectory "${INFA_HOME}/isp/log" \
        -ResourceFile "${INFA_HOME}/isp/bin/nodeoptions.xml" \
        -KeysDirectory "${INFA_HOME}/isp/config/keys" \
        -MinProcessPort 6013 \
        -MaxProcessPort 6113 \
        -ServerPort 6007 \
        -AdminconsolePort 6008 \
        -AdminconsoleShutdownPort 6009 "${params[@]}"

    exit_on_fail "Could not define domain!"
}

waitForOracle(){
    log_header "Waiting for Oracle..."

    local timeout=60
    local result

    for i in $(seq 1 ${timeout}); do
        echo "QUIT" | sqlplus -L "${DOMAIN_DB_USERNAME}/${DOMAIN_DB_PASSWORD}@${DOMAIN_DB_HOST}:${DOMAIN_DB_PORT}/${DOMAIN_DB_SERVICE_NAME}" | grep "Connected to:" > /dev/null 2>&1
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

startServer() {
    log_header "Starting server..."

    "${INFA_HOME}/tomcat/bin/infaservice.sh" startup

    exit_on_fail "Failed to start server"

    tail --retry -f "${INFA_HOME}/logs/${NODE_NAME}/node.log" &
    childPID=$!
    wait $childPID
}

stopServer() {
    log_header "Stopping server..."

    "${INFA_HOME}/tomcat/bin/infaservice.sh" shutdown

    snore 10
}


init_trap() {
  trap stopServer SIGTERM SIGINT SIGKILL
}

snore() {
    local IFS
    [[ -n "${_snore_fd:-}" ]] || exec {_snore_fd}<> <(:)
    read ${1:+-t "$1"} -u $_snore_fd || :
}


validate_env() {
    log_header "Validating environment variables"

    local requiredVariables=(
        "DOMAIN_NAME"
        "DOMAIN_ENCRYPTION_KEY"
        "DOMAIN_DB_TYPE"
        "DOMAIN_DB_HOST"
        "DOMAIN_DB_PORT"
        "DOMAIN_DB_SERVICE_NAME"
        "DOMAIN_DB_USERNAME"
        "DOMAIN_DB_PASSWORD"
        "DOMAIN_ADMIN_USERNAME"
        "DOMAIN_ADMIN_PASSWORD"
        "DOMAIN_ACTION"
        "NODE_NAME"
    )

    declare -n variable
    local missingVariable=false

    for variable in "${requiredVariables[@]}"; do
        if [[ ! -v variable ]]; then
            missingVariable=true
            log_error "Variable <${!variable}> is required and must be set"
        fi
    done

    if [[ "${missingVariable}" == true ]]; then
        exit 1
    fi


    if [[ "${DOMAIN_DB_TYPE^^}" != "ORACLE" && "${DOMAIN_DB_TYPE^^}" != "POSTGRESQL" ]]; then
        log_error "<DOMAIN_DB_TYPE> must be set to one of two values 'Oracle' or 'PostgreSQL'!"
        exit 1
    fi

    if [[ "${DOMAIN_ACTION^^}" != "CREATE" && "${DOMAIN_ACTION}" != "JOIN" ]]; then
        log_error "<DOMAIN_ACTION> must be set to 'CREATE' or 'JOIN'!"
        exit 1
    fi


    log "OK"
}

setup_env() {
    file_env "NODE_NAME" "node_${RANDOM}"
    file_env "DOMAIN_ACTION" "CREATE"

    declare -g INFA_CONFIG="${HOME}/infa_config"

    declare -g LICENSE_FILE_EXISTS=false
    if [[ -n "${LICENSE_KEY_FILE}" && -f "${LICENSE_KEY_FILE}" ]]; then
        LICENSE_FILE_EXISTS=true
    fi
}

main() {
    setup_env
    validate_env

    if [[ ! -f "${INFA_CONFIG}/isp/config/keys/siteKey" ]]; then
        generateEncryptionKey
    fi


    if [[ "${DOMAIN_DB_TYPE^^}" == "ORACLE" ]]; then
        waitForOracle
    fi


    if [[ ! -f "${INFA_CONFIG}/isp/config/nodemeta.xml" && ! -f "${INFA_CONFIG}/tomcat/conf/server.xm" ]]; then
        case "${DOMAIN_ACTION^^}" in
            CREATE)
                defineDomain
                ;;

            JOIN)
                defineGatewayNode
                ;;
        esac
        
    fi;


    if [[ -d "${INFA_CONFIG}" ]]; then
        symlinkConfigFiles
    else
        moveConfigFiles
    fi

    init_trap
    startServer
}

main