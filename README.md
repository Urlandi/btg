### Backup regular files

Arc and compress files from list of directories by <b>tar</b>. Puts arc file to remote host with <b>md5</b> checksum file by <b>scp</b> to home directory. Checking files on server side and notify administrator about errors. Used TCL and Expect.

#### Edit config file 
<i>/usr/local/etc/btg[s|l].conf</i> (default). If it not exist you will have to create it or specify other location by command argument.

 - set backup_dir {/dir/for/backup/1;/dir/for/backup/2; ... ;/dir/for/backup/n} - which directories backuped
 - set skip_dir {/skip/dir/1;/skip/dir/2; ... ;/skip/dir/n} - which directories excluded from backup
 - set save_dir {/var/backup} - where saved local copy
 - set local_copy {7} - the number of local copies. Early copies are deleted.
 - set pack_arc {1} - archive will be compressed

-
 - set server_host {backup.host} - remote hostname for backup
 - set server_usr {login} - remote hostname login
 - set server_pass {password}  - remote hostname password
 - set server_port {22} - remote hostname tcp port
 - set server_dir {/dir/copy} - copy backup file to local directory also, if present. (for btgl.ex)

-
 - set server_prompt {[Pp]assword:} - remote hostname promt password
 - set server_wait {600} - server time connection wait

-
 - set notify_email {root@} - email for notify and error messages

skip any options for default use

#### Put on crontab job 

Run <i>btg[s|l].ex [/config/file]</i>

 - [btg.ex](btg.ex) - regular script for backup
 - [btgl.ex](btgl.ex) - only local copies
 - [btgs.ex](btgs.ex) - script on server side. Crontab job must be performed after receiving all backup files from remote hosts.

