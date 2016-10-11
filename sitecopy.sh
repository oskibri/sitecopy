#!/bin/bash

usage() {
  echo "usage: $0 [ options ] user@hostname"
}

abspath() {
  echo $(cd "$(dirname $1)" ;pwd -P)
}

AP=`abspath $0`
SCRIPT="$AP/$(basename $0)"
USER=`whoami`
FORCE=0

if ! options=$(getopt -o fhu: -l user:,force -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    exit 1
fi

eval set -- $options

until [ -z "$1" ] ; do
  case $1 in
    -h) usage ; exit 1 ;;
    -f|--force) FORCE=1 ;;
    -u|--user) USER=$2 ; shift ;;
    --) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
  esac
  shift
done

SOURCE=$1

if [ -z "$SOURCE"] ; then
usage
exit
fi

## begin rsync public folder
if [ ! "$USER" = "`whoami`" ] ; then
  CMD="$SCRIPT $*"
  su $USER -c "echo $CMD"
else
  cd $HOME
  echo "copy site from $SOURCE to $PWD"
  if [ ! -e ~/.ssh/id_sitecopy ] ; then
    echo "generating new public/private key pair"
    ssh-keygen -N "" -f ~/.ssh/id_sitecopy
  fi

  if [ -z "$SSH_AGENT_PID" ]; then
    eval `ssh-agent -s`
  fi
  ssh-add ~/.ssh/id_sitecopy

  echo "adding public key to authorized_keys"
  ssh-copy-id -o StrictHostKeyChecking=no -o PreferredAuthentications=password -i ~/.ssh/id_sitecopy "$SOURCE"
  echo "copying public folder from $SOURCE"
  rsync --delete -rauve ssh $SOURCE:public .
fi

## begin copy database
