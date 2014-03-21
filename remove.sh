#!/bin/bash
#
# Removes a site, deletes user and database
# Author: Aydin Hassan <aydin@hotmail.co.uk>
#

usage()
{

  echo '
  usage: $0 --siteName sitename --domain domain options

  Create a new site

  OPTIONS:
     -?, --help        Show this message
     -d                If specified will delete the database  (OPTIONAL)

  Config is read from config.sh in the same directory. It should contain
  the web root and server admin details, and MySQL details if db options is used.
'
}

if [[ "$1" ==  "-?" || "$1" ==  "--help" ||  "$1" ==  "?" ||  "$1" ==  "help" ]]; then
    usage
    exit 0
fi

dropDatabase=false
#Parse args
while [[ $# > 0 ]]
do
    key="$1"
    shift

    case $key in
        --siteName)
            siteName="$1"
            shift
            ;;
        --domain)
            serverName="$1"
            shift
            ;;
        -d)
            dropDatabase=true
            ;;
        *)
            # unknown option
            usage
            exit 0
        ;;
    esac
done

#if we didn't find name and host - quit
if [[ -z "$siteName"  || -z "$serverName" ]]; then
    usage
    exit 1
fi

#Load and validate config
if [[ ! -e "config.sh" ]]; then
    echo -e "Config file does not exist\n"
    exit 1
fi

source "config.sh"

if [[ "dropDatabase" == "true" ]]; then

    if ! which mysql >/dev/null; then
        echo -e "MySQL does not exist on the system\n"
        exit 1
    fi
    if [[ -z "$mysqlUser"  || -z "$mysqlPass" ]]; then
        echo -e "Config does not contain MySQL credentials\n"
        exit 1
    fi
fi

if [[ "$UID" -ne 0 ]]; then
    echo "Please run as root"
    exit
fi

sudo userdel $siteName
sudo rm "/etc/apache2/sites-available/$serverName"
sudo rm -rf "/var/www/$siteName"

sudo a2dissite $serverName
sudo service apache2 reload

if [ "dropDatabase" == "true" ]; then
    mysql -u $mysqlUser -p$mysqlPass -e "DROP DATABASE $siteName"
fi