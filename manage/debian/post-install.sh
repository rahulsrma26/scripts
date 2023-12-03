#!/usr/bin/env bash
apt update
apt install sudo -y

read -p "Enter sudo username (e.g. admin): " USERNAME
adduser --gecos "" ${USERNAME}
usermod -aG sudo ${USERNAME}

read -p "Enter ip/subnet (e.g. 192.168.0.10/24): " ADDRESS
read -p "Enter gateway (e.g. 192.168.0.1): " GATEWAY

DATA="static\\n\\taddress ${ADDRESS}\\n\\tgateway ${GATEWAY}\\n"
sed -i -e "s/dhcp/${DATA}/" /etc/network/interfaces
systemctl restart networking
