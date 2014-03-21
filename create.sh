#!/bin/bash
#
# Creates a new site, sets up git
# and configures database if specified
# Author: Aydin Hassan <aydin@hotmail.co.uk>
#

usage()
{

  echo '
  usage: $0 --siteName sitename --domain domain options

  Create a new site

  OPTIONS:
     -?, --help        Show this message
     -d                If specified will create a database and user (OPTIONAL)

  Config is read from config.sh in the same directory. It should contain
  the web root and server admin details, and MySQL details if db options is used.
'
}

if [[ "$1" ==  "-?" || "$1" ==  "--help" ||  "$1" ==  "?" ||  "$1" ==  "help" ]]; then
    usage
    exit 0
fi

createDatabase=false
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
            createDatabase=true
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
if [[ -z "$siteDir" ]]; then
    echo -e "Config does not contain Webroot\n"
    exit 1
fi

if [[ -z "$serverAdmin" ]]; then
    echo -e "Config does not contain Server Admin\n"
    exit 1
fi

if [[ "$createDatabase" == "true" ]]; then

    if ! which mysql >/dev/null; then
        echo -e "MySQL does not exist on the system\n"
        exit 1
    fi
    if [[ -z "$mysqlUser"  || -z "$mysqlPass" ]]; then
        echo -e "Config does not contain MySQL credentials\n"
        exit 1
    fi
fi

#must be run as root
if [[ "$UID" -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

#remove openssl rand config - throws errors when
#generating password
if [[ -e ~/.rnd ]]; then
   sudo rm ~/.rnd
fi

#Validate directories and stuff
if [ ! -d  "$siteDir" ]; then
    echo -e "Site Directory root does not exist - Is apache installed?\n"
    exit 1
fi

if ! which apache2 >/dev/null; then
    echo -e "Apache2 does not exist on the system\n"
    exit 1
fi

if [ -d  "$siteDir/$siteName" ]; then
    echo -e "Site Directory exists - try another\n"
    exit 1
fi

if id -u $siteName >/dev/null 2>&1; then
     echo -e "User exists - try another\n"
     exit 1
fi

if [[ "$createDatabase" == "true" ]]; then
    dbExists=$(mysql -u $mysqlUser -p$mysqlPass --batch --skip-column-names -e "SHOW DATABASES LIKE '"$siteName"';" | grep -q "$siteName"; echo "$?")
    if [[ "$dbExists" == "0" ]];then
        echo "A database with the name $siteName already exists. exiting"
        exit 1
    fi
fi

if [[ -e "/etc/apache2/sites-available/$serverName" ]]; then
    echo -e "Vhost exists already\n"
    exit 1
fi

postReceive="#!/bin/sh\nGIT_WORK_TREE=/var/www/$1/public git checkout -f"
mkdir "$siteDir/$siteName"
cd "$siteDir/$siteName"
mkdir public
mkdir .git
cd .git
git init --bare
cd hooks/
echo $postReceive > post-receive
chmod +x post-receive
chmod 775 "$siteDir/$siteName"

cd $siteDir
sudo useradd -r -s /bin/false $siteName
sudo usermod -a -G www-data $siteName
sudo chown -R $siteName:www-data $siteName

#build vhost
vhostTemplate="
<VirtualHost *:80>
    ServerName $serverName
    ServerAdmin $serverAdmin

    DocumentRoot $siteDir/$siteName
    <Directory $siteDir/$siteName>
            AllowOverride All
            Order allow,deny
            allow from all
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/$siteName_error.log

    # Possible values include: debug, info, notice, warn, error, crit,
    # alert, emerg.
    LogLevel warn

    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
"
echo "$vhostTemplate" >> /etc/apache2/sites-available/$serverName

#enable site and restart apache
sudo a2ensite $serverName
sudo service apache2 reload

#mysql
password=$(openssl rand -base64 20)
if [ "$createDatabase" == "true" ]; then
    echo -e "Creating database..\n"
    mysql -u $mysqlUser -p$mysqlPass -e "CREATE DATABASE $siteName; GRANT ALL PRIVILEGES ON $siteName.* TO $siteName@localhost IDENTIFIED BY '$password'"
    echo -e "Database Name: $siteName"
    echo -e "Database User: $siteName@localhost"
    echo -e "Database Password: $password"
fi 

