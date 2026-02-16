# sitecopy

**sitecopy** is a Bash script for copying a website from a remote server into a Servebolt environment.  
It transfers both **files and database**, and attempts to automatically detect configuration and credentials.

It is primarily intended for:

- Migrating sites into Servebolt
- Creating staging environments
- Copying sites between environments

---

## Features

- Copies site files over SSH using `rsync`
- Dumps and imports remote MySQL databases
- Auto-detects:
  - CMS configuration file
  - Database credentials
  - Document root
- Supports:
  - WordPress (`wp-config.php`)
  - Magento-style `env.php`
- Automatically sets up SSH keys if needed
- Shows transfer progress using `pv`
- Option to copy only the document root

---

## Requirements

The script depends on:

- `bash`
- `ssh`
- `ssh-agent`
- `ssh-keygen`
- `ssh-copy-id`
- `rsync`
- `mysqldump`
- `mysql`
- `pv`
- `awk`
- `sed`
- `perl`
- `getopt`

Optional:

- `jq` (used when `environment.json` is present)

---

## Basic Usage

```bash
bash sitecopy.sh [OPTIONS] <USER@HOSTNAME> <LOCAL_DATABASE>
bash sitecopy.sh boltuser_1234@servebolt.cloud localdb
```

### With options
```
bash sitecopy.sh \
  -u boltuser_1234 \
  -h servebolt.cloud \
  -p 1022 \
  -D localdb \
  --exclude="*.jpg,cache,tmp"
```

## How It Works

1. Ensures SSH keys exist locally.
2. Copies the SSH public key to the remote host (if needed).
3. Searches the remote home directory for known config files:
   - `wp-config.php`
   - `.env`
   - `env.php`
4. Extracts database credentials.
5. Verifies:
   - Remote database connection
   - Local database connection
6. Detects document root (if possible).
7. Transfers:
   - Files via `rsync`
   - Database via `mysqldump` over SSH
8. Updates local config with new DB credentials.

---

## Options

| Option | Description |
|--------|-------------|
| `--help` | Show help text |
| `-s, --src <DIR>` | Source directory on remote server |
| `-d, --dest <DIR>` | Destination directory locally |
| `-e, --exclude <LIST>` | Comma-separated exclude list |
| `-u, --user <USER>` | Remote SSH user |
| `-h, --host <HOST>` | Remote SSH host |
| `-p, --port <PORT>` | Remote SSH port (default: 22) |
| `-D, --local-dbname <NAME>` | Local database name |
| `-P, --local-dbpass <PASS>` | Local database password |
| `--remote-dbname <NAME>` | Remote database name |
| `--remote-dbuser <USER>` | Remote database user |
| `--remote-dbhost <HOST>` | Remote database host |
| `--remote-dbpass <PASS>` | Remote database password |
| `-o, --only-docroot` | Transfer only document root |

---

## Default Behavior

### Source directory
- Remote user’s home directory unless overridden.

### Destination directory
Depends on Servebolt environment structure:

| Structure | Destination |
|-----------|------------|
| `~/cust/...` | `~/site/public` |
| `~/kunder/...` | `~/public` |
| Otherwise | Derived from environment config |

---

## Default Exclude List

The following paths are excluded by default:
```
sitecopy
/.*
/environment.*
/.ssh
/logs
/tmp
/php-session
/php-upload
```


You can extend this list using `--exclude`.

---

## Database Handling

If a local database name is provided:

- The script attempts to:
  - Extract remote DB credentials
  - Verify connections
  - Transfer database using:

```bash
mysqldump | mysql
