#!/bin/bash

set -Eeuo pipefail

_command=${1:-"build"}

_root_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
_bold="\033[1m"
_normal="\033[0m"


_help="
${_bold}SYNOPSIS${_normal} 
    ./build.sh [image-name]

${_bold}IMAGES${_normal}
    ${_bold}software${_normal}
        image with software binaries

    ${_bold}base-os${_normal}
        image with operating system and basic libs

    ${_bold}builder${_normal}
        builder image 
  
    ${_bold}final${_normal}
        final image with working database
        
"

show_help() {
    echo -e "$_help"
}


build() {
    local image=${1:-""}


    case $image in
        software)
        docker build \
            -t ipc_lab/oracle-software:12.2.0.1 \
            -f "${_root_dir}/software/Dockerfile" "${_root_dir}/software"
        ;;

        base-os)
        docker build \
            --target base-os \
            --cache-from ipc_lab/oracle-base-os:12.2.0.1 \
            -t ipc_lab/oracle-base-os:12.2.0.1 \
            -f "${_root_dir}/Dockerfile" "${_root_dir}"
        ;;

        builder)
            docker build \
            --target builder \
            --cache-from ipc_lab/oracle-base-os:12.2.0.1 \
            --cache-from ipc_lab/oracle-builder:12.2.0.1 \
            -t ipc_lab/oracle-builder:12.2.0.1 \
            -f "${_root_dir}/Dockerfile" "${_root_dir}"
        ;;

        final)
        docker build \
            --target final \
            --cache-from ipc_lab/oracle-base-os:12.2.0.1 \
            --cache-from ipc_lab/oracle-builder:12.2.0.1 \
            --cache-from ipc_lab/oracle:12.2.0.1 \
            -t ipc_lab/oracle:12.2.0.1 \
            -f "${_root_dir}/Dockerfile" "${_root_dir}"
        ;;

        *)
        echo -e "${_help}"
        ;;
    esac
}



build ${@:1}