#!/bin/sh

DEBUG=0 # 0-false 1-true
SSHUTTLE_USER="sshuttle" # user created specifically to operate sshuttle
SSHUTTLE_GROUP="sshuttle"
SSHUTTLE_HOME="/home/sshuttle"

RUNTIME_USER=`ls -ld $HOME | awk '{print $3}'`
RUNTIME_GROUP=`ls -ld $HOME | awk '{print $4}'`

# Create a new sshuttle user for control over sshuttle
create_user()
{
	[ $DEBUG -eq 1 ] && set -x
	groupadd $SSHUTTLE_GROUP
	mkdir $SSHUTTLE_HOME
	useradd -d $SSHUTTLE_HOME -g $SSHUTTLE_GROUP $SSHUTTLE_USER
	mkdir "$SSHUTTLE_HOME/.ssh"
	chown -R $SSHUTTLE_USER:$SSHUTTLE_GROUP $SSHUTTLE_HOME
	chmod 700 "$SSHUTTLE_HOME/.ssh"
}

# Create ssh key for ssh connection to remote server
create_key()
{
	if [ ! -f "$HOME/.ssh" ]; then
        echo ".ssh directory not found in $HOME directory. Creating new one."
        mkdir "$HOME/.ssh"
        chown -R $RUNTIME_USER:$RUNTIME_GROUP "$HOME/.ssh"
    fi
	[ $DEBUG -eq 1 ] && set -x
	if [ -f "$SSHUTTLE_HOME/.ssh/id_ed25519" ]; then
		echo "Key already exists"
		return
	fi
	# This key is created by user which run this script (login user) and it is then copied to local sshuttle user
	ssh-keygen -o -a 100 -t ed25519 -N '' -C 'sshuttle_key' -f $HOME/.ssh/id_ed25519 
	cp $HOME/.ssh/id_ed25519 $SSHUTTLE_HOME/.ssh/id_ed25519
	chown sshuttle:sshuttle $SSHUTTLE_HOME/.ssh/id_ed25519 
}

# Test connection to remote server using created ssh key
test_remote()
{
	[ $DEBUG -eq 1 ] && set -x
	# Update of fingerprint on sshuttle user
	su - $SSHUTTLE_USER -c "ssh-keygen -R $REMOTE_HOSTNAME #2>/dev/null" 
	su - $SSHUTTLE_USER -c "ssh-keyscan -t ed25519 -H $REMOTE_HOSTNAME >> $SSHUTTLE_HOME/.ssh/known_hosts"
	RC=$?
	if [ $RC -ne 0 ]; then
		echo "ERROR: Cannot create fingerprint."
	fi

	# Tests local sshuttle users connection to remote server using his ssh key
	OUT=`su - $SSHUTTLE_USER -c "ssh -i $SSHUTTLE_HOME/.ssh/id_ed25519 $REMOTE_USER@$REMOTE_HOSTNAME uname -n" 2>&1`
	RC=$?
	if [ $RC -ne 0 ]; then
		# ssh key wasn't found on remote server, it needs to be copied there
		echo "ERROR: $OUT"
		echo "Failed communication with remote server"
		echo "Coping ssh key to remote"
		copy_key_to_remote
	elif [ $RC -eq 0 ]; then
		# Communication was succesfully established using local sshuttle users ssh key
		echo "Remote server hostname: $OUT"
		echo "Succesful communication with remote server"
	fi
}

# Copy created ssh key to sshuttle .ssh directory on remote server
copy_key_to_remote(){
        [ $DEBUG -eq 1 ] && set -x
	# Update of fingerprint login user
        ssh-keygen -R $REMOTE_HOSTNAME #2>/dev/null
        ssh-keyscan -t ed25519 -H $REMOTE_HOSTNAME >> $HOME/.ssh/known_hosts
        echo "YOU NEED TO PROVIDE PASSWORD FOR REMOTE USER $REMOTE_USER ON REMOTE SERVER!"
        ssh-copy-id -i "$HOME/.ssh/id_ed25519" $REMOTE_USER@$REMOTE_HOSTNAME
}

# Create sudoers file for sshuttle user to give sshuttle user permissions
set_sudoers(){
	[ $DEBUG -eq 1 ] && set -x
	if [ -f "/etc/sudoers.d/sshuttle" ]; then
		echo "ERROR: Sudoers already set for user $SSHUTTLE_USER"
	
	else
		echo "Sudoers for user $SSHUTTLE_USER not set. Setting sudoers now"
		cp "./sshuttle" "/etc/sudoers.d/$SSHUTTLE_USER"
	fi
}

# Install sshuttle and its dependencies
install_sshuttle()
{
    [ $DEBUG -eq 1 ] && set -x
    apt list --installed 2>/dev/null | grep sshuttle # ask if sshuttle is already installed
    RC=$?
    if [ $RC -eq 0 ]; then
        echo "ERROR: Sshuttle already installed."

    elif [ $RC -ne 0 ]; then
        echo " Sshuttle is not installed. Installing now."
        apt install -f /home/wasadmin/sshuttle_install/sshuttle_bin/*
    fi

    RC=$?
    if [ $RC -ne 0 ]; then
        echo " Sshuttle is was not installed. You need to try again later."
    fi
}


# Create sshuttle as a service by coping files from script directory
create_sshuttle_service()
{
	[ $DEBUG -eq 1 ] && set -x
	cp "./sshuttle.conf" "$SSHUTTLE_HOME/sshuttle.conf"
	cp "./sshuttle.sh" "$SSHUTTLE_HOME/sshuttle.sh"
	cp "./sshuttle.service" "/etc/systemd/system/sshuttle.service"
	
	# Systemd needs to be restarted for service to work
	echo "Reloading systemd"
	systemctl daemon-reload

	#Asks if sshuttle service is properly instaled
	systemctl status sshuttle | grep sshuttle.service
	RC=$?
	if [ $RC -eq 0 ]; then
        echo "Sshuttle service was correctly created."
		echo "Enabling sshuttle"
	        systemctl enable sshuttle # Commands sshuttle service to run on system start

        elif [ $RC -ne 0 ]; then
            echo "ERROR: Sshuttle service was not correctly created"
        fi

}

# Edit sshuttle config file with parameters from variables
edit_config()
{
	[ $DEBUG -eq 1 ] && set -x
	#wasadmin@10.0.2.5,0/0 -x 10.0.2.5 -x 10.0.2.6:22
	if [ -f  "$SSHUTTLE_HOME/sshuttle.conf" ]; then
		echo "Config file found checking for remote host"
		grep "$REMOTE_USER@$REMOTE_HOSTNAME," $SSHUTTLE_HOME/sshuttle.conf
		RC=$?
		if [ $RC -eq 0 ]; then
			echo "Remote $REMOTE_USER@$REMOTE_HOSTNAME found in config file."
			return

       		elif [ $RC -ne 0 ]; then
			echo "Remote $REMOTE_USER@$REMOTE_HOSTNAME not found, adding to config file"
        		LOCAL_HOSTNAME=`hostname -I | tr -d ' '`
			echo "$REMOTE_USER@$REMOTE_HOSTNAME,0/0 -x $REMOTE_HOSTNAME -x $LOCAL_HOSTNAME:22" >> "$SSHUTTLE_HOME/sshuttle.conf"
        	fi
	else
		echo "Config file not found. Creating new one with $REMOTE_USER@$REMOTE_HOSTNAME parameters"
		LOCAL_HOSTNAME=`hostname -I | tr -d ' '`
		echo "#<username>@<server_hostname>,<IP to tunnel 0/0 = all> -x <IP and ports to exclude>" > "$SSHUTTLE_HOME/sshuttle.conf"
		echo "$REMOTE_USER@$REMOTE_HOSTNAME,0/0 -x $REMOTE_HOSTNAME -x $LOCAL_HOSTNAME:22" >> "$SSHUTTLE_HOME/sshuttle.conf"

	fi
}

# Prints help
usage()
{
	echo "sshuttle_install_script.sh [-dh] -u <Remote username> -s <Remote hostname>"
}

# Parsing from command line
if [ $# -eq 0 ]; then
	usage
	exit 0
fi
while getopts du:s:vq Opt; do
  case "$Opt" in
    d)  DEBUG=1 ;;
    u)  REMOTE_USER=$OPTARG;;
    s)  REMOTE_HOSTNAME=$OPTARG;;
    h)
        usage
        exit 0
        ;;
    \?) usage; exit 1 ;;
  esac
done
shift `expr $OPTIND - 1`

# If x and s is emtz script wont run
if [ "x$REMOTE_USER" = "x" ]; then
	usage
	exit 0
fi

if [ "s$REMOTE_HOSTNAME" = "s" ]; then
	usage
	exit 0
fi

echo "Script modified for server: $REMOTE_USER@$REMOTE_HOSTNAME"

echo "Add user sshuttle"
create_user
echo "Creating ssh key"
create_key
echo "Testing remote communication"
test_remote
echo "Setting sudoers" 
set_sudoers
echo "Installing sshuttle"
install_sshuttle
echo "Creating sshuttle service"
create_sshuttle_service
echo "Editing config"
edit_config
