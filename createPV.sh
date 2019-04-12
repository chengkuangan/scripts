#!/bin/bash

USERNAME=""
PASSWORD=""
MASTER_URL=""
PV_SIZE="1Gi"
NFS_PATH="/exports/"
NFS_PATH_PREFIX="vol-"
NFS_VOL_NUMBER="30"
NFS_EXPORT_FILE_LOCATION="/etc/exports.d/"
NFS_EXPORT_FILE_NAME=""
NFS_SERVER=""
PV_ACCESS_MODE="ReadWriteOnce"        #ReadOnlyMany, ReadWriteMany, ReadWriteOnce
PV_RECLAIM_POLICY="Recycle"
SSH_PORT="22"
SSH_USERNAME="root"
SSH_PASSWORD="password"

function printUsage(){
    echo
    echo "This command helps to create NFS shared storage and PV in the OCP Master Node."
    echo "It is recommended to configure SSH public key for the OCP Master Node Server."
    echo
    echo "Command Usage: initPV.sh -u <username> -p <password> -url <url> --nfs-server <NFS-Server-Name> --nfs-export-filename <file-name> [options]"
    echo "-u    Username to authenticate to the OCP"
    echo "-p    Password to authenticate to the OCP"
    echo "-url  OCP Master node url"
    echo "--nfs-server    NFS Server name."
    echo "--nfs-export-filename    Export file name."
    echo "[options]"
    echo "--ssh-port   SSH port if not default 22."
    echo "--ssh-username     SSH Username. Default: $SSH_USERNAME"
    echo "--ssh-password     SSH Password. Default: $SSH_PASSWORD"
    echo "-s    PV size. e.g. 1Gi. Default: $PV_SIZE"
    echo "--nfs-path    NFS PATH to create the shared volume. Default: $NFS_PATH"
    echo "--nfs-path-prefix    NFS PATH to create the shared volume. Default: $NFS_PATH_PREFIX"
    echo "--nfs-vol-no    Number of NFS Volume Path to create. Default: $NFS_VOL_NUMBER"
    echo "--nfs-export-filepath    Default path to create export files. Default: $NFS_EXPORT_FILE_LOCATION"
    echo "--pv-access-mode    PV Access Mode. Default: $PV_ACCESS_MODE. Possible values: ReadOnlyMany, ReadWriteMany, ReadWriteOnce"
    echo "--pv-reclaim-policy    PV Reclaim Policy. Default: $PV_RECLAIM_POLICY"
    echo
}

function printVariables(){
    echo
    echo "Environment variables:"
    echo
    echo "USERNAME = $USERNAME"
    echo "PASSWORD = *********"
    echo "MASTER_URL = $MASTER_URL"
    echo "PV_SIZE = $PV_SIZE"
    echo "NFS_SERVER = $NFS_SERVER"
    echo "NFS_PATH = $NFS_PATH"
    echo "NFS_PATH_PREFIX = $NFS_PATH_PREFIX"
    echo "NFS_VOL_NUMBER = $NFS_VOL_NUMBER"
    echo "NFS_EXPORT_FILE_LOCATION = $NFS_EXPORT_FILE_LOCATION"
    echo "NFS_EXPORT_FILE_NAME = $NFS_EXPORT_FILE_NAME"
    echo "PV_ACCESS_MODE = $PV_ACCESS_MODE"
    echo "PV_RECLAIM_POLICY = $PV_RECLAIM_POLICY"
    echo "SSH_PORT = $SSH_PORT"
    echo
}

processArguments(){

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
      elif [ "$1" == "--nfs-path-prefix" ]; then
        shift
        NFS_PATH_PREFIX="$1"
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
      else
        echo "Unknown argument $1"
        exit 0
      fi
      shift
    done

    if [ "$USERNAME" = "" ] || [ "$PASSWORD" = "" ] || [ "$MASTER_URL" = "" ] || [ "$NFS_EXPORT_FILE_NAME" = "" ]  || [ "$NFS_SERVER" = "" ] ; then
        echo
        echo "Missing one or more mandatory argument(s)..."
        printUsage
        echo
        exit 0
    fi

}

createNFS(){

    dirCount=0

    while [ $dirCount -lt $NFS_VOL_NUMBER ]
    do
       dirCount=`expr $dirCount + 1`
       pathToCreate="$NFS_PATH$NFS_PATH_PREFIX$dirCount"
       echo "Creating directory: $pathToCreate"
       ssh $SSH_USERNAME@$NFS_SERVER -p $SSH_PORT "mkdir $pathToCreate &&  chown nfsnobody:nfsnobody $pathToCreate && chmod 777 $pathToCreate && echo '$pathToCreate *(rw,root_squash)' >> $NFS_EXPORT_FILE_LOCATION$NFS_EXPORT_FILE_NAME"
       #mkdir $pathToCreate
       #chown nfsnobody:nfsnobody $pathToCreate
       #chmod 777 $pathToCreate
       #echo "$pathToCreate *(rw,root_squash)" >> $NFS_EXPORT_FILE_LOCATION
    done

    ssh $SSH_USERNAME@$NFS_SERVER -p $SSH_PORT "exportfs -a"
    ssh $SSH_USERNAME@$NFS_SERVER -p $SSH_PORT "showmount -e"

}

createPV(){
    dirCount=0

    while [ $dirCount -lt $NFS_VOL_NUMBER ]
    do
       dirCount=`expr $dirCount + 1`
       pvString="{\"apiVersion\": \"v1\",\"kind\": \"PersistentVolume\",\"metadata\":{\"name\": \"$NFS_PATH_PREFIX$dirCount-volume\",\"label\": {\"name\": \"$NFS_PATH_PREFIX$dirCount-volume\"}},\"spec\":{\"capacity\": {\"storage\": \"$PV_SIZE\"},\"accessModes\": [ \"$PV_ACCESS_MODE\" ],\"nfs\": {\"path\": \"$NFS_PATH$NFS_PATH_PREFIX$dirCount\",\"server\": \"$NFS_SERVER\"}, \"persistentVolumeReclaimPolicy\": \"$PV_RECLAIM_POLICY\"}}"
       echo $pvString > ./$7$dirCount-volume.json
    done

    TEMP_FILES="./*.json"

    oc login --username=$USERNAME --password=$PASSWORD $MASTER_URL
    sleep 2

    for entry in $TEMP_FILES
    do
      echo "Using file: $entry"
      oc create -f $entry
    done

    echo
    echo

    oc get pv
    echo
    echo
    oc logout
    rm $TEMP_FILES
}


processArguments $@
printVariables

createNFS
createPV

