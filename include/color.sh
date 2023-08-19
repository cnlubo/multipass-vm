#!/bin/bash
###---------------------------------------------------------------------------
# Author: cnak47
# Date: 2023-08-04 10:16:00
# LastEditors: cnak47
# LastEditTime: 2023-08-04 10:18:57
# FilePath: /ak47Docker/postgresql/include/color.sh
# Description: 
# 
# Copyright (c) 2023 by cnak47, All Rights Reserved. 
###----------------------------------------------------------------------------

# shellcheck disable=SC2034
echo="echo"
for cmd in echo /bin/echo; do
    $cmd >/dev/null 2>&1 || continue
    if ! $cmd -e "" | grep -qE '^-e'; then
        echo=$cmd
        break
    fi
done
CSI=$($echo -e "\033[")
CEND="${CSI}0m"
CBOLD="${CSI}1m"
CDGREEN="${CSI}32m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CMAGENTA="${CSI}1;35m"
CCYAN="${CSI}1;36m"
CWHITE="${CSI}38;5;7m"
CSUCCESS="$CCYAN"
CFAILURE="$CRED"
CQUESTION="$CMAGENTA"
CWARNING="$CYELLOW"
CMSG="$CCYAN"
## Background
ON_BLACK='\033[48;5;0m'
ON_RED='\033[48;5;1m'
ON_GREEN='\033[48;5;2m'
ON_YELLOW='\033[48;5;3m'
ON_BLUE='\033[48;5;4m'
ON_MAGENTA='\033[48;5;5m'
ON_CYAN='\033[48;5;6m'
ON_WHITE='\033[48;5;7m'