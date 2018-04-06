#!/bin/bash

wpconfig="wp-config.php"
mgconfig="app/etc/local.xml"
m2config="app/etc/env.php"
fromdir="public"
todir="$HOME/public"
pause=0

DSTDBHOST="localhost"
TMPDIR=$(mktemp -d "${TMPDIR:-/tmp/}$(basename "$0").XXXXXXXXXXXX")
GETOPT=getopt
GETOPT_LONG=1

if [ "Darwin" = "$(uname)" ] ; then
  if [ -x "/usr/local/opt/gnu-getopt/bin/getopt" ] ; then
    GETOPT="/usr/local/opt/gnu-getopt/bin/getopt"
  else
    GETOPT_LONG=0
  fi
fi

usage() {
  echo "usage: $0 [OPTIONS] user@hostname local-db [remote-db]"
  echo "Options"
  echo " -s, --src=DIR         source directory (default: ~/public)"
  echo " -d, --dest=DIR        destination directory (default: ~/public)"
  echo " -u, --user=NAME       run this script under another account."
  echo " -t, --type=CMS        website type (wp=Wordpress, mg=Magento, m2=M2)."
  echo " -p, --pause           wait for keypress before database transfer."
  echo " -h, --help            display this help and exit."
  echo " -e, --exclude=PATTERN exclude files from transfer."
  if [ $GETOPT_LONG -eq 0 ]; then
    echo ""
    echo "warning: long options are not supported on this system."
  fi
}

abspath() {
  ( 
    cd "$(dirname "$1")" || return
    pwd -P
  )
}

AP=$(abspath "$0")
SCRIPT="$AP/$(basename "$0")"
USER=$(whoami)
SITE=""

if [ $GETOPT_LONG -eq 1 ]; then
  options=$(${GETOPT} -o phu:t:s:d:e: -l pause,help,user:,src:,dest:,exclude: -- "$@")
else # assume GNU getopt (long arguments)
  options=$(${GETOPT} phu:t:s:d:e: "$@")
fi

if [ -z "$options" ] ; then
  # something went wrong, getopt will put out an error message for us
  exit 1
fi

eval set -- "$options"

declare -a exclude=( var/cache )
until [ -z "$1" ] ; do
  case $1 in
    -e|--exclude)
      exclude=( "${exclude[@]}" "$2" )
      shift
      ;;
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

if [ ! "$USER" = "$(whoami)" ] ; then
  echo "running $0 as $USER"
  CMD="$SCRIPT $*"
  su "$USER" -c "echo $CMD"
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
) > "$TMPDIR/mg-read.xsl"
xsltproc "$TMPDIR/mg-read.xsl" "$1"
}

wp_read_config() {
  ( echo "<?php" ; grep DB_ "$1" ; cat <<EOF
echo 'SRCDBPASS="' . DB_PASSWORD . '"' . PHP_EOL;
echo 'SRCDBUSER="' . DB_USER . '"' . PHP_EOL;
echo 'SRCDBNAME="' . DB_NAME . '"' . PHP_EOL;
echo 'SRCDBHOST="' . DB_HOST . '"' . PHP_EOL;
EOF
) | php
}

m2_read_config() {
( cat <<EOF
<?php
\$conf = include('$1');
\$db = \$conf['db']['connection']['default'];
echo 'SRCDBPASS="' . \$db['password'] . '"' . PHP_EOL;
echo 'SRCDBUSER="' . \$db['username'] . '"' . PHP_EOL;
echo 'SRCDBNAME="' . \$db['dbname'] . '"' . PHP_EOL;
echo 'SRCDBHOST="' . \$db['host'] . '"' . PHP_EOL;
EOF
) | php
}

config_read() {
  if [ "$SITE" = "wp" ] ; then
    confdir=$todir/$(dirname $wpconfig)
    mkdir -p "$confdir"
    scp "$SOURCE:$fromdir/$wpconfig" "$confdir"
    eval "$(wp_read_config "$todir/$wpconfig")"
  elif [ "$SITE" = "mg" ] ; then
    confdir="$todir/$(dirname "$mgconfig")"
    mkdir -p "$confdir"
    scp "$SOURCE:$fromdir/$mgconfig" "$confdir"
    eval "$(mg_read_config "$todir/$mgconfig")"
    echo "remote database is $SRCDBNAME"
  elif [ "$SITE" = "m2" ] ; then
    confdir=$todir/$(dirname $m2config)
    mkdir -p "$confdir"
    scp "$SOURCE:$fromdir/$m2config" "$confdir"
    eval "$(m2_read_config "$todir/$m2config")"
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
    eval "$(ssh-agent -s)"
    echo "starting local ssh-agent, pid ${SSH_AGENT_PID}"
    # shellcheck disable=SC2064
    trap "kill ${SSH_AGENT_PID}" EXIT
  fi
  ssh-add ~/.ssh/id_sitecopy
}


mycfg_create() {
  echo "[client]"
  echo "password=$1"
}

dbconf_local() {
  ## guess/ask local db credentials
  if [ ! -z "$DSTDB" ] ; then
    [ -z "$DSTDBNAME" ] && DSTDBNAME=$DSTDB
    [ -z "$DSTDBUSER" ] && DSTDBUSER=$DSTDB
  fi
  if [ -z "$DSTDBPASS" ] && [ ! -z "$DSTDBNAME" ] ; then
    echo "querying local database information"
    read -re -p "database name [$DSTDBNAME]:" DSTDB
    [ -z "$DSTDB" ] || DSTDBNAME=$DSTDB
    [ -z "$DSTDBUSER" ] && DSTDBUSER=$DSTDB
    read -re -p "database user [$DSTDBUSER]:" DSTDB
    [ -z "$DSTDB" ] || DSTDBUSER=$DSTDB
    read -rs -p "database password for $DSTDBUSER@$DSTDBNAME:" DSTDBPASS
    echo
  fi
  mycfg_create "$DSTDBPASS" > "$TMPDIR/.servebolt.cnf"
}

dbconf_remote() {
  ## guess/ask local db credentials
  if [ ! -z "$SRCDB" ] ; then
    [ -z "$SRCDBNAME" ] && SRCDBNAME=$SRCDB
    [ -z "$SRCDBUSER" ] && SRCDBUSER=$SRCDB
    [ -z "$SRCDBHOST" ] && SRCDBHOST=localhost
  fi
  if [ -z "$SRCDBPASS" ] && [ ! -z "$SRCDBNAME" ] ; then
    echo "querying remote database information"
    read -er -p "database name [$SRCDBNAME]:" SRCDB
    [ -z "$SRCDB" ] || SRCDBNAME=$SRCDB
    [ -z "$SRCDBUSER" ] && SRCDBUSER=$SRCDB
    read -er -p "database user [$SRCDBUSER]:" SRCDB
    [ -z "$SRCDB" ] || SRCDBUSER=$SRCDB
    read -sr -p "database password for $SRCDBUSER@$SRCDBNAME:" SRCDBPASS
    echo
  fi
  mycfg_create "$SRCDBPASS" | ssh "$SOURCE" "umask 077 ; cat > .servebolt.cnf"
}

config_write_wp() {
( cat <<AWK
\$0 ~ "DB_PASSWORD" { print substr(\$0, 1, index(\$0, "$SRCDBPASS")-1) "$DSTDBPASS" substr(\$0, length("$SRCDBPASS")+index(\$0, "$SRCDBPASS")) }
\$0 ~ "DB_USER" { sub("$SRCDBUSER","$DSTDBUSER") }
\$0 ~ "DB_NAME" { sub("$SRCDBNAME","$DSTDBNAME") }
\$0 ~ "DB_HOST" { sub("$SRCDBHOST","$DSTDBHOST") }
\$0 !~ "DB_PASSWORD" { print }
AWK
) > "$TMPDIR/rules.awk"
awk -f "$TMPDIR/rules.awk" < "$1"
}

config_write_m2() {
( cat <<REWRITE
<?php
\$conf = include('$1');
\$con = \$conf['resource']['default_setup']['connection'];
if (empty(\$con)) \$con = 'default';
\$db = &\$conf['db']['connection'][\$con];
\$db['host'] = '$DSTDBHOST';
\$db['username'] = '$DSTDBUSER';
\$db['password'] = '$DSTDBPASS';
\$db['dbname'] = '$DSTDBNAME';
\$db['host'] = '$DSTDBHOST';
echo '<?php' . PHP_EOL;
echo 'return ' . var_export(\$conf, TRUE) . ';' . PHP_EOL;
REWRITE
) | php
}

config_write_mg() {
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
<xsl:template match="host">
<host><![CDATA[$DSTDBHOST]]></host>
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
) > "$TMPDIR/mg-write.xsl"
xsltproc "$TMPDIR/mg-write.xsl" "$1" |xmllint --format -
}

config_write() {
  bak="$TMPDIR/config.bak"
  if [ "$SITE" = "wp" ] ; then
    cfg="$todir/$wpconfig"
    mv "$cfg" "$bak"
    config_write_wp "$bak" > "$cfg"
  elif [ "$SITE" = "mg" ] ; then
    cfg="$todir/$mgconfig"
    mv "$cfg" "$bak"
    config_write_mg "$bak" > "$cfg"
  elif [ "$SITE" = "m2" ] ; then
    cfg="$todir/$m2config"
    mv "$cfg" "$bak"
    config_write_m2 "$bak" > "$cfg"
  fi
}

rsync_public () {
  echo "copying website folder from $SOURCE:$fromdir"
  (
  for ex in "$@" ; do
    echo "$ex"
  done
  ) > "$TMPDIR/excludes"
  rsync --exclude-from="$TMPDIR/excludes" --delete -rave ssh "$SOURCE:$fromdir/" "$todir"
}

db_export() {
  args="-h $SRCDBHOST -u $SRCDBUSER $SRCDBNAME"
  # shellcheck disable=SC2029
  ssh "$SOURCE" "mysqldump --defaults-file=.servebolt.cnf $args ; rm .servebolt.cnf" > "$sqlfile"
}

db_transfer() {
sqlfile=$1
sqlbase=$(basename "$sqlfile")
if [ ! -z "$SRCDBNAME" ] ; then
  if [ $pause -eq 1 ] ; then
    read -rs -n 1 -p "press any key to start databse transfer."
    echo
  fi
  echo "exporting database $SRCDBUSER/$SRCDBNAME to $sqlbase"
  db_export
fi
if [ ! -z "$DSTDBNAME" ] ; then
  echo "importing database $DSTDBUSER/$DSTDBNAME from $sqlbase"
  if [ -e "$sqlfile" ] ; then
    # shellcheck disable=SC2016
    ( [ "$SITE" = "mg" ] && echo "SET FOREIGN_KEY_CHECKS = 0;" ; \
    sed -e 's/DEFINER=`$SRCDBUSER`@/DEFINER=`$DSTDBUSER`@/g' "$sqlfile" ; \
    [ "$SITE" = "mg" ] && echo "SET FOREIGN_KEY_CHECKS = 1;" ) | \
      mysql --defaults-file="$TMPDIR/.servebolt.cnf" -u "$DSTDBUSER" "$DSTDBNAME"
  fi
fi
rm -f "$sqlfile"
}

cleanup() {
  rm -rf "$TMPDIR" \
    ~/.ssh/id_sitecopy*
}

cd ~ || exit
echo "copy site from $SOURCE to $PWD"
setup_ssh
config_read
dbconf_remote
dbconf_local
rsync_public "${exclude[@]}"
config_write
db_transfer "$TMPDIR/sitecopy.sql"
cleanup
