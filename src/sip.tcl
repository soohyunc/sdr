set invited_sessions {}
set qdurs {"5 mins" "15 mins" "half hour" "an hour"}
set qdurt {300 900 1800 3600}
#set qpurp {"Two-way call" "Group Chat" "Small Meeting" "Large Meeting"}
set qpurp {"Group Chat" "Small Meeting" "Large Meeting"}
#set qpmway {0 1 1 1}
set qpmway {1 1 1}
proc qcall {} {
    global scope qdurs qdurt qpurp qpmway medialist send
    catch {destroy .qc}
    toplevel .qc
    wm title .qc "Sdr: Quick Call"
    posn_win .qc
    frame .qc.f -borderwidth 2 -relief groove
    pack .qc.f -side top
    new_mk_session_name .qc.f new
    set scope admin
    frame .qc.f.l -borderwidth 0
    pack .qc.f.l -side left -anchor nw
    label .qc.f.l.l -text "Expected Duration:  "
    pack .qc.f.l.l -side top
    menubutton .qc.f.l.m -menu .qc.f.l.m.menu -text [lindex $qdurs 0] -relief raised -borderwidth 1

    tixAddBalloon .qc.f.l.m MenuButton [tt "Select how long your quick \
call is likely to last. \n\nThis is the time that the quick call \
will be advertised in the main session window under private \
sessions - the session announcement will only be available to \
people you invite to join the session"]

    global qdur
    set qdur [lindex $qdurt 0]
    pack .qc.f.l.m -side top
    menu .qc.f.l.m.menu -tearoff 0
    for {set i 0} {$i < [llength $qdurs]} {incr i} {
	.qc.f.l.m.menu add radiobutton -label [lindex $qdurs $i] \
	    -variable qdur -value [lindex $qdurt $i] \
	    -command ".qc.f.l.m configure -text \"[lindex $qdurs $i]\""
    }
    label .qc.f.l.l2 -text "Purpose:"
    pack .qc.f.l.l2 -side top
    menubutton .qc.f.l.m2 -menu .qc.f.l.m2.menu -text [lindex $qpurp 0] -relief raised -borderwidth 1
    tixAddBalloon .qc.f.l.m2 MenuButton [tt "Select the purpose of the quick call. This will be given to the people you invite to partake in the quick call"]
    global qpur
    set qpur [lindex $qpurp 0]
    pack .qc.f.l.m2 -side top
    menu .qc.f.l.m2.menu -tearoff 0
    for {set i 0} {$i < [llength $qpurp]} {incr i} {
	.qc.f.l.m2.menu add radiobutton -label [lindex $qpurp $i] \
	    -variable qpur -value [lindex $qpurp $i] \
	    -command ".qc.f.l.m2 configure -text \"[lindex $qpurp $i]\";qset_config_scope \$qpur"
    }
    frame .qc.f.l.f -borderwidth 0
    pack .qc.f.l.f -side top
    new_mk_session_admin .qc.f.l.f.admin new $scope
    qset_config_scope $qpur
    foreach i $medialist {
	set send($i) 0
    }
    set send(audio) 1
    new_mk_session_media .qc.f.media new admin 0
    frame .qc.f.buttons -borderwidth 2 -relief groove
    pack .qc.f.buttons -side top -fill x -expand true
    button .qc.f.buttons.invite -text "Invite" -command {set invaid [qcreate];if {$invaid!=0} { popup $invaid $ifstyle(view) advert;embed_invite $invaid .desc$invaid.f;destroy .qc}}
    tixAddBalloon .qc.f.buttons.invite Button [tt "Click here to invite people to participate in the session"]
    pack .qc.f.buttons.invite -side left -fill x -expand true
    button .qc.f.buttons.dismiss -text "Cancel" -command {destroy .qc}
    tixAddBalloon .qc.f.buttons.dismiss Button [tt "Click here to cancel creating a quick call"]
    pack .qc.f.buttons.dismiss -side left -fill x -expand true
    move_onscreen .qc
}


proc qset_config_scope {purpose} {
    if {$purpose=="Two-way call"} {
	pack unpack .qc.f.l.f.admin
    } else {
	pack .qc.f.l.f.admin  -side top
    }
}

set qseq 0
proc qcreate {} {
    #create a session that we don't publically announce to anyone
    #so we can do a private invitation
    global qseq qpur qdur zone ttl media_attr media_fmt media_proto
    global yourphone youremail medialist send ldata sesstype
    global sdrversion
    set aid priv$qseq
    incr qseq
    if {[get_new_session_name .qc.f]==""} {
        errorpopup "No Session Name" "You must give the session a name"
        return 0
    }
    set ldata($aid,session) [get_new_session_name .qc.f]
    set ldata($aid,desc) $qpur
    set ldata($aid,phonelist) \"$yourphone\"
    set ldata($aid,emaillist) \"$youremail\"
    set ldata($aid,starttime) [unix_to_ntp [gettimeofday]]
    set ldata($aid,endtime) [unix_to_ntp [expr [gettimeofday] + $qdur]]
    set ldata($aid,no_of_times) 1
    set ldata($aid,time0,no_of_rpts) 0
    set ldata($aid,starttime,0) [unix_to_ntp [gettimeofday]]
    set ldata($aid,endtime,0) [unix_to_ntp [expr [gettimeofday] + $qdur]]
    set ldata($aid,method) invite
    set ldata($aid,type) meeting
    set ldata($aid,tool) "sdr $sdrversion"
    set ldata($aid,vars) "tool:$ldata($aid,tool)\ntype:$ldata($aid,type)"
    set ldata($aid,key) ""
    set ldata($aid,lastheard) [gettimeofday]
    set medianum 0
    foreach media $medialist {
        if {$send($media)==1} {
	    set ldata($aid,$medianum,media) $media
	    set ldata($aid,$medianum,port) [generate_port $media]
	    set ldata($aid,$medianum,addr) [generate_address $zone(base_addr,$zone(cur_zone)) $zone(netmask,$zone(cur_zone))]
	    set ldata($aid,$medianum,fmt) $media_fmt($media)
	    set ldata($aid,$medianum,proto) $media_proto($media)
	    set ldata($aid,$medianum,ttl) $zone(ttl,$zone(cur_zone))
	    set ldata($aid,$medianum,vars) ""
            foreach attr [array names media_attr] {
                set m [lindex [split $attr ","] 0]
                set a [lindex [split $attr ","] 1]
                if {$m==$media} {
                    if {$media_attr($attr)==1} {
			set ldata($aid,$medianum,vars) \
                        "$ldata($aid,$medianum,vars) $a"
		    } elseif {($media_attr($attr)!=0)&&\
			    ($media_attr($attr)!="")} {
			set ldata($aid,$medianum,vars) \
		           "$ldata($aid,$medianum,vars) $a:$media_attr($attr)"
		    }
                }
            }
	    incr medianum
        }
    }
    if {$medianum==0} {
	errorpopup "No Media Selected" "You must select at least one media"
	return 0
    }
    set ldata($aid,medianum) $medianum
    set ldata($aid,creator) [getusername]
    set ldata($aid,createtime) [gettimeofday]
    set ldata($aid,modtime) [gettimeofday]
    set ldata($aid,createaddr) [gethostaddr]
    set ldata($aid,uri) 0
    set ldata($aid,multicast) $ldata($aid,0,addr)
    set ldata($aid,ttl) $ldata($aid,0,ttl)
    set ldata($aid,tfrom) [fixtime [gettime \
                                    [ntp_to_unix $ldata($aid,starttime)]]]
    set ldata($aid,tfrom,0) $ldata($aid,tfrom)
    set ldata($aid,tto) [fixtime [gettime \
                                  [ntp_to_unix $ldata($aid,endtime)]]]
    set ldata($aid,tto,0) $ldata($aid,tto)
    set ldata($aid,source) $ldata($aid,createaddr)
    set ldata($aid,heardfrom) "local user"
    set ldata($aid,theard) [fixtime [gettime [gettimeofday]]]
    return $aid
}

proc invite {aid} {
    global invited_sessions ldata
    catch {destroy .inv}
    toplevel .inv
#    puts "C aid:$aid"
    wm title .inv "Sdr: Invite User"
    if {$invited_sessions=={}} {
	set invited_sessions $aid
    } else {
	if {[lsearch $invited_sessions $aid]==-1} {
	    set invited_sessions "$invited_sessions $aid"
	}
    }
    foreach session $invited_sessions {
	set wname .inv.$session
	frame $wname -borderwidth 2 -relief groove
	pack $wname -side top
	label $wname.l -text $ldata($session,session)
	pack $wname.l -side top
	frame $wname.f
	pack $wname.f -side top -fill x -expand true
	entry $wname.f.e -width 30 -relief sunken \
	    -bg [option get . entryBackground Sdr]
	bind $wname.f.e <Return> "send_sip \[$wname.f.e get\] \"$session\" 0 0"
	pack $wname.f.e -side left -fill x -expand true
	button $wname.f.inv -text "Invite" -command "send_sip \[$wname.f.e get\] \"$session\" 0 0"
	pack $wname.f.inv -side left
	sip_list_invitees $wname $session
    }
    frame .inv.f -borderwidth 2 -relief groove
    pack .inv.f -side top -fill x -expand true
    button .inv.f.dismiss -text "Dismiss" -command "destroy .inv"
    pack .inv.f.dismiss -side left -fill x -expand true
}

proc embed_invite {aid win} {
    global invited_sessions ldata
    frame $win.inv
    pack $win.inv -side top -before $win.f3  -fill x -expand true
    if {$invited_sessions=={}} {
	set invited_sessions $aid
    } else {
	if {[lsearch $invited_sessions $aid]==-1} {
	    set invited_sessions "$invited_sessions $aid"
	}
    }
    set session $aid
    set wname $win.inv.$session
    frame $wname -borderwidth 2 -relief groove
    pack $wname -side top
    frame $wname.f0
    pack $wname.f0 -side top -anchor nw -expand true -fill x
    label $wname.f0.l -text "Invite user: (username@hostname)"
    pack $wname.f0.l -side left
    menubutton $wname.f0.m -text "Browse" -menu $wname.f0.m.m -relief raised
    menu $wname.f0.m.m
    make_address_book $wname.f0.m.m $wname.f.e
    pack $wname.f0.m -side right 
    
    frame $wname.f
    pack $wname.f -side top -fill x -expand true
    entry $wname.f.e -width 30 -relief sunken \
	    -bg [option get . entryBackground Sdr]
    tixAddBalloon $wname.f.e Entry [tt "Enter username and machinename for user in the form: username@machine"]
    bind $wname.f.e <Return> "send_sip \[$wname.f.e get\] \"$session\" 0 $wname 0"
    pack $wname.f.e -side left -fill x -expand true
    button $wname.f.inv -text "Invite" -highlightthickness 0 \
	    -command "send_sip \[$wname.f.e get\] \"$session\" 0 $wname 0"
    pack $wname.f.inv -side right
    sip_list_invitees $wname $session
    catch {pack unpack $win.f3.invite}
}

proc sip_list_invitees {wname aid} {
    global sip_request_status sip_requests sip_request_user sip_request_aid
    foreach id $sip_requests {
	if {$sip_request_aid($id)==$aid} {
	    set lid [join [split $id "."] "-"]
	    if {$sip_request_status($id)!="declined"} {
		frame $wname.$lid
		pack $wname.$lid -side top
		label $wname.$lid.l1 -width 20 -text $sip_request_user($id)
		pack $wname.$lid.l1 -side left
		label $wname.$lid.l2 -width 10 -text $sip_request_status($id)
		pack $wname.$lid.l2 -side left
	    }
	}
    }
}

proc send_sip {user aid id win addr} {
    global youremail no_of_connections sip_request_status sip_requests
    global sip_request_count sip_request_user
    set username [string trimleft [lindex [split $user "@"] 0] " "]
    set host [string trimright [lindex [split $user "@"] 1] " "]
    if {($username=="")||($host=="")} {
	msgpopup "Invalid Address" "Addresses must be of the form \"username@host\""
	return 0
    }
    if {[string compare $addr "0"]==0} {
	set addr [lookup_host $host]
	if {$addr=="0.0.0.0"} {
	    msgpopup "Invalid Address" "The hostname $host is not known"
	    return 0
	}
    } else {
	set addr [lookup_host $addr]
	if {$addr=="0.0.0.0"} {
	    msgpopup "Invalid Address" "The hostname $addr is not known"
	    return 0
	}
    }

    if {[lsearch $sip_requests $id]!=-1} {
	if {($sip_request_status($id)=="unknown") &&
	    ($sip_request_count($id)>10)} {
		sip_connection_fail $id "No response from remote site while trying to contact $sip_request_user($id)"
		return 0
	    }
	if {($sip_request_status($id)=="progressing") &&
	    ($sip_request_count($id)>20)} {
		sip_connection_fail $id "Unknown failure at remote site while trying to contact $sip_request_user($id)"
		return 0
	    }
	if {($sip_request_status($id)=="ringing") &&
	    ($sip_request_count($id)>30)} {
		sip_connection_fail $id "No response from $sip_request_user($id) to ringing at remote site"
		return 0
	    }
	if {($sip_request_status($id)=="connected")||
	    ($sip_request_status($id)=="declined")} {
		return 0
	    }
	incr sip_request_count($id)
    }
    if {$id==0} {
	set id "[getpid]-[gettimeofday]@[gethostaddr]"
	set sip_request_count($id) 0
    }
    set body [make_session $aid]
    set length [string length $body]
    set msg "INVITE $user SIP/2.0"
    set msg "$msg\r\nVia: SIP/2.0/UDP [gethostaddr]"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nFrom:$youremail"
    set msg "$msg\r\nTo:$user"
    set msg "$msg\r\nContent-type:application/sdp"
    set msg "$msg\r\nContent-length:$length"
    set msg "$msg\r\n\n\r$body"
    debug $msg
    if {[sip_user_pending $user $id $aid $win]==0} {
	if {[sip_send_msg $msg $addr]==0} {
	    set no_of_connections($id) 1
	    after 2000 send_sip \"$user\" $aid $id $win $addr
	} else {
	    sip_connection_fail $id "No-one is listening to invitations sent to $sip_request_user($id)"
	}
    }
    return 0
}

set sip_requests {}
proc sip_user_pending {user id aid win} {
    global sip_request_status sip_requests sip_request_user sip_request_aid
    global sip_request_win
#    puts $id
    if {[lsearch $sip_requests $id]!=-1} {
	return 0
    }
    foreach eid $sip_requests {
	if {$sip_request_user($eid)==$user} {
	    if {($sip_request_status($eid)=="unknown")||
		($sip_request_status($eid)=="progressing")||
		($sip_request_status($eid)=="ringing")} {
		    msgpopup "Call in progress" "You are already calling $user"
		    return -1
		}
	}
    }
    set sip_request_status($id) unknown
    set sip_request_user($id) $user
    set sip_request_aid($id) $aid
    set sip_request_win($id) $win
    set sip_requests "$sip_requests $id"
    set lid [join [split $id "."] "-"]
#    set f .inv.$aid.$lid
    set f $win.$lid
    frame $f
    pack $f -after $win.f
    label $f.l1 -text $user -width 20
    pack $f.l1 -side left
    label $f.l2 -text "?" -width 10
    pack $f.l2 -side left
    return 0
}

proc sip_session_status {id status} {
    global sip_request_status sip_requests sip_request_aid
    global sip_request_win
    if {[lsearch $sip_requests $id]==-1} {
        return 0
    }
    set sip_request_status($id) [lindex $status 0]
    set lid [join [split $id "."] "-"]
#    set aid $sip_request_aid($id)
    set f $sip_request_win($id).$lid
    catch {$f.l2 configure -text $status}
}

set sip_invites {}
proc sip_user_alert {msg} {
    global sip_invites sip_invite_status
    set lines [split $msg "\n"]
    set cur-to [lindex [lindex $lines 0] 1]
    set path ""
    set srcuser ""
    set dstuser ""
    set ct ""
    foreach line $lines {
	set line [string trim $line "\r"]
	if {$line==""} {break}
	set lparts [split $line ":"]
	switch [string toupper [lindex $lparts 0]] {
	    CALL-ID {
		set id [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    FROM {
		set srcuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    TO {
		set dstuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    VIA {
		if {$path==""} {
		    set path $line
		} else {
		    set path "$path\r\n$line"
		}
	    }
	    CONTENT-TYPE {
		set ct [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	}
    }
    debug "ct=$ct"
    if {[string compare $ct "application/sdp"]!=0} {
	return 0
    }
    foreach line $lines {
	set line [string trim $line "\r"]
	set lparts [split $line "="]
	switch [lindex $lparts 0] {
	    s {
		set sname [join [lrange $lparts 1 end] "="]
	    }
	}
    }

#    puts here
    if {[lsearch $sip_invites $id]==-1} {
	#it's a new invite
	set sip_invites "$sip_invites $id"

	#shouldn't really pass the SIP header to the SDP parser
	#but it doesn't break anything
	sip_inform_user $id $srcuser $dstuser $path $sname $msg

	set sip_invite_status($id) ringing
	sip_ringing_user $id $srcuser $dstuser $path
    } else {
	switch $sip_invite_status($id) {
	    ringing {
		sip_ringing_user $id $srcuser $dstuser $path
	    }
	    refused {
		set aid [parse_sdp $msg]
		sip_refuse_invite $aid
	    }
	    accepted {
		set aid [parse_sdp $msg]
		sip_accept_invite $aid
	    }
	}
    }
}

proc sip_inform_user {id srcuser dstuser path sname sdp} {
    global ifstyle
    global sessdetails
#    set win .alert[join [split $id "."] "-"]
#    catch {destroy $win} 
#    toplevel $win
#    wm title $win "Sdr: Incoming call from $srcuser"
#    frame $win.f -borderwidth 2 -relief groove
#    pack $win.f -side top
#    label $win.f.l -text "Incoming call"
#    pack $win.f.l -side top
#    message $win.f.m -aspect 500 -text "User $srcuser is inviting you to join a session called $sname"
#    pack $win.f.m -side top
#    frame $win.f.f 
#    pack $win.f.f -side top -fill x
#    button $win.f.f.yes -text "Accept Invitation" -command "sip_accept_invite $id $srcuser $dstuser $path \"[escape_quotes $sdp]\";popup [parse_sdp $sdp] $ifstyle(view) $srcuser;destroy $win"
#    pack $win.f.f.yes -side left -fill x
#    button $win.f.f.no -text "Refuse Invitation" -command "sip_refuse_invite $id $srcuser $dstuser $path;destroy $win"
#    pack $win.f.f.no -side left -fill x
    popup [set aid [parse_sdp $sdp]] $ifstyle(view) $srcuser
    set sessdetails($id,aid) $aid
    set sessdetails($aid,id) $id
    set sessdetails($aid,srcuser) $srcuser
    set sessdetails($aid,time) [gettimeofday]
    set sessdetails($aid,dstuser) $dstuser
    set sessdetails($aid,path) $path
    set sessdetails($aid,sdp) $sdp
}

proc sip_ringing_user {id srcuser dstuser path} {
    set msg "SIP/2.0 150 Ringing"
    set msg "$msg\r\n$path"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nFrom:$srcuser"
    set msg "$msg\r\nTo:$dstuser"
    set msg "$msg\r\nContact-host:[gethostaddr]"
    sip_send_msg $msg [lrange $path end end]
    start_ringing $id
}

proc sip_accept_invite {aid} {
    global sessdetails sip_invite_status
    sip_send_accept_invite \
	$sessdetails($aid,id) \
	$sessdetails($aid,srcuser) \
	$sessdetails($aid,dstuser) \
	$sessdetails($aid,path) \
	$sessdetails($aid,sdp)
    if {$sip_invite_status($sessdetails($aid,id))!="accepted"} {
	add_to_display_list $aid priv
    }
    set sip_invite_status($sessdetails($aid,id)) accepted
    stop_ringing
}

proc sip_refuse_invite {aid} {
    global sessdetails sip_invite_status
    set sip_invite_status($sessdetails($aid,id)) refused
    sip_send_refuse_invite \
	$sessdetails($aid,id) \
	$sessdetails($aid,srcuser) \
	$sessdetails($aid,dstuser) \
	$sessdetails($aid,path)
    stop_ringing
}

proc sip_send_accept_invite {id srcuser dstuser path sdp} {
    set msg "SIP/2.0 200 OK"
    set msg "$msg\r\n$path"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nFrom:$srcuser"
    set msg "$msg\r\nTo:$dstuser"
    set msg "$msg\r\nContact-host:[gethostaddr]"
    sip_send_msg $msg [lrange $path end end]
}

proc sip_send_refuse_invite {id srcuser dstuser path} {
    set msg "SIP/2.0 450 Refused"
    set msg "$msg\r\n$path"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nFrom:$srcuser"
    set msg "$msg\r\nTo:$dstuser"
    set msg "$msg\r\nContact-host:[gethostaddr]"
    sip_send_msg $msg [lrange $path end end]
}

proc sip_success {msg} {
    set lines [split $msg "\n"]
#    puts $msg
    set path ""
    set srcuser ""
    set dstuser ""
    set ct ""
    set ch ""
    foreach line $lines {
	set line [string trim $line "\r"]
	if {$line==""} {break}
	set lparts [split $line ":"]
	switch [string toupper [lindex $lparts 0]] {
	    CALL-ID {
		set id [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    FROM {
		set srcuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    TO {
		set dstuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    VIA {
		if {$path==""} {
		    set path $line
		} else {
		    set path "$path\r\n$line"
		}
	    }
	    CONTENT-TYPE {
		set ct [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    CONTACT-HOST {
		set ch [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	}
    }
    if {[string compare $ct "application/sdp"]==0} {
	foreach line $lines {
	    set line [string trim $line "\r"]
	    set lparts [split $line "="]
	    switch [lindex $lparts 0] {
		s {
		    set sname [join [lrange $lparts 1 end] "="]
		}
	    }
	}
    }
    sip_connection_succeed $id "$dstuser accepts your invitation"
}

proc sip_status {msg} {
    set smode [lindex $msg 1]
    set reason [lindex $msg 2]
    debug "sip_status: $smode"
    set lines [split $msg "\n"]
    set path ""
    set srcuser ""
    set dstuser ""
    set ct ""
    set ch ""
    foreach line $lines {
	set line [string trim $line "\r"]
	if {$line==""} {break}
	set lparts [split $line ":"]
	switch [string toupper [lindex $lparts 0]] {
	    CALL-ID {
		set id [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    FROM {
		set srcuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    TO {
		set dstuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    VIA {
		if {$path==""} {
		    set path $line
		} else {
		    set path "$path\r\n$line"
		}
	    }
	    CONTENT-TYPE {
		set ct [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    CONTACT-HOST {
		set ch [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	}
    }
    set path [lindex [string trim [lindex [split $path ":"] 1]] 1]
    debug "smode: $smode id: $id path: >$path< me: >[gethostaddr]<"
    switch $smode {
	100 {
	    if {$path==[gethostaddr]} {
		#I sent this request
		sip_session_status $id progressing
	    }
	}
	150 {
	    if {$path==[gethostaddr]} {
		#I sent this request
		sip_session_status $id ringing
	    }
	}
    }
}

proc sip_failure {msg} {
    global no_of_connections
    set smode [lindex $msg 1]
    set reason [lindex $msg 2]
    set lines [split $msg "\n"]
    set path ""
    set srcuser ""
    set dstuser ""
    set ct ""
    set ch ""
    foreach line $lines {
        set line [string trim $line "\r"]
        if {$line==""} {break}
        set lparts [split $line ":"]
        switch [string toupper [lindex $lparts 0]] {
	    CALL-ID {
		set id [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    FROM {
		set srcuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    TO {
		set dstuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    VIA {
		if {$path==""} {
		    set path $line
		} else {
		    set path "$path\r\n$line"
		}
	    }
	    CONTENT-TYPE {
		set ct [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    CONTACT-HOST {
		set ch [string trim [join [lrange $lparts 1 end] ":"]]
	    }
        }
    }
    switch $smode {
	404 {
	    sip_connection_fail $id "User $dstuser does not exist"
	    sip_cancel_connection $id $path
	}
	450 {
	    sip_connection_fail $id "User $dstuser declined to join"
	    sip_cancel_connection $id all
	}
	451 {
	    sip_connection_fail $id "User $dstuser was busy"
	    sip_cancel_connection $id all
	}
	600 {
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "User $dstuser could not be contacted"
	    } else {
		sip_cancel_connection $id $path
	    }
	}
	601 {
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "User $dstuser was not known"
	    } else {
		sip_cancel_connection $id $path
	    }
	}
	602 {
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "User $dstuser was not at the location(s) I could contact."
	    } else {
		sip_cancel_connection $id $path
	    }
	}
	default {
	    if {($smode>=400)&&($smode<500)} {
		sip_connection_fail $id \
			"Failed to contact $dstuser (reason $smode)"
		sip_cancel_connection $id $path
	    } else {
		if {$no_of_connections($id)==1} {
		    sip_connection_fail $id \
			    "Failed to contact $dstuser (reason $smode)"
		} else {
		    sip_cancel_connection $id $path
		}
	    }
	}
    }
}

proc sip_moved {msg} {
    global no_of_connections sip_request_aid sip_request_win
    set smode [lindex $msg 1]
    set reason [lindex $msg 2]
    set lines [split $msg "\n"]
    set path ""
    set srcuser ""
    set dstuser ""
    set ct ""
    set ch ""
    set location ""
    foreach line $lines {
        set line [string trim $line "\r"]
        if {$line==""} {break}
        set lparts [split $line ":"]
        switch [lindex $lparts 0] {
	    CALL-ID {
		set id [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    FROM {
		set srcuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    TO {
		set dstuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    VIA {
		if {$path==""} {
		    set path $line
		} else {
		    set path "$path\r\n$line"
		}
	    }
	    LOCATION {
		set location [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    CONTENT-TYPE {
		set ct [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    CONTACT-HOST {
		set ch [string trim [join [lrange $lparts 1 end] ":"]]
	    }
        }
    }
    set aid $sip_request_aid($id) 
    if {[string first "@" $location]>=0} {
	#location is giving us username@hostname
	#XXX don't this this is valid, but handle it anyway
	set dstuser $location
	set location 0
    }
    switch $smode {
	301 {
	    sip_session_status $id "progressing $location"
	    sip_cancel_connection $id $path
	    send_sip $dstuser $aid $id $sip_request_win($id) $location
	}
	302 {
	    sip_session_status $id "progressing $location"
	    sip_cancel_connection $id $path
	    send_sip $dstuser $aid $id $sip_request_win($id) $location
	}
    }
}

proc sip_connection_fail {id msg} {
    global sip_request_status sip_requests sip_request_win
    if {[lsearch $sip_requests $id]==-1} {
#        puts a
        return 0
    }
    msgpopup "Connection attempt unsuccessful" $msg
    set lid [join [split $id "."] "-"]
    set f $sip_request_win($id).$lid
    catch {pack forget $f}
    set sip_request_status($id) declined
}

proc sip_connection_succeed {id msg} {
    global sip_request_status sip_requests sip_request_win sip_request_aid
    if {[lsearch $sip_requests $id]==-1} {
#        puts a
        return 0
    }
    msgpopup "Connection attempt Successful" $msg
    set lid [join [split $id "."] "-"]
    set f $sip_request_win($id).$lid
    catch {$f.l2 configure -text "connected"}
    set sip_request_status($id) connected
    add_to_display_list  $sip_request_aid($id) priv
}

proc sip_cancel_connection {id hostaddr} {
}

proc escape_quotes {msg} {
    return [join [split $msg "\""] "\\\""]
}

proc start_ringing {id} {
    global ringing_bell bells
    if {$ringing_bell==1} {
	after cancel $bells(0)
	set bells(0) [after 10000 timeout_ringing $id]
	return 0
    }
    set ringing_bell 1
    phone_ringing
    set bells(0) [after 10000 timeout_ringing $id]
}
proc stop_ringing {} {
    global ringing_bell bells
    after cancel $bells(0)
    set ringing_bell 0
}

proc timeout_ringing {id} {
    global sessdetails
    set aid $sessdetails($id,aid)
    popdown $aid
    add_to_call_list $aid
    stop_ringing
}

set ringing_bell 0
proc phone_ringing {} {
    global ringing_bell bells
    catch {after cancel $bells(3)}
    if {$ringing_bell==0} {
	catch {
	    after cancel $bells(1)
	    after cancel $bells(2)
	}
	return 0
    }
    bell
    set bells(1) [after 200 bell]
    set bells(2) [after 400 bell]
    set bells(3) [after 1500 phone_ringing]
}

set sip_call_list {}
proc add_to_call_list {aid} {
    global sip_call_list sessdetails
    if {$sip_call_list == {} } {
	toplevel .calls
	wm title .calls "Incoming Calls"
	frame .calls.f -borderwidth 2 -relief groove
	pack .calls.f -side top -expand true -fill both
	label .calls.f.l -text "While you were out..."
	pack .calls.f.l -side top
	message .calls.f.m -aspect 500 -text "You received incoming calls which were not answered from the following people:"
	pack .calls.f.m -side top
	frame .calls.f.f -relief groove -borderwidth 2
	pack .calls.f.f -side top -fill both -expand true
	frame .calls.f.f.from
	pack .calls.f.f.from -side left -fill both -expand true
	label  .calls.f.f.from.l -text "Caller"
	pack .calls.f.f.from.l -side top
	frame .calls.f.f.purpose
	pack .calls.f.f.purpose -side left -fill both -expand true
	label  .calls.f.f.purpose.l -text "Purpose"
	pack .calls.f.f.purpose.l -side top
	frame .calls.f.f.time
	pack .calls.f.f.time -side left -fill both -expand true
	label  .calls.f.f.time.l -text "Time"
	pack .calls.f.f.time.l -side top
	frame .calls.f.cp -borderwidth 2 -relief groove
	pack .calls.f.cp -expand true -fill x -side top
	button .calls.f.cp.cancel -text "Dismiss" -command {
	    set sip_call_list {}
	    destroy .calls
	}
	pack .calls.f.cp.cancel -side right -fill x -expand true
    }
    label .calls.f.f.from.l$aid -text $sessdetails($aid,srcuser)
    pack .calls.f.f.from.l$aid -side bottom
    label .calls.f.f.purpose.l$aid -text "unknown"
    pack .calls.f.f.purpose.l$aid -side bottom
    label .calls.f.f.time.l$aid -text \
	    [clock format $sessdetails($aid,time) -format "%H:%M %a %d %b"]
    pack .calls.f.f.time.l$aid -side bottom
    lappend sip_call_list $aid
}

proc enter_new_address {menu entry} {
    global address_book
    catch {destroy .ab}
    toplevel .ab
    posn_win .ab
    wm title .ab "Address Book"
    frame .ab.f -borderwidth 2 -relief groove
    pack .ab.f -side top

    frame .ab.f.f1 
    pack .ab.f.f1 -side top
    label .ab.f.f1.l -text "Add an entry to your address book:"
    pack .ab.f.f1.l -side left

    frame .ab.f.f2
    pack .ab.f.f2 -side top
    frame .ab.f.f2.f1
    pack .ab.f.f2.f1 -side left
    label .ab.f.f2.f1.l -text "Name:"
    pack .ab.f.f2.f1.l -side top -anchor w
    entry .ab.f.f2.f1.e -width 20 -relief sunken -borderwidth 1 \
	    -bg [option get . entryBackground Sdr]
    pack .ab.f.f2.f1.e -side top -anchor w

    frame .ab.f.f2.f2
    pack .ab.f.f2.f2 -side left
    label .ab.f.f2.f2.l -text "Address:"
    pack .ab.f.f2.f2.l -side top -anchor w
    entry .ab.f.f2.f2.e -width 30 -relief sunken -borderwidth 1 \
	    -bg [option get . entryBackground Sdr]
    pack .ab.f.f2.f2.e -side top -anchor w

    frame .ab.f.f3
    pack .ab.f.f3 -side top -fill x -expand true
    button .ab.f.f3.ok -text "Store Entry" -command "add_address_entry $menu $entry"
    pack  .ab.f.f3.ok -side left -fill x -expand true
    button .ab.f.f3.cancel -text "Cancel" -command "destroy .ab"
    pack  .ab.f.f3.cancel -side left -fill x -expand true
}

proc embedd_enter_new_address {origwin win after mode} {
    global tmp_address_book ab_user

    active_address_book $origwin add
    frame $win.f -borderwidth 2 -relief groove
    pack $win.f -side top -after $after -fill x -expand true
    
    frame $win.f.f2
    pack $win.f.f2 -side top
    
    frame $win.f.f2.cp
    pack $win.f.f2.cp -side right
    button $win.f.f2.cp.ok -highlightthickness 0
    pack  $win.f.f2.cp.ok -side top -fill x -expand true
    button $win.f.f2.cp.cancel -text "Cancel" \
	    -highlightthickness 0 \
	    -command "destroy $win.f;active_address_book $origwin unselected"
    pack  $win.f.f2.cp.cancel -side top -fill x -expand true
    
    frame $win.f.f2.f1 
    pack $win.f.f2.f1 -side left -fill x -expand true
    label $win.f.f2.f1.l -text "Name:" -anchor nw
    pack $win.f.f2.f1.l -side top -anchor w -fill x -expand true
    entry $win.f.f2.f1.e -width 20 -relief sunken -borderwidth 1 \
	    -bg [option get . entryBackground Sdr]
    pack $win.f.f2.f1.e -side top -anchor w -fill x -expand true
    
    frame $win.f.f2.f2
    pack $win.f.f2.f2 -side left -fill x -expand true
    label $win.f.f2.f2.l -text "Address:" -anchor nw
    pack $win.f.f2.f2.l -side top -anchor w -fill x -expand true
    entry $win.f.f2.f2.e -width 30 -relief sunken -borderwidth 1 \
	    -bg [option get . entryBackground Sdr] 
    pack $win.f.f2.f2.e -side top -anchor w -fill x -expand true
    
    if {$mode=="add"} {
	$win.f.f2.cp.ok configure -text "Store Entry" -command \
		"embedd_add_address_entry $win.f.f2.f1.e $win.f.f2.f2.e $win.f $origwin"
    } else {
	$win.f.f2.cp.ok configure -text "Modify Entry" -command \
		"delete_address_entry \"$ab_user\";\
		 embedd_add_address_entry $win.f.f2.f1.e $win.f.f2.f2.e $win.f $origwin"
	$win.f.f2.f1.e insert 0 $ab_user
	$win.f.f2.f2.e insert 0 $tmp_address_book($ab_user)
    }
}

proc add_address_entry {menu entry} {
    global address_book
    set name [.ab.f.f2.f1.e get]
    if {$name==""} {
	errorpopup "No name entered" "You must enter a name to add to your address book"
	return -1
    }
    set address [.ab.f.f2.f2.e get] 
    if {($address == "") || ([string first "@" $address]<0)} {
	errorpopup "Invalid address entered" "You must enter an address for $name.  This should be in the form \"username@hostname\""
	return -1
    }
    clear_address_book $menu
    set address_book($name) $address
    make_address_book $menu $entry
    save_prefs
    catch {destroy .ab}
    return 0
}

proc embedd_add_address_entry {uwin awin destroy origwin} {
    global tmp_address_book
    set name [$uwin get]
    if {$name==""} {
	errorpopup "No name entered" "You must enter a name to add to your address book"
	return -1
    }
    set address [$awin get] 
    if {($address == "") || ([string first "@" $address]<0)} {
	errorpopup "Invalid address entered" "You must enter an address for $name.  his should be in the form \"username@hostname\""
	return -1
    }
    active_address_book $origwin unselected
    set tmp_address_book($name) $address
    embedd_redisplay_address_book $origwin
    save_prefs
    catch {destroy $destroy}
    return 0
}

proc delete_address_entry {user} {
    global tmp_address_book
    if {([info exists tmp_address_book])&&($user!="")} {
	unset tmp_address_book($user)
    }
}

proc make_address_book {menu entry} {
    global address_book
    if {$menu!="0"} {
	if {[info exists address_book]} {
	    foreach user [array names address_book] {
		$menu add command -label $user -command \
			"insert_invite_addr $entry $address_book($user)" 
	    }
	} else {
	    $menu add command -label \
		    "No entries in address book" -state disabled
	}
	$menu add separator
	$menu add command -label "Add new entry" -command \
		"enter_new_address $menu $entry"
    }
}

proc clear_address_book {menu} {
    if {$menu!="0"} {
	$menu delete 0 end
    }
}

proc insert_invite_addr {entry address} {
    $entry delete 0 end
    $entry insert 0 $address
}

proc save_address_book {file} {
    global address_book
    if {[info exists address_book]} {
        foreach user [array names address_book] {
	    regsub -all " " $user "\\ " tmpuser
	    puts $file "set address_book($tmpuser) \"$address_book($user)\""
	}
    }
}

proc address_book_copyin {} {
    global address_book tmp_address_book
    if {[info exists address_book]} {
	foreach name [array names address_book] {
	    set tmp_address_book($name) $address_book($name)
	}
    }
}

proc address_book_copyout {} {
    global address_book tmp_address_book
    if {[info exists address_book]} {
        foreach name [array names address_book] {
	    unset address_book($name)
	}
    }
    if {[info exists tmp_address_book]} {
	foreach name [array names tmp_address_book] {
	    set address_book($name) $tmp_address_book($name)
	    unset tmp_address_book($name)
	}
    }
}

proc select_address_book {win width height} {
    global tmp_address_book
    frame $win -relief raised -borderwidth 3
    frame $win.setw -borderwidth 0 -height 1 -width $width
    pack $win.setw -side top

    frame $win.f -borderwidth 2
    pack $win.f -side top
    frame $win.f.f1 
    pack $win.f.f1 -side top
    label $win.f.f1.l -text "Address Book for Session Invitation"
    pack $win.f.f1.l -side left
    frame $win.f.f2
    pack $win.f.f2 -side top
    frame $win.f.f2.cp
    pack $win.f.f2.cp -side left -anchor nw
    button $win.f.f2.cp.add -text "Add Entry" \
	    -highlightthickness 0 \
	    -command "embedd_enter_new_address $win $win.f $win.f.f1 add"
    pack $win.f.f2.cp.add -side top -fill x -expand true
    button $win.f.f2.cp.edit -text "Edit" \
	    -highlightthickness 0 -state disabled \
	    -command "embedd_enter_new_address $win $win.f $win.f.f1 modify"
    pack $win.f.f2.cp.edit -side top -fill x -expand true
    button $win.f.f2.cp.delete -text "Delete" \
	    -highlightthickness 0 -state disabled \
	    -command "delete_address_entry \[set ab_user\];\
	    embedd_redisplay_address_book $win"
    pack $win.f.f2.cp.delete -side top -fill x -expand true

    listbox $win.f.f2.l -width 20 -height 12 -yscroll "set_ab_lbscroll $win"
    pack $win.f.f2.l -side left
    bind $win.f.f2.l <1> [format {
	tkListboxBeginSelect %%W [%%W index @%%x,%%y]
	address_book_select %s user
    } $win]
    listbox $win.f.f2.r -width 30 -height 12 -yscroll "set_ab_lbscroll $win"
    pack $win.f.f2.r -side left
    bind $win.f.f2.r <1> [format {
	tkListboxBeginSelect %%W [%%W index @%%x,%%y]
	address_book_select %s address
    } $win]
    scrollbar $win.f.f2.sb  -command "set_ab_scroll $win" \
	    -background [resource scrollbarForeground] \
	    -troughcolor [resource scrollbarBackground] \
	    -borderwidth 1 -relief flat \
	    -highlightthickness 0

    pack $win.f.f2.sb -side left -fill y -expand true

    if {[info exists tmp_address_book]} {
	foreach user [array names tmp_address_book] {
	    $win.f.f2.l insert end $user
	    $win.f.f2.r insert end $tmp_address_book($user)
	}
    }

    #provide additional vertical padding in the canvas
    frame $win.f2 -borderwidth 0 -relief flat -width 1 -height \
        [expr $height - [winfo reqheight $win]]
    pack $win.f2 -side top
}

proc set_ab_scroll {win args} {
    eval $win.f.f2.r yview $args
    eval $win.f.f2.l yview $args
}
proc set_ab_lbscroll {win args} {
    eval $win.f.f2.l yview moveto [lindex $args 0]
    eval $win.f.f2.r yview moveto [lindex $args 0]
    eval $win.f.f2.sb set $args
}


proc embedd_redisplay_address_book {win} {
    global tmp_address_book
    $win.f.f2.l delete 0 end
    $win.f.f2.r delete 0 end
    if {[info exists tmp_address_book]} {
	foreach user [array names tmp_address_book] {
	    $win.f.f2.l insert end $user
	    $win.f.f2.r insert end $tmp_address_book($user)
	}
    }
}

proc address_book_select {win which} {
    global tmp_address_book ab_user
    set ab_user ""
    if {[info exists tmp_address_book]} {
	switch $which {
	    user {
		set ab_user [selection get]
		set address $tmp_address_book($ab_user)
	    }
	    address {
		set address [selection get]
		foreach u [array names tmp_address_book] {
		    if {[string compare $tmp_address_book($u) $address]==0} {
			set ab_user $u
			break
		    }
		}
	    }
	}
	if {$ab_user!=""} {
	    active_address_book $win selected
	} else {
	    active_address_book $win unselected
	}
    }
}

proc active_address_book {win mode} {
    switch $mode {
	add {
	    selection clear
	    $win.f.f2.cp.add configure -state disabled
	    $win.f.f2.cp.edit configure -state disabled
	    $win.f.f2.cp.delete configure -state disabled
	    $win.f.f2.l configure -fg \
		    [option get . disabledForeground Sdr]
	    $win.f.f2.r configure -fg \
		    [option get . disabledForeground Sdr]
	}
	edit {
	    $win.f.f2.cp.add configure -state disabled
	    $win.f.f2.cp.edit configure -state disabled
	    $win.f.f2.cp.delete configure -state disabled
	}
	selected {	
	    $win.f.f2.cp.add configure -state normal
	    $win.f.f2.cp.edit configure -state normal
	    $win.f.f2.cp.delete configure -state normal
	    $win.f.f2.l configure -fg \
		    [option get . foreground Sdr]
	    $win.f.f2.r configure -fg \
		    [option get . foreground Sdr]
	}
	unselected {	
	    selection clear
	    $win.f.f2.cp.add configure -state normal
	    $win.f.f2.cp.edit configure -state disabled
	    $win.f.f2.cp.delete configure -state disabled
	    $win.f.f2.l configure -fg \
		    [option get . foreground Sdr]
	    $win.f.f2.r configure -fg \
		    [option get . foreground Sdr]
	}
    }
}