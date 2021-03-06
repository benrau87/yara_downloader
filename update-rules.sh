#!/bin/bash
####################################################################################################################
RULESFILE=/opt/yara-rules/  ##set rules file output


if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
gitdir=$PWD

##Logging setup
logfile=/var/log/yara-update.log
mkfifo ${logfile}.pipe
tee < ${logfile}.pipe $logfile &
exec &> ${logfile}.pipe
rm ${logfile}.pipe

##Functions
function print_status ()
{
    echo -e "\x1B[01;34m[*]\x1B[0m $1"
}

function print_good ()
{
    echo -e "\x1B[01;32m[*]\x1B[0m $1"
}

function print_error ()
{
    echo -e "\x1B[01;31m[*]\x1B[0m $1"
}

function print_notification ()
{
	echo -e "\x1B[01;33m[*]\x1B[0m $1"
}

function error_check
{

if [ $? -eq 0 ]; then
	print_good "$1 successfully."
else
	print_error "$1 failed. Please check $logfile for more details."
exit 1
fi

}

function install_packages()
{

apt-get update &>> $logfile && apt-get install -y --allow-unauthenticated ${@} &>> $logfile
error_check 'Package installation completed'

}

function dir_check()
{

if [ ! -d $1 ]; then
	print_notification "$1 does not exist. Creating.."
	mkdir -p $1
else
	print_notification "$1 already exists. (No problem, We'll use it anyhow)"
fi

}
export DEBIAN_FRONTEND=noninteractive

########################################
##BEGIN MAIN SCRIPT##
dir_check $RULESFILE
dir_check $RULESFILE/unparsed_rules
dir_check $RULESFILE/rules
dir_check $RULESFILE/rules/all
print_notification 'Downloading rules...this can take a while'
python scripts/GithubDownloader/git_downloader.py -r rules_repos.txt -w *.yar* -o $RULESFILE/unparsed_rules &>> $logfile
error_check 'Rules downloaded'
print_notification 'Sorting rules and checking for duplicates and bad files'
python scripts/yarasorter/sorter.py -f $RULESFILE/unparsed_rules/* -o $RULESFILE/rules -r -t &>> $logfile
rm -rf $RULESFILE/rules/Broken* &>> $logfile
rm -rf $RULESFILE/rules/Dup* &>> $logfile
rm -rf $RULESFILE/rules/Imports &>> $logfile
rm -rf $RULESFILE/rules/Meta* &>> $logfile
cp $RULESFILE/rules/**/** $RULESFILE/rules/all &>> $logfile
error_check 'Rules sorted and ready'
