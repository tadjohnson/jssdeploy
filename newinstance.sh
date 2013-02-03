#! /bin/sh

#	Automated multi-instance JSS deployment script by John Kitzmiller
#	Version 2.2.4 - 2/2/12
#	The latest version of this script can be found at https://github.com/jkitzmiller/jssdeploy
#	Fully tested on Ubuntu 12.04 LTS with Tomcat 7 and Casper Suite v. 8.62

#	This script should be run as root

# Declare Variables
# Edit these to suit your environment

	#The FQDN or IP of your mySQL database host
	dbHost="localhost"
	#Path where you store your JSS logs (do not leave a trailing / at the end of your path)
	logPath="/var/log/JSS"
	#Path to your ROOT.war file
	webapp="/usr/jsscomponents/ROOT.war"
	
# Check to make sure ROOT.war exists at the specified path

	if [ ! -f $webapp ]; then
		echo $webapp does not exist!
		sleep 1
		echo Aborting!
		sleep 1
		exit 1
	fi

# Get JSS instance name and database connection information from user

	read -p "Instance Name: " instanceName
	read -p "Database Name: " dbName
	read -p "Database User: " dbUser
	read -s -p "Database Password: " dbPass
	
# Check connection to MySQL server using user-defined credentials

	echo Testing database username and password
	until mysql -h $dbHost -u $dbUser -p$dbPass  -e ";" ; do
		echo Invalid database username or password. Please retry.
		read -p "Database User: " dbUser
		read -s -p "Database Password: " dbPass
	done
	
# Check to make sure the user-defined database exists

	echo Checking existence of $dbName on $dbHost
	if [[ ! -z "`mysql -h $dbHost -u $dbUser -p$dbPass -qfsBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$dbName'" 2>&1`" ]];
		then
  			echo "Database connection test successful"
		else
 			echo "DATABASE DOES NOT EXIST or USER $dbUser DOES NOT HAVE PERMISSION!"
 			sleep 1
 			exit 1
	fi

# Check to make sure the instance doesn't already exist
# This gives an option to overwrite if desired

	if [ -d "/var/lib/tomcat7/$instanceName" ]; then
		echo A JSS instance called $instanceName already exists!
		sleep 1
		read -p "Type 'OVERWRITE' to overwrite this instance: " overwriteInstance
			if [ $overwriteInstance == OVERWRITE ]; then
				echo Overwriting instance $instanceName!!!
			else
				echo Aborting!
				sleep 1
				exit 1
			fi
	fi

# Check to make sure the directory defined in $logPath exists

	if [ ! -d "$logPath" ]; then
		echo $logPath does not exist!
		echo Creating $logPath
		mkdir -p $logPath
	fi
					
# Create unique logs for the JSS instance
# This will create a new directory at the path specified in logPath above using your instance name

	echo Creating $logPath/$instanceName
	mkdir $logPath/$instanceName
	echo Creating JAMFSoftwareServer.log
	touch $logPath/$instanceName/JAMFSoftwareServer.log
	echo Creating jamfChangeManagement.log
	touch $logPath/$instanceName/jamfChangeManagement.log
	echo Applying permissions to log files
	chown tomcat7:tomcat7 $logPath/$instanceName/*

# Deploy Tomcat JSS webapp with user-defined instance name

	echo Deploying Tomcat webapp
	cp $webapp /var/lib/tomcat7/webapps/$instanceName.war
	
# Sleep timer to allow tomcat app to deploy before attempting to write to log4j files

	sleep 15

# Change log4j files to point logs to new log locations

	echo Updating log4j files
	sed -e "s@log4j.appender.JAMFCMFILE.File=.*@log4j.appender.JAMFCMFILE.File=$logPath/$instanceName/jamfChangeManagement.log@" -e "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$instanceName/JAMFSoftwareServer.log@" -i /var/lib/tomcat7/webapps/$instanceName/WEB-INF/classes/log4j.JAMFCMFILE.properties
	sed "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$instanceName/JAMFSoftwareServer.log@" -i /var/lib/tomcat7/webapps/$instanceName/WEB-INF/classes/log4j.JAMFCMSYSLOG.properties
	sed -e "s@log4j.appender.JAMFCMFILE.File=.*@log4j.appender.JAMFCMFILE.File=$logPath/$instanceName/jamfChangeManagement.log@" -e "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$instanceName/JAMFSoftwareServer.log@" -i /var/lib/tomcat7/webapps/$instanceName/WEB-INF/classes/log4j.properties

# Add database connection info to JSS instance

	echo Writing database connection settings
	sed -e "s@<ServerName>.*@<ServerName>$dbHost</ServerName>@" -e "s@<DataBaseName>.*@<DataBaseName>$dbName</DataBaseName>@" -e "s@<DataBaseUser>.*@<DataBaseUser>$dbUser</DataBaseUser>@" -e "s@<DataBasePassword>.*@<DataBasePassword>$dbPass</DataBasePassword>@" -i /var/lib/tomcat7/webapps/$instanceName/WEB-INF/xml/DataBase.xml

# Restart Tomcat

	echo Restarting Tomcat
	service tomcat7 restart

# Enjoy your burrito

	echo Configuration complete. Enjoy your burrito.