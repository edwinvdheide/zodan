#!/bin/bash
name=${1}
devenv=${1}.dev

# BEGIN CONFIG SHIT #
host=127.0.1.1
hostsfile=/etc/hosts
defaultconf=/etc/apache2/sites-enabled/000-default.conf
dbuser=root
dbpassword=test
relativepath=/var/www/dev/devenv/		# this is the relative path to the dev env...
dbfile=${relativepath}/${name}/public_html/sql/db.sql
configlocal=${relativepath}/${name}/public_html/config.local.php

# END CONFIG SHIT #

# check if directory exists
if [ ! -d "$relativepath" ]; then
      echo "Directory $relativepath does not exists. Please check script file and alter the path"
      echo "Thank you"
      exit 1
fi

#check db connection. Google was my friend...
DB_con_ok=$(mysql -u $dbuser --password=$dbpassword -e "show databases;"|grep "mysql")
if [[ $DB_con_ok != "mysql" ]]
then
echo "The DB connection could not be established. Check you username and password and try again."
echo "Thank you"
exit 1
fi


# am I root / sudo?
if [ "$(whoami)" != "root" ]; then
      echo "Please execute this script as root / sudo user"
      echo "Thank you"
      exit 1
fi

if [ -z "${name}" ]; then
  echo "No name given. Aborting"
  exit 1
fi

# goto oswdev directory and fetch the repo
echo "running oswdev add ${1}"

cd ../dev/devenv/
./oswdev add ${1}

# check db patch file. This needs to be done AFTER getting the repo from github...
if [ ! -f ${dbfile} ]; then
    echo "Could not locate database file! (db.sql)"
    exit
fi

# set up host
echo "${host} ${name}.dev" >> ${hostsfile}

# set up virtual host config apacha
echo "# CONFIG ADDED BY GETREPO SCRIPT #" >> ${defaultconf}
echo "<VirtualHost *:80>" >> ${defaultconf}
echo "	ServerAdmin webmaster@localhost" >> ${defaultconf}
echo "	ServerName ${1}.dev" >> ${defaultconf}
echo "	DocumentRoot /var/www/dev/devenv/${1}/public_html/" >> ${defaultconf}
echo "	<Directory />" >> ${defaultconf}
echo "		Options FollowSymLinks" >> ${defaultconf}
echo "		AllowOverride All" >> ${defaultconf}
echo "	</Directory>" >> ${defaultconf}
echo "	<Directory /var/www/>" >> ${defaultconf}
echo "		Options Indexes FollowSymLinks MultiViews" >> ${defaultconf}
echo "		AllowOverride All" >> ${defaultconf}
echo "		Order allow,deny" >> ${defaultconf}
echo "		allow from all" >> ${defaultconf}
echo "	</Directory>" >> ${defaultconf}
echo "	ErrorLog ${APACHE_LOG_DIR}/${1}-error.log" >> ${defaultconf}
echo "	LogLevel warn" >> ${defaultconf}
echo "	CustomLog ${APACHE_LOG_DIR}/${1}-access.log combined" >> ${defaultconf}
echo "</VirtualHost>" >> ${defaultconf}

# import db
mysql -u $dbuser --password=$dbpassword -e "create database $name" < ${dbfile} 
mysql -u $dbuser --password=$dbpassword --database=$name < ${dbfile} 

# write config local file
echo "<?php" >  ${configlocal}		# create new config file
echo "	\$sql_host = 'localhost'; ">> ${configlocal}
echo "	\$sql_user = '${dbuser}'; ">> ${configlocal}
echo "	\$sql_db = '${name}'; ">> ${configlocal}
echo "	\$sql_password = '${dbpassword}'; ">> ${configlocal}
echo "?>" >>  ${configlocal}

# thats should be it I think...

# just restart apache and we'r all set
service apache2 restart
