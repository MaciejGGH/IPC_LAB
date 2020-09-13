#!/bin/bash

header(){
  echo "
==================================================================
      ${1^^}
=================================================================="
}


header "Creating network files"

cat > "$ORACLE_HOME/network/admin/sqlnet.ora" <<EOF
NAME.DIRECTORY_PATH= (TNSNAMES, EZCONNECT, HOSTNAME)
EOF


cat > "${ORACLE_HOME}/network/admin/listener.ora" <<EOF
LISTENER = 
(DESCRIPTION_LIST = 
  (DESCRIPTION = 
    (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1)) 
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521)) 
  ) 
)
DEDICATED_THROUGH_BROKER_LISTENER=ON
DIAG_ADR_ENABLED = off
EOF


header "Altering install.rsp"

cp /tmp/install.rsp $ORACLE_BASE/dbca.rsp
sed -i -e "s|%%ORACLE_SID%%|$ORACLE_SID|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|%%ORACLE_PWD%%|$ORACLE_PWD|g" $ORACLE_BASE/dbca.rsp


header "Starting listener"
lsnrctl start 


header "Running DBCA"
dbca -silent -createDatabase -responseFile $ORACLE_BASE/dbca.rsp
rm -rf "$ORACLE_BASE/dbca.rsp"

sqlplus / as sysdba << EOF
   SHUTDOWN;
   exit;
EOF

tar -I pigz -cf "${ORACLE_BASE}/oradata.tgz" "${ORACLE_BASE}/oradata" 
rm -rf "${ORACLE_BASE}/oradata"