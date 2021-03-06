#!/bin/bash

USERNAME=""
PASSWORD=""
MASTER_URL=""
PV_SIZE="1Gi"
NFS_PATH="/exports"
#NFS_PATH_PREFIX="vol-"
NFS_VOL_NUMBER="30"
NFS_EXPORT_FILE_LOCATION="/etc/exports.d"
NFS_EXPORT_FILE_NAME=""
NFS_VOLUME_NAME="myvolume"
NFS_SERVER=""
PV_ACCESS_MODE="ReadWriteOnce"        #ReadOnlyMany, ReadWriteMany, ReadWriteOnce
PV_RECLAIM_POLICY="Recycle"
SSH_PORT="22"
SSH_USERNAME=""
#SSH_PASSWORD=""
SSH_KEYFILE=""
IS_NFS_SERVER_REMOTE="Yes"
SKIP_PV="No"
SIMULATE_MODE="no"
SSH_COMMAND=""
SSH_SUDO="yes"
SSH_SUDO_COMMAND=""

function printUsage(){
    echo
    echo "This script helps to create NFS volume and PV for OCP environment."
    echo "You can also use this script to create NFS without creating PV."
    echo "If you are creating NFS on remote NFS server, it is required to use the passwordless "
    echo "public key login or use a key file."
    echo  
    echo "Example usage:"
    echo "To create both PV and NFS with remote NFS server :"
    echo "    ./createPV.sh -u admin -p r3dh4t1! -url https://master.example.com:8443 --nfs-server nfs.example.com --nfs-export-filename myvolume.exports --ssh-username root"
    echo "To create NFS only at remote NFS server with key file:"
    echo "    ./createPV.sh --skip-pv yes --nfs-server nfs.example.com --nfs-export-filename myvolume.exports --ssh-username root --ssh-keyfile /pah/to/my/keyfile.pem"
    echo "To create NFS locally without PV:"
    echo "    ./createPV.sh --skip-pv yes --is-nfs-server-remote no --nfs-export-filename myvolume.exports"
    echo
    echo "Parameters:"
    echo "-u    Username to authenticate to the OCP"
    echo "-p    Password to authenticate to the OCP"
    echo "-url  OCP Master node url"
    echo "--nfs-server    NFS Server host name"
    echo "--nfs-export-filename    Export file name, file name ends with .exports"
    echo "--ssh-port   SSH port. Default:$SSH_PORT"
    echo "--ssh-username     SSH Username. Default:$SSH_USERNAME"
#    echo "--ssh-password     SSH Password. Default: $SSH_PASSWORD"
    echo "--ssh-keyfile     SSH Key File. Default:$SSH_KEYFILE"
    echo "--ssh-sudo     Default:$SSH_SUDO. Enable sudo to run command for ssh"
    echo "-s    PV size. e.g. 1Gi, 512Mi Default:$PV_SIZE"
    echo "--nfs-path    NFS PATH to create the volume. This path will be created if not exists. Default: $NFS_PATH"
#    echo "--nfs-path-prefix    NFS PATH Prefix to create the shared volume. Default: $NFS_PATH_PREFIX"
    echo "--nfs-vol-name    NFS VOLUME NAME to be created. Default: $NFS_VOLUME_NAME"
    echo "--nfs-vol-no    Number of NFS Volume to create. Default: $NFS_VOL_NUMBER"
    echo "--nfs-export-filepath    Default path to create export file. Default: $NFS_EXPORT_FILE_LOCATION"
    echo "--pv-access-mode    PV Access Mode. Default:$PV_ACCESS_MODE. Possible values: ReadOnlyMany, ReadWriteMany, ReadWriteOnce"
    echo "--pv-reclaim-policy    PV Reclaim Policy. Default: $PV_RECLAIM_POLICY. Possible values: Retain, Recycle"
    echo "--is-nfs-server-remote   Default:$IS_NFS_SERVER_REMOTE. 'Yes' if NFS server is remote, ssh will be used to create NFS mounts. 'No' if server local."
    echo "--skip-pv   Default:$SKIP_PV. 'Yes' if you want to skip PV creation and only perform the NFS exports, otherwise 'No'."
    echo "--simulate    Simulate without doing anything. Default:$SIMULATE_MODE"
    echo
}


function printVariables(){
    echo
    echo "Parameters:"
    echo
    echo "USERNAME = $USERNAME"
    echo "PASSWORD = *********"
    echo "SSH_KEYFILE = $SSH_KEYFILE"
    echo "MASTER_URL = $MASTER_URL"
    echo "PV_SIZE = $PV_SIZE"
    echo "NFS_SERVER = $NFS_SERVER"
    echo "NFS_PATH = $NFS_PATH"
#    echo "NFS_PATH_PREFIX = $NFS_PATH_PREFIX"
    echo "NFS_VOL_NUMBER = $NFS_VOL_NUMBER"
    echo "NFS_VOLUME_NAME = $NFS_VOLUME_NAME"
    echo "NFS_EXPORT_FILE_LOCATION = $NFS_EXPORT_FILE_LOCATION"
    echo "NFS_EXPORT_FILE_NAME = $NFS_EXPORT_FILE_NAME"
    echo "PV_ACCESS_MODE = $PV_ACCESS_MODE"
    echo "PV_RECLAIM_POLICY = $PV_RECLAIM_POLICY"
    echo "SSH_USERNAME = $SSH_USERNAME"
#    echo "SSH_PASSWORD = $SSH_PASSWORD"
    echo "SSH_KEYFILE = $SSH_KEYFILE"
    echo "SSH_PORT = $SSH_PORT"
    echo "IS_NFS_SERVER_REMOTE = $IS_NFS_SERVER_REMOTE"
    echo "SKIP_PV = $SKIP_PV"
    echo "SIMULATE_MODE = $SIMULATE_MODE"
    echo "SSH_SUDO = $SSH_SUDO"
    echo
	
}

function validation(){

	if [[ $(fgrep -ix $SKIP_PV <<< "no") ]]; then 
		if [ "$MASTER_URL" == "" ] || [ "$USERNAME" == "" ] || [ "$PASSWORD" == "" ]; then
			echo "Error: Missing parameter -url, -u or -p. You enter --skip-pv $SKIP_PV. -url, -u or -p is mandatory."
			echo
			exit 0
		fi
	fi
	if [ "$NFS_SERVER" == "" ] && [[ $(fgrep -ix $IS_NFS_SERVER_REMOTE <<< "yes") ]]; then
		echo "Error: Missing parameter --nfs-server. You enter --is-nfs-server-remote $IS_NFS_SERVER_REMOTE. --nfs-server is mandatory."
		echo
		exit 0
	fi
	if [ "$SSH_KEYFILE" != "" ] && [ "$SSH_USERNAME" == "" ]; then
		echo "Error: Missing parameter --ssh-username. You enter --ssh-keyfile $SSH_KEYFILE. --ssh-username is mandatory."
		echo
		exit 0
	fi
	if [ "$NFS_EXPORT_FILE_NAME" == "" ]; then
		echo "Error: Missing parameter --nfs-export-filename. --nfs-export-filename is mandatory."
		echo
		exit 0
	fi
}

function processArguments(){

    if [ $# -eq 0 ]; then
        printUsage
        exit 0
    fi

    while (( "$#" )); do
      if [ "$1" == "-h" ]; then
        printUsage
        exit 0
      elif [ "$1" == "-url" ]; then
        shift
        MASTER_URL="$1"
      elif [ "$1" == "-u" ]; then
        shift
        USERNAME="$1"
      elif [ "$1" == "-p" ]; then
        shift
        PASSWORD="$1"
      elif [ "$1" == "--nfs-server" ]; then
        shift
        NFS_SERVER="$1"
      elif [ "$1" == "--nfs-export-filename" ]; then
        shift
        NFS_EXPORT_FILE_NAME="$1"
      elif [ "$1" == "-s" ]; then
        shift
        PV_SIZE="$1"
      elif [ "$1" == "--nfs-path" ]; then
        shift
        NFS_PATH="$1"
#      elif [ "$1" == "--nfs-path-prefix" ]; then
#        shift
#        NFS_PATH_PREFIX="$1"
      elif [ "$1" == "--nfs-vol-name" ]; then
        shift
        NFS_VOLUME_NAME="$1"
      elif [ "$1" == "--nfs-vol-no" ]; then
        shift
        NFS_VOL_NUMBER="$1"
      elif [ "$1" == "--nfs-export-filepath" ]; then
        shift
        NFS_EXPORT_FILE_LOCATION="$1"
      elif [ "$1" == "--ssh-port" ]; then
        shift
        SSH_PORT="$1"
      elif [ "$1" == "--ssh-username" ]; then
        shift
        SSH_USERNAME="$1"
      elif [ "$1" == "--ssh-sudo" ]; then
        shift
        SSH_SUDO="$1"
        if [[ $(fgrep -ix $SSH_SUDO <<< "yes") ]]; then
            SSH_SUDO_COMMAND="sudo"
        fi
      elif [ "$1" == "--pv-access-mode" ]; then
        shift
        PV_ACCESS_MODE="$1"
      elif [ "$1" == "--is-nfs-server-remote" ]; then
        shift
        IS_NFS_SERVER_REMOTE="$1"
      elif [ "$1" == "--skip-pv" ]; then
        shift
        SKIP_PV="$1"
      elif [ "$1" == "--simulate" ]; then
        shift
        SIMULATE_MODE="$1"
      elif [ "$1" == "--ssh-keyfile" ]; then
        shift
        SSH_KEYFILE="$1"
      else
        echo "Unknown argument $1"
        exit 0
      fi
      shift
    done

}

function createNFS(){

    dirCount=0

    echo "Creating export path: $NFS_PATH if it is not exists."
    if [[ $(fgrep -ix $SIMULATE_MODE <<< "yes") ]]; then
        echo "mkdir $NFS_PATH"
    else
        $SSH_COMMAND "$SSH_SUDO_COMMAND mkdir -p $NFS_PATH"
    fi
    
    sudo touch /tmp/$NFS_EXPORT_FILE_NAME
	
    while [ $dirCount -lt $NFS_VOL_NUMBER ]
    do
       dirCount=`expr $dirCount + 1`
       pathToCreate="$NFS_PATH/$NFS_VOLUME_NAME$dirCount"
       echo "Creating file: $pathToCreate"
       if [[ $(fgrep -ix $IS_NFS_SERVER_REMOTE <<< "yes") ]] ; then
          if [[ $(fgrep -ix $SIMULATE_MODE <<< "yes") ]]; then
             printf "$SSH_COMMAND \"$SSH_SUDO_COMMAND mkdir $pathToCreate && $SSH_SUDO_COMMAND chown nfsnobody:nfsnobody $pathToCreate && $SSH_SUDO_COMMAND chmod 777 $pathToCreate && $SSH_SUDO_COMMAND echo '$pathToCreate *(rw,root_squash)' >> $NFS_EXPORT_FILE_LOCATION/$NFS_EXPORT_FILE_NAME\"\n"
          else
              $SSH_COMMAND "$SSH_SUDO_COMMAND mkdir $pathToCreate && $SSH_SUDO_COMMAND chown nfsnobody:nfsnobody $pathToCreate && $SSH_SUDO_COMMAND chmod 777 $pathToCreate && $SSH_SUDO_COMMAND echo '$pathToCreate *(rw,root_squash)' >> /tmp/$NFS_EXPORT_FILE_NAME"
          fi
       else
          if [[ $(fgrep -ix $SIMULATE_MODE <<< "yes") ]]; then
             printf "$SSH_SUDO_COMMAND mkdir $pathToCreate && $SSH_SUDO_COMMAND chown nfsnobody:nfsnobody $pathToCreate && $SSH_SUDO_COMMAND chmod 777 $pathToCreate && $SSH_SUDO_COMMAND echo \"$pathToCreate *(rw,root_squash)\" >> /tmp/$NFS_EXPORT_FILE_NAME\n"
          else
             $SSH_SUDO_COMMAND mkdir $pathToCreate && $SSH_SUDO_COMMAND chown nfsnobody:nfsnobody $pathToCreate && $SSH_SUDO_COMMAND chmod 777 $pathToCreate && $SSH_SUDO_COMMAND echo "$pathToCreate *(rw,root_squash)" >> /tmp/$NFS_EXPORT_FILE_NAME
          fi
       fi
    done
        echo "Copying /tmp/$NFS_EXPORT_FILE_NAME to $NFS_EXPORT_FILE_LOCATION/$NFS_EXPORT_FILE_NAME"
        $SSH_COMMAND "$SSH_SUDO_COMMAND cp /tmp/$NFS_EXPORT_FILE_NAME $NFS_EXPORT_FILE_LOCATION/$NFS_EXPORT_FILE_NAME"
    echo
    echo "Results: "
    echo
    if [[ $(fgrep -ix $SIMULATE_MODE <<< "yes") ]]; then
       printf "$SSH_COMMAND \"$SSH_SUDO_COMMAND exportfs -a\"\n"
       printf "$SSH_COMMAND \"$SSH_SUDO_COMMAND showmount -e\"\n"
    else
       $SSH_COMMAND "$SSH_SUDO_COMMAND exportfs -a"
       $SSH_COMMAND "$SSH_SUDO_COMMAND showmount -e"
    fi
    
    $SSH_COMMAND "rm /tmp/$NFS_EXPORT_FILE_NAME"
	
    echo
}

function sshcommand(){

    if [ "$SSH_KEYFILE" != "" ]; then
        SSH_COMMAND="ssh -i $SSH_KEYFILE -p $SSH_PORT $SSH_USERNAME@$NFS_SERVER"
    else
        SSH_COMMAND="ssh $NFS_SERVER -p $SSH_PORT"
    fi

}

function createPV(){
    dirCount=0
    TEMP_DIR="$NFS_VOLUME_NAME"
    echo "Creating temp directory $TEMP_DIR"
    mkdir $TEMP_DIR
    
    while [ $dirCount -lt $NFS_VOL_NUMBER ]
    do
       dirCount=`expr $dirCount + 1`
       pvString="{\"apiVersion\": \"v1\",\"kind\": \"PersistentVolume\",\"metadata\":{\"name\": \"$NFS_VOLUME_NAME$dirCount-volume\",\"label\": {\"name\": \"$NFS_VOLUME_NAME$dirCount\"}},\"spec\":{\"capacity\": {\"storage\": \"$PV_SIZE\"},\"accessModes\": [ \"$PV_ACCESS_MODE\" ],\"nfs\": {\"path\": \"$NFS_PATH/$NFS_VOLUME_NAME$dirCount\",\"server\": \"$NFS_SERVER\"}, \"persistentVolumeReclaimPolicy\": \"$PV_RECLAIM_POLICY\"}}"
       echo $pvString > $TEMP_DIR/$7$NFS_VOLUME_NAME$dirCount.json
    done

    TEMP_FILES="$TEMP_DIR/*.json"
	
    if [[ $(fgrep -ix $SIMULATE_MODE <<< "yes") ]] ; then
       echo "oc login --username=$USERNAME --password=$PASSWORD $MASTER_URL"
    else
       oc login --username=$USERNAME --password=$PASSWORD $MASTER_URL
    fi

    sleep 10

    for entry in $TEMP_FILES
       do
         echo "Using file: $entry"
         if [[ $(fgrep -ix $SIMULATE_MODE <<< "yes") ]] ; then
            echo "oc create -f $entry"
         else
            oc create -f $entry
         fi
       done
    echo
    echo
    if [[ $(fgrep -ix $SIMULATE_MODE <<< "yes") ]] ; then
        echo "oc get pv"
        echo "oc logout"
    else
        oc get pv
        oc logout
    fi
	echo "Removing temporary directory $TEMP_DIR"
	rm -rf $TEMP_DIR
    echo
    echo
    
}


processArguments $@
printVariables
validation
sshcommand
createNFS

echo "Everything OK so far?"
echo "Press ENTER (OR Ctrl-C to cancel) to proceed..."
read bc

if [[ $(fgrep -ix $SKIP_PV <<< "no") ]]; then
    createPV
fi 
