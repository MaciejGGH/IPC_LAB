#!/bin/bash

header() {
  echo "
==================================================================
      ${1^^}
=================================================================="
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

startOracle() {
  lsnrctl start

  sqlplus / as sysdba <<EOF
  STARTUP;
  show pdbs;
  exit;
EOF

}

createPDB() {
  local pdbName=$1
  local pdbPassword=$2

  sqlplus / as sysdba <<EOF
create pluggable database ${pdbName} admin user admin identified by "${pdbPassword}" default tablespace users create_file_dest='/opt/oracle/pdbs';
alter pluggable database ${pdbName} open;
alter pluggable database ${pdbName} save state;
show pdbs;
exit;
EOF
}

function symLinkFiles() {
  header "Creating symlink files"

  if [ ! -L "${ORACLE_HOME}/dbs/spfile$ORACLE_SID.ora" ]; then
    ln -s "${ORACLE_BASE}/oradata/dbconfig/${ORACLE_SID}/spfile${ORACLE_SID}.ora" "${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora"
  fi

  if [ ! -L "${ORACLE_HOME}/dbs/orapw${ORACLE_SID}" ]; then
    ln -s "${ORACLE_BASE}/oradata/dbconfig/${ORACLE_SID}/orapw${ORACLE_SID}" "${ORACLE_HOME}/dbs/orapw${ORACLE_SID}"
  fi

  if [ ! -L "${ORACLE_HOME}/network/admin/sqlnet.ora" ]; then
    ln -s "${ORACLE_BASE}/oradata/dbconfig/${ORACLE_SID}/sqlnet.ora" "${ORACLE_HOME}/network/admin/sqlnet.ora"
  fi

  if [ ! -L "${ORACLE_HOME}/network/admin/listener.ora" ]; then
    ln -s "${ORACLE_BASE}/oradata/dbconfig/${ORACLE_SID}/listener.ora" "${ORACLE_HOME}/network/admin/listener.ora"
  fi

  if [ ! -L "${ORACLE_HOME}/network/admin/tnsnames.ora" ]; then
    ln -s "${ORACLE_BASE}/oradata/dbconfig/${ORACLE_SID}/tnsnames.ora" "${ORACLE_HOME}/network/admin/tnsnames.ora"
  fi

  if [ ! -L "${ORACLE_BASE}/oradata" ]; then
    ln -sf "/home/oracle/volume-data/oradata" "${ORACLE_BASE}/oradata"
  fi

  if [ ! -L "${ORACLE_BASE}/pdbs" ]; then
    ln -sf "/home/oracle/volume-data/pdbs" "${ORACLE_BASE}/pdbs"
  fi

  # oracle user does not have permissions in /etc, hence cp and not ln
  cp "${ORACLE_BASE}/oradata/dbconfig/${ORACLE_SID}/oratab" "/etc/oratab"

}


init_traps


if [ -d "/home/oracle/volume-data/oradata/${ORACLE_SID}" ]; then
  symLinkFiles

  startOracle
else
  header "Unpacking..."

  mkdir -p "/home/oracle/volume-data/oradata"
  mkdir -p "/home/oracle/volume-data/pdbs"
  rm -rf "${ORACLE_BASE}/pdbs"

  ln -sf "/home/oracle/volume-data/oradata" "${ORACLE_BASE}/oradata"
  ln -sf "/home/oracle/volume-data/pdbs" "${ORACLE_BASE}/pdbs"
  # unpack archive with oradata
  tar -I pigz --strip-components=3 -xf "${ORACLE_BASE}/oradata.tgz" -C "/home/oracle/volume-data/oradata"

  header "Starting oracle"
  # start oracle
  startOracle

  header "Creating PDB"
  # create pdb
  createPDB "ORAPDB" "Oracle123!"
fi

# Tail on alert log and wait (otherwise container will exit)
echo "The following output is now a tail of the alert.log:"
tail -f $ORACLE_BASE/diag/rdbms/*/*/trace/alert*.log &
childPID=$!
wait $childPID