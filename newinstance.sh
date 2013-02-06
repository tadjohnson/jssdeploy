#! /bin/bash

#	Automated multi-instance JSS deployment script by John Kitzmiller
#	Version 2.2.6 - 2/6/12
#	The latest version of this script can be found at https://github.com/jkitzmiller/jssdeploy
#	Fully tested on Ubuntu 12.04 LTS with Tomcat 7 and Casper Suite v. 8.63

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
		echo $webapp not found!
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

	echo "Checking existence of database $dbName on host $dbHost"
	if [[ ! -z "`mysql -h $dbHost -u $dbUser -p$dbPass -qfsBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$dbName'" 2>&1`" ]];
		then
  			echo "Database connection test successful"
		else
 			echo DATABASE DOES NOT EXIST or USER $dbUser DOES NOT HAVE PERMISSION!
 			echo "Please ensure that user $dbUser has permission to access database $dbName on host $dbHost"
 			sleep 1
 			exit 1
	fi

# Check to make sure the instance doesn't already exist
# This gives an option to overwrite if desired

	if [ -d "/var/lib/tomcat7/webapps/$instanceName" ]; then
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

	if [ ! -d "$logPath/$instanceName" ];
		then
			echo Creating $logPath/$instanceName/
			mkdir $logPath/$instanceName
			chown tomcat7:tomcat7 $logPath/$instanceName
		else
			echo $logPath/$instanceName/ exists
	fi
	
	if [ ! -f "$logPath/$instanceName/JAMFSoftwareServer.log" ];
		then
			echo Creating $logPath/$instanceName/JAMFSoftwareServer.log
			touch $logPath/$instanceName/JAMFSoftwareServer.log
			chown tomcat7:tomcat7 $logPath/$instanceName/JAMFSoftwareServer.log
		else
			echo $logPath/$instanceName/JAMFSoftwareServer.log exists
	fi
	
	if [ ! -f "$logPath/$instanceName/jamfChangeManagement.log" ];
		then
			echo Creating $logPath/$instanceName/jamfChangeManagement.log
			touch $logPath/$instanceName/jamfChangeManagement.log
			chown tomcat7:tomcat7 $logPath/$instanceName/jamfChangeManagement.log
		else
			echo $logPath/$instanceName/jamfChangeManagement.log exists
	fi

# Deploy Tomcat JSS webapp with user-defined instance name

	if [ $overwriteInstance == OVERWRITE ]; then
		echo Removing existing webapp
		rm -rf /var/lib/tomcat7/webapps/$instanceName.war
		rm -rf /var/lib/tomcat7/webapps/$instanceName
	fi

	echo Deploying Tomcat webapp
	cp $webapp /var/lib/tomcat7/webapps/$instanceName.war
	
# Sleep timer to allow tomcat app to deploy before attempting to write to log4j files

	sleep 25

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