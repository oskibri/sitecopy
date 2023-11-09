* Thu 9th Nov Oskar VH <oskar@servebotl.com> - 1.2.1
- Fixed checking if remote DB creds are set by user before auto checking for creds in config file
- Removed checks for env files and usage of SB API
- Fixed proper feedback for wrong port number
- Fixed removal of env path in SBO by removing redundant value set for MYSQL_PWD

* Wed 8th Nov Oskar VH <oskar@servebotl.com> - 1.2.0
- Added removal of Servebolt Optimizer env path in database after migration

* Wed 8th Nov Oskar VH <oskar@servebotl.com> - 1.1.9
- Changed explicit default exclusion of .dotfiles (because of .env f.ex). More might come in the future
- Added .wp-cli to default exclusion list
- Fixed proper removal of exclusion lists in /tmp

* Wed 11 Oct Oskar VH <oskar@servebolt.com> - 1.1.8
- Hotfix duplicate config file with E appended of filename with sed command

* Wed 11 Oct Oskar VH <oskar@servebolt.com> - 1.1.7
- Hotfix changed sed back to perl for config DB pass overwrite for working substition

* Wed 11 Oct Oskar VH <oskar@servebolt.com> - 1.1.6
- Added changelog
- Duplicate DB name/user string after local config overwrite fix
  - Changed out perl with sed and added use of word boundary (\b)
