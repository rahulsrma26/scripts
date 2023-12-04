#!/usr/bin/env bash
apt update
apt install sudo -y

read -p "Enter sudo username (e.g. foo): " username

if [ $(grep -ic "${username}" /etc/passwd) -eq 1 ]
then
    echo "User exist."
else
    echo "User ${username} not found. Creating a new one."
    adduser --gecos "" ${USERNAME}
fi
echo "Adding user to sudo"
usermod -aG sudo ${username}
#chown -R ${USERNAME}: /home/${USERNAME}

read -p "Enter ip/subnet (e.g. 192.168.0.10/24): " ADDRESS
read -p "Enter gateway (e.g. 192.168.0.1): " GATEWAY

DATA="static\\n\\taddress ${ADDRESS}\\n\\tgateway ${GATEWAY}\\n"
sed -i -e "s/dhcp/${DATA}/" /etc/network/interfaces

echo "Restarting networking service"
systemctl restart networking
