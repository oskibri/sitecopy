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
```

If the local DB password is not provided:

- The script will prompt for it.

If no local database is specified:

- Database transfer is skipped.

---

## Document Root Detection

### WordPress

Detected if the config directory contains:

- `wp-admin`
- `wp-includes`

### Magento (`env.php`)

Detected by removing `/app/etc` from the config path.

If document root cannot be detected:

- The entire remote home directory is copied.

---

## Example Workflows

### Simple migration

```bash
bash sitecopy.sh user@example.com mylocaldb

Copy only document Root:

bash sitecopy.sh -o user@example.com mylocaldb

Custom source and excludes:

bash sitecopy.sh \
  -s /var/www/site \
  -e "cache,tmp,*.log" \
  user@example.com mylocaldb
```

## Exit Behavior

On exit (normal or interrupted), the script:

- Restores original working directory
- Stops `ssh-agent`
- Restores terminal state
- Removes temporary exclude list

---

## Notes / Caveats

- Assumes MySQL-compatible databases.
- Designed primarily for Servebolt environments.
- Only basic CMS auto-detection is implemented.
- API-based DB password updates are not implemented yet.

