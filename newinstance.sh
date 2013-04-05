#! /bin/bash

#	Automated multi-context JSS deployment script by John Kitzmiller

#	http://www.johnkitzmiller.com

#	The latest version of this script can be found at https://github.com/jkitzmiller/jssdeploy

#	Version 2.7.3 - 4/5/13

#	Tested on Ubuntu 12.04 LTS with Tomcat 7 and Casper Suite v. 8.64

#	This script assumes Tomcat7 and MySQL client are installed

#	This script should be run as root

##########################################################################################
############### Edit the following variables to suit your environment ####################
##########################################################################################

	# The FQDN or IP of your MySQL database host
	
	dbHost="localhost"
	
	# Path where you store your JSS logs (do not leave a trailing / at the end of your path)
	
	logPath="/var/log/JSS"
	
	# Path to your .war file
	
	webapp="/usr/local/jssdeploy/ROOT.war"
	
	# Path to Tomcat directory (do not leave a trailing / at the end of your path)
	
	tomcatPath="/var/lib/tomcat7"
	
	# Path to dump MySQL database (do not leave a trailing / at the end of your path)
	
	dbDump="/tmp"
	
##########################################################################################
########### It is not recommended that you make any changes after this line ##############
##########################################################################################
	
# Check to make sure ROOT.war exists at the specified path

	if [ ! -f $webapp ];
		then
			echo $webapp not found!
			sleep 1
			echo Aborting!
			sleep 1
			exit 1
	fi

# Get JSS instance name and database connection information from user

	clear
	echo "Please enter a name for this instance."
	echo
	read -p "Instance Name: " instanceName
	clear
	echo "Please enter the name of the database."
	echo
	read -p "Database Name: " dbName
	clear
	echo "Please enter the name of the database user."
	echo
	read -p "Database User: " dbUser
	clear
	echo "Please enter the database user's password."
	echo
	read -s -p "Database Password: " dbPass
	
# Check connection to MySQL server using user-defined credentials

	echo Testing database username and password
	until mysql -h $dbHost -u $dbUser -p$dbPass  -e ";" ;
		do
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
	
# Dump MySQL database to directory declared above

	dbBackup=""
	
	until [[ $dbBackup == y || $dbBackup == n || $dbBackup == Y || $dbBackup == N ]];
		do
			read -p "Would you like to back up your database before proceeding? [y/n]: " dbBackup
	done
	
	if [[ $dbBackup == y || $dbBackup == Y ]];
		then
			dateTime=$(date '+%Y%m%d_%H%M%S')
			echo Dumping MySQL database...
			mysqldump -h $dbHost -u $dbUser -p$dbPass $dbName > $dbDump/$dateTime_$dbName.sql
			echo Database dumped to $dbDump/$dateTime_$dbName.sql
		else
			dbBackupSure=""
			until [[ $dbBackupSure == y || $dbBackupSure == n || $dbBackupSure == Y || $dbBackupSure == N ]];
				do
					echo Database will not be backed up!
					read -p "Are you sure you want to proceed? [y/n]: " dbBackupSure
		done
		
		if [[ $dbBackupSure == y || $dbBackupSure == Y ]];
			then
				echo Proceeding without backing up the database!
			else
				echo Aborting!
				sleep 1
				exit 1
		fi
	fi

# Check to make sure the instance doesn't already exist
# This gives an option to overwrite if desired

	if [ -d "$tomcatPath/webapps/$instanceName" ];
		then
			echo A JSS instance called $instanceName already exists!
			sleep 1
			read -p "Type 'OVERWRITE' to overwrite this instance: " overwriteInstance
				if [ $overwriteInstance == OVERWRITE ];
					then
						echo Overwriting instance $instanceName!!!
					else
						echo Aborting!
						sleep 1
						exit 1
				fi
	fi

# Check to make sure the directory defined in $logPath exists

	until [ -d "$logPath" ];
		do
			createLogPath=""
			until [[ $createLogPath == y || $createLogPath == Y || $createLogPath == n || $createLogPath == N ]];
			do
				echo $logPath does not exist!
				read -p "Would you like to create it? [y/n]: " createLogPath
			done
			
			if [[ $createLogPath == Y || $createLogPath == y ]];
			then
				echo Creating $logPath
				mkdir -p $logPath
			else
				echo
				echo "Please specify a new directory for log files."
				echo "Make sure not to leave a trailing / at the end of your path."
				echo
				read -p "Log directory: " logPath
			fi
		done
					
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
	
# Check to make sure Tomcat is running before deploying webapp
# Gives the user an option to try to start Tomcat if it isn't running

	tomcatStat=`service tomcat7 status | grep pid | awk '{print $6}'`

	if [[ $tomcatStat != running ]];
		then
			echo Tomcat does not appear to be running.
			startTomcat=""
			until [[ $startTomcat == y || $startTomcat == Y || $startTomcat == n || $startTomcat == N ]];
				do
					read -p "Would you like to try to start Tomcat? [y/n]: " startTomcat
			done
	
		if [[ $startTomcat == y || $startTomcat == Y ]];
			then
				service tomcat7 start
				tomcatStat=`service tomcat7 status | grep pid | awk '{print $6}'`
					if [ $tomcatStat != running ];
						then
							echo Unable to start Tomcat.
							echo Aborting!
							sleep 1
							exit 1
					fi
			else
				echo "App will not deploy properly if Tomcat is not running."
				echo "Please start Tomcat before running this script."
				sleep 1
				exit 1
		fi
	fi

# Deploy JSS webapp with user-defined instance name

	if [[ $overwriteInstance == OVERWRITE ]];
		then
			echo Removing existing webapp
			rm -rf $tomcatPath/webapps/$instanceName.war
			rm -rf $tomcatPath/webapps/$instanceName
	fi

	echo Deploying Tomcat webapp
	cp $webapp $tomcatPath/webapps/$instanceName.war
	
# Sleep timer to allow tomcat app to deploy

	counter=0
	while [ $counter -lt 12 ];
		do
			if [ ! -d "$tomcatPath/webapps/$instanceName" ];
				then
					echo "Waiting for Tomcat webapp to deploy..."
					sleep 5
					let counter=counter+1
				else
					let counter=12
			fi
	done
	
	if [ ! -d "$tomcatPath/webapps/$instanceName" ];
		then
			echo Something is wrong...
			echo Tomcat webapp has not deployed.
			echo Aborting!
			sleep 1
			exit 1
		else
			echo Webapp has deployed.
	fi

# Change log4j files to point logs to new log locations

	echo Updating log4j files
	sed -e "s@log4j.appender.JAMFCMFILE.File=.*@log4j.appender.JAMFCMFILE.File=$logPath/$instanceName/jamfChangeManagement.log@" -e "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$instanceName/JAMFSoftwareServer.log@" -i $tomcatPath/webapps/$instanceName/WEB-INF/classes/log4j.JAMFCMFILE.properties
	sed "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$instanceName/JAMFSoftwareServer.log@" -i $tomcatPath/webapps/$instanceName/WEB-INF/classes/log4j.JAMFCMSYSLOG.properties
	sed -e "s@log4j.appender.JAMFCMFILE.File=.*@log4j.appender.JAMFCMFILE.File=$logPath/$instanceName/jamfChangeManagement.log@" -e "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$instanceName/JAMFSoftwareServer.log@" -i $tomcatPath/webapps/$instanceName/WEB-INF/classes/log4j.properties

# Add database connection info to JSS instance

	echo Writing database connection settings
	sed -e "s@<ServerName>.*@<ServerName>$dbHost</ServerName>@" -e "s@<DataBaseName>.*@<DataBaseName>$dbName</DataBaseName>@" -e "s@<DataBaseUser>.*@<DataBaseUser>$dbUser</DataBaseUser>@" -e "s@<DataBasePassword>.*@<DataBasePassword>$dbPass</DataBasePassword>@" -i $tomcatPath/webapps/$instanceName/WEB-INF/xml/DataBase.xml

# Restart Tomcat

	echo Restarting Tomcat
	service tomcat7 restart

# Enjoy your burrito

	echo Configuration complete. Enjoy your burrito.