#!/bin/bash
###---------------------------------------------------------------------------
# Author: cnak47
# Date: 2022-04-16 23:21:13
# LastEditors: cnak47
# LastEditTime: 2022-09-29 15:43:08
# FilePath: /docker_workspace/ak47Docker/k3s/include/common.sh
# Description:
#
# Copyright (c) 2022 by cnak47, All Rights Reserved.
###----------------------------------------------------------------------------
EXIT_SCRIPT() {
    kill -s TERM "$TOP_PID"
}

EXIT_MSG() {
    log "${1}" "${CFAILURE}Error ${CEND} ==> ${CBOLD}${CRED}${2}${CEND}"
    exit 1
}

stderr_print() {
    printf "%b\\n" "${*}" >&2
}
log() {
    Module="$1"
    Msg="$2"
    stderr_print "[${CBLUE}${Module} ${CMAGENTA}$(date "+%Y-%m-%d %H:%M:%S ")${CEND}] ${Msg}"
}
INFO_MSG() {
    log "${1}" "${CDGREEN}INFO ${CEND} ==> ${CBOLD}${2}${CEND}"
}
WARNING_MSG() {

    log "${1}" "${CYELLOW}WARN ${CEND} ==> ${CBOLD}${CYELLOW}${2}${CEND}"
}
ERROR_MSG() {
    log "${1}" "${CRED}Error ${CEND} ==> ${CBOLD}${2}${CEND}"
}
FAILURE_MSG() {
    log "${1}" "${CFAILURE}FAILURE ${CEND} ==> ${CBOLD}${2}${CEND}"
}
SUCCESS_MSG() {
    log "${1}" "${CSUCCESS}SUCCESS ${CEND} ==> ${CBOLD}${CCYAN}${2}${CEND}"
}

#check script exists and loading
SOURCE_SCRIPT() {
    for arg; do
        if [ ! -f "$arg" ]; then
            EXIT_MSG "not exist $arg,so $0 can not be supported!"
        else
            #INFO_MSG "loading $arg now, continue ......"
            # shellcheck source=/dev/null.
            source $arg
        fi
    done
}
PASS_ENTER_TO_EXIT() {
    InfoMsg="input enter or wait 10s to continue"
    # shellcheck disable=SC2034
    read -r -p "$InfoMsg" -t 10 ok
    echo ""
}

TEST_FILE() {
    if [[ ! -f $1 ]]; then
        INFO_MSG "Not exist $1"
        PASS_ENTER_TO_EXIT
        return 1
    else
        INFO_MSG "loading $1 now..."
        return 0
    fi
}
TEST_PROGRAMS() {
    for arg; do
        if [[ -z $(which $arg) ]]; then
            INFO_MSG "Your system do not have $arg"
            return 1
        else
            INFO_MSG "loading $arg ..."
            return 0
        fi
    done
}
BACK_TO_INDEX() {
    if [[ $? -gt 0 ]]; then
        INFO_MSG "Ready back to index"
        PASS_ENTER_TO_EXIT
        SELECT_RUN_SCRIPT
    else
        INFO_MSG "succeed , continue ..."
    fi
}
INPUT_CHOOSE() {

    VarTmp=
    select vars in "$@" "exit"; do
        case $vars in
        $vars)
            # shellcheck disable=SC2034
            [[ "$vars" == "exit" ]] && VarTmp="" || VarTmp="$vars"
            break
            ;;
        esac
        INFO_MSG "Input again"
    done
}

INSTALL_BASE_PACKAGES() {
    case $OS in
    "CentOS")
        {
            cp /etc/yum.conf /etc/yum.conf.back
            sed -i 's:exclude=.*:exclude=:g' /etc/yum.conf
            for arg; do
                # INFO_MSG "正在安装 ${arg} ....."
                yum -y install $arg
            done
            mv -f /etc/yum.conf.back /etc/yum.conf
        }
        ;;
    "Ubuntu")
        {
            [[ -z $SysCount ]] && apt-get update && SysCount="1"
            apt-get -fy install
            apt-get -y autoremove --purge
            dpkg -l | grep ^rc | awk '{print $2}' | sudo xargs dpkg -P
            for arg; do
                INFO_MSG "正在安装 ${arg} ************************************************** >>" "[${arg} Installing] ************************************************** >>"
                apt-get install -y $arg --force-yes
            done
        }
        ;;

    *)
        echo "unknow System"
        ;;
    esac
    return 1
}

Download_src() {

    if [ ! -e "$(command -v wget)" ]; then
        yum -y install wget
    fi
    cd "${src_dir:?}" || exit
    if [ -s "${src_url##*/}" ]; then
        INFO_MSG "[ ${src_url##*/} ] found"
    else

        {
            wget --tries=6 -c -P "$src_dir" --no-check-certificate "${src_url}"
            sleep 1
        }
    fi

    if [ ! -e "${src_url##*/}" ]; then
        FAILURE_MSG "${src_url##*/} download failed, Please contact the author"
        kill -9 $$
    fi

}

get_char() {
    SAVEDSTTY=$(stty -g)
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2>/dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}
system_check() {

    [[ "$OS" == '' ]] && echo "${CWARNING}[Error] Your system is not supported this script${CEND}" && exit
    [ ${RamTotal:?} -lt '1000' ] && echo -e "${CWARNING}[Error] Not enough memory install.\nThis script need memory more than 1G.\n${CEND}" && exit
}

get_latest_release() {
    curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
        grep '"tag_name":' |                                          # Get tag line
        sed -E 's/.*"([^"]+)".*/\1/'                                  # Pluck JSON value
}

# ISTIO_VERSION="$(curl -sL https://github.com/istio/istio/releases | \
#                   grep -o 'releases/[0-9]*.[0-9]*.[0-9]*/' | sort -V | \
#                   tail -1 | awk -F'/' '{ print $2}')"
#   ISTIO_VERSION="${ISTIO_VERSION##*/}"

# get_release_version() {
#     if [ -n "${INSTALL_K3S_COMMIT}" ]; then
#         VERSION_K3S="commit ${INSTALL_K3S_COMMIT}"
#     elif [ -n "${INSTALL_K3S_VERSION}" ]; then
#         VERSION_K3S=${INSTALL_K3S_VERSION}
#     else
#         info "Finding release for channel ${INSTALL_K3S_CHANNEL}"
#         version_url="${INSTALL_K3S_CHANNEL_URL}/${INSTALL_K3S_CHANNEL}"
#         case $DOWNLOADER in
#             curl)
#                 VERSION_K3S=$(curl -w '%{url_effective}' -L -s -S ${version_url} -o /dev/null | sed -e 's|.*/||')
#                 ;;
#             wget)
#                 VERSION_K3S=$(wget -SqO /dev/null ${version_url} 2>&1 | grep -i Location | sed -e 's|.*/||')
#                 ;;
#             *)
#                 fatal "Incorrect downloader executable '$DOWNLOADER'"
#                 ;;
#         esac
#     fi
#     info "Using ${VERSION_K3S} as release"
# }

# cat 1.json | jq '.[]'| jq '.tag_name' |grep -o 'v[0-9]*.[0-9]*.[0-9]*+k3s1'
