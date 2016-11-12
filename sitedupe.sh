#!/bin/bash

wpconfig="wp-config.php"
mgconfig="app/etc/local.xml"
srcdir="public"
pause=0

usage() {
  echo "usage: $0 [OPTIONS] user1@origin user2@target"
  echo "Options"
  echo "  -d, --dir[=path]    source directory (default: public)"
  echo "  -t, --type[=name]   website type (wp=Wordpress, mg=Magento)."
  echo "  -h, --help          display this help and exit."
}

abspath() {
  echo $(cd "$(dirname $1)" ;pwd -P)
}

AP=`abspath $0`
SCRIPT="$AP/$(basename $0)"
SITE=""

if [ -d /Applications ] ; then # OS X
  options=$(getopt ht:d: "$@")
else # GNU getopt
  options=$(getopt -o ht:d: -l help,dir: -- "$@")
fi

if [ -z "$options" ] ; then
  # something went wrong, getopt will put out an error message for us
  exit 1
fi

eval set -- $options

until [ -z "$1" ] ; do
  case $1 in
    -h|--help) usage ; exit 1 ;;
    -d|--dir) srcdir=$2 ; shift ;;
    -t|--type) SITE=$2 ; shift ;;
    --) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
  esac
  shift
done

ORIGIN=$1
TARGET=$2

if [ -z "$ORIGIN" ] || [ -z "$TARGET" ] ; then
  usage
  exit
fi

setup_ssh() {
  if [ ! -e ~/.ssh/id_sitecopy ] ; then
    echo "generating new public/private key pair"
    ssh-keygen -N "" -f ~/.ssh/id_sitecopy
  fi
  echo "adding public key to authorized_keys of $ORIGIN (origin)"
  ssh-copy-id -o StrictHostKeyChecking=no -o PreferredAuthentications=password -i ~/.ssh/id_sitecopy "$ORIGIN"
  echo "adding public key to authorized_keys of $TARGET (target)"
  ssh-copy-id -o StrictHostKeyChecking=no -o PreferredAuthentications=password -i ~/.ssh/id_sitecopy "$TARGET"

  if [ -z "$SSH_AGENT_PID" ]; then
    echo "starting local ssh-agent"
    eval `ssh-agent -s`
  fi
  ssh-add ~/.ssh/id_sitecopy
}

rsync_pull () {
  mkdir -p /tmp/sites/$ORIGIN
  echo "copying $srcdir folder from $ORIGIN to $TARGET"
  rsync --exclude var/cache --delete -rave ssh $ORIGIN:$srcdir /tmp/sites/$ORIGIN
}

rsync_push () {
  rsync --delete -rave ssh /tmp/sites/$ORIGIN/$srcdir/ $TARGET:$srcdir
}

cleanup() {
#  rm -rf /tmp/sites/$ORIGIN
  cd $HOME
}

cd $HOME
setup_ssh
rsync_pull
rsync_push
cleanup
