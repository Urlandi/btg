#!/usr/local/bin/expect -f

### Default settings

set backup_dir {/etc;/usr/local/etc}
set skip_dir {}
set save_dir {/var/backup}
set local_copy {7}
set pack_arc {1}

set server_dir {}

set notify_email {admin@}

#########

array set err_param {}

set send_slow {4 .05}

set conf_file {/usr/local/etc/btgl.conf}
set conf_file_opt {}

set hostname [info hostname]
set date [clock format [clock seconds] -format {%Y%m%d-%H%M%S}]
set file_ext {tar}
set tar_opt {chP}

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
global hostname

set err_msg {}
set email_msg "$hostname alerts at [clock format [clock seconds] -format {%H:%M:%S %d/%m/%Y}]"

foreach { err err_det } [array get err_param] {
        set type {err%}
        if { $err > 100 } then { set type {wrn%} }

	foreach t_param $err_det {
        	switch $err {
        	1 { lappend err_msg "$type Error in \"[lindex $t_param 0]\"\n% [lindex $t_param 1]" }    
        	2 { lappend err_msg "$type Not exists \"[lindex $t_param 0]\"" }    
        	4 { lappend err_msg "$type Error backup \"[lindex $t_param 0]\"\n% [lindex $t_param 1]" }   
        	5 { lappend err_msg "$type Error file \"[lindex $t_param 0]\" copy\n% [lindex $t_param 1]" }
        	101 { lappend err_msg "$type Not found \"[join [lindex $t_param 0] {;}]\": use default settings" }  
        	102 { lappend err_msg "$type Can't remove old \"[lindex $t_param 0]\"\n% [lindex $t_param 1]" }  
        	103 { lappend err_msg "$type Can't pack some files \"[lindex $t_param 0]\"\n% [lindex $t_param 1]" }  
        	104 { lappend err_msg "$type Can't create md5 hashsum file \"[lindex $t_param 0]\"\n% [lindex $t_param 1]" }  
        	default { lappend err_msg "$type Unknown error with return code $err: \"lindex $t_param 0]\"\n% [lindex $t_param 1]" }
        	}
	}
}

foreach i $err_msg {
                puts stderr "$i"
                set email_msg "$email_msg\n$i"
        }

if { [string length $notify_email] && [llength $err_msg] } then {
	send_email $notify_email "$hostname backup errors" $email_msg
}
}

proc putscp backup_file {

global server_dir

if [string length $server_dir] then {
       	if [catch "file copy $backup_file $server_dir" err] then {
		push_err {5} "$backup_file" $err
		return {5}
       	}
}
return {0}
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

dir_rotate "$hostname*" $save_dir $local_copy

if $pack_arc then {
        set file_ext "$file_ext.gz"
        set tar_opt "$tar_opt\z"
}

set backup_file "$save_dir/$hostname\_$date.$file_ext"
set exclude_dir {}
if [string length $skip_dir] then {
	set exclude_dir "--exclude \"[join [split $skip_dir {;}] {" --exclude "}]\""
}
set arcmd "/usr/bin/tar -$tar_opt -f $backup_file $exclude_dir [split $backup_dir {;}]"

if [catch "exec $arcmd" err] then {
	if { [string match -nocase {*Truncated write;*} $err] || [string match -nocase {*file changed as we read it*} $err] || [string match -nocase {*file removed before we read it*} $err] } then {
		push_err {103} $arcmd $err
	} else {
		push_err {4} $arcmd $err
		break
	}
}

if [catch "exec /sbin/md5 -q $backup_file > $backup_file.md5" err] then {
	push_err {104} "$backup_file.md5" $err
}

if [putscp $backup_file] then { break }
if [file exists $backup_file.md5] then { 
	if [putscp $backup_file.md5] then { break }
}

break 
} 
show_err
