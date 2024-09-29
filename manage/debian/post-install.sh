#!/usr/bin/env bash

# Download and run script:
# bash -c "$(wget -qLO - https://github.com/rahulsrma26/scripts/raw/main/manage/debian/post-install.sh)"

echo "Updating and upgrading system"
apt update && apt upgrade -y

echo "Do you want to setup sudo user? (y/n)"
read -r choice

if [ "$choice" = "y" ] || [ "$choice" = "Y" ]
then
    apt install sudo -y
    echo "Enter sudo username (e.g. foo): "
    read -r username
    if [ "$(grep -ic "${username}" /etc/passwd)" -eq 1 ]
    then
        echo "User exist."
    else
        echo "User ${username} not found. Creating a new one."
        adduser --gecos "" "${username}"
    fi
    echo "Adding user to sudo"
    usermod -aG sudo "${username}"
else
    echo "Skipping sudo setup"
fi

echo "Do you want to set static ip? (y/n)"
read -r choice

if [ "$choice" = "y" ] || [ "$choice" = "Y" ]
then
    echo "Enter ip/subnet (e.g. 192.168.0.10/24): "
    read -r ADDRESS
    echo "Enter gateway (e.g. 192.168.0.1): "
    read -r GATEWAY
    DATA="static\\n\\taddress ${ADDRESS}\\n\\tgateway ${GATEWAY}\\n"
    sed -i -e "s/dhcp/${DATA}/" /etc/network/interfaces
    echo "Restarting networking service"
    systemctl restart networking
else
    echo "Skipping static ip setup"
fi
