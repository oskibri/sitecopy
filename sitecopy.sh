#!/bin/bash

wpconfig="public/wp-config.php"

usage() {
  echo "usage: $0 [OPTIONS] user@hostname local-db [remote-db]"
  echo "Options"
  echo "  -u, --user[=name]   run this script under another account."
  echo "  -t, --type[=name]   website type {i.e. wp}."
  echo "  -h, --help          display this help and exit."
}

abspath() {
  echo $(cd "$(dirname $1)" ;pwd -P)
}

AP=`abspath $0`
SCRIPT="$AP/$(basename $0)"
USER=`whoami`
SITE=""

if [ -d /Applications ] ; then # OS X
  options=$(getopt hu:t: "$@")
else # GNU getopt
  options=$(getopt -o hu:t: -l help,user: -- "$@")
fi

if [ -z "$options" ] ; then
  # something went wrong, getopt will put out an error message for us
  exit 1
fi

eval set -- $options

until [ -z "$1" ] ; do
  case $1 in
    -h|--help) usage ; exit 1 ;;
    -u|--user) USER=$2 ; shift ;;
    -t|--type) SITE=$2 ; shift ;;
    --) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
  esac
  shift
done

if [ "$USER" = "root" ] ; then
  echo "cannot run as root. did you forget to add -u?"
  exit 1
fi

if [ ! "$USER" = "`whoami`" ] ; then
  echo "running $0 as $USER"
  CMD="$SCRIPT $*"
  su $USER -c "echo $CMD"
  exit
fi

SOURCE=$1
DSTDB=$2
SRCDB=$3

if [ -z "$SOURCE" ] ; then
  usage
  exit
fi


wp_read_config() {
  ( echo "<?php" ; grep DB_ $1 ; cat <<EOF
echo 'SRCDBPASS="' . DB_PASSWORD . '"' . PHP_EOL;
echo 'SRCDBUSER="' . DB_USER . '"' . PHP_EOL;
echo 'SRCDBNAME="' . DB_NAME . '"' . PHP_EOL;
EOF
) | php
}

setup_ssh() {
  if [ ! -e ~/.ssh/id_sitecopy ] ; then
    echo "generating new public/private key pair"
    ssh-keygen -N "" -f ~/.ssh/id_sitecopy
  fi
  echo "adding public key to authorized_keys"
  ssh-copy-id -o StrictHostKeyChecking=no -o PreferredAuthentications=password -i ~/.ssh/id_sitecopy "$SOURCE"

  if [ -z "$SSH_AGENT_PID" ]; then
    echo "starting local ssh-agent"
    eval `ssh-agent -s`
  fi
  ssh-add ~/.ssh/id_sitecopy
}

config_read() {
  mkdir -p ~/public
  if [ "$SITE" = "wp" ] ; then
    scp $SOURCE:$wpconfig ~/public/
    eval `wp_read_config $wpconfig`
  fi
}

dbconf_local() {
  ## guess/ask local db credentials
  if [ ! -z "$DSTDB" ] ; then
    [ -z "$DSTDBNAME" ] && DSTDBNAME=$DSTDB
    [ -z "$DSTDBUSER" ] && DSTDBUSER=$DSTDB
  fi
  if [ -z "$DSTDBPASS" ] && [ ! -z "$DSTDBNAME" ] ; then
    echo "querying local database information"
    read -e -p "database name [$DSTDBNAME]:" DSTDB
    [ -z "$DSTDB" ] || DSTDBNAME=$DSTDB
    [ -z "$DSTDBUSER" ] && DSTDBUSER=$DSTDB
    read -e -p "database user [$DSTDBUSER]:" DSTDB
    [ -z "$DSTDB" ] || DSTDBUSER=$DSTDB
    read -s -p "database password for $DSTDBUSER@$DSTDBNAME:" DSTDBPASS
    echo
  fi
}


dbconf_remote() {
  ## guess/ask local db credentials
  if [ ! -z "$SRCDB" ] ; then
    [ -z "$SRCDBNAME" ] && SRCDBNAME=$SRCDB
    [ -z "$SRCDBUSER" ] && SRCDBUSER=$SRCDB
  fi
  if [ -z "$SRCDBPASS" ] && [ ! -z "$SRCDBNAME" ] ; then
    echo "querying remote database information"
    read -e -p "database name [$SRCDBNAME]:" SRCDB
    [ -z "$RCDB" ] || SRCDBNAME=$SRCDB
    [ -z "$SRCDBUSER" ] && SRCDBUSER=$SRCDB
    read -e -p "database user [$SRCDBUSER]:" SRCDB
    [ -z "$SRCDB" ] || SRCDBUSER=$SRCDB
    read -s -p "database password for $SRCDBUSER@$SRCDBNAME:" SRCDBPASS
    echo
  fi
}

config_write_wp() {
mv $wpconfig $wpconfig.orig
( cat <<AWK
\$0 ~ "DB_PASSWORD" { sub("$SRCDBPASS","$DSTDBPASS") }
\$0 ~ "DB_USER" { sub("$SRCDBUSER","$DSTDBUSER") }
\$0 ~ "DB_NAME" { sub("$SRCDBNAME","$DSTDBNAME") }
{ print }
AWK
) > rules.awk
awk -f rules.awk < $wpconfig.orig > $wpconfig
}

config_write() {
if [ "$SITE" = "wp" ] ; then
  config_write_wp $wpconfig
fi
}

rsync_public () {
  echo "copying public folder from $SOURCE"
  rsync --delete -rave ssh $SOURCE:public .
}

db_transfer(){
sqlfile=$1
if [ ! -z "$SRCDBNAME" ] ; then
  echo "exporting database $SRCDBUSER/$SRCDBNAME to $sqlfile"
  ssh $SOURCE "mysqldump --password=\"$SRCDBPASS\" -u $SRCDBUSER $SRCDBNAME" > $sqlfile
fi
if [ ! -z "$DSTDBNAME" ] ; then
  echo "importing database $DSTDBUSER/$DSTDBNAME from $sqlfile"
  if [ -e $SRCDBNAME.sql ] ; then
    mysql --user="$DSTDBUSER" --password="$DSTDBPASS" $DSTDBNAME < $sqlfile
  fi
fi
}

cleanup() {
  rm -f sitecopy.sql $wpconfig.orig rules.awk
}

cd $HOME
echo "copy site from $SOURCE to $PWD"
setup_ssh
config_read
dbconf_remote
dbconf_local
rsync_public
config_write
db_transfer sitecopy.sql
cleanup
