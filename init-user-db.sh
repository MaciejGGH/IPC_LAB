#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    create role "${DOMAIN_DB_USERNAME}" with login encrypted password '${DOMAIN_DB_PASSWORD}';
    create database "${DOMAIN_DB_USERNAME}" with owner "${DOMAIN_DB_USERNAME}";
    grant all privileges on database "${DOMAIN_DB_USERNAME}" to "${DOMAIN_DB_USERNAME}";

    create role "IPCLAB_REP" with login encrypted password 'IPCLAB_REP';
    create database "IPCLAB_REP" with owner "IPCLAB_REP";
    grant all privileges on database "IPCLAB_REP" to "IPCLAB_REP";

    create role "IPCLAB_MRS" with login encrypted password 'IPCLAB_MRS';
    create database "IPCLAB_MRS" with owner "IPCLAB_MRS";
    grant all privileges on database "IPCLAB_MRS" to "IPCLAB_MRS";

    create role "IPCLAB_DATA" with login encrypted password 'IPCLAB_DATA';
    create database "IPCLAB_DATA" with owner "IPCLAB_DATA";
    grant all privileges on database "IPCLAB_DATA" to "IPCLAB_DATA";
EOSQL

