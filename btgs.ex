#!/usr/local/bin/expect -f

### Default settings

set save_dir {/var/backup}
set local_copy {14}

set server_host {backup.host}
set server_usr {login}
set server_pass {password}
set server_port {22}
set server_prompt {[Pp]assword:}
set server_wait {600}

set notify_email {admin@}

#########

array set err_param {}

set send_slow {4 .05}

set conf_file {/usr/local/etc/btgs.conf}
set conf_file_opt {}

set serv_name [info hostname]

set got_files {0}
set bad_files {0}
set proc_files {0}
set err_files {0}
set new_files {0}
set miss_files {0}

proc send_email { to subj body } {
	if [catch { exec echo "To:$to\nSubj:$subj\n\n$body" | /usr/sbin/sendmail -t } err] then {
                puts stderr "err% Error sending email to \"$to\"\n% $err"
        }
	
}

proc push_err { c t_param { t {} } } {

	global err_param

	set err {}

	if { [lsearch -integer [array names err_param] $c] > -1 } then {
		set err $err_param($c)
	}
	set t_param [list $t_param $t]
	lappend err $t_param
	set err_param($c) $err
}

proc dir_rotate { files directory copys } {

set ls_save_dir [lsort -decreasing [glob -nocomplain -directory $directory $files]]
set num_files [llength $ls_save_dir]
set j {1}

foreach i $ls_save_dir {
        if { ! [string match {*.md5} $i] } then {
                if { $j > $copys } then {
                        if { [catch {file delete -force $i $i.md5} err] } then {
                                push_err {102} $i $err
                                return
                        }
                }
                incr j
        }
}
}

proc show_err {} { 

global err_param
global notify_email
global serv_name

set err_msg {}
set email_msg "$serv_name alerts at [clock format [clock seconds] -format {%H:%M:%S %d/%m/%Y}]"

foreach { err err_det } [array get err_param] {
	set type {err%}
	if { $err > 100 } then { set type {wrn%} }

	foreach t_param $err_det {
		switch $err {
		1 { lappend err_msg "$type Error in \"[lindex $t_param 0]\"\n% [lindex $t_param 1]" }
		2 { lappend err_msg "$type Not exists \"[lindex $t_param 0]\"" }
		3 { lappend err_msg "$type Can't create directory \"[lindex $t_param 0]\"\n% [lindex $t_param 1]" }
		4 { lappend err_msg "$type Wrong directory: is a file \"[lindex $t_param 0]\"" }
		5 { lappend err_msg "$type Error move file \"[lindex $t_param 0]\"\n% [lindex $t_param 1]" }	
		6 { lappend err_msg "$type Server \"[lindex $t_param 0]\" timeout" }	
		7 { lappend err_msg "$type Error scp connect \"[lindex $t_param 0]\"\n% [lindex $t_param 1]" }
                8 { lappend err_msg "$type Server \"[lindex $t_param 0]\" timeout" }
		101 { lappend err_msg "$type Not found \"[join [lindex $t_param 0] {;}]\": use default settings" }
		102 { lappend err_msg "$type Can't calculate md5 hashsum file \"[lindex $t_param 0]\"\n% [lindex $t_param 1]" }
		103 { lappend err_msg "$type Can't read md5 hashsum file \"[lindex $t_param 0]\"\n% [lindex $t_param 1]" }
		104 { lappend err_msg "$type Wrong backup file \"[lindex $t_param 0]\"" }
		default { lappend err_msg "$type Unknown error with return code $err: \"lindex $t_param 0]\"\n% [lindex $t_param 1]" }
		}
	}
}

foreach i $err_msg {
                puts stderr "$i"
                set email_msg "$email_msg\n$i"
        }
if { [string length $notify_email] && [llength $err_msg] } then {
	send_email $notify_email "$serv_name backup server errors" $email_msg
}
}

proc putscp backup_file {

global server_host
global server_usr
global server_pass
global server_port
global server_prompt
global server_wait

log_user {0}

set retn {0}
set err {}

while { 1 } {
if { [string length $server_host] && [string length $server_port] } then {
        if [catch { spawn -noecho /usr/bin/scp -qP $server_port $backup_file $server_usr@$server_host: } err] then {
                set retn 7
                break
        }

	if [catch {

        expect {
                $server_prompt {send -s "$server_pass\n"}
                -timeout $server_wait timeout {
                        set retn 8
  		        close                    
                        break
                }
        }
        expect {
                -timeout $server_wait timeout {
                        set retn 8
			close                        
                        break
                }
                eof {}
        }

	} err] then {
                set retn 5
                break
        }

}
break
}
if $retn then { push_err $retn "$server_host:$server_port" $err }
return $retn
}


if { $argc > 0 } then { set conf_file_opt [lindex $argv 0] }
if [string length $conf_file_opt] then { set conf_file [linsert $conf_file 0 $conf_file_opt] }

set c {0}
foreach i $conf_file {
	if [file exists $i] then {
		set conf_file $i
		break
	}
	incr c
}

while { ! [array size err_param] } { 

if { $c == [llength $conf_file] } then {
	push_err {101} $conf_file
} else {
	if { [catch { source $conf_file } err] } then {
		push_err {1} $conf_file $err
		break	
	}
}

set save_dir [string trim $save_dir]

if { ! [file exists $save_dir] || ! [file isdirectory $save_dir] } then {
	push_err {2} $save_dir
	break
}

set ls_save_dir [glob -nocomplain -types f -directory $save_dir {*}]

foreach i $ls_save_dir {

	set hostname {}
	set md5calc {}
	set md5got {}

	if { ! [string match {*.md5} $i] } then {

		incr got_files

		if [catch "exec /sbin/md5 -q $i" err] then {
			push_err {102} $i $err
		} else {
			set md5calc $err
		}
		if [file exists $i.md5] then { 
			if [catch "exec /bin/cat $i.md5" err] then {
                        	push_err {103} "$i.md5" $err
                	} else {
                        	set md5got $err
                	}
		}
		if { ! [regexp {.*/(.*)_.*} $i t hostname] } then {
			push_err {104} $i
			continue
		}
		
		if { ! [file exists "$save_dir/$hostname"] } then {
			incr new_files
			if [catch "file mkdir $save_dir/$hostname" err] then {
				push_err {3} "$save_dir/$hostname" $err
				continue
			}
		} elseif { ! [file isdirectory "$save_dir/$hostname"] } {
			push_err {4} "$save_dir/$hostname"
			continue
		}
		
		putscp $i
                if [file exists $i.md5] then { putscp $i.md5 }

		if [string equal $md5calc $md5got] then {
			if [catch "file rename $i $i.md5 $save_dir/$hostname" err] then {
				push_err {5} $i $err
				continue
			}
		} else {
			incr bad_files
			if [catch "file rename $i $save_dir/$hostname/[file tail $i].bad" err] {
				push_err {5} $i $err
				continue
			}
			if [file exists $i.md5] then { 	
				if [catch "file rename $i.md5 $save_dir/$hostname/[file tail $i].bad.md5" err] {
					push_err {5} $i $err
					continue
				} 
			}
		}

		incr proc_files
	}
}

set ls_save_dir_dir [glob -nocomplain -types d -directory $save_dir {*}]
set miss_files [expr [llength $ls_save_dir_dir] - $got_files]

foreach i $ls_save_dir_dir {
	dir_rotate "*" $i $local_copy
}

break 
} 

set err_files [expr $got_files - $proc_files]

if [string length $notify_email]  then {
	send_email $notify_email "$serv_name backup server statistics"\
	"$serv_name info at [clock format [clock seconds] -format {%H:%M:%S %d/%m/%Y}]\nIncoming:\t$got_files\nProcessed:\t$proc_files\nProblem:\t$err_files\nMiss:\t\t$miss_files\nBad hashsum:\t$bad_files\nNew:\t\t$new_files"
}

show_err 
