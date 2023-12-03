#!/usr/bin/env bash
apt update
apt install sudo -y
adduser admin
usermod -aG sudo admin

read -p "Enter ip/subnet (e.g. 192.168.0.10/24): " ADDRESS
read -p "Enter gateway (e.g. 192.168.0.1): " GATEWAY

DATA="static\\n\\taddress ${ADDRESS}"
sed "s/dhcp/${DATA}/" /etc/network/interfaces
systemctl restart networking
