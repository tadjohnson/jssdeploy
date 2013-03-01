JSSDeploy
=========

The purpose of this script is to automate the installation of JAMF's manual installer in a multi-context environment.

The script is tested using the latest version of the JSS, Ubuntu Server 12.04, and MySQL 5.5. Use in other environments at your own risk, and please test this script before using it in your production environments.


Setup

The script requires a few things to be in place to operate correctly.

-Tomcat 7 should be installed on your server.

-MySQL should be installed on your database server.

-A copy of the JSS ROOT.war needs to be stored locally on the server. By default, the script will look for it in /usr/local/jssdeploy, however this is stored in a variable and can be changed if needed.

-The script can be stored wherever you'd like. It does not need to be in the same location as your ROOT.war file

-This script must be run as root.



User Definable Variables

dbHost - set this to the DNS name or IP of your MySQL server. If you're running MySQL on the same server, you can leave this set to localhost.

webapp - set this to the location or your ROOT.war file. The default location is recommended.

logPath - where you want to store logs for the JSS. The default location is /var/log/jss.

tomcatPath - this was added for environments where the root instance was installed by JAMF's installer. If you're using a default installation of Tomcat 7, there is no reason to change this.

dbDump - the script gives an option to make a dump of the database before proceeding. Enter the path of where you wish to store the dump.
