#!/usr/bin/env bash
# @Time    : 07/20/2022 4:00 PM
# @Author  : iopssre
# @File    : sui-full-node-install.sh
# @github  : https://github.com/iopssre
# @Role    : install sui full node with script
# @Version : 0.1


echo -ne "\\033[0;33m"
cat<<EOT
                                  _oo0oo_
                                 088888880
                                 88" . "88
                                 (| -_- |)
                                  0\\ = /0
                               ___/'---'\\___
                             .' \\\\\\\\|     |// '.
                            / \\\\\\\\|||  :  |||// \\\\
                           /_ ||||| -:- |||||- \\\\
                          |   | \\\\\\\\\\\\  -  /// |   |
                          | \\_|  ''\\---/''  |_/ |
                          \\  .-\\__  '-'  __/-.  /
                        ___'. .'  /--.--\\  '. .'___
                     ."" '<  '.___\\_<|>_/___.' >'  "".
                    | | : '-  \\'.;'\\ _ /';.'/ - ' : | |
                    \\  \\ '_.   \\_ __\\ /__ _/   .-' /  /
                ====='-.____'.___ \\_____/___.-'____.-'=====
                                  '=---='
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                Recommend OS                 Ubuntu 18.04 TLS
                Recommend Hardware           2C 8G
                Recommend Disk               >=50G
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

EOT
echo -ne "\\033[m"

# working dir
SUI_INSTALL_PATH="/blockchain/sui/devtest"

# install dependency packages
echo -e "\033[32m [INFO]: Install the base dependencies, here apt update will be time consuming \033[0m"
sudo apt-get update && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC && apt-get install -y --no-install-recommends tzdata git ca-certificates curl build-essential libssl-dev  pkg-config libclang-dev cmake jq


# usage note
function usage() {
    cat << 
    usage: $0 OPTIONS

    This script use install Sui Full Node and upgrade.

    OPTIONS:
    install    Install Sui Full Node
    upgrade    Upgrade Sui Full Node
    ENDF
}


# check os version
function check_os_version() {
    echo -e "\033[32m [INFO]: Check OS Version \033[0m"
    version=$(grep "^PRETTY_NAME" /etc/os-release)
    case $version in
        *Ubuntu*)
            echo -e "\033[32m [INFO]: Ubuntu is Support \033[0m"
            ;;
        *)
            echo -e "\033[32m [INFO]: OS is not Support \033[0m"
            exit 1
        ;;
    esac
}

# get docker-compose release
function get_docker_compose_release() {
    curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")'
}

# install docker
function install_docker() {
    echo -e "\033[32m [INFO]: Start install docker \033[0m"
    # remove old package
    sudo apt remove --yes docker docker-engine docker.io containerd runc || true
    # config gpg key
    if [ ! -d /etc/apt/keyrings ]
    then
        sudo mkdir -p /etc/apt/keyrings
    fi

    if [ ! -f /etc/apt/keyrings/docker.gpg ]
    then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    fi
    # seting repo
    if [ ! -f /etc/apt/sources.list.d/docker.list ]
    then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    # install docker
    if [ ! -x "$(command -v docker)" ]
    then
        sudo apt update && sudo apt install --yes docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi
}

# install docker-compose
function install_docker_compose() {
    echo -e "\033[32m [INFO]: Start install docker-compose \033[0m"
    # install docker-compose
    if [ ! -x "$(command -v docker-compose)" ]
    then
        sudo curl -L https://github.com/docker/compose/releases/download/$(get_docker_compose_release)/docker-compose-$(uname -s)-$(uname -m) \
        -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
    fi
    
}

# install sui full node
function install_sui() {
    echo -e "\033[32m [INFO]: Install Sui Full Node \033[0m"
    [ ! -d $SUI_INSTALL_PATH ] && mkdir -p $SUI_INSTALL_PATH
    # download docker-compose config files
    if [ ! -f ${SUI_INSTALL_PATH}/docker-compose.yaml ]
    then
        wget -O ${SUI_INSTALL_PATH}/docker-compose.yaml https://raw.githubusercontent.com/MystenLabs/sui/main/docker/fullnode/docker-compose.yaml
    fi
    # download fullnode config files
    if [ ! -f ${SUI_INSTALL_PATH}/fullnode-template.yaml ]
    then
        wget -O ${SUI_INSTALL_PATH}/fullnode-template.yaml https://github.com/MystenLabs/sui/raw/main/crates/sui-config/data/fullnode-template.yaml
        sed -i 's/127.0.0.1:9184/0.0.0.0:9184/' ${SUI_INSTALL_PATH}/fullnode-template.yaml
        sed -i 's/127.0.0.1:9000/0.0.0.0:9000/' ${SUI_INSTALL_PATH}/fullnode-template.yaml
    fi
    # download genesis config files
    if [ ! -f ${SUI_INSTALL_PATH}/genesis.blob ]
    then
        wget -O ${SUI_INSTALL_PATH}/genesis.blob https://github.com/MystenLabs/sui-genesis/raw/main/devnet/genesis.blob
    fi
}

# start sui full node
function start_sui() {
    echo -e "\033[32m [INFO]: Start Docker Compose \033[0m"
    if [ $PWD != $SUI_INSTALL_PATH ]
    then
        cd $SUI_INSTALL_PATH
        docker-compose up -d
    else
        docker-compose up -d
    fi
}

# check sui full node
function check_sui_status() {
    echo -e "\033[32m [INFO]: Start Sui Check \033[0m"
    curl --location --request POST 'http://127.0.0.1:9000/'     --header 'Content-Type: application/json'     --data-raw '{ "jsonrpc":"2.0", "id":1, "method":"sui_getRecentTransactions", "params":[5] }' | jq
}

# upgrade
function upgrade() {
    cd $SUI_INSTALL_PATH
    docker-compose down --volumes
    cp -arp $SUI_INSTALL_PATH $SUI_INSTALL_PATH_$(date +%Y%m%d%H%M)
    install_sui
    start_sui
}

export -f install_docker
export -f install_docker_compose
export -f install_sui
export -f start_sui

# start install
case $1 in:
    install)
        check_os_version
        [ -x "$(command -v docker)" ] && echo -e "\033[33m [Warning]: Docker already exists,Skip installation \033[0m"  || install_docker
        [ -x "$(command -v docker-compose)" ] && echo -e "\033[33m [Warning]: Docker-compose already exists,Skip installation \033[0m"  || install_docker_compose
        check_sui_port=$(netstat -nltp | egrep "(9000|9184)" | wc -l)
        [[ ${check_sui_port} != 0 ]] && echo -e "\033[33m [Warning]: Sui Full Node already exists,Skip installation \033[0m" || (install_sui && start_sui)
        echo -e "\033[33m [Info]: Sleep 10s Check Sui Status \033[0m" && sleep 10 && check_sui_status
    ;;
    upgrade)
        upgrade
    *)
        usage
    ;;
esac

