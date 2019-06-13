#!/bin/bash

SOURCE_URL=""
SOURCE_NATIONALPARKS_URL="https://github.com/chengkuangan/nationalparks.git"
SOURCE_PARKSMAP_URL="https://github.com/chengkuangan/parksmap-web.git"
SOURCE_MLBPARKS_URL="https://github.com/chengkuangan/mlbparks.git"
SOURCE_PASSWORD=""
SOURCE_USERNAME=""
TARGET_URL=""
TARGET_PASSWORD=""
TARGET_USERNAME=""
WHICH_PROJECT="1"
SUBDOMAIN=""
PROJECT_NAME_DEV=""
PROJECT_NAME_TEST=""
PROJECT_NAME_PROD=""

function printVariables(){
    echo
    echo "Environment variables:"
    echo
    echo "SOURCE_NATIONALPARKS_URL = $SOURCE_NATIONALPARKS_URL"
    echo "SOURCE_PARKSMAP_URL = $SOURCE_PARKSMAP_URL"
    echo "SOURCE_MLBPARKS_URL = $SOURCE_MLBPARKS_URL"
    echo "SOURCE_URL = $SOURCE_URL"
    echo "SOURCE_USERNAME = $SOURCE_USERNAME"
    echo "SOURCE_PASSWORD = ********"
    echo "TARGET_URL = $TARGET_URL"
    echo "TARGET_USERNAME = $TARGET_USERNAME"
    echo "TARGET_USERNAME = ********"
    echo "WHICH_PROJECT = $WHICH_PROJECT"
    echo "SUBDOMAIN = $SUBDOMAIN"
    echo "PROJECT_NAME_DEV = $PROJECT_NAME_DEV"
    echo "PROJECT_NAME_TEST = $PROJECT_NAME_TEST"
    echo "PROJECT_NAME_PROD = $PROJECT_NAME_PROD"
    echo
}


function printUsage(){
    echo
    echo "This command performs a fresh initialize on a Git with source code from a different Git."
    echo
    echo "Command Usage: initGogs.sh -su <username> -sp <password> -turl <url> -tu <username> -tp <password> [options]"
    echo "-su    Username to authenticate to the source git"
    echo "-sp    Password to authenticate to the source git"
    echo "-turl  Target Git URL to push the source code to"
    echo "-tu    Username to authenticate to the target git"
    echo "-tp    Password to authenticate to the target git"
    echo "[options]"
    echo "-surl            Source Git URL to clone the source code from. Defaults:"
    echo "                 $SOURCE_NATIONALPARKS_URL"
    echo "                 $SOURCE_PARKSMAP_URL"
    echo "                 $SOURCE_MLBPARKS_URL"
    echo "                 This argument is required to be set to different URL if -proj is set to '4'"
    echo "-proj            Specify which repository to provision."
    echo "                 1 - nationalparks. Default."
    echo "                 2 - parksmap"
    echo "                 3 - mlbparks"
    echo "                 4 - Custom. Requires to set the -surl to a different source git."
    echo "-subdomain       OpenShift subdomain name for Gogs. Default: ''. If omitted or it is empty string, the pre-defined subdomain will not be modified." 
    echo "-proj-name-dev   OpenShift project name for Development Environment. If omitted or empty, it will be ignored."
    echo "-proj-name-test  OpenShift project name for Test Environment. If omitted or empty, it will be ignored."
    echo "-proj-name-prod  OpenShift project name for Production Environment. If omitted or empty, it will be ignored."
    echo
}


urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done

    LC_COLLATE=$old_lc_collate
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
      elif [ "$1" == "-surl" ]; then
        shift
        SOURCE_URL="$1"
      elif [ "$1" == "-su" ]; then
        shift
        SOURCE_USERNAME="$1"
      elif [ "$1" == "-sp" ]; then
        shift
        SOURCE_PASSWORD="$1"
      elif [ "$1" == "-turl" ]; then
        shift
        TARGET_URL="$1"
      elif [ "$1" == "-tu" ]; then
        shift
        TARGET_USERNAME="$1"
      elif [ "$1" == "-tp" ]; then
        shift
        TARGET_PASSWORD="$1"
      elif [ "$1" == "-proj" ]; then
        shift
        WHICH_PROJECT="$1"
      elif [ "$1" == "-subdomain" ]; then
        shift
	SUBDOMAIN="$1"
      elif [ "$1" == "-proj-name-dev" ]; then
        shift
        PROJECT_NAME_DEV="$1"
      elif [ "$1" == "-proj-name-test" ]; then
       	shift
       	PROJECT_NAME_TEST="$1"
      elif [ "$1" == "-proj-name-prod" ]; then
       	shift
       	PROJECT_NAME_PROD="$1"
      else
        echo "Unknown argument $1"
        exit 0
      fi
      shift
    done

    if [ "$SOURCE_USERNAME" = "" ] || [ "$SOURCE_PASSWORD" = "" ] || [ "$TARGET_URL" = "" ] || [ "$TARGET_USERNAME" = "" ] || [ "$TARGET_PASSWORD" = "" ]; then
        echo
        echo "Missing one or more mandatory argument(s)..."
        printUsage
        echo
        exit 0
    fi

    if [ "$WHICH_PROJECT" = "1" ]; then
        SOURCE_URL=$SOURCE_NATIONALPARKS_URL
    elif [ "$WHICH_PROJECT" = "2" ]; then
        SOURCE_URL=$SOURCE_PARKSMAP_URL
    elif [ "$WHICH_PROJECT" = "3" ]; then
        SOURCE_URL=$SOURCE_MLBPARKS_URL
    elif [[ "$WHICH_PROJECT" = "4" ]] && [[ "$SOURCE_URL" = "" ]]; then
        echo "Missing argument -surl. A source Git URL is required when '-proj 4' is specified."
        exit 0
    fi
}

processArguments $@
printVariables

CREDENTIAL=$(urlencode "$SOURCE_USERNAME")":"$(urlencode "$SOURCE_PASSWORD")"@"
SURL="$SOURCE_URL"
PREFIX="http://"
if [[ "$SURL" =~ ^https.* ]]; then
    PREFIX="https://"
fi
SURL=${SURL#$PREFIX}
SURL=$PREFIX$CREDENTIAL$SURL

CREDENTIAL=$(urlencode "$TARGET_USERNAME")":"$(urlencode "$TARGET_PASSWORD")"@"
TURL="$TARGET_URL"
PREFIX="http://"
if [[ "$TURL" =~ ^https.* ]]; then
    PREFIX="https://"
fi
TURL=${TURL#$PREFIX}
TURL=$PREFIX$CREDENTIAL$TURL

TEMP_DIR=./nationalparks-temp

echo

mkdir $TEMP_DIR
cd $TEMP_DIR
git clone $SURL
cd *
rm -rf .git
if [ "$SUBDOMAIN" != "" ]; then
    sed -i s/ocp.demo.com/${SUBDOMAIN}/g Jenkinsfile
fi

if [ "$PROJECT_NAME_DEV" != "" ]; then
    sed -i s/\"dev\"/\"${PROJECT_NAME_DEV}\"/g Jenkinsfile
fi

if [ "$PROJECT_NAME_TEST" != "" ]; then
    sed -i s/\"test\"/\"${PROJECT_NAME_TEST}\"/g Jenkinsfile
fi

if [ "$PROJECT_NAME_PROD" != "" ]; then
    sed -i s/\"prod\"/\"${PROJECT_NAME_PROD}\"/g Jenkinsfile
fi

git init
git add .
git commit -m "first commit"
git remote add origin $TURL
git push -u origin master

rm -rf ../../$TEMP_DIR
echo
