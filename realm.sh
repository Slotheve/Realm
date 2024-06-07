#!/bin/bash
# Author: Slotheve<https://slotheve.com>

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN='\033[0m'

CPU=`uname -m`
conf="/etc/realm/realm.toml"

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

archAffix(){
    if [[ "$CPU" = "x86_64" ]] || [[ "$CPU" = "amd64" ]]; then
        ARCH="x86_64"
    elif [[ "$CPU" = "armv8" ]] || [[ "$CPU" = "aarch64" ]]; then
        ARCH="aarch64"
    else
        colorEcho $RED " 不支持的CPU架构！"
    fi
}

checkSystem() {
    result=$(id | awk '{print $1}')
    if [[ $result != "uid=0(root)" ]]; then
        result=$(id | awk '{print $1}')
        if [[ $result != "用户id=0(root)" ]]; then
            colorEcho $RED " 请以root身份执行该脚本"
            exit 1
        fi
    fi

    res=`which yum 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        res=`which apt 2>/dev/null`
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " 不受支持的Linux系统"
            exit 1
        fi
	    OS="apt"
    else
	    OS="yum"
    fi
    res=`which systemctl 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        colorEcho $RED " 系统版本过低，请升级到最新版本"
        exit 1
    fi
}

status() {
    if [[ ! -f /etc/realm/realm ]]; then
        echo 0
        return
    fi
    if [[ ! -f ${conf} ]]; then
        echo 1
        return
    fi
    res=`ss -nutlp| grep realm`
    if [[ -z ${res} ]]; then
        echo 2
    else
        echo 3
        return
    fi
}

statusText() {
    res=`status`
    case ${res} in
        2)
            echo -e ${GREEN}已安装${PLAIN} ${RED}未运行${PLAIN}
            ;;
        3)
            echo -e ${GREEN}已安装${PLAIN} ${GREEN}正在运行${PLAIN}
            ;;
        *)
            echo -e ${RED}未安装${PLAIN}
            ;;
    esac
}

Download(){
    rm -rf /etc/realm
    mkdir -p /etc/realm
    archAffix
    DOWNLOAD_LINK="https://raw.githubusercontent.com/Slotheve/Realm/main/realm-${ARCH}"
    colorEcho $YELLOW "下载Realm: ${DOWNLOAD_LINK}"
    curl -L -H "Cache-Control: no-cache" -o /etc/realm/realm ${DOWNLOAD_LINK}
    chmod +x /etc/realm/realm
}

Deploy(){
    cd /etc/systemd/system
    cat > realm.service<<-EOF
[Unit]
Description=Realm
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
DynamicUser=true
ExecStart=/etc/realm/realm -c /etc/realm/realm.toml

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable realm

    cat > /etc/realm/realm.toml<<-EOF
[network]
use_udp = true

[[endpoints]]
listen = "0.0.0.0:6666"
remote = "1.1.1.1:6666"

#[[endpoints]]
#listen = "0.0.0.0:6666"
#remote = "1.1.1.1:6666"
EOF
}

Install(){
    if [[ ${OS} == "yum" ]]; then
        echo ""
        colorEcho $YELLOW "安装依赖中..."
        yum install unzip wget -y >/dev/null 2>&1
        echo ""
    else
        echo ""
        colorEcho $YELLOW "安装依赖中..."
        apt install unzip wget -y >/dev/null 2>&1
        echo ""
    fi
	Download
	Deploy
	echo ""
	colorEcho $BLUE " Realm已安装, 请修改配置文件中后启动"
}

Start){
    systemctl start realm
    colorEcho $BLUE " Realm已启动"
}

Restart){
    systemctl restart realm
    colorEcho $BLUE " Realm已启动"
}

Stop(){
    systemctl stop realm
    colorEcho $BLUE " Realm已停止"
}

Uninstall(){
    read -p $' 是否卸载Realm？[y/n]\n (默认n, 回车): ' answer
    if [[ "${answer}" = "y" ]]; then
        systemctl stop realm
        systemctl disable realm >/dev/null 2>&1
        rm -rf /etc/systemd/system/realm.service
        rm -rf /etc/realm
        systemctl daemon-reload
        colorEcho $BLUE " Realm已经卸载完毕"
    else
        colorEcho $BLUE " 取消卸载"
    fi
}

checkSystem
menu() {
	clear
	echo "################################"
	echo -e "#      ${RED}Realm一键安装脚本${PLAIN}       #"
	echo -e "# ${GREEN}作者${PLAIN}: 怠惰(Slotheve)         #"
	echo -e "# ${GREEN}网址${PLAIN}: https://slotheve.com   #"
	echo -e "# ${GREEN}频道${PLAIN}: https://t.me/SlothNews #"
	echo "################################"
	echo " ----------------------"
	echo -e "  ${GREEN}1.${PLAIN}  安装Realm"
	echo -e "  ${GREEN}2.${PLAIN}  ${RED}卸载Realm${PLAIN}"
	echo " ----------------------"
	echo -e "  ${GREEN}3.${PLAIN}  启动Realm"
	echo -e "  ${GREEN}4.${PLAIN}  重启Realm"
	echo -e "  ${GREEN}5.${PLAIN}  停止Realm"
	echo " ----------------------"
	echo -e "  ${GREEN}0.${PLAIN}  退出"
	echo ""
	echo -n " 当前状态："
	statusText
	echo 

	read -p " 请选择操作[0-5]：" answer
	case $answer in
		0)
			exit 0
			;;
		1)
			Install
			;;
		2)
			Uninstall
			;;
		3)
			Start
			;;
		4)
			Restart
			;;
		5)
			Stop
			;;
		*)
			colorEcho $RED " 请选择正确的操作！"
   			sleep 2s
			menu
			;;
	esac
}
menu
