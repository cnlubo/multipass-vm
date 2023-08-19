#!/bin/bash
###---------------------------------------------------------------------------
# Author: cnak47
# Date: 2022-04-29 17:02:24
# LastEditors: cnak47
# LastEditTime: 2023-08-19 09:51:11
# FilePath: /multipass-vm/deploy-postgresql-vm.sh
# Description:
#
# Copyright (c) 2022 by cnak47, All Rights Reserved.
###----------------------------------------------------------------------------
set -e
MODULE="$(basename $0)"
# dirname $0，取得当前执行的脚本文件的父目录
# cd `dirname $0`，进入这个目录(切换当前工作目录)
# pwd，显示当前工作目录(cd执行后的)
parentdir=$(dirname "$0")
ScriptPath=$(cd "${parentdir:?}" && pwd)
# BASH_SOURCE[0] 等价于 BASH_SOURCE,取得当前执行的shell文件所在的路径及文件名
scriptdir=$(dirname "${BASH_SOURCE[0]}")
#加载配置内容
# shellcheck disable=SC1091
source "$ScriptPath"/include/color.sh
# shellcheck disable=SC1091
source "$ScriptPath"/include/common.sh
SOURCE_SCRIPT "${scriptdir:?}"/options.conf
cpuCount=2
memCount=4
diskCount=10
vm_name=pg-${pg_version:?}
pg_password='12345678'
pg_port=54321
db_name=test_db1,test_db2
db_user='admin'
db_pass=admin123
if [ -f pg-"$pg_version"-config.yaml ]; then
    rm pg-"$pg_version"-config.yaml
fi
cp pg-config_template.yaml pg-"$pg_version"-config.yaml

INFO_MSG "$MODULE" "Create VM $vm_name"
multipass launch --name "$vm_name" \
    --cpus ${cpuCount} \
    --memory ${memCount}G \
    --disk ${diskCount}G \
    --cloud-init pg-"$pg_version"-config.yaml \
    --timeout 600 \
    "${OSversion:?}"
sleep 10
multipass mount /Users/ak47/Documents/postgresql/pgdata "$vm_name":"/var/lib/postgresql" \
    -u "$(id -u)":9999 -g "$(id -g)":999
rm -rf pg-"$pg_version"-config.yaml

INFO_MSG "$MODULE" "Install gosu postgresql-common"
multipass exec -d "/home/ubuntu" "$vm_name" -- bash -c \
    "sudo apt-get install -y postgresql-common gosu >/dev/null&& \
    sudo sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf"

INFO_MSG "$MODULE" "Install postgresql-$pg_version postgresql-contrib"
multipass exec -d "/home/ubuntu" "$vm_name" -- bash -c \
    "sudo apt-get install -y postgresql-$pg_version postgresql-contrib >/dev/null"
INFO_MSG "$MODULE" "initialize postgresql database"
multipass exec -d "${pg_home:?}" "$vm_name" -- bash -c \
    "sudo gosu ${pg_user:?} echo ${pg_password} >/tmp/pwfile&& \
     sudo gosu $pg_user ${pg_bindir:?}/initdb --pgdata=${pg_datadir:?} \
     --username=$pg_user --auth=trust --pwfile=/tmp/pwfile >/dev/null && \
     rm -rf /tmp/pwfile"

INFO_MSG "$MODULE" "Setting postgresql.conf pg_hba.conf"
multipass exec -d "$pg_home" "$vm_name" -- bash -c \
    "sed -i  \"s@^#listen_addresses.*@&\nlisten_addresses =\'*\'@\" ${pg_datadir}/postgresql.conf&& \
    sed -i  \"s@^#port.*@&\nport =$pg_port@\" ${pg_datadir}/postgresql.conf&& \
    sed -i 's@^#\(unix_socket_directories =\)@\1@' ${pg_datadir}/postgresql.conf&& \
    sed -i 's@^#\(unix_socket_permissions =\)@\1@' ${pg_datadir}/postgresql.conf&& \
    sed -i  \"s@^#logging_collector.*@&\nlogging_collector = on@\" ${pg_datadir}/postgresql.conf"

multipass exec -d "$pg_home" "$vm_name" -- bash -c \
    "sed -i 's@^host.*@#&@g' ${pg_datadir}/pg_hba.conf&& \
    sed -i 's@^local.*@#&@g' ${pg_datadir}/pg_hba.conf&& \
    echo -e '\nlocal   all             all                                     trust' >>${pg_datadir}/pg_hba.conf&& \
    echo 'host    all             all             0.0.0.0/0               md5' >>${pg_datadir}/pg_hba.conf && \
    echo '# IPv6 local connections: ' >>${pg_datadir}/pg_hba.conf && \
    echo 'host    all             all             ::1/128                 md5' >>${pg_datadir}/pg_hba.conf"

INFO_MSG "$MODULE" "Setting systemd service "
if [ -f pgsql-"$pg_version".service ]; then
    rm pgsql-"$pg_version".service
fi
cp "$scriptdir"/systemd/pgsql.service pg-"$pg_version".service
multipass transfer pg-"$pg_version".service "$vm_name":/home/ubuntu/
rm -rf pg-"$pg_version".service
multipass exec -d "/home/ubuntu" "$vm_name" -- bash -c \
    "sed -i \"s#@pgsqluser#${pg_user:?}#g\" pg-$pg_version.service&& \
    sed -i \"s#@PgsqlBasePath#${pg_basedir:?}#g\" pg-$pg_version.service && \
    sed -i \"s#@PgsqlDataPath#${pg_datadir:?}#g\" pg-$pg_version.service && \
    sudo mv pg-$pg_version.service /lib/systemd/system/pg-$pg_version.service && \
    sudo systemctl disable postgresql.service && sudo systemctl stop postgresql.service&&\
    sudo systemctl enable pg-$pg_version.service && sudo systemctl start pg-$pg_version.service"
sleep 10
multipass exec -d "$pg_home" "$vm_name" -- bash -c \
    "sudo gosu ${pg_user:?} bash -c \"$pg_basedir/bin/psql -p $pg_port -c '\\l'\""

INFO_MSG "$MODULE" "Creating database user: ${db_user}"
if [[ -z ${db_pass} ]]; then
    ERROR_MSG "$MODULE" "ERROR! Please specify a password for DB_USER in DB_PASS. Exiting..."
    exit 1
fi
multipass exec -d "$pg_home" "$vm_name" -- bash -c \
    "sudo gosu ${pg_user:?} bash -c \"$pg_basedir/bin/psql -p $pg_port -c 'CREATE ROLE \"${db_user}\" with LOGIN CREATEDB PASSWORD '\''$db_pass'\'';'\""

for database in $(awk -F',' '{for (i = 1 ; i <= NF ; i++) print $i}' <<<"${db_name}"); do

    INFO_MSG "$MODULE" "Creating database: ${database}..."
    multipass exec -d "$pg_home" "$vm_name" -- bash -c \
        "sudo gosu ${pg_user:?} bash -c \"$pg_basedir/bin/psql -p $pg_port -c \
            'CREATE DATABASE $database WITH TEMPLATE = ${db_template:?};'\""

    for extension in $(awk -F',' '{for (i = 1 ; i <= NF ; i++) print $i}' <<<"${db_extension}"); do
        INFO_MSG "$MODULE" "‣ Loading ${extension} extension..."
        multipass exec -d "$pg_home" "$vm_name" -- bash -c \
            "sudo gosu ${pg_user:?} bash -c \"$pg_basedir/bin/psql -p $pg_port -d \"$database\" -c \
    'CREATE EXTENSION IF NOT EXISTS $extension;'>/dev/null 2>&1\""
    done

    if [[ -n ${db_user} ]]; then
        INFO_MSG "$MODULE" "‣ Granting access to ${db_user} user..."
        multipass exec -d "$pg_home" "$vm_name" -- bash -c \
            "sudo gosu ${pg_user:?} bash -c \"$pg_basedir/bin/psql -p $pg_port -c \
      'GRANT ALL PRIVILEGES ON DATABASE ${database} to $db_user;'\""
    fi
done
