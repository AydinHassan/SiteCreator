#!/bin/bash

if [[ "$UID" -ne 0 ]]; then 
    echo "Please run as root"
    exit
fi

if [ -z "$1" ]; then
    echo "Please pass site name as arg1"
    exit
fi

if [ -z "$2" ]; then
    echo "Please pass server name as arg2"
    exit
fi
siteName=$1
serverName=$2
sudo userdel $siteName
sudo rm "/etc/apache2/sites-available/$serverName"
sudo rm -rf "/var/www/$siteName"

sudo a2dissite $serverName
sudo service apache2 reload

mysql -u root -pnodeisthebestphpsux -e "DROP DATABASE $siteName"
