#!/bin/bash

dbsettings="$(pwd)/settings.php"
wpconfig="wp-config.php"
mgconfig="app/etc/local.xml"
srcdir="public"
pause=0

usage() {
  echo "usage: $0 [OPTIONS] user1@origin user2@target"
  echo "Options"
  echo "  -d, --dir[=path]      source directory (default: public)"
  echo "  -t, --type[=name]     website type (wp=Wordpress, mg=Magento)."
  echo "  -s, --settings[=name] location of settings.php database configuration."
  echo "  -h, --help            display this help and exit."
}

abspath() {
  echo $(cd "$(dirname $1)" ;pwd -P)
}

AP=`abspath $0`
SCRIPT="$AP/$(basename $0)"
SITE=""

if [ -d /Applications ] ; then # OS X
  options=$(getopt ht:d:s: "$@")
else # GNU getopt
  options=$(getopt -o ht:d:s: -l settings:,help,dir: -- "$@")
fi

if [ -z "$options" ] ; then
  # something went wrong, getopt will put out an error message for us
  exit 1
fi

eval set -- $options

until [ -z "$1" ] ; do
  case $1 in
    -h|--help) usage ; exit 1 ;;
    -s|--settings) dbsettings=$2 ; shift ;;
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


ssh_copy_id() {
  echo "adding public key to authorized_keys of $2 ($1)"
  echo $2 | cut -d@ -f2 | (read ; ssh-keyscan $REPLY >> ~/.ssh/known_hosts )
  ssh-copy-id -i ~/.ssh/id_sitecopy "$2"
}

setup_ssh() {
  if [ ! -e ~/.ssh/id_sitecopy ] ; then
    echo "generating new public/private key pair"
    ssh-keygen -N "" -f ~/.ssh/id_sitecopy
  fi
  if [ -z "$SSH_AGENT_PID" ]; then
    echo "starting local ssh-agent"
    eval `ssh-agent -s`
    trap "kill $SSH_AGENT_PID" EXIT
  fi
  ssh-add ~/.ssh/id_sitecopy

  ssh_copy_id origin "$ORIGIN"
  ssh_copy_id target "$TARGET"
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
  # rm -rf mg-read.xsl wg-write.xsl
  # rm -rf /tmp/sites/$ORIGIN
  cd $HOME
}

update_db_user() {
  # this needs to be run on rask1, where the user has access to the mysql database on all other hosts
echo "updating database user $USERNAME on $DBHOST"
( cat <<MYSQL
UPDATE mysql.user SET Host='%' WHERE Host='127.0.0.1' AND User='$USERNAME';
UPDATE mysql.db SET Host='%' WHERE Host='127.0.0.1' AND User='$USERNAME';
FLUSH PRIVILEGES;
MYSQL
) | mysql -h $DBHOST --user="$DBUSER" --password="$DBPASS"
}

read_settings() {
DB="$1_mysql"
( cat <<EOF
<?php
require_once "$dbsettings";
\$db=\$databases['$DB']['default'];
echo "DBUSER='" . \$db['username'] . "'" . PHP_EOL;
echo "DBPASS='" . \$db['password'] . "'" . PHP_EOL;
echo "DBHOST='" . \$db['host'] . "'" . PHP_EOL;
EOF
) | php
}

wp_read_config() {
  ( echo "<?php" ; grep DB_USER $1 ; cat <<EOF
echo 'USERNAME="' . DB_USER . '"' . PHP_EOL;
EOF
) | php
}

mg_read_config() {
( cat <<MGREAD
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="*" />
<xsl:output method="text"/>
<xsl:template match="connection">USERNAME="<xsl:copy-of select="username/text()"/>"
</xsl:template>
<xsl:template match="text()"/>
</xsl:stylesheet>
MGREAD
) > mg-read.xsl
xsltproc mg-read.xsl $1
}

read_config() {
  USERNAME='crankycroc'
  if [ "$SITE" == "wp" ] ; then
  wp_read_config "$1/$wpconfig"
  else
  mg_read_config "$1/$mgconfig"
  fi
}

wp_write_config() {
  mv $1 $1.bak
  sed -e 's/\(DB_HOST.*\)localhost/\1'$2'/' < $1.bak > $1
  rm $1.bak
}

mg_write_config() {
mv $1 $1.bak
( cat <<MGWRITE
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="*" />
<xsl:output method="xml" indent="yes"/>
<xsl:template match="node()|@*">
<xsl:copy><xsl:apply-templates select="node()|@*"/></xsl:copy>
</xsl:template>
<xsl:template match="connection/host">
<host><![CDATA[$2]]></host>
</xsl:template>
</xsl:stylesheet>
MGWRITE
) > mg-write.xsl
xsltproc mg-write.xsl $1.bak > $1
rm $1.bak
}

write_config() {
  if [ "$SITE" == "wp" ] ; then
  wp_write_config "$1/$wpconfig" $2
  else
  mg_write_config "$1/$mgconfig" $2
  fi
}

HOSTNAME=`echo $ORIGIN | cut -d@ -f2`
eval $(read_settings $HOSTNAME)
setup_ssh
rsync_pull
eval $(read_config "/tmp/sites/$ORIGIN/$srcdir")
write_config "/tmp/sites/$ORIGIN/$srcdir" $HOSTNAME
rsync_push
update_db_user
cleanup
