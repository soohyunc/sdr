set invited_sessions {}
set qdurs {"5 mins" "15 mins" "half hour" "an hour"}
set qdurt {300 900 1800 3600}
#set qpurp {"Two-way call" "Group Chat" "Small Meeting" "Large Meeting"}
set qpurp {"Group Chat" "Small Meeting" "Large Meeting"}
#set qpmway {0 1 1 1}
set qpmway {1 1 1}

#Notes:
#SDR can be both a sip client and server
#
#sip_requests holds the list of request ids that a client has outstanding
#sip_request_status holds the status of each of these
#  possible values are:
#    unknown - we sent a request and didn't get anything back yet
#    progressing - we sent a request and got back a 100 trying reply
#    ringing - we sent a request and the remote end says its ringing
#    connected - we got back a 200 response
#    declined - we got back a failure and have no more options for this call
#    hungup - we hung up on a call we initiated.
#
#sip_invites holds the list of request ids that a server has outstanding
#sip_invite_status holds the status of each of these
#  possible values are:
#    ringing - we alerted the user but no response yet
#    accepted - we sent a 200 response
#    connected - we sent a 200 response and got an ACK
#    failed - we sent more than ten 200 responses and got no ACK
#    refused - we sent a failure response
#    done - we sent a failure response and got an ACK or didn't get an
#           ACK after resending the response more than ten times.

proc qcall {} {
    global scope qdurs qdurt qpurp qpmway medialist send youremail
    catch {destroy .qc}
    if {$youremail==""} {
	enter_phone_details qcall
	return 
    }
    
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
    global media_layers
    global yourphone youremail medialist send ldata sesstype
    global sdrversion
    global sessionkey
#edmund
    global mediaenc
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
    set ldata($aid,sap_addr) ""
    set ldata($aid,sap_port) ""
    set ldata($aid,started) 0
    set ldata($aid,list) ""
    set ldata($aid,trust) sip
    set medianum 0
    foreach media $medialist {
        if {$send($media)==1} {
	    set ldata($aid,$medianum,media) $media
	    set ldata($aid,$medianum,port) [generate_port $media]
	    set ldata($aid,$medianum,addr) [generate_address $zone(base_addr,$zone(cur_zone)) $zone(netmask,$zone(cur_zone))]
	    set ldata($aid,$medianum,fmt) $media_fmt($media)
	    set ldata($aid,$medianum,proto) $media_proto($media)
	    set ldata($aid,$medianum,layers) $media_layers($media)
	    set ldata($aid,$medianum,ttl) $zone(ttl,$zone(cur_zone))
	    set ldata($aid,$medianum,vars) ""
#edmund
	    if {$mediaenc($media) == 1} {
              set ldata($aid,$medianum,mediakey) $sessionkey($media)
            } else {
              set ldata($aid,$medianum,mediakey) ""
            }
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
    set ldata($aid,sessid) [gettimeofday]
    set ldata($aid,sessvers) [gettimeofday]
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
    set ldata($aid,heardfrom) [gethostaddr]
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
	bind $wname.f.e <Return> "send_sip \[$wname.f.e get\] \[$wname.f.e get\] \"$session\" 0 0 0 0 NONE"
	pack $wname.f.e -side left -fill x -expand true
	button $wname.f.inv -text "Invite" -command "send_sip \[$wname.f.e get\] \[$wname.f.e get\] \"$session\" 0 0 0 0 NONE"
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
    label $wname.f0.l -text "Invite user (SIP URL or username@hostname)"
    pack $wname.f0.l -side left
    menubutton $wname.f0.m -text "Browse" -menu $wname.f0.m.m -relief raised
    menu $wname.f0.m.m
    make_address_book $wname.f0.m.m $wname.f.e $wname.f.inv
    pack $wname.f0.m -side right 
    
    frame $wname.f
    pack $wname.f -side top -fill x -expand true
    entry $wname.f.e -width 30 -relief sunken \
	    -bg [option get . entryBackground Sdr]
    tixAddBalloon $wname.f.e Entry [tt "Enter username and machinename for user in the form: username@machine"]

    pack $wname.f.e -side left -fill x -expand true
    button $wname.f.inv -text "Invite" -highlightthickness 0 \
	    -state disabled \
	    -command "send_sip \[$wname.f.e get\] \[$wname.f.e get\] \"$session\" 0 $wname 0 0 0 NONE"
    foreach binding [bind Entry] {
	bind $wname.f.e $binding "[bind Entry $binding];break"
    }
    bind $wname.f.e <Key> "[bind Entry <Key>];check_sip_url $wname.f.e $wname.f.inv;break"
    bind $wname.f.e <Delete> "[bind Entry <Delete>];check_sip_url $wname.f.e $wname.f.inv;break"
    bind $wname.f.e <BackSpace> "[bind Entry <BackSpace>];check_sip_url $wname.f.e $wname.f.inv;break"
    bind $wname.f.e <Return> "if {\[check_sip_url $wname.f.e $wname.f.inv\]==1} {send_sip \[$wname.f.e get\] \[$wname.f.e get\] \"$session\" 0 $wname 0 0 0 NONE} else {bell}"
    pack $wname.f.inv -side right
    sip_list_invitees $wname $session
    catch {pack unpack $win.f3.invite}
}

proc check_sip_url {entry button} {
    #try and ensure it's a valid URL before we let the user press the 
    #invite button
    set url [$entry get]
    set res [sip_parse_url $url]
    set user [lindex $res 0]"
    set passwd [lindex $res 1]
    set addr [lindex $res 2]
    set port [lindex $res 3]
    set ttl [lindex $res 5]
    set maddr [lindex $res 6]
    set parts [split $addr "."]
    if {([llength $parts] <2)} {set addr ""}
    if {[string length [lindex $parts [expr [llength $parts] - 1]]]==0} {
	set addr ""
    }
    if {($user!="")&&($addr!="")} {
	$button configure -state normal
	return 1
    } else {
	$button configure -state disabled
	return 0
    }
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

proc sip_map_url_to_addr {location} {
    #if it was a URL other than a SIP one, this doesn't work...

    if {[string compare [string range $location 0 3] "sip:"]==0} {
	#it's a SIP URL
	#trim the URL
	set location [string range $location 6 end]
	set param [string first ";" $location]
	if {$param>=0} {
	    #there was a parameter to the URL.
	    #we don't understand parameters, so trim it off and continue
	    #in the hope this is OK.
	    set location [string range $location 0 [expr $param - 1]]
	}
    }

    set username [string trimleft [lindex [split $location "@"] 0] " "]
    set host [string trimright [lindex [split $location "@"] 1] " "]
    if {($username=="")||($host=="")} {
	msgpopup "Invalid Address" "Addresses must be of the form \"username@host\""
	return 0
    }
    set addr [lookup_host $host]
    if {$addr=="0.0.0.0"} {
	msgpopup "Invalid Address" "The hostname $host is not known"
	return 0
    }
    return $addr
}

proc send_sip {dstuser user aid id win addr port ttl transport} {
    #dstuser is where the message is currently destined
    #user is the SIP name of the user at that location
    #the addr parameter should be zero when send_sip is called with
    #a new or modified request
    puts "send_sip: dstuser=$dstuser, user=$user, aid=$aid, id=$id, win=$win, addr=$addr, port=$port, ttl=$ttl"

    global youremail no_of_connections sip_request_status sip_request_addrs
    global sip_requests
    global sip_request_count sip_request_user sdrversion

    if {$addr!=0} {
        set addr [lookup_host $addr]
    } else {
	set res [sip_parse_url $dstuser]
	puts "$dstuser --> $res"
	set addr [lookup_host [lindex $res 2]]
	if {$addr=="0.0.0.0"} {
	    msgpopup "Invalid Address" \
		    "The hostname [lindex $res 2] is not known"
	    return 0
	}
	set maddr [lindex $res 6]
	set port [lindex $res 3]
	set ttl [lindex $res 5]

	#fix up the URL by removing unnecessary parts
	set user "sip:[lindex $res 0]"
	set passwd [lindex $res 1]
	if {$passwd!=""} {
	    set user "$user:$password"
	} 
	set user "$user@[lindex $res 2]"
	if {$port!="5060"} {
	    set user "user:$port"
	}

	if {$maddr!=""} {
	    if {$ttl==0} {set ttl 16}
	    set addr $maddr
	}
	set transport [lindex $res 4]
	if {$transport=="NONE"} {set transport "UDP"}
    }
    if {$addr==0} {return 0}

    #we can handle calls to multiple remote sites simultaneously
    #need to keep track of whether we've tried somewhere before
    set addrstatus ""
    catch {
	set addrstatus $sip_request_addrs($id,$addr)
    }
    puts "addrstatus: $addrstatus"
    if {$addrstatus==""} {
	set sip_request_addrs($id,$addr) "possible"
    } elseif {$addrstatus=="failed"} {
	return 0
    }
    if {[lsearch $sip_requests $id]!=-1} {
	if {($sip_request_status($id)=="unknown") &&
	    ($sip_request_count($id)>20)} {
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
	if {($sip_request_status($id)=="hungup")} {
	    sip_send_bye 0 $dstuser $user $id $cseq 1
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
    if {$ttl>0} {
	set msg "$msg\r\nVia: SIP/2.0/UDP $addr;ttl=$ttl"
    }
    set msg "$msg\r\nVia: SIP/2.0/$transport [gethostaddr]"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nCseq: 0 INVITE"
    set msg "$msg\r\nFrom:sip:$youremail"
    set msg "$msg\r\nTo:$user"
    set msg "$msg\r\nUser-Agent:sdr/$sdrversion"
    set msg "$msg\r\nContent-type:application/sdp"
    set msg "$msg\r\nContent-length:$length"
    set msg "$msg\r\n\r\n$body"
    debug $msg
    if {$transport=="UDP"} {
	if {[sip_user_pending $user $id $aid $win]==0} {
	    if {[sip_send_udp $addr $ttl $port $msg]==0} {
		set no_of_connections($id) 1
		if {($sip_request_status($id)=="progressing")||\
			($sip_request_status($id)=="ringing")} {
		    set timer 5000
		} else {
		    set timer 1000
		}
		after $timer send_sip \"$dstuser\" \"$user\" $aid $id \
			$win \"$addr\" $port $ttl $transport
	    } else {
		sip_connection_fail $id "No-one is listening to invitations sent to $sip_request_user($id)"
	    }
	}
	return 0
    } else {
	global sip_request_fd
	if {[sip_user_pending $user $id $aid $win]==0} {
	    set sip_request_fd($id) [sip_send_tcp_request 0 $addr $port $msg]
	    if {$sip_request_fd($id)>0} {
                set no_of_connections($id) 1
		#no need for retransmissions, but arrange for the connection
		#to eventually timeout if no answer is received
		after 30000 sip_check_tcp_connection_status $user $id $aid $win
	    } else {
		sip_connection_fail $id "No-one is listening to invitations sent to $sip_request_user($id)"
		sip_close_tcp_connection $id
		unset sip_request_fd($id)
	    }
	}
    }
}

proc sip_check_tcp_connection_status {user id aid win} {
    global sip_request_fd sip_request_user
    #this is called to time out TCP connections to places where either 
    #the TCP connection doesn't connect or we don't get a response back
    #after connection
    if {[sip_user_pending $user $id $aid $win]==1} {
	if {[info exists sip_request_user($id)]} {
	    sip_connection_fail $id "No response from remote site while trying to contact $sip_request_user($id)"
	}
	if {[info exists sip_request_fd($id)]==1} {
	    sip_close_tcp_connection $sip_request_fd($id)
	}
    }
}

proc sip_send_ack {fd dstuser origuser id cseq} {
    global youremail sdrversion sip_requests sip_request_status
    if {[lsearch $sip_requests $id]!=-1} {
	puts "sip_request_status($id)==$sip_request_status($id)"
	if {($sip_request_status($id)=="progressing") || \
		($sip_request_status($id)=="ringing") || \
		($sip_request_status($id)=="unknown") || \
		($sip_request_status($id)=="declined") || \
		($sip_request_status($id)=="connected")} {
	    #the call is in progress or already connected
	    set res [sip_parse_url $dstuser]
	    set addr [lookup_host [lindex $res 2]]
	    if {$addr=="0.0.0.0"} {
		msgpopup "Invalid Address" "The hostname $host is not known"
		return 0
	    }
	    set maddr [lindex $res 6]
	    set port [lindex $res 3]
	    set ttl [lindex $res 5]
	    set transport [lindex $res 4]
	    if {$transport=="NONE"} {
		if {$fd==0} {
		    set transport "UDP"
		} else {
		    set transport "TCP"
		}
	    }
	    set msg "ACK $dstuser SIP/2.0"
	    if {$maddr!=""} {
		if {$ttl==0} {set ttl 16}
		set msg "$msg\r\nVia: SIP/2.0/UDP $maddr;ttl=$ttl"
	    }
	    set msg "$msg\r\nVia: SIP/2.0/$transport [gethostaddr]"
	    set msg "$msg\r\nCall-ID:$id"
	    set msg "$msg\r\nCseq:[lindex $cseq 0] ACK"
	    set msg "$msg\r\nFrom:sip:$youremail"
	    set msg "$msg\r\nTo:$origuser"
	    set msg "$msg\r\nUser-Agent:sdr/$sdrversion"
	    set msg "$msg\r\nContent-length:0\r\n\r\n"
	    if {$maddr!=""} {set addr $maddr}
	    if {$transport=="UDP"} {
		sip_send_udp $addr $ttl $port $msg 
	    } else {
		sip_send_tcp_request $fd $addr $port $msg 
		puts "about to close connection"
		sip_close_tcp_connection $id
		puts "connection closed"
	    }
	} else {
	    #the call is not in a useful state - either the far end
	    #confused us, or we hung up.
	    puts here1
	    sip_send_bye $fd $dstuser $origuser $id $cseq
	}
    } else {
	#we have no record of this call
	puts here2
	sip_send_bye $fd $dstuser $origuser $id $cseq
    }
}

proc sip_send_bye {fd dstuser origuser id cseq} {
    global youremail sdrversion sip_requests sip_request_status
    if {[lsearch $sip_requests $id]!=-1} {
	#for some reason we're sending a bye but still have call state
	#clear it out
	#catch {unset sip_request_status($id)}
    }
    set res [sip_parse_url $dstuser]
    set addr [lookup_host [lindex $res 2]]
    if {$addr=="0.0.0.0"} {
	msgpopup "Invalid Address" "The hostname $host is not known"
	return 0
    }
    set maddr [lindex $res 6]
    set port [lindex $res 3]
    set ttl [lindex $res 5]
    set transport [lindex $res 4]
    if {$transport=="NONE"} {set transport "UDP"}

    puts "sip_send_bye: $addr, $port, $ttl, $maddr"
    set msg "BYE $dstuser SIP/2.0"
    if {$maddr!=""} {
	if {$ttl==0} {set ttl 16}
	set msg "$msg\r\nVia: SIP/2.0/UDP $maddr;ttl=$ttl"
    }
    set msg "$msg\r\nVia: SIP/2.0/$transport [gethostaddr]"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nCseq:[expr [lindex $cseq 0] + 1] BYE"
    set msg "$msg\r\nFrom:sip:$youremail"
    set msg "$msg\r\nTo:$origuser"
    set msg "$msg\r\nUser-Agent:sdr/$sdrversion"
    #XXX should a BYE include a body??
    set msg "$msg\r\nContent-length:0\r\n\r\n"
    #puts "------\nSending to $addr:\n$msg\n"
    if {$transport=="UDP"} {
	if {$maddr!=""} {set addr $maddr}
	sip_send_udp $addr $ttl $port $msg 
    } else {
	sip_send_tcp_request $fd $addr $port $msg
    }
}

proc sip_hang_up {id} {
    global sip_request_status
    set sip_request_status($id) hungup
    sip_clear_connection_ui $id
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
    button $f.hangup -text "Hang up" -command "sip_hang_up $id" \
	    -borderwidth 1 -relief raised -highlightthickness 0
    pack $f.hangup -side left
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
proc sip_user_alert {fd msg} {
    global sip_invites sip_invite_status sip_invite_tag
    #puts " $fd  TESTing $msg"
    set lines [split $msg "\n"]
    set cur-to [lindex [lindex $lines 0] 1]
    set request [lindex [lindex $lines 0] 0]
    set path ""
    set srcuser ""
    set dstuser ""
    set ct ""
    set cseq ""
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
	    CSEQ {
		set cseq [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	}
    }
    debug "ct=$ct"
    #puts "request: >$request<"
    switch $request {
	"INVITE" {
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
		sip_inform_user $fd $id $srcuser $dstuser $path $sname \
			$msg $cseq

		set sip_invite_status($id) ringing
		#this should be a UUID
		set sip_invite_tag($id) [gethostaddr].[gettimeofday]
		sip_ringing_user $fd $id $srcuser $dstuser $path $cseq
	    } else {
		switch $sip_invite_status($id) {
		    ringing {
			sip_ringing_user $fd $id $srcuser $dstuser $path $cseq
		    }
		    refused {
			set aid [parse_sdp $msg]
			sip_refuse_invite $aid
		    }
		    accepted {
			set aid [parse_sdp $msg]
			sip_accept_invite $aid
		    }
		    done {
			#fail silent?
		    }
		}
	    }
	}
	"BYE" {
	    sip_handle_bye $fd $id $srcuser $dstuser $path $cseq
	}
	"CANCEL" {
	    sip_handle_cancel $fd $id $srcuser $dstuser $path $cseq
	}
	"ACK" {
	    sip_handle_ack $fd $id
	}
	default {
	    sip_send_method_unsupported $fd $id $srcuser $dstuser \
		    $path $cseq $request
	}
    }
}

proc sip_handle_bye {fd id srcuser dstuser path cseq} {
    global sip_invites sip_invite_status sessdetails
    if {[lsearch $sip_invites $id]!=-1} {
	if {$sip_invite_status($id)=="accepted"} {
	    #Ooops, the caller hung up after we sent our response
	    #notify the user and stop sending retransmissions of 
	    #our 200 response
	    set sip_invite_status($id) refused
	    set aid $sessdetails($id,aid)
	    popdown $aid
	    msgpopup "Sorry" "Caller $sessdetails($aid,srcuser) has hung up the connection."
	    sip_send_cancelled $fd $id $srcuser $dstuser $path $cseq
	} elseif {($sip_invite_status($id)=="ringing")} {
	    #The caller hung up before we could get an answer from
	    #the user
	    #stop making all the noise and clear up
	    set sip_invite_status($id) refused
	    timeout_ringing $id
	    sip_send_cancelled $fd $id $srcuser $dstuser $path $cseq
	} elseif {$sip_invite_status($id)=="connected"} {
	    #We already got an ACK and now we get a BYE - we don't
	    #perform this kind of call control in sdr.  If we were a 
	    #telephone this would be OK and would terminate the call
	    set sip_invite_status($id) refused
	    sip_send_cancelled $fd $id $srcuser $dstuser $path $cseq
	    return
	} else {
	    #it's not clear what happened here, but set the call to
	    #declined anyway
	    set sip_invite_status($id) refused
	    sip_send_cancelled $fd $id $srcuser $dstuser $path $cseq
	}
    } else {
	#a bye for a call we have no knowledge should result in 
	#us returning "481 Invalid Call-ID"
	sip_send_invalid_callid $fd $id $srcuser $dstuser $path $cseq BYE
    }
}

proc sip_handle_cancel {fd id srcuser dstuser path cseq} {
    global sip_invites sip_invite_status sessdetails
    if {[lsearch $sip_invites $id]!=-1} {
	if {$sip_invite_status($id)=="accepted"} {
	    #Ooops, the caller sent cancel after we sent our response
	    #in this case we ignore cancel.  The callee should send
	    #us an ACK or a BYE to terminate our state.
	    return
	} elseif {($sip_invite_status($id)=="ringing")} {
	    #The caller sent cancel before we could get an answer from
	    #the user
	    #stop making all the noise and clear up
	    set sip_invite_status($id) refused
	    timeout_ringing $id
	    sip_send_cancelled $fd $id $srcuser $dstuser $path $cseq
	} elseif {$sip_invite_status($id)=="connected"} {
	    #We already got an ACK and now we get a CANCEL
	    #this shouldn't happen, but ignore the CANCEL if it does
	    return
	} else {
	    #it's not clear what happened here, but set the call to
	    #declined anyway
	    set sip_invite_status($id) refused
	    sip_send_cancelled $fd $id $srcuser $dstuser $path $cseq
	}
    } else {
	#a cancel for a call we have no knowledge of can be safely ignored
    }
}

proc sip_handle_ack {fd id} {
    #since we're optimists we assume that when we send a 200 response 
    #the caller won't have hung up.  All we do is stop sending
    #retransmissions of our 200 response 
    global sip_invites sip_invite_status
    if {[lsearch $sip_invites $id]!=-1} {
	if {$sip_invite_status($id)=="accepted"} {
	    set sip_invite_status($id) "connected"
	}
	if {$sip_invite_status($id)=="refused"} {
	    set sip_invite_status($id) "done"
	}
    }
}

proc sip_inform_user {fd id srcuser dstuser path sname sdp cseq} {
    global ifstyle
    global sessdetails
    popup [set aid [parse_sdp $sdp]] $ifstyle(view) $srcuser
    set sessdetails($id,aid) $aid
    set sessdetails($aid,id) $id
    set sessdetails($aid,fd) $fd
    set sessdetails($aid,srcuser) $srcuser
    set sessdetails($aid,time) [gettimeofday]
    set sessdetails($aid,dstuser) $dstuser
    set sessdetails($aid,path) $path
    set sessdetails($aid,sdp) $sdp
    set sessdetails($aid,cseq) $cseq
}

proc sip_ringing_user {fd id srcuser dstuser path cseq} {
    set msg "SIP/2.0 180 Ringing"
    set msg "$msg\r\n$path"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nFrom:$srcuser"
    set msg "$msg\r\nTo:$dstuser"
    if {$cseq!=""} {
	set msg "$msg\r\nCseq:$cseq"
    }
    set msg "$msg\r\nContact:sip:[getusername]@[gethostname]"
    set msg "$msg\r\nContent-length:0\r\n\r\n"
    sip_send_reply $fd $id $path $msg INVITE -1
    start_ringing $id
}

proc sip_accept_invite {aid} {
    global sessdetails sip_invite_status ldata
    set fd $sessdetails($aid,fd)
    if {$sip_invite_status($sessdetails($aid,id))!="accepted"} {
	if {$ldata($aid,list)==""} {
	    #no need to display it again id it's already displayed
	    add_to_display_list $aid priv
	}
    }
    set sip_invite_status($sessdetails($aid,id)) accepted
    sip_send_accept_invite $fd \
	$sessdetails($aid,id) \
	$sessdetails($aid,srcuser) \
	$sessdetails($aid,dstuser) \
	$sessdetails($aid,path) \
	$sessdetails($aid,sdp) \
        $sessdetails($aid,cseq)
    stop_ringing
}

proc sip_refuse_invite {aid} {
    global sessdetails sip_invite_status
    set fd $sessdetails($aid,fd)
    set sip_invite_status($sessdetails($aid,id)) refused
    sip_send_refuse_invite $fd \
	$sessdetails($aid,id) \
	$sessdetails($aid,srcuser) \
	$sessdetails($aid,dstuser) \
	$sessdetails($aid,path) \
        $sessdetails($aid,cseq)
    stop_ringing
}

proc sip_send_accept_invite {fd id srcuser dstuser path sdp cseq} {
    global sip_invites sip_invite_status sip_invite_responses
    global sip_invite_tag

    #keep resending the response until we get an ACK, BYE, or timeout
    set sip_invite_responses($id) 1
    #puts "sip_send_accept_invite $sip_invite_status($id)"
#    if {[lsearch $sip_invites $id]>=0} {
#	if {$sip_invite_status($id)!="accepted"} {
#	    catch {unset sip_invite_responses($id)}
#	    return
#	}
#	#resend a maximum of 10 times according to spec
#	if {$sip_invite_responses($id)>10} {
#	    unset sip_invite_responses($id)
	    #we never got either an ACK or a NACK back in response 
	    #to our 200 response - strictly speaking this is a failure
	    #and we should notify the user.
#	    set sip_invite_status($id) failure
#	    return
#	}
#	#resend every 2 seconds according to spec
#	incr sip_invite_responses($id)
#	after 2000 "sip_send_accept_invite $fd $id $srcuser $dstuser \
#		\"$path\" \"$sdp\" {$cseq}"
#    }
    set tag ";tag=$sip_invite_tag($id)"
    puts "**tag: $tag"
    set msg "SIP/2.0 200 OK"
    set msg "$msg\r\n$path"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nFrom:$srcuser"
    set msg "$msg\r\nTo:$dstuser$tag"
    if {$cseq!=""} {
	set msg "$msg\r\nCseq:$cseq"
    }
    set msg "$msg\r\nContact: sip:[getusername]@[gethostname]"
    #XXXX must send back the original request
    set msg "$msg\r\nContent-length:0\r\n\r\n"
    #puts "------\nSending response to [lrange $path end end]\n$msg\n"
    sip_send_reply $fd $id $path $msg INVITE 0
}

proc sip_send_refuse_invite {fd id srcuser dstuser path cseq} {
    global sip_invite_tag
    set tag ""
    if {[info exists sip_invite_tag($id)]} {
	set tag ";tag=$sip_invite_tag($id)"
    }
    set msg "SIP/2.0 603 Decline"
    set msg "$msg\r\n$path"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nFrom:$srcuser"
    set msg "$msg\r\nTo:$dstuser$tag"
    if {$cseq!=""} {
	set msg "$msg\r\nCseq:$cseq"
    }
    set msg "$msg\r\nContact: sip:[getusername]@[gethostname]"
    set msg "$msg\r\nContent-length:0\r\n\r\n"
    sip_send_reply $fd $id $path $msg INVITE 0
}

proc sip_send_method_unsupported {fd id srcuser dstuser path cseq method} {
    global sip_invite_tag
    set tag ""
    if {[info exists sip_invite_tag($id)]} {
	set tag ";tag=$sip_invite_tag($id)"
    }
    set msg "SIP/2.0 501 Not Implemented"
    set msg "$msg\r\n$path"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nFrom:$srcuser"
    set msg "$msg\r\nTo:$dstuser$tag"
    if {$cseq!=""} {
	set msg "$msg\r\nCseq:$cseq"
    }
    set msg "$msg\r\nContact: sip:[getusername]@[gethostname]"
    set msg "$msg\r\nContent-length:0\r\n\r\n"
    sip_send_reply $fd $id $path $msg $method 0
}

proc sip_send_invalid_callid {fd id srcuser dstuser path cseq method} {
    global sip_invite_tag
    set tag ""
    if {[info exists sip_invite_tag($id)]} {
	set tag ";tag=$sip_invite_tag($id)"
    }
    set msg "SIP/2.0 481 Invalid Call-ID"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nFrom:$srcuser"
    set msg "$msg\r\nTo:$dstuser$tag"
    if {$cseq!=""} {
        set msg "$msg\r\nCseq:$cseq"
    }
    set msg "$msg\r\nContact: sip:[getusername]@[gethostname]"
    set msg "$msg\r\nContent-length:0\r\n\r\n"
    sip_send_reply $fd $id $path $msg $method 0
}


proc sip_send_unknown_user {fd id srcuser dstuser path cseq method} {
    global sip_invite_tag
    set tag ""
    if {[info exists sip_invite_tag($id)]} {
	set tag ";tag=$sip_invite_tag($id)"
    }
    set msg "SIP/2.0 404 Not Found"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nFrom:$srcuser"
    set msg "$msg\r\nTo:$dstuser$tag"
    if {$cseq!=""} {
        set msg "$msg\r\nCseq:$cseq"
    }
    set msg "$msg\r\nContent-length:0\r\n\r\n"
    sip_send_reply $fd $id $path $msg $method 0
}

proc sip_unknown_user_ack {callid} {
    #we got an ACK containing an unknown user.
    #either something bizarre happened, or we previously sent 404 Not Found
    #or something similar, so we need to stop resending this response.
    global sip_invite_status
    if {[info exists sip_invite_status($callid)]} {
	if {$sip_invite_status($callid)=="refused"} {
	    #Ok, this makes sense - we had sent a response.
	    set sip_invite_status($callid) "done"
	} else {
	    puts "got an ACK for an unknown user when we're is $sip_invite_status($callid) state"
	}
    }
}

proc sip_send_cancelled {fd id srcuser dstuser path cseq} {
    global sip_invite_tag
    set tag ""
    if {[info exists sip_invite_tag($id)]} {
	set tag ";tag=$sip_invite_tag($id)"
    }
    set msg "SIP/2.0 200 Cancelled"
    set msg "$msg\r\nCall-ID:$id"
    set msg "$msg\r\nFrom:$srcuser"
    set msg "$msg\r\nTo:$dstuser$tag"
    if {$cseq!=""} {
        set msg "$msg\r\nCseq:$cseq"
    }
    set msg "$msg\r\nContact: sip:[getusername]@[gethostname]"
    set msg "$msg\r\nContent-length:0\r\n\r\n"
    sip_send_reply $fd $id $path $msg CANCEL 0
}

proc sip_send_reply {fd callid path msg method counter} {
    global sip_invite_status
    set res [sip_parse_path $path]
    puts "$path ---> $res"
    set version [lindex $res 0]
    set transport [lindex $res 1]
    set host [lindex $res 2]
    set port [lindex $res 3]
    set ttl [lindex $res 4]
    if {$port==0} {set port 5060}
    set addr [lookup_host $host]
    puts "$host -> $addr"
    if {$addr=="0.0.0.0"} {
        msgpopup "Invalid Address" "The hostname $host is not known"
        return 0
    }
    if {$transport=="UDP"} {
	if {$method=="INVITE"} {
	    if {$counter==-1} {
		#it's a response we don't repeat
		sip_send_udp $addr $ttl $port $msg
	    } elseif {$counter==0} {
		sip_send_udp $addr $ttl $port $msg
		after 2000 "sip_send_reply $fd \"$callid\" \"$path\" \
			\"$msg\" $method 1"
		if {[info exists sip_invite_status($callid)]==0} {
		    #we've no state for this reply - must be a failure
		    #response - instatiate the state
		    set sip_invite_status($callid) "refused"
		}
	    } elseif {$counter<10} {
		#only keep retransmitting if we're in a retransmit state
		if {($sip_invite_status($callid)=="refused")||
		    ($sip_invite_status($callid)=="accepted")} {
			sip_send_udp $addr $ttl $port $msg
			after 2000 "sip_send_reply $fd \"$callid\" \"$path\" \
				\"$msg\" $method [expr $counter + 1]"
		}
	    } else {
		#we failed to get an ACK.
		if {$sip_invite_status($callid)=="accepted"} {
		    set sip_invite_status($callid) failure
		} else {
		    set sip_invite_status($callid) done
		}
	    }
	} else {
	    sip_send_udp $addr $ttl $port $msg
	}
    } else {
	sip_send_tcp_reply $fd $callid $addr $port $msg
    }
}

proc sip_success {fd msg pktsrc} {
    global sip_requests
    set lines [split $msg "\n"]
    #puts $msg
    set path ""
    set srcuser ""
    set dstuser ""
    set origuser ""
    set ct ""
    set cseq ""
    set method ""
    foreach line $lines {
	set line [string trim $line "\r"]
	if {$line==""} {break}
	set lparts [split $line ":"]
	switch [string toupper [lindex $lparts 0]] {
	    CALL-ID {
		set id [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    CSEQ {
		set cseq [string trim [join [lrange $lparts 1 end] ":"]]
		set method [lindex $cseq 1]
	    }
	    FROM {
		set srcuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    TO {
		set origuser [string trim [join [lrange $lparts 1 end] ":"]]
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
	    CONTACT {
		set dstuser [string trim [join [lrange $lparts 1 end] ":"]]
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
    if {$method == "INVITE"} {
	if {[lsearch $sip_requests $id]==-1} {	
	    sip_send_bye $fd $dstuser $origuser $id $cseq
	} else {
	    sip_send_ack $fd $dstuser $origuser $id $cseq
	    sip_connection_succeed $id "$dstuser accepts your invitation"
	    if {$fd>0} {
		sip_close_tcp_connection $id
	    }
	}
    } elseif {($method == "BYE")||($method == "CANCEL")} {
	#this is the response to our bye or cancel - now close the connection
	if {$fd>0} {
	    sip_close_tcp_connection $id
	}
    } else {
	#don't know what happened here but we don't want to talk to
	#them again :-)
	if {$fd>0} {
	    sip_close_tcp_connection $id
	}
    }
}

proc sip_status {fd msg pktsrc} {
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
	    CONTACT {
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
	180 {
	    if {$path==[gethostaddr]} {
		#I sent this request
		sip_session_status $id ringing
	    }
	}
    }
}

proc sip_failure {fd msg pktsrc} {
    global no_of_connections
    set smode [lindex $msg 1]
    set reason [lindex $msg 2]
    set lines [split $msg "\n"]
    set path ""
    set srcuser ""
    set dstuser ""
    set ct ""
    set cseq ""
    foreach line $lines {
        set line [string trim $line "\r"]
        if {$line==""} {break}
        set lparts [split $line ":"]
        switch [string toupper [lindex $lparts 0]] {
	    CALL-ID {
		set id [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    CSEQ {
		set cseq [string trim [join [lrange $lparts 1 end] ":"]]
		set method [lindex $cseq 1]
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
    switch $smode {
	400 {
	    # Bad request
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "There was a internal SIP problem: code 400"
	    }
	    sip_cancel_connection $id $pktsrc
	}
	401 {
	    # Unauthorised
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "There was an authorization failure will contacting $dstuser"
	    }
	    sip_cancel_connection $id $pktsrc
	}
	402 {
	    # Payment required
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "$dstuser is requiring payment!"
	    }
	    sip_cancel_connection $id $pktsrc
	}
	403 {
	    # Forbidden
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "The remote server is refusing to connect your call"
	    }
	    sip_cancel_connection $id $pktsrc
	}
	404 {
	    #Not found
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "User $dstuser does not appear to exist"
	    }
	    sip_cancel_connection $id $pktsrc
	}
	407 {
	    #Method Not Allowed
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "There was a internal SIP problem: code 407"
	    }
	    sip_cancel_connection $id $pktsrc
	}
	408 {
	    #Request Timeout
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "There was a internal SIP problem: code 408"
	    }
	    sip_cancel_connection $id $pktsrc
	}
	420 {
	    #Bad extension
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "There was a internal SIP problem: code 420"
	    }
	    sip_cancel_connection $id $pktsrc
	}
	480 {
	    #temporarily unavailable
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "User $dstuser was unavailable"
	    }
	    sip_cancel_connection $id $pktsrc
	}
	481 {
	    #Invalid call ID
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "There was a internal SIP problem: code 481"
	    }
	    sip_cancel_connection $id $pktsrc
	}
	481 {
	    #Loop detected
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    if {$no_of_connections($id)==1} {
		sip_connection_fail $id "There was a internal SIP problem: code 482"
	    }
	    sip_cancel_connection $id $pktsrc
	}
	600 {
	    # Busy
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    sip_connection_fail $id "User $dstuser was busy"
	    sip_cancel_connection $id all
	}
	603 {
	    # Decline
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    sip_connection_fail $id "User $dstuser declined your call"
	    sip_cancel_connection $id all
	}
	604 {
	    # Does not exist anywhere
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    sip_connection_fail $id "User $dstuser aparently no longer exists!"
	    sip_cancel_connection $id all
	}
	606 {
	    # Not acceptable
	    sip_send_ack $fd $dstuser $dstuser $id $cseq
	    sip_connection_fail $id "User $dstuser does not have the facilities to participate in the session you specified"
	    sip_cancel_connection $id all
	}
	default {
	    if {($smode>=400)&&($smode<600)} {
		sip_send_ack $fd $dstuser $dstuser $id $cseq
		if {$no_of_connections($id)==1} {
		    sip_connection_fail $id \
			    "Failed to contact $dstuser (reason $smode)"
		} else {
		    sip_cancel_connection $id $pktsrc
		}
	    } else {
		sip_send_ack $fd $dstuser $dstuser $id $cseq
		sip_connection_fail $id \
			"Failed to contact $dstuser (reason $smode)"
		sip_cancel_connection $id all
	    }
	}
    }
}

proc sip_moved {fd msg pktsrc} {
    global no_of_connections sip_request_aid sip_request_win
    set smode [lindex $msg 1]
    set reason [lindex $msg 2]
    set lines [split $msg "\n"]
    set path ""
    set srcuser ""
    set dstuser ""
    set ct ""
    set contact ""
    set id ""
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
		set origuser [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    VIA {
		if {$path==""} {
		    set path $line
		} else {
		    set path "$path\r\n$line"
		}
	    }
	    CONTACT {
		set contact [string trim [join [lrange $lparts 1 end] ":"]]
	    }
	    CONTENT-TYPE {
		set ct [string trim [join [lrange $lparts 1 end] ":"]]
	    }
        }
    }
    if {$id==""} {
	#got a redirect with no call ID - this is bogus
	#puts "Got a bogus response - no call-ID:\n$msg"
	return 0
    }
    set aid $sip_request_aid($id) 
    if {[string compare [string range $contact 0 3] "sip:"]==0} {
	#it's a SIP URL
	#trim the URL
	set contact [string range $contact 6 end]
	set param [string first ";" $contact]
	if {$param>=0} {
	    #there was a parameter to the URL.
	    #we don't understand parameters, so trim it off and continue
	    #in the hope this is OK.
	    set contact [string range $contact 0 [expr $param - 1]]
	}
    }
    if {[string first ":" $contact]>=0} {
	#it's some other URL
	if {$no_of_connections($id)==1} {
	    sip_connection_fail $id "I got an alternative location I don't undertand: $contact."
	}
	sip_cancel_connection $id $pktsrc
	return
    }
	
    if {[string first "@" $contact]>=0} {
	set dstuser $contact
    }
    switch $smode {
	301 {
	    #moved permanently
	    sip_session_status $id "progressing $contact"
	    sip_cancel_connection $id $pktsrc
	    send_sip $dstuser $dstuser $aid $id $sip_request_win($id) 0 0 0 NONE
	}
	302 {
	    #moved temporarily
	    #puts "got a 302, $origuser->$dstuser"
	    sip_session_status $id "progressing $contact"
	    sip_cancel_connection $id $pktsrc
	    send_sip $dstuser $origuser $aid $id $sip_request_win($id) 0 0 0 NONE
	}
	380 {
	    #alternative service
	    #not yet supported
            if {$no_of_connections($id)==1} {
                sip_connection_fail $id "An alternative service was suggested by $dstuser but I don't support this yet."
            }
	    sip_cancel_connection $id $pktsrc
        }
	    
    }
}

proc sip_update_request_dst {mode aid id location} {
}

proc sip_connection_fail {id msg} {
    global sip_request_status sip_requests
    if {[lsearch $sip_requests $id]==-1} {
#        puts a
        return 0
    }
    msgpopup "Connection attempt unsuccessful" $msg
    sip_clear_connection_ui $id
    set sip_request_status($id) declined
}

proc sip_clear_connection_ui {id} {
    global sip_request_win
    set lid [join [split $id "."] "-"]
    set f $sip_request_win($id).$lid
    catch {pack forget $f}
}

proc sip_connection_succeed {id msg} {
    global sip_request_status sip_requests sip_request_win sip_request_aid
    global ldata
    msgpopup "Connection attempt Successful" $msg
    set lid [join [split $id "."] "-"]
    set f $sip_request_win($id).$lid
    catch {$f.l2 configure -text "connected"}
    catch {pack forget $f.hangup}
    set sip_request_status($id) connected
    if {$ldata($sip_request_aid($id),list)==""} {
	#no need to add it to the display list if it's already displayed
	add_to_display_list  $sip_request_aid($id) priv
    }
}

proc sip_cancel_connection {id hostaddr} {
    global sip_request_addrs
    puts "sip_cancel_connection $id $hostaddr"
    if {$hostaddr=="all"} {
	#need to cancel all requests made for this call-ID
	set sip_request_status($id) "declined"
	set list [array names sip_request_addrs]
	foreach item $list {
	    set tmpid [lindex [split $item ","] 0]
	    if {[string compare $tmpid $id]==0} {
		set sip_request_addrs($item) "failed"
	    }
	}
    } else {
	set list [array names sip_request_addrs]
	foreach item $list {
	    #puts "addrs: $item $sip_request_addrs($item)"
	}
	set sip_request_addrs($id,$hostaddr) "failed"
    }
}

proc escape_quotes {msg} {
    return [join [split $msg "\""] "\\\""]
}

proc start_ringing {id} {
    global ringing_bell bells
    if {$ringing_bell==1} {
	after cancel $bells(0)
	set bells(0) [after 15000 timeout_ringing $id]
	return 0
    }
    set ringing_bell 1
    phone_ringing
    #the choice of timing the call out after 15 seconds is somewhat
    #arbitrary.  If the sender conforms to the spec, they should resend
    #the request every 5 seconds after they receive a RINGING response,
    #so this allows for reasonable loss rates and yet doesn't let the
    #ringing continue too long when the caller may have hung up and the
    #BYE got lost.
    set bells(0) [after 15000 timeout_ringing $id]
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
    if {[winfo exists .calls.f.f.from.l$aid]==0} {
	label .calls.f.f.from.l$aid -text $sessdetails($aid,srcuser)
	pack .calls.f.f.from.l$aid -side bottom
	label .calls.f.f.purpose.l$aid -text "unknown"
	pack .calls.f.f.purpose.l$aid -side bottom
	label .calls.f.f.time.l$aid -text \
		[clock format $sessdetails($aid,time) -format "%H:%M %a %d %b"]
	pack .calls.f.f.time.l$aid -side bottom
	lappend sip_call_list $aid
    } else {
	#the person recalled with the same call id.  Simply replace the
	#previous information...
	.calls.f.f.from.l$aid configure -text $sessdetails($aid,srcuser)
	.calls.f.f.time.l$aid configure -text \
		[clock format $sessdetails($aid,time) -format "%H:%M %a %d %b"]
    }
}

proc enter_new_address {menu entry} {
    global address_book ab
    catch {destroy .ab}
    toplevel .ab
    posn_win .ab
    wm title .ab "Address Book"
    frame .ab.f -borderwidth 2 -relief groove
    pack .ab.f -side top

    frame .ab.f.f1 
    pack .ab.f.f1 -side top
    label .ab.f.f1.l -text "Add an entry to your address book"
    pack .ab.f.f1.l -side left

    frame .ab.f.f2 -relief groove -borderwidth 2
    pack .ab.f.f2 -side top -fill both -expand true -padx 10
    frame .ab.f.f2.f1
    pack .ab.f.f2.f1 -side left
    label .ab.f.f2.f1.l -text "Name:"
    pack .ab.f.f2.f1.l -side top -anchor w
    entry .ab.f.f2.f1.e -width 40 -relief sunken -borderwidth 1 \
	    -bg [option get . entryBackground Sdr] \
	    -textvariable ab(name)
    pack .ab.f.f2.f1.e -side top -anchor w

    frame .ab.f.f4 -relief groove -borderwidth 2

    message .ab.f.f4.m -aspect 600 -text "Enter either the person's username and hostname, or a SIP URL for them."
    pack .ab.f.f4.m -side top

    frame .ab.f.f4.f4
    frame .ab.f.f4.f4.f1
    pack .ab.f.f4.f4.f1 -side left
    label .ab.f.f4.f4.f1.l -text "Person's Username:"
    pack .ab.f.f4.f4.f1.l -side top -anchor w
    entry .ab.f.f4.f4.f1.e -width 20 -relief sunken -borderwidth 1 \
	    -bg [option get . entryBackground Sdr] \
	    -textvariable ab(username)
    trace variable ab(username) w "ab_activity"
    pack .ab.f.f4.f4.f1.e -side top -anchor w
    frame .ab.f.f4.f4.f2
    pack .ab.f.f4.f4.f2 -side left
    label .ab.f.f4.f4.f2.l -text "Their computer hostname:"
    pack .ab.f.f4.f4.f2.l -side top -anchor w
    entry .ab.f.f4.f4.f2.e -width 30 -relief sunken -borderwidth 1 \
	    -bg [option get . entryBackground Sdr] \
	    -textvariable ab(hostname)
    trace variable ab(hostname) w "ab_activity"
    pack .ab.f.f4.f4.f2.e -side top -anchor w
    pack .ab.f.f4.f4 -side top

    frame .ab.f.f4.f5
    frame .ab.f.f4.f5.f1
    pack .ab.f.f4.f5.f1 -side left
    label .ab.f.f4.f5.f1.l -text "SIP URL for person:"
    pack .ab.f.f4.f5.f1.l -side top -anchor w
    entry .ab.f.f4.f5.f1.e -width 50 -relief sunken -borderwidth 1 \
	    -bg [option get . entryBackground Sdr] \
	    -textvariable ab(url) 
    trace variable ab(url) w "ab_activity"

    pack .ab.f.f4.f5.f1.e -side top -anchor w
    .ab.f.f4.f5.f1.e insert 0 "sip:"
    pack .ab.f.f4.f5 -side top
    pack .ab.f.f4 -side top -padx 10 -pady 10 -fill both -expand true

    frame .ab.f.f3
    pack .ab.f.f3 -side top -fill x -expand true
    button .ab.f.f3.ok -text "Store Entry" -command "add_address_entry $menu $entry"
    pack  .ab.f.f3.ok -side left -fill x -expand true
    button .ab.f.f3.cancel -text "Cancel" -command "destroy .ab"
    pack  .ab.f.f3.cancel -side left -fill x -expand true

    set ab(first) ""
}

proc ab_activity args {
    global ab
    puts "$args"
    set type [lindex $args 1]
    puts "var: $ab($type), first: $ab(first)"
    if {$type=="url"} {
	if {([string length $ab(url)]>4)&&($ab(first)=="")} {
	    if {$ab(first)==""} {set ab(first) url}
	    .ab.f.f4.f4.f1.e configure -state disabled -relief flat \
		    -background [option get . background Sdr]
	    .ab.f.f4.f4.f2.e configure -state disabled -relief flat \
		    -background [option get . background Sdr]
	} elseif {([string length $ab(url)]<=4)&&($ab(first)=="url")} {
	    .ab.f.f4.f4.f1.e configure -state normal -relief sunken \
		    -background [option get . entryBackground Sdr]
	    .ab.f.f4.f4.f2.e configure -state normal -relief sunken \
		    -background [option get . entryBackground Sdr]
	    set ab(first) ""
	}
    } elseif {$type=="username"} {
	if {(($ab(username)!="")||($ab(hostname)!=""))&&($ab(first)!="url")} {
	    if {$ab(first)==""} {set ab(first) username}
	    .ab.f.f4.f5.f1.e configure  -state normal
	    .ab.f.f4.f5.f1.e delete 0 end
	    .ab.f.f4.f5.f1.e insert 0 "sip:$ab(username)@$ab(hostname)"
	    .ab.f.f4.f5.f1.e configure  -state disabled \
		    -background [option get . background Sdr] -relief flat
	} elseif {($ab(username)=="")&&($ab(hostname)=="")} {
	    .ab.f.f4.f5.f1.e configure \
		    -background [option get . entryBackground Sdr] \
		    -relief sunken -state normal
	    .ab.f.f4.f5.f1.e delete 0 end
	    .ab.f.f4.f5.f1.e insert 0 "sip:"
	    set ab(first) ""
	}
    } elseif {$type=="hostname"} {
	if {(($ab(username)!="")||($ab(hostname)!=""))&&($ab(first)!="url")} {
	    if {$ab(first)==""} {set ab(first) hostname}
	    .ab.f.f4.f5.f1.e configure  -state normal
	    .ab.f.f4.f5.f1.e delete 0 end
	    .ab.f.f4.f5.f1.e insert 0 "sip:$ab(username)@$ab(hostname)"
	    .ab.f.f4.f5.f1.e configure -state disabled \
		    -background [option get . background Sdr] -relief flat
	} elseif {($ab(username)=="")&&($ab(hostname)=="")} {
	    .ab.f.f4.f5.f1.e configure \
		    -background [option get . entryBackground Sdr] \
		    -relief sunken -state normal
	    .ab.f.f4.f5.f1.e delete 0 end
	    .ab.f.f4.f5.f1.e insert 0 "sip:"
	    set ab(first) ""
	}
    }
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

proc add_address_entry {menu entry button} {
    global address_book ab
    if {$ab(name)==""} {
	errorpopup "No name entered" "You must enter a name to add to your address book"
	return -1
    }
    if {([string length $ab(url)] <=4) || ([string first "@" $ab(url)]<0)} {
	if {($ab(username)!="")||($ab(hostname)!="")} {
	    errorpopup "Invalid address entered" "You must enter both a username and hostname"
	} else {
	    errorpopup "Invalid URL entered" "You must enter a SIP URL in one of the following forms: \"sip:<username>@<hostname>\", \"sip:<username>@<hostname>:<port>\", or \"sip:<username>@<hostname>;maddr=<mcast_addr>;ttl=<ttl>\""
	}
	return -1
    }
    clear_address_book $menu
    set address_book($ab(name)) $ab(url)
    make_address_book $menu $entry $button
    save_prefs
    catch {destroy .ab}
    foreach var [array names ab] {
	unset ab($var)
    }
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

proc make_address_book {menu entry button} {
    global address_book
    if {$menu!="0"} {
	if {[info exists address_book]} {
	    foreach user [array names address_book] {
		$menu add command -label $user -command \
			"insert_invite_addr $entry $button \"$address_book($user)\"" 
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

proc insert_invite_addr {entry button address} {
    $entry delete 0 end
    $entry insert 0 $address
    check_sip_url $entry $button
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
