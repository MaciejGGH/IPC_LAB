#!/bin/bash
set -eo pipefail


_log() {
	printf '%s [Entrypoint]: %s\n' "$(date --rfc-3339=seconds)" "$*"
}


shutdown() {
  echo "Stopping database"

  sqlplus / as sysdba <<EOF
  shutdown immediate;
  exit
EOF

  lsnrctl stop
}


init_traps() {
  trap shutdown SIGTERM SIGINT
}

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
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
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}


createSymlinks() {
    _log "Creating symlinks"

    if [ ! -L "${ORACLE_BASE}/oradata" ]; then
        ln -sf "${ORADATA_DIR}" "${ORACLE_BASE}/oradata"
    fi

    if [ ! -L "${ORACLE_BASE}/pdbs" ]; then
        ln -sf "${PDBS_DIR}" "${ORACLE_BASE}/pdbs"
    fi
}


startOracle() {
    _log "Starting Oracle"

    lsnrctl start

    sqlplus -s / as sysdba <<EOF
    STARTUP;
    exit;
EOF

}


createPDB() {
    _log "Creating PDB"

    local pdbName=$1
    local pdbPassword=$2

    sqlplus -s / as sysdba <<EOF
    create pluggable database ${pdbName} admin user PDBADMIN identified by "${pdbPassword}" default tablespace users create_file_dest='/opt/oracle/pdbs';
    alter pluggable database ${pdbName} open;
    alter pluggable database ${pdbName} save state;
    show pdbs;
    exit;
EOF

}


changePassword() {
    _log "Changing password"

    local newPassword=$1

    sqlplus -s / as sysdba << EOF
    ALTER USER SYS IDENTIFIED BY "${newPassword}";
    ALTER USER SYSTEM IDENTIFIED BY "${newPassword}";
    ALTER SESSION SET CONTAINER = "${ORACLE_PDB}";
    ALTER USER PDBADMIN IDENTIFIED BY "${newPassword}";
    exit;
EOF
}


docker_setup_env() {
    file_env "ORACLE_PASSWORD" "Oracle123!"
    file_env "ORACLE_PDB" "ORAPDB"

    declare -g ORADATA_ALREADY_EXISTS
    if [ -d "${ORADATA_DIR}/${ORACLE_SID}" ]; then
        ORADATA_ALREADY_EXISTS=true
    fi
    
    
    declare -g PDB_ALREADY_EXISTS
    if [ -d "${PDBS_DIR}/${ORACLE_SID}" ]; then
        PDB_ALREADY_EXISTS=true
    fi
}

docker_process_sql() {
    exit | sqlplus -s / as sysdba @"$@"
}

docker_run_user_scripts() {
    for f in "$@"; do
		case "$f" in
			*.sh)
				# https://github.com/docker-library/postgres/issues/450#issuecomment-393167936
				# https://github.com/docker-library/postgres/pull/452
				if [ -x "$f" ]; then
					echo "$0: running $f"
					
				else
					echo "$0: sourcing $f"
				fi
				;;
			*.sql)    echo "$0: running $f"; docker_process_sql "$f"; echo ;;
			*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | docker_process_sql; echo ;;
			*.sql.xz) echo "$0: running $f"; xzcat "$f" | docker_process_sql; echo ;;
			*)        echo "$0: ignoring $f" ;;
		esac
		echo
	done
}


docker_main() {
    docker_setup_env
    createSymlinks

    if [ ! "${ORADATA_ALREADY_EXISTS}" == true ]; then
        _log "Extracting oradata archive"

        tar -I pigz --strip-components=3 -xf "${ORACLE_BASE}/oradata.tgz" -C "${ORADATA_DIR}"
    fi

    startOracle

    if [ ! "${PDB_ALREADY_EXISTS}" == true ]; then
        createPDB "${ORACLE_PDB}" "${ORACLE_PASSWORD}"
    fi

    if [ ! "${ORACLE_PASSWORD}" == "Oracle123!" ]; then
        changePassword "${ORACLE_PASSWORD}"
    fi

    if [ ! "${ORADATA_ALREADY_EXISTS}" == true ]; then
        docker_run_user_scripts /docker-entrypoint-initdb.d/*
    fi

    unset ORACLE_PASSWORD

    echo "The following output is now a tail of the alert.log:"
    tail -f $ORACLE_BASE/diag/rdbms/*/*/trace/alert*.log &
    childPID=$!
    wait $childPID
}

init_traps
docker_main
