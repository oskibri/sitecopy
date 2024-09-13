### Thu 05 Sep Oskar VH <oskar@servebolt.com> - `v1.3.2`
  - Fixed broken check for remote os by cat out /proc/version instead of looking at filesystem
  - Added -o|--only-db flag to be able to only transfer database and skip files
  - Added short options for remote database credentials (-N,-H,-U,-X)
  - Updated usage to reflec changed to options/flag

### Thu 05 Sep Oskar VH <oskar@servebolt.com> - `v1.3.1`
  - Sitecopy now properly checks the remote server if it is SL7, SL8 or something else and updates rsync accordinly
  - Updated rsync function to either copy from manual source by user or default which is public, site/pulic or home depending on SL7, SL8 or other os respectively
  - Removed unnecessary comments
  - Added --delete-after to rsync
  - Fixed last printf to contain newline at end
  - Removed (WIP) from usage section regarding getting local db password. Currently not a feature
  - Updated usage section for -s|--src to give more explicit information of its functionality

### Thu 05 Sep Oskar VH <oskar@servebolt.com> - `v1.3.0`
  - Added -v|--version flag to print version number
  - Changed date to ISO 8601 format

### Mon 26 Aug Oskar VH <oskar@servebolt.com> - `v1.2.9`
  - Removed hardcoded 'localhost' for $REMOTE_DBHOST. This ensures that a custom database host are applied to remote db.cnf
  - Added exit statement to the end of script to properly run trap sequence (exit codes have always been redundant because of trap and should be removed)

### Thu 6 Jun Oskar VH <oskar@servebolt.com> - `v1.2.8`
  - Added -p to mkdir $SBTEMP to prevent error when dir already exists
  - Added single quotes around local DB password in cnf file

### Tue 5 Mar Oskar VH <oskar@servebolt.com> - `v1.2.7`
  - Added the whole .ssh directory to be excluded

### Fri 1 Mar Oskar VH <oskar@servebolt.com> - `v1.2.6`
  - Hotfix for help page always showing
  - Switch from using rsa SSH keys, to ed_25519 as default 

### Fri 1 Mar Oskar VH <oskar@servebolt.com> - `v1.2.5`
  - Updated trap function to check if remove .cnf file has been added before removing
  - If ~/site and/or ~/site/public doesnt exist, create them
  - If destination env is SL8, update public dir perms to 0710
  - Updated help page to reflect changes in flags (long overdue)

### Thu 29 Feb Oskar VH <oskar@servebolt.com> - `v1.2.4`
  - Mysql credentials are now stored in a .cnf file for better security
  - Removed default migration of $HOME dir if not $DOCUMENT_ROOT is specified or found
  - Removed the --only-root and -o flag
  - For finer control on source and destination directory, --src and --dest have to be used
  - If CMS config file is automatically found and --src isnt specified, sitecopy will exit instead of continuing

### Mon 8 Jan Oskar VH <oskar@servebolt.com> - `v1.2.3`
  - Made $SSHUSER check contain periods in the if statement

### Wed 15 Nov Oskar VH <oskar@servebolt.com> - `v1.2.2`
  - Added option -t and -k for sitecopy1 backwards compatibility

### Thu 09 Nov Oskar VH <oskar@servebolt.com> - `v1.2.1`
  - Fixed checking if remote DB creds are set by user before auto checking for creds in config file
  - Removed checks for env files and usage of SB API
  - Fixed proper feedback for wrong port number
  - Fixed removal of env path in SBO by removing redundant value set for MYSQL_PWD

### Wed 08 Nov Oskar VH <oskar@servebolt.com> - `v1.2.0`
  - Added removal of Servebolt Optimizer env path in database after migration

### Wed 08 Nov Oskar VH <oskar@servebolt.com> - `v1.1.9`
  - Changed explicit default exclusion of .dotfiles (because of .env f.ex). More might come in the future
  - Added .wp-cli to default exclusion list
  - Fixed proper removal of exclusion lists in /tmp

### Wed 11 Oct Oskar VH <oskar@servebolt.com> - `v1.1.8`
  - Hotfix duplicate config file with E appended of filename with sed command

### Wed 11 Oct Oskar VH <oskar@servebolt.com> - `v1.1.7`
  - Hotfix changed sed back to perl for config DB pass overwrite for working substition

### Wed 11 Oct Oskar VH <oskar@servebolt.com> - `v1.1.6`
  - Added changelog
  - Duplicate DB name/user string after local config overwrite fix
    - Changed out perl with sed and added use of word boundary (\b)
