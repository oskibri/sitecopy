#!/bin/bash

wpconfig="wp-config.php"
mgconfig="app/etc/local.xml"
fromdir="public"
todir="$HOME/public"
pause=0

usage() {
  echo "usage: $0 [OPTIONS] user@hostname local-db [remote-db]"
  echo "Options"
  echo "  -s, --src[=path]    source directory (default: ~/public)"
  echo "  -d, --dest[=path]   destination directory (default: ~/public)"
  echo "  -u, --user[=name]   run this script under another account."
  echo "  -t, --type[=name]   website type (wp=Wordpress, mg=Magento)."
  echo "  -p, --pause         wait for keypress before database transfer."
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
  options=$(getopt phu:t:s:d: "$@")
else # GNU getopt
  options=$(getopt -o phu:t:s:d: -l pause,help,user:,src:,dest: -- "$@")
fi

if [ -z "$options" ] ; then
  # something went wrong, getopt will put out an error message for us
  exit 1
fi

eval set -- $options

until [ -z "$1" ] ; do
  case $1 in
    -h|--help) usage ; exit 1 ;;
    -p|--pause) pause=1 ;;
    -d|--dest) todir=$2 ; shift ;;
    -s|--src) fromdir=$2 ; shift ;;
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

mg_read_config() {
( cat <<XSL
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="*" />
<xsl:output method="text"/>
<xsl:template match="connection">
SRCDBHOST="<xsl:copy-of select="host/text()"/>"
SRCDBUSER="<xsl:copy-of select="username/text()"/>"
SRCDBPASS="<xsl:copy-of select="password/text()"/>"
SRCDBNAME="<xsl:copy-of select="dbname/text()"/>"
</xsl:template>
<xsl:template match="text()"/>
</xsl:stylesheet>
XSL
) > mg-read.xsl
xsltproc mg-read.xsl $1
}

wp_read_config() {
  ( echo "<?php" ; grep DB_ $1 ; cat <<EOF
echo 'SRCDBPASS="' . DB_PASSWORD . '"' . PHP_EOL;
echo 'SRCDBUSER="' . DB_USER . '"' . PHP_EOL;
echo 'SRCDBNAME="' . DB_NAME . '"' . PHP_EOL;
EOF
) | php
}

config_read() {
  if [ "$SITE" = "wp" ] ; then
    confdir=$todir/$(dirname $wpconfig)
    mkdir -p $confdir
    scp $SOURCE:$fromdir/$wpconfig $confdir
    eval `wp_read_config $todir/$wpconfig`
  elif [ "$SITE" = "mg" ] ; then
    confdir=$todir/$(dirname $mgconfig)
    mkdir -p $confdir
    scp $SOURCE:$fromdir/$mgconfig $confdir
    eval `mg_read_config $todir/$mgconfig`
    echo "remote database is $SRCDBNAME"
  fi
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
    trap "kill $SSH_AGENT_PID" EXIT
  fi
  ssh-add ~/.ssh/id_sitecopy
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
mv $todir/$wpconfig $todir/$wpconfig.orig
( cat <<AWK
\$0 ~ "DB_PASSWORD" { print substr(\$0, 1, index(\$0, "$SRCDBPASS")-1) "$DSTDBPASS" substr(\$0, length("$SRCDBPASS")+index(\$0, "$SRCDBPASS")) }
\$0 ~ "DB_USER" { sub("$SRCDBUSER","$DSTDBUSER") }
\$0 ~ "DB_NAME" { sub("$SRCDBNAME","$DSTDBNAME") }
\$0 !~ "DB_PASSWORD" { print }
AWK
) > rules.awk
awk -f rules.awk < $todir/$wpconfig.orig > $todir/$wpconfig
}

config_write_mg() {
mv $todir/$mgconfig $todir/$mgconfig.orig
( cat <<XSL
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml" indent="yes"
cdata-section-elements="date key table_prefix session_save password dbname username host frontName model type pdoType initStatements"/>
<xsl:template match="@*|node()">
<xsl:copy>
<xsl:apply-templates select="@*|node()"/>
</xsl:copy>
</xsl:template>
<xsl:template match="username">
<username><![CDATA[$DSTDBUSER]]></username>
</xsl:template>
<xsl:template match="password">
<password><![CDATA[$DSTDBPASS]]></password>
</xsl:template>
<xsl:template match="dbname">
<dbname><![CDATA[$DSTDBNAME]]></dbname>
</xsl:template>
</xsl:stylesheet>
XSL
) > mg-write.xsl
xsltproc mg-write.xsl $todir/$mgconfig.orig |xmllint --format - > $todir/$mgconfig
}

config_write() {
if [ "$SITE" = "wp" ] ; then
  config_write_wp
elif [ "$SITE" = "mg" ] ; then
  config_write_mg
fi
}

rsync_public () {
  echo "copying website folder from $SOURCE:$fromdir"
  rsync --exclude var/cache --delete -rave ssh $SOURCE:$fromdir/ $todir
}

db_transfer() {
sqlfile=$1
if [ ! -z "$SRCDBNAME" ] ; then
  if [ $pause -eq 1 ] ; then
    read -s -n 1 -p "press any key to start databse transfer."
    echo
  fi
  echo "exporting database $SRCDBUSER/$SRCDBNAME to $sqlfile"
  ssh $SOURCE "mysqldump --password=\"$SRCDBPASS\" -u $SRCDBUSER $SRCDBNAME" > $sqlfile
fi
if [ ! -z "$DSTDBNAME" ] ; then
  echo "importing database $DSTDBUSER/$DSTDBNAME from $sqlfile"
  if [ -e $sqlfile ] ; then
    ( [ "$SITE" = "mg" ] && echo "SET FOREIGN_KEY_CHECKS = 0;" ; \
    sed -e 's/DEFINER=`$SRCDBUSER`@/DEFINER=`$DSTDBUSER`@/g' $sqlfile ; \
    [ "$SITE" = "mg" ] && echo "SET FOREIGN_KEY_CHECKS = 1;" ) | \
      mysql --user="$DSTDBUSER" --password="$DSTDBPASS" $DSTDBNAME
    rm -f $sqlfile
  fi
fi
}

cleanup() {
  cd $HOME
  rm -f \
    rules.awk mg-read.xsl mg-write.xsl \
    $todir/$wpconfig.orig \
    $todir/$mgconfig.orig \
    .ssh/id_sitecopy*
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
