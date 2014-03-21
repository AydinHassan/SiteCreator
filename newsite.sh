#!/bin/bash

sudo rm ~/.rnd
siteDir="/var/www"
serverAdmin="shane.osbourne8@gmail.com"

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

if [ -d  "$siteDir/$siteName" ]; then
    echo "Site Directory exists - try another"
    exit
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
if [ "$3" == "-d" ]; then
    echo -e "Creating database..\n"
    mysql -u root -pnodeisthebestphpsux -e "CREATE DATABASE $siteName; GRANT ALL PRIVILEGES ON $siteName.* TO $siteName@localhost IDENTIFIED BY '$password'"
    echo -e "Database Name: $siteName\n"
    echo -e "Database User: $siteName@localhost\n"
    echo -e "Database Password: $password\n"
fi 

