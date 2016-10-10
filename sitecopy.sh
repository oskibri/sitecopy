#!/bin/bash

SCRIPT="$(pwd)/$(dirname $0)/$(basename $0)"
CMD="$SCRIPT $*"
USER=""
WHOAMI=`whoami`
FORCE=0

while getopts fu: opt ; do
  case $opt in
    f)
      FORCE=1
      ;;
    u)
      USER=$OPTARG
      ;;
  esac
done

shift $((OPTIND-1))
SOURCE=$1

if [ ! "$USER" = "`whoami`" ] ; then
  sudo su $USER -c "echo $CMD"
else
  cd $HOME
  echo "copy site from $SOURCE to $PWD"
  if [ ! -e ~/.ssh/id_sitecopy ] ; then
    echo "generating new public/private key pair"
    ssh-keygen -N "" -f ~/.ssh/id_sitecopy
  fi
  echo "adding public key to authorized_keys"
  ssh-copy-id -o PreferredAuthentications=password -i ~/.ssh/id_sitecopy "$SOURCE"
  echo "copying public folder from $SOURCE"
  rsync --delete -rauve ssh $SOURCE:public .
fi
