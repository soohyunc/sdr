

#new.tcl Copyright (c) 1995 University College London
#see ui_fns.c for information on usage and redistribution of this file
#and for a DISCLAIMER OF ALL WARRANTIES.

proc new {aid} {
    global ifstyle ldata
    if {[string compare $aid "new"]!=0} {
	#we need a working variable while we think about editing sessions,
	#in case we don't commit the changes.
	set ldata($aid,tmpmulticast) $ldata($aid,multicast)
    }
    if {$ifstyle(create)=="norm"} {
	norm_new $aid
    } else {
	tech_new $aid
    }
}

####
#new creates a window to allow a new session to be defined
####
proc norm_new {aid} {
    global send durationix sd_menu scope zone
    global monthix dayix dayofmonth hrix ttl timeofday
    global video_attr audio_attr whiteboard_attr
    global ldata startdayofweek medialist media_fmt media_proto
    global security
    global yourphone
    global youremail
    global yourname
    global new_createtime
    if {[string length $yourphone]==0} {
	#enter_phone_details will re-run this if it succeeds
	enter_phone_details "norm_new $aid"
	return
    }

    catch {destroy .new}
    toplevel .new
    posn_win .new
    if {[string compare $aid "new"]!=0} {
	wm title .new "Sdr: [tt "Edit Session"]"
	foreach i $medialist {
            set send($i) 0
        }
  	set new_createtime $ldata($aid,createtime)
    } else {
	wm title .new "Sdr: [tt "Create New Session"]"
	foreach i $medialist {
	    set send($i) 0
	}
	set send(audio) 1
	set new_createtime [unix_to_ntp [gettimeofday]]
    }


    new_mk_session_name .new $aid
    new_mk_session_desc .new $aid
    new_mk_session_url .new $aid

    frame .new.type -relief groove -borderwidth 2
    pack .new.type -side top -fill x -pady 2 -ipady 2
    new_mk_session_type .new.type left $aid

    if {[string compare $aid "new"]!=0} {
	set sd_addr $ldata($aid,sd_addr)
	set ttl $ldata($aid,ttl)
	set scope ttl
	set zone(cur_zone) $zone(ttl_scope)
	for {set i 0} {$i<$zone(no_of_zones)} {incr i} {
#	    puts "$zone(sd_addr,$i)==$sd_addr)&&($zone(ttl,$i)==$ttl)"
	    if {($zone(sd_addr,$i)==$sd_addr)&&($zone(ttl,$i)==$ttl)} {
#		puts "setting zone(cur_zone) $i"
		set scope admin
		set zone(cur_zone) $i
	    }
	}
    } else {
	set scope admin
	set zone(cur_zone) 0
	set ttl $zone(ttl,$zone(cur_zone))
    }


    frame .new.f3
    pack .new.f3 -side top -pady 5 -fill x -expand true

    catch {
	new_mk_session_security .new.f3.l $aid
    }

    frame .new.f3.m -width 1 -height 1
    pack .new.f3.m -side left -fill y -padx 3

    #padding frame
    pack [frame .new.f3.m2 -width 1 -height 1] -side left -fill y -padx 3

    new_mk_session_admin .new.f3.admin $aid $scope
    

    #padding frame
    pack [frame .new.f3.m3 -width 1 -height 1] -side left -fill y -padx 3

    set show_details 0
    new_mk_session_media .new.f3.media $aid $scope $show_details

    frame .new.f2
    frame .new.f2.act -relief groove -borderwidth 2
    pack .new.f2.act -side left -fill both -expand true
    pack .new.f2 -side top -pady 5 -fill x -expand true
    pack [frame .new.f2.act.l] -side top -anchor w
    label .new.f2.act.l.icon -bitmap clock
    pack .new.f2.act.l.icon -side left
    label .new.f2.act.l.l -text "Session will take place ..." 
    tixAddBalloon .new.f2.act.l.l Label [tt "When and how often is the session going to be on"]
    pack .new.f2.act.l.l -side left

    global rpt_times
    global has_times
    global needs_lifetime
    global rpt_min_values 
    global rpt_menu_value
    global duration_max

    set rpt_times {{---} {Once} {Daily} {Weekly} {Every Two Weeks}\
     {Monthly by Date} {Monday thru Friday}}

    #whether or not the times box should be active 
    set has_times {0 1 1 1 1 1 1}

    set menu_disabled {0 0 0 0 0 1 1}

    #whether or not there is a repeat time
    set needs_lifetime {0 0 1 1 1 1 1}

    #what the default minimum repeat time should be
    set rpt_min_values {0 0 2880 20160 40320 40320 20160}

    #what the max duration should be for each repeat interval
    set duration_max {0 4838400 43200 518400 1036800 0 604800}

    if {[string compare $aid "new"]!=0} {
	for {set box 1} {$box <= $ldata($aid,no_of_times)} { incr box} {
	    set rpt_menu_value($box) 1
	    new_mk_session_time_box .new.f2.act.f$box $box $ldata($aid,no_of_times) $rpt_times $menu_disabled
	}
    } else {
	set rpt_menu_value(1) 1
	new_mk_session_time_box .new.f2.act.f1 1 1 $rpt_times $menu_disabled
    }

    label .new.f2.act.expl2 -text [tt "Length of this series of sessions"] \
	-font [resource infoFont]
    pack .new.f2.act.expl2 -side top -anchor w
    pack [frame .new.f2.act.fd] -side top -anchor w
    pack [label .new.f2.act.fd.l -text [tt "Repeat for:"]] -side left -anchor w
    duration_widget .new.f2.act.fd.duration 3600
    if {[string compare $aid "new"]!=0} {
	configure_duration_box .new.f2.act.fd $ldata($aid,no_of_times)
    } else {
	configure_duration_box .new.f2.act.fd 1
    }
    if {[string compare $aid "new"]!=0} {
	set rpts 0
	set maxdiff 0
	for {set t 0} {$t < $ldata($aid,no_of_times)} {incr t} {
	    if {$ldata($aid,time$t,no_of_rpts)==0} {
		.new.f2.act.fb[expr $t+1].day.workaround configure \
		    -time $ldata($aid,starttime,$t)		
		.new.f2.act.fb[expr $t+1].time.workaround configure \
		    -time $ldata($aid,starttime,$t)
		.new.f2.act.fb[expr $t+1].duration.workaround configure -time \
		    [expr $ldata($aid,endtime,$t) - $ldata($aid,starttime,$t)]
		set rpt_menu_value([expr $t+1]) 1
		configure_rpt_menu [expr $t+1] .new.f2.act.fb[expr $t+1]
	    } else {

		set rpts 1
		for {set r 0} {$r < $ldata($aid,time$t,no_of_rpts)} {incr r} {
		    if {$r>0} {puts "too complicated - tragic!"}
		    if {$ldata($aid,time$t,offset$r)!="0"} {
			puts "too many offsets! - tragic!"
		    }
		    set start $ldata($aid,starttime,$t)
		    set end $ldata($aid,endtime,$t)
		    set dur $ldata($aid,time$t,duration$r)
		    set ofs $ldata($aid,time$t,offset$r)
		    if {[expr ($end-$start)-$dur]> $maxdiff } {
			     set maxdiff [expr ($end-$start)-$dur]
		    }
		    .new.f2.act.fb[expr $t+1].day.workaround configure -time $start
		    .new.f2.act.fb[expr $t+1].time.workaround configure -time $start
		    .new.f2.act.fb[expr $t+1].duration.workaround configure -time $dur
		    case $ldata($aid,time$t,interval$r) in {
			86400 {set rpt_menu_value([expr $t+1]) 2}
			604800 {
			    if {$ofs=="0"} {
				set rpt_menu_value([expr $t+1]) 3
			    } elseif {$ofs=="0 86400 172800 259200 345600"} {
				set rpt_menu_value([expr $t+1]) 6
			    } else {
				puts "help - can't handle this weekly offset"
			    }
			}
			1209600 {set rpt_menu_value([expr $t+1]) 4}
		    }
		    configure_rpt_menu [expr $t+1] .new.f2.act.fb[expr $t+1]
		}
	    }
	}
	if {$rpts==1} {
	    .new.f2.act.fd.duration.workaround configure -time $maxdiff
	    .new.f2.act.fd.duration.workaround configure -state normal
	}
    }
    new_mk_session_contact .new.you $aid

    new_mk_session_buttons .new.f4 $aid
    move_onscreen .new
    log "displaying normal session creation interface at [getreadabletime]"
}

####
#new creates a window to allow a new session to be defined
####
set sizes(.new.x) 473
set sizes(.new.y) 814
proc tech_new {aid} {
    global send durationix sd_menu scope zone
    global monthix dayix dayofmonth hrix ttl timeofday
    global video_attr audio_attr whiteboard_attr
    global ldata startdayofweek medialist sd_fmt media_fmt media_proto
    global security
    global yourphone
    global youremail
    global yourname
    global new_createtime
    if {[string length $yourphone]==0} {
	enter_phone_details "tech_new $aid"
	return
    }

    catch {destroy .new}
    toplevel .new

    posn_win .new
    if {[string compare $aid "new"]!=0} {
	wm title .new "Sdr: [tt "Edit Session"]"
	foreach i $medialist {
            set send($i) 0
        }
  	set new_createtime $ldata($aid,createtime)
    } else {
	wm title .new "Sdr: [tt "Create New Session"]"
	foreach i $medialist {
	    set send($i) 0
	}
	set send(audio) 1
	set new_createtime [unix_to_ntp [gettimeofday]]
    }


    new_mk_session_name .new $aid
    new_mk_session_desc .new $aid
    new_mk_session_url .new $aid

    if {[string compare $aid "new"]!=0} {
	set sd_addr $ldata($aid,sd_addr)
	set ttl $ldata($aid,ttl)
	set scope ttl
	set zone(cur_zone) $zone(ttl_scope)
	for {set i 0} {$i<$zone(no_of_zones)} {incr i} {
#	    puts "$zone(sd_addr,$i)==$sd_addr)&&($zone(ttl,$i)==$ttl)"
	    if {($zone(sd_addr,$i)==$sd_addr)&&($zone(ttl,$i)==$ttl)} {
#		puts "setting zone(cur_zone) $i"
		set scope admin
		set zone(cur_zone) $i
	    }
	}
    } else {
	set scope admin
	set zone(cur_zone) 0
	set ttl $zone(ttl,$zone(cur_zone))
    }


    frame .new.f3
    pack .new.f3 -side top -pady 5 -fill x -expand true

    catch {
	new_mk_session_security .new.f3.l $aid
    }

    frame .new.f3.m -width 1 -height 1
    pack .new.f3.m -side left -fill y -padx 3
    frame .new.f3.r -relief groove -borderwidth 2
    pack .new.f3.r -side left -fill both -expand true

    new_mk_session_type .new.f3.r top $aid

    label .new.f3.r.l2 -text "Scope Mechanism:"
    pack .new.f3.r.l2 -side top -anchor nw
    radiobutton .new.f3.r.b3 -text "TTL Scope" \
	-highlightthickness 0 \
	-variable scope -value ttl -relief flat -command \
	[format { 
	    set addr [generate_address %s]
	    if {$addr!=0} {
		pack .new.f3.rr -after .new.f3.m2 -side left -fill both \
		    -expand true
		pack forget .new.f3.admin
		if {$addr!=1} {
		    set_new_session_addr conference $addr
		    foreach media $medialist {
			if {$send($media)==1} {
			    set_new_session_addr $media [generate_address]
			}
		    }
		}
		set zone(cur_zone) $zone(ttl_scope)
		set scope ttl
		set_ttl_scope $ttl
	    } else {
		set scope admin
	    }
	} $aid ]
    pack .new.f3.r.b3 -side top -anchor nw
    radiobutton .new.f3.r.b4 -text "Admin Scope" \
	-highlightthickness 0 \
	-variable scope -value admin -relief flat -command \
	[format { 
	    # Recover the previously-selected scope if one clicks
	    # on "admin" then "ttl" then "admin".
	    #
	    set tmpzone 0
	    for {set i 0} {$i < $zone(no_of_zones)} {incr i} {
		if {[string compare \
		     [.new.f3.admin.f.lb tag cget line$i -background] \
			 [option get . activeBackground Sdr]]==0} {
			     set tmpzone $i
			     break
			 }
	    }
	    set addr [generate_address $zone(base_addr,$tmpzone) \
                         $zone(netmask,$tmpzone) %s]
	    if {$addr!=0} {
		set zone(cur_zone) $tmpzone
		pack .new.f3.admin -after .new.f3.m2 -side left -fill both \
		    -expand true
		pack forget .new.f3.rr
		if {$addr!=1} {
		    set_new_session_addr conference $addr
		    foreach media $medialist {
			if {$send($media)==1} {
			    set_new_session_addr $media \
				[generate_address \
				 $zone(base_addr,$zone(cur_zone)) \
				     $zone(netmask,$zone(cur_zone))]
			}
		    }
		}
		set scope admin
		set ttl $zone(ttl,$zone(cur_zone))
	    } else {
		set scope ttl
	    }
	    unset tmpzone
	} $aid]
    pack .new.f3.r.b4 -side top -anchor nw

    hlfocus .new.f3.r.b3
    hlfocus .new.f3.r.b4
    #padding frame
    pack [frame .new.f3.m2 -width 1 -height 1] -side left -fill y -padx 3

    #admin scope frame
    frame .new.f3.admin -relief groove -borderwidth 2
    if {$scope=="admin"} {pack .new.f3.admin -side left -fill both -expand true}
    label .new.f3.admin.l -text Scope:
    pack .new.f3.admin.l -side top -anchor w
    frame .new.f3.admin.f -relief sunken -borderwidth 1
    pack .new.f3.admin.f -side top -fill both -expand true
    text .new.f3.admin.f.lb -width 15 -height 6 -relief flat -wrap none
    pack .new.f3.admin.f.lb -side top -fill both -expand true
    for {set i 0} {$i < $zone(no_of_zones)} {incr i} {
	.new.f3.admin.f.lb insert [expr $i+1].0 "$zone(name,$i)"
	.new.f3.admin.f.lb tag add line$i [expr $i+1].0 end-1c
	.new.f3.admin.f.lb tag configure line$i -background\
	    [option get . background Sdr]
	.new.f3.admin.f.lb insert end " \n"
	.new.f3.admin.f.lb tag bind line$i <1> \
	    [format {
		set addr [generate_address $zone(base_addr,%s) \
			  $zone(netmask,%s) %s]
		if {$addr!=0} {
		    #the change of scope is OK
		    for {set i 0} {$i < $zone(no_of_zones)} {incr i} {
			.new.f3.admin.f.lb tag configure line$i -background\
			    [option get . background Sdr]
		    }
		    .new.f3.admin.f.lb tag configure line%s -background\
			[option get . activeBackground Sdr]
		    set ttl $zone(ttl,%s)
		    if {$addr!=1} {
			#and we can reallocated the addresses too.
			set_new_session_addr conference $addr
			foreach media $medialist {
			    if {$send($media)==1} {
				set_new_session_addr $media \
				    [generate_address $zone(base_addr,%s) \
				     $zone(netmask,%s)]
			    }
			}
		    }
		    set zone(cur_zone) %s
		}
	    } $i $i $aid $i $i $i $i $i]
    }
    .new.f3.admin.f.lb configure -state disabled
    .new.f3.admin.f.lb tag configure line$zone(cur_zone) -background\
	[option get . activeBackground Sdr]

    
    frame .new.f3.rr -relief groove -borderwidth 2
    tixAddBalloon .new.f3.rr Frame [tt "The scope determines how far your session will reach.  The default values are:

Local net: 1
Site:      15
Region:    63
World:     127

Specify the smallest scope that will reach the people you want to communicate with."]

    label .new.f3.rr.l -text [tt "Scope"]
    radiobutton .new.f3.rr.r1 -relief flat -text [tt "Site"] -variable ttl\
	-highlightthickness 0 \
	-value 15 -command {disable_scope_entry 15}
    radiobutton .new.f3.rr.r2 -relief flat -text [tt "Region"] -variable ttl\
	-highlightthickness 0 \
	-value 63 -command {disable_scope_entry 63}
    radiobutton .new.f3.rr.r3 -relief flat -text [tt "World"] -variable ttl\
	-highlightthickness 0 \
	-value 127 -command {disable_scope_entry 127}
    hlfocus .new.f3.rr.r1
    hlfocus .new.f3.rr.r2
    hlfocus .new.f3.rr.r3
    frame .new.f3.rr.f
    if {[string compare $aid "new"]==0} {
	radiobutton .new.f3.rr.f.r4 -relief flat -variable ttl\
	    -highlightthickness 0 \
	    -command "enable_scope_entry 1" -value 0
    } else {
	radiobutton .new.f3.rr.f.r4 -relief flat -variable ttl\
	    -highlightthickness 0 \
	    -command "enable_scope_entry $ttl" -value 0
    }
    entry .new.f3.rr.f.e -relief sunken -width 4 -text 1 \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0
    .new.f3.rr.f.e insert 0 $ttl
    proc disable_scope_entry {value} {
	.new.f3.rr.f.e configure -state normal
	.new.f3.rr.f.e delete 0 end
	.new.f3.rr.f.e insert 0 $value
	.new.f3.rr.f.e configure -state disabled \
	    -background [option get . background Sdr]\
	    -relief groove
    }
    proc enable_scope_entry {ttl} {
	.new.f3.rr.f.e configure -state normal \
            -background [option get . entryBackground Sdr]\
            -relief sunken
	.new.f3.rr.f.e delete 0 end
        .new.f3.rr.f.e insert 0 $ttl
    }
    bind .new.f3.rr.f.e <1> {
	.new.f3.rr.f.r4 invoke
	.new.f3.rr.f.e icursor end
	focus .new.f3.rr.f.e
    }
    pack .new.f3.rr.f.r4 -side left
    pack .new.f3.rr.f.e -side left
    if {[string compare $aid "new"]!=0} {
	set ttl $ldata($aid,ttl)
	if {$scope=="ttl"} {
	    set_ttl_scope $ttl
	}
    } else {
	if {$scope=="ttl"} {
	    .new.f3.rr.r1 invoke
	}
    }
    pack .new.f3.rr.l -side top -anchor w
    pack .new.f3.rr.r1 -side top -anchor w
    pack .new.f3.rr.r2 -side top -anchor w
    pack .new.f3.rr.r3 -side top -anchor w
    pack .new.f3.rr.f -side top -anchor w
    if {$scope=="ttl"} {pack .new.f3.rr -side left -fill both -expand true}


    set show_details 1
    new_mk_session_media .new.f1 $aid $scope $show_details

    frame .new.f2
    frame .new.f2.act -relief groove -borderwidth 2
    pack .new.f2.act -side left -fill both -expand true
    pack .new.f2 -side top -pady 5 -fill x -expand true
    pack [frame .new.f2.act.l] -side top -anchor w
    label .new.f2.act.l.icon -bitmap clock
    pack .new.f2.act.l.icon -side left
    label .new.f2.act.l.l -text "Session will be active:" 
    pack .new.f2.act.l.l -side left

    global rpt_times
    global has_times
    global needs_lifetime
    global rpt_min_values 
    global rpt_menu_value
    global duration_max

    set rpt_times {{---} {Once} {Daily} {Weekly} {Every Two Weeks}\
     {Monthly by Date} {Monday thru Friday}}

    #whether of not the times box should be active 
    set has_times {0 1 1 1 1 1 1}

    set menu_disabled {0 0 0 0 0 1 1}

    #whether or not there is a repeat time
    set needs_lifetime {0 0 1 1 1 1 1}

    #what the default minimum repeat time should be
    set rpt_min_values {0 0 2880 20160 40320 40320 20160}

    #what the max duration should be for each repeat interval
    set duration_max {0 4838400 43200 518400 1036800 0 604800}

    set rpt_menu_value(1) 1
    set rpt_menu_value(2) 0
    set rpt_menu_value(3) 0
    foreach box {1 2 3} {
	new_mk_session_time_box .new.f2.act.f$box $box 3 $rpt_times $menu_disabled
    }
    pack [frame .new.f2.act.fd] -side top -anchor w
    pack [label .new.f2.act.fd.l -text "Repeat for:"] -side left -anchor w
    duration_widget .new.f2.act.fd.duration 3600
    configure_duration_box .new.f2.act.fd 3
    if {[string compare $aid "new"]!=0} {
	set rpts 0
	set maxdiff 0
	for {set t 0} {$t < $ldata($aid,no_of_times)} {incr t} {
	    if {$ldata($aid,time$t,no_of_rpts)==0} {
		.new.f2.act.fb[expr $t+1].day.workaround configure \
		    -time $ldata($aid,starttime,$t)		
		.new.f2.act.fb[expr $t+1].time.workaround configure \
		    -time $ldata($aid,starttime,$t)
		.new.f2.act.fb[expr $t+1].duration.workaround configure -time \
		    [expr $ldata($aid,endtime,$t) - $ldata($aid,starttime,$t)]
		set rpt_menu_value([expr $t+1]) 1
		configure_rpt_menu [expr $t+1] .new.f2.act.fb[expr $t+1]
	    } else {
		set rpts 1
		for {set r 0} {$r < $ldata($aid,time$t,no_of_rpts)} {incr r} {
		    if {$r>0} {puts "too complicated - tragic!"}
		    if {$ldata($aid,time$t,offset$r)!="0"} {
			puts "too many offsets! - tragic!"
		    }
		    set start $ldata($aid,starttime,$t)
		    set end $ldata($aid,endtime,$t)
		    set dur $ldata($aid,time$t,duration$r)
		    set ofs $ldata($aid,time$t,offset$r)
		    if {[expr ($end-$start)-$dur]> $maxdiff } {
			     set maxdiff [expr ($end-$start)-$dur]
		    }
		    .new.f2.act.fb[expr $t+1].day.workaround configure -time $start
		    .new.f2.act.fb[expr $t+1].time.workaround configure -time $start
		    .new.f2.act.fb[expr $t+1].duration.workaround configure -time $dur
		    case $ldata($aid,time$t,interval$r) in {
			86400 {set rpt_menu_value([expr $t+1]) 2}
			604800 {
			    if {$ofs=="0"} {
				set rpt_menu_value([expr $t+1]) 3
			    } elseif {$ofs=="0 86400 172800 259200 345600"} {
				set rpt_menu_value([expr $t+1]) 6
			    } else {
				puts "help - can't handle this weekly offset"
			    }
			}
			1209600 {set rpt_menu_value([expr $t+1]) 4}
		    }
		    configure_rpt_menu [expr $t+1] .new.f2.act.fb[expr $t+1]
		}
	    }
	}
	if {$rpts==1} {
	    .new.f2.act.fd.duration.workaround configure -time $maxdiff
	    .new.f2.act.fd.duration.workaround configure -state normal
	}
    }
    new_mk_session_contact .new.you $aid

    new_mk_session_buttons .new.f4 $aid
    move_onscreen .new
    log "displaying technical session creation interface at [getreadabletime]"
}

proc set_sess_type {win type} {
    global sess_type
    set sess_type $type
    switch $type {
	test {
	    $win.m configure -text Test
	}
	broadcast {
	    $win.m configure -text Broadcast
	}
	meeting {
	    $win.m configure -text Meeting
	}
	other {
	    $win.m configure -text Unspecified
	}
    }
}

proc new_mk_session_type {win order aid} {
    global ldata typelist
    label $win.l -text "Type of Session:"
    pack $win.l -side $order -anchor nw
    menubutton $win.m -menu $win.m.menu -width 10\
	-borderwidth 1 -relief raised
    pack $win.m -side $order -anchor nw -padx 10
    menu $win.m.menu -tearoff 0
    foreach type $typelist {
	$win.m.menu add command -label [get_type_name $type] \
		-command "set_sess_type $win $type"
    }
    if {[string compare $aid "new"]==0} {
	set_sess_type $win test
    } else {
	set_sess_type $win $ldata($aid,type)
    }
}

proc new_mk_session_name {win aid} {
    global ldata
    frame $win.f0
    label $win.f0.l -text [tt "Session Name:"]
    entry $win.f0.entry -width 30 -relief sunken\
	 -bg [option get . entryBackground Sdr] \
	 -highlightthickness 0
    tixAddBalloon  $win.f0.entry Entry [tt "Enter the name of the session here"]
    if {[string compare $aid "new"]!=0} { $win.f0.entry insert 0 $ldata($aid,session) }
    pack $win.f0.l -side left
    pack $win.f0.entry -side left -fill x -expand true
    pack $win.f0 -side top -anchor w -fill x
    proc get_new_session_name {win} {
	$win.f0.entry get
    }
}

proc new_mk_session_desc {win aid} {
    global ldata
    label $win.descl -text [tt "Description:"]
    pack $win.descl -side top -anchor w
    frame $win.df
    text $win.df.desc -width 40 -height 5 -relief sunken -borderwidth 2 \
	 -bg [option get . entryBackground Sdr] -yscroll "$win.df.sb set"\
	-wrap word
    scrollbar $win.df.sb -command "$win.df.desc yview" \
      -background [option get . scrollbarBackground Sdr] \
      -borderwidth 1 -relief flat
#TBD
#      -foreground [option get . scrollbarForeground Sdr] \
#      -activeforeground [option get . scrollbarActiveForeground Sdr] 



    tixAddBalloon $win.df.desc Text [tt "Enter a short description of your session here"]


    #this shouldn't really list the widgets by name
    bind $win.df.desc <Tab> "focus $win.url.f0.e;break"
    bind $win.df.desc <Shift-Tab> "focus $win.f0.entry;break"

    pack $win.df.desc -side left -fill both -expand true
    pack $win.df.sb -side left -fill y
    pack $win.df -side top -fill both -expand true
    if {[string compare $aid "new"]!=0} { 
#	$win.df.desc insert 0.0 [text_wrap $ldata($aid,desc) 40] 
	$win.df.desc insert 0.0 $ldata($aid,desc)
    }    
    proc get_new_session_desc {} {
	.new.df.desc get 0.0 end-1c
    }
}

proc new_mk_session_url {win aid} {
    global ldata
    frame .new.url -borderwidth 2 -relief groove
    pack .new.url -side top -fill x -expand true -ipady 2 -ipadx 2 -pady 2
    frame .new.url.f0 
    pack .new.url.f0 -side top -fill x -expand true
    label .new.url.f0.l -text URL:
    pack .new.url.f0.l -side left
    entry .new.url.f0.e -width 30 -relief sunken -borderwidth 2 \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0
    tixAddBalloon .new.url.f0.e Entry [tt "You can enter a URL here to provide additional information about your session.\n\nA URL is a reference to a web page. E.g. http://www"]
    pack .new.url.f0.e -side left -fill x -expand true
    button .new.url.f0.b -text "Test URL" \
	-highlightthickness 0 \
	-command \
	{ .new.url.f0.e select from 0; \
	  .new.url.f0.e select to end; \
	  catch {selection get} url; \
	  timedmsgpopup "Testing URL - please wait" $url 5000; \
	  stuff_mosaic }
    tixAddBalloon .new.url.f0.b Button [tt "Click here to test the URL entered in the box to the left of this button"]
    pack .new.url.f0.b -side left
    if {[string compare $aid "new"]!=0} {
	if {$ldata($aid,uri)!=0} {
	    .new.url.f0.e insert 0 $ldata($aid,uri)
	}
    }
    proc get_new_session_uri {} {
	.new.url.f0.e get
    }
}

proc new_mk_session_admin {win aid scope} {
    global zone send medialist ttl ldata
    #admin scope frame
    frame $win -relief groove -borderwidth 2
    if {$scope=="admin"} {pack $win -side left -fill both -expand true}
    label $win.l -text "Area Reached:"

    tixAddBalloon $win.l Label [tt "The area reached determines the \
range of the session.  People outside this area will not be able to receive it."]

    pack $win.l -side top -anchor w
    pack [frame $win.f] -side top -fill both -expand true
    text $win.f.lb -width 15 -height 6 -relief flat \
	 -relief sunken -borderwidth 1 -yscroll "$win.f.sb set" \
	 -highlightthickness 0
    pack $win.f.lb -side left -fill both -expand true
    scrollbar $win.f.sb -borderwidth 1 -command "$win.f.lb yview" \
	 -highlightthickness 0
    pack $win.f.sb -side right -fill y -expand true
    for {set i 0} {$i < $zone(no_of_zones)} {incr i} {
	$win.f.lb insert [expr $i+1].0 "$zone(name,$i)"
	$win.f.lb tag add line$i [expr $i+1].0 end-1c
	$win.f.lb tag configure line$i -background\
	    [option get . background Sdr]
	$win.f.lb insert end " \n"
	$win.f.lb tag bind line$i <1> \
	    [format {
		set ttl $zone(ttl,%s)
		set addr [generate_address $zone(base_addr,%s) \
			  $zone(netmask,%s) %s]
		if {$addr!=0} { \
		    for {set i 0} {$i < $zone(no_of_zones)} {incr i} {
			%s.f.lb tag configure line$i -background\
			    [option get . background Sdr]
		    }
		    %s.f.lb tag configure line%s -background\
                     [option get . activeBackground Sdr]
		    if {$addr!=1} {
			set_new_session_addr conference $addr
			foreach media $medialist {
			    if {$send($media)==1} {
				set_new_session_addr $media \
				    [generate_address $zone(base_addr,%s) \
				     $zone(netmask,%s)]
			    }
			}
		    }
		    set zone(cur_zone) %s
		}
	    } $i $i $i $aid $win $win $i $i $i $i]
    }
    if {($scope=="admin")&&([string compare $aid "new"]==0)} {
	set ttl $zone(ttl,0)
    } elseif {[string compare $aid "new"]!=0} {
	set ttl $ldata($aid,ttl)
    } else {
	set ttl 15
    }
    $win.f.lb configure -state disabled
    $win.f.lb tag configure line$zone(cur_zone) -background\
	[option get . activeBackground Sdr]
}

proc new_mk_session_media {win aid scope show_details} {
    global ldata zone medialist sd_menu send 
    global media_fmt media_proto media_attr media_layers
    #multicast address and ttl
    frame $win -relief groove -borderwidth 2
    frame $win.f0
    label $win.f0.l -text [tt "Address:"]
    entry $win.f0.entry -width 20 -relief sunken\
	 -bg [option get . entryBackground Sdr] \
	 -highlightthickness 0
    tixAddBalloon $win.f0.entry Entry [tt "A multicast address has been assigned you.  If you need to modify this, change this entry.

Multicast addresses must be class D IP addresses.  These are of the form
      a.b.c.d 
where a is in the range 224 to 239 and b, c and d are in the range 0 to 255."]
    if {[string compare $aid "new"]!=0} {
	$win.f0.entry insert 0 $ldata($aid,multicast)	    
    } else {
        if {$scope=="admin"} {
            $win.f0.entry insert 0 [generate_address $zone(base_addr,$zone(cur_zone)) $zone(netmask,$zone(cur_zone))]
        } else {
            $win.f0.entry insert 0 [generate_address]
        }
    }
    pack $win.f0.l -side left
    pack $win.f0.entry -side left -fill x -expand true

    #Media
    pack [frame $win.l] -side top -anchor w
    label $win.l.1 -text [tt "Media:"] -anchor w -width 15
    pack $win.l.1 -side left -anchor w -padx 10 
    label $win.l.5 -text [tt "Protocol"] -anchor w -width 8
    if {$show_details==1} {
	pack $win.l.5 -side left -anchor w
    }
    label $win.l.2 -text [tt "Format"] -anchor w -width 9
    pack $win.l.2 -side left -anchor w
    label $win.l.3 -text [tt "Address"] -anchor w -width 13
    if {($show_details==1)} {
	pack $win.l.3 -side left -anchor w
    }
    label $win.l.6 -text [tt "Layers"] -anchor w -width 6
    pack $win.l.6 -side left -anchor w
    label $win.l.4 -text [tt "Port"] -anchor w -width 6
    if {$show_details==1} {
	pack $win.l.4 -side left -anchor w 
    }

    foreach attr [array names media_attr] {
	unset media_attr($attr)
    }
    if {[string compare $aid "new"]!=0} {
	for {set mnum 0} {$mnum < $ldata($aid,medianum)} {incr mnum} {
	    set send($ldata($aid,$mnum,media)) 1
#	    set media_attr($ldata($aid,$mnum,media)) $ldata($aid,$mnum,vars)
#	    puts "vars: $ldata($aid,$mnum,vars)"
	    foreach var $ldata($aid,$mnum,vars) {
		set key [lindex [split $var ":"] 0]
		set value [lindex [split $var ":"] 1]
		if {$value==""} {
		    set media_attr($ldata($aid,$mnum,media),$key) 1
		} else {
		    set media_attr($ldata($aid,$mnum,media),$key) $value
		}
	    }
	}
    }
    
    foreach media $medialist {
	frame $win.$media
	pack $win.$media -side top -anchor w  -padx 10 -pady 2

	button $win.$media.cb -command "togglemedia $win $media"
	pack $win.$media.cb -side left
	iconbutton $win.$media.mb -text $media -bitmap [get_icon $media] -width 10 -relief raised\
	    -menu $win.$media.mb.menu 
	pack $win.$media.mb -side left -fill y
	create_menu $win.$media.mb.menu "" "" $media "create"

	menubutton $win.$media.fmt -width 8  -relief raised\
	    -menu $win.$media.fmt.menu
	create_fmt_menu $win $win.$media.fmt $win.$media.layers \
            [lindex [get_media_protos $media] 0] \
	    [get_media_fmts $media [lindex [get_media_protos $media] 0]] $media

	menubutton $win.$media.proto -width 6 -relief raised\
	    -menu $win.$media.proto.menu
	create_proto_menu $win $win.$media.proto $win.$media.layers \
		$win.$media.fmt [get_media_protos $media] $media

	entry $win.$media.addr -width 14 -relief sunken\
	    -bg [option get . entryBackground Sdr] \
	     -highlightthickness 0
	menubutton $win.$media.layers -width 3 -relief raised\
	     -menu $win.$media.layers.menu
        create_layers_menu $win $win.$media.layers $media
	entry $win.$media.port -width 6 -relief sunken\
	    -bg [option get . entryBackground Sdr] \
	     -highlightthickness 0
	set media_fmt($media) \
	    [lindex [get_media_fmts $media [lindex [get_media_protos $media] 0]] 0]
	set media_proto($media) [lindex [get_media_protos $media] 0]
	set media_layers($media) \
		[get_max_layers $media $media_proto($media) $media_fmt($media)]
	if {([string compare $aid "new"]==0)&&($send($media)==1)} {
	    if {$scope=="admin"} {
		$win.$media.addr insert 0 [generate_address $zone(base_addr,$zone(cur_zone)) $zone(netmask,$zone(cur_zone))]
	    } else {
		$win.$media.addr insert 0 [generate_address]
	    }
	    setmediamode $media $win $send($media) 1
	} elseif {([string compare $aid "new"]!=0)&&($send($media)==1)} { 
	    setmediaflags $media $win $aid 
	    setmediamode $media $win $send($media) 0
	} else {
	    setmediamode $media $win $send($media) 0
	}

	if {$show_details==1} {
	    pack $win.$media.proto -side left -fill y -padx 2
	}
	pack $win.$media.fmt -side left -fill y -padx 2
	if {$show_details==1} {
	    pack $win.$media.addr -side left -padx 2
	}
	pack $win.$media.layers -side left -padx 2
	if {$show_details==1} {
	    pack $win.$media.port -side left -padx 2
	}
    }
    

    if {$show_details==1} {
	pack $win -fill x -side top -anchor w -pady 5
    } else {
	pack $win -fill both -expand true -side top -anchor nw
    }
    proc get_new_session_addr {media} [format {
	if {$media=="conference"} {
           %s.f0.entry get
        } else {
           %s.$media.addr get
        }
    } $win $win]
    proc set_new_session_addr {media str} [format {
        if {$media=="conference"} {
           %s.f0.entry delete 0 end
	    %s.f0.entry insert 0 $str
       } else {
           %s.$media.addr delete 0 end
	   %s.$media.addr insert 0 $str
       }
    } $win $win $win $win]


    proc get_new_session_port {media} [format {
	%s.$media.port get
    } $win ]
    proc get_new_session_proto {media} {
    }
    proc get_new_session_format {media} {
    }
}


proc new_mk_session_time_box {win box maxbox rpt_times menu_disabled} {
    global ifstyle
    if {($box==1)&&($ifstyle(create)=="norm")} {
	label .new.f2.act.expl -font [resource infoFont] -text \
	    "how often it takes place               when it first takes place                                      how long each time"
	pack .new.f2.act.expl -side top
    }
    frame .new.f2.act.fb$box
    set mb .new.f2.act.fb$box.m
    menubutton $mb  -width 20 -anchor w\
	-relief raised -borderwidth 1 -menu $mb.m
    menu $mb.m -tearoff 0
    pack $mb -side left -anchor w
    set ctr 0
    foreach i $rpt_times {
	if {[lindex $menu_disabled $ctr]==0} {
	    $mb.m add command -label $i -command "\
		    $mb configure -text \"$i\";\
                    set rpt_menu_value($box) $ctr;\
                    configure_rpt_menu $box .new.f2.act.fb$box;\
                    configure_duration_box .new.f2.act.fd $maxbox"
	} else {
	    $mb.m add command -label $i -state disabled
	}
	incr ctr
    }
    pack .new.f2.act.fb$box -side top
    pack [label .new.f2.act.fb$box.l -text "from:"] -side left
    day_widget .new.f2.act.fb$box.day now
    pack [label .new.f2.act.fb$box.l1 -text "at"] -side left
    time_widget .new.f2.act.fb$box.time now
    pack [label .new.f2.act.fb$box.l2 -text "for"] -side left
    duration_widget .new.f2.act.fb$box.duration 7200
    pack [frame .new.f2.act.pad$box -height 10] -side top
    configure_rpt_menu $box .new.f2.act.fb$box
}

proc new_mk_session_contact {win aid} {
    global ldata yourname yourphone youremail
    frame $win -relief groove -borderwidth 2
    label $win.l -text "Person to contact about this session:"

    tixAddBalloon $win.l Label [tt "Name, email address and telephone \
number of person to be contacted about the session. You can \
edit the suggested address and telephone number. To edit the \
default, choose \"Preferences\" in the session main session \
window, then \"You\"."]

    pack $win.l -side top -anchor nw
    frame $win.f0 
    pack $win.f0 -side top -pady 3

    label $win.f0.l -bitmap mail -anchor w
    pack $win.f0.l -side left -fill x -anchor s
    entry $win.f0.e -width 35 -relief sunken \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0
    tixAddBalloon $win.f0.e Entry [tt "Enter your name and email address here"]
    pack $win.f0.e -side bottom -anchor sw


    frame $win.f1 
    pack $win.f1 -side top
    label $win.f1.l -bitmap phone -anchor w
    pack $win.f1.l -side left -fill x
    entry $win.f1.e -width 35 -relief sunken \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0
    tixAddBalloon $win.f1.e Entry [tt "Enter your telephone number here"]
    pack $win.f1.e -side left -fill x -expand true
    pack $win -side top -fill both -expand true

    if {[string compare $aid "new"]!=0} { 
 	foreach p $ldata($aid,phonelist) {
	    $win.f1.e insert 0 $p
	}
	foreach e $ldata($aid,emaillist) {
	    $win.f0.e insert 0 $e
	}
   } else {
       $win.f1.e insert 0 "$yourname $yourphone"
       $win.f0.e insert 0 "$yourname <$youremail>"
    }
}

proc new_mk_session_buttons {win aid} {
    frame $win
    if {[string compare $aid "new"]!=0} {
	button $win.create -text [tt "Modify"] -command \
	    "if {\[create\]==1} \
                { ui_stop_session_ad $aid;\
                  destroy .new}"
	tixAddBalloon $win.create Button [tt "Click here to advertise the modified session.  

Changing the session name may result in some sites seeing duplicate announcements for a while."]
    } else {
	button $win.create -text [tt "Create"] -command \
	    "if {\[create\]==1} {destroy .new}" \
	     -highlightthickness 0
	tixAddBalloon $win.create Button [tt "When you've filled out all the above information, click here to create and advertise this session"]
    }
    button $win.cal -text [tt "Show Daily Listings"] -command "calendar" \
	 -highlightthickness 0
    tixAddBalloon $win.cal Button [tt "Click here to show a calendar of current sessions"]
    button $win.help -text [tt "Help"] -command "help" \
	 -highlightthickness 0
    tixAddBalloon $win.help Button [tt "Click here for more help or to turn balloon help off"]

    button $win.dismiss -text "Dismiss" -command "destroy .new" \
	 -highlightthickness 0
    tixAddBalloon $win.dismiss Button [tt "Click here to close this window"]
    pack $win.create -side left -fill x -expand true
    pack $win.cal -side left -fill x -expand true
    pack $win.help -side left -fill x -expand true
    pack $win.dismiss -side left -fill x -expand true
    pack $win -fill x
}

proc set_ttl_scope {ttl} {
    case $ttl {
	15 { .new.f3.rr.r1 invoke;return}
	63 { .new.f3.rr.r2 invoke;return}
	127 {.new.f3.rr.r3 invoke;return}
	default {
#	    puts $ttl
	    .new.f3.rr.f.r4 invoke
	}
    }
}
proc day_widget {widget time} {
    global $widget
    frame $widget
    if {$time!="now"} {
	set [set widget](startdayofweek) [lindex [gettime $time] 5]
	set [set widget](monthix) [fixint [lindex [gettime $time] 1]]
	set [set widget](dayofmonth) [fixint [lindex [gettime $time] 2]]
    } else {
	set [set widget](startdayofweek) [lindex [gettimenow] 5]
	set [set widget](monthix) [fixint [lindex [gettimenow] 1]]
	set [set widget](dayofmonth)  [fixint [lindex [gettimenow] 2]]
    }
    set [set widget](dayix) 0
    set [set widget](today_day) \
	[getdayname [set [set widget](startdayofweek)]]
    set [set widget](today_mon) [getmonname [set [set widget](monthix)]]
    label $widget.bx -relief sunken -width 10 -text \
	"[set [set widget](today_day)] [set [set widget](dayofmonth)] [set [set widget](today_mon)]"

    frame $widget.f
    button $widget.f.up -bitmap uparrow -relief flat \
	-borderwidth 0 -command "changeday $widget 1" \
	-highlightthickness 0
    button $widget.f.down -bitmap downarrow -relief flat \
	-borderwidth 0 -command "changeday $widget -1" \
	-highlightthickness 0
    pack $widget.f.up -side top
    pack $widget.f.down -side bottom
    pack $widget.f -side right
    pack $widget.bx -side right
    pack $widget -side left

    proc $widget.workaround {command args} [format {
	global %s
	case $command {
	    configure { configure_day_widget %s [lindex $args 0] [lindex $args 1] }
	    get { 
		return [set %s(dayix)]
	    }
	}
    } $widget $widget $widget $widget]
}

proc configure_day_widget {widget flag value} {
    global $widget
    case $flag {
	"-state" {
	    case $value {
		disabled {
		    $widget.f.up configure -state disabled
		    $widget.f.down configure -state disabled
		    $widget.bx configure \
			-relief groove\
			-fg [option get . background Sdr]
		}
		normal {
		    $widget.f.up configure -state normal
		    $widget.f.down configure -state normal
		    $widget.bx configure \
			-relief sunken\
			-fg [option get . foreground Sdr]
		}
	    }
	}
	"-time" {
	    set [set widget](startdayofweek) [lindex [gettime $value] 5]
	    set [set widget](monthix) [fixint [lindex [gettime $value] 1]]
	    set [set widget](dayofmonth) [fixint [lindex [gettime $value] 2]]
	    set [set widget](dayix) 0
	    set [set widget](today_day) \
		[getdayname [set [set widget](startdayofweek)]]
	    set [set widget](today_mon) [getmonname [set [set widget](monthix)]]
	    $widget.bx configure -text \
		"[set [set widget](today_day)] [set [set widget](dayofmonth)] [set [set widget](today_mon)]"
	}
    }
}

proc changeday {widget change} {
    global $widget daysinmonth
    if {($change < 0)&&([set [set widget](dayix)] >= [expr 0 - $change])} {
	set [set widget](dayix) [expr [set [set widget](dayix)] + $change]
	set [set widget](dayofmonth) [expr [set [set widget](dayofmonth)] +  $change]

    }
    if {$change > 0} {
	set [set widget](dayix) [expr [set [set widget](dayix)] + $change]
	set [set widget](dayofmonth) [expr [set [set widget](dayofmonth)] +  $change]
    }
    
    set thismonthlen [lindex $daysinmonth [expr [set [set widget](monthix)] - 1]]
    if {[set [set widget](dayofmonth)] > $thismonthlen} {
	set [set widget](dayofmonth) [expr [set [set widget](dayofmonth)] - $thismonthlen]
	incr [set widget](monthix)
	if {[set [set widget](monthix)]==13} {set [set widget](monthix) 1}
    } 
    if {[set [set widget](dayofmonth)]==0} {
	incr [set widget](monthix) -1
	if {[set [set widget](monthix)]==0} {set [set widget](monthix) 12}
        set thismonthlen [lindex $daysinmonth [expr [set [set widget](monthix)] - 1]]
	set [set widget](dayofmonth) $thismonthlen
    }
    set tmpday [expr ([set [set widget](dayix)] + [set [set widget](startdayofweek)]) % 7]
    $widget.bx configure -text \
	"[getdayname $tmpday] [set [set widget](dayofmonth)] [getmonname [set [set widget](monthix)]]"
}

proc time_widget {widget time} {
    global $widget
    if {$time!="now"} {
	set [set widget](timeofday) $time
    } else {
	set [set widget](timeofday) [expr [format %d [expr [gettimeofday] / 1800]] * 1800]
    }
    frame $widget
    if {$time!="now"} {
	label $widget.bx -relief sunken -width 5 \
	    -text [timethen $widget $time]
    } else {
	label $widget.bx -relief sunken -width 5 -text [timenow $widget]
    }
    frame $widget.f
    button $widget.f.up -bitmap uparrow -relief flat -borderwidth 0 \
	-command "$widget.bx configure -text \[changetime $widget 1\]" \
	-highlightthickness 0
    button $widget.f.down -bitmap downarrow -relief flat -borderwidth 0 -command "$widget.bx configure -text \[changetime $widget -1\]" \
	-highlightthickness 0
    pack $widget.f.up -side top
    pack $widget.f.down -side top
    pack $widget.f -side right
    pack $widget.bx -side right
    pack $widget -side left
    proc $widget.workaround {command args} [format {
	global %s
	case $command {
	    configure { configure_time_widget %s [lindex $args 0] [lindex $args 1] }
	    get { 
		return [set %s(timeofday)]
	    }
	}
    } $widget $widget $widget $widget]
}

proc configure_time_widget {widget flag value} {
    global $widget
    case $flag {
	"-state" {
	    case $value {
		disabled {
		    $widget.f.up configure -state disabled
		    $widget.f.down configure -state disabled
		    $widget.bx configure \
			-relief groove\
			-fg [option get . background Sdr]
		}
		normal {
		    $widget.f.up configure -state normal
		    $widget.f.down configure -state normal
		    $widget.bx configure \
			-relief sunken\
			-fg [option get . foreground Sdr]
		}
	    }
	}
	"-time" {
	    set [set widget](timeofday) $value
	    $widget.bx configure -text [timethen $widget $value]
	}
    }
}

proc changetime {widget change} {
    global $widget

    #we may have got given a hour with a leading zero - if so remove it
    #to avoid confusing TCL
    if {[string range [set [set widget](hrs)] 0 0] == "0"} {
	if {[string length [set [set widget](hrs)]] == 2} {
	    set [set widget](hrs) [string range [set [set widget](hrs)] 1 1]
	}
    }


    if {$change == -1} {
	if {[set [set widget](mins)]==30} {
	    set [set widget](mins) 0
	    if {[set [set widget](hrs)]<0} {set [set widget](hrs) 0;set [set widget](mins) 30} else {
		incr [set widget](timeofday) -1800
	    }
	    
	} else {
	    if {[set [set widget](hrs)]!=0} {
		set [set widget](mins) 30
		incr [set widget](hrs) -1
		incr [set widget](timeofday) -1800
	    }
	}
    } else {
	if {$change!=1} {puts "odd change value $change"}
	if {[set [set widget](mins)]==0} {
	    set [set widget](mins) 30
	    incr [set widget](timeofday) 1800
	} else {
	    set [set widget](mins) 0
	    incr [set widget](hrs) 1
	    if {[set [set widget](hrs)] > 23} {set [set widget](hrs) 23; set [set widget](mins) 30} else {
		incr [set widget](timeofday) 1800
	    }
	} 
    }
    if {[set [set widget](hrs)] < 10} { set hrsstr 0[set [set widget](hrs)] } else {set hrsstr [set [set widget](hrs)]}
    if {[set [set widget](mins)] < 10} { set minsstr 0[set [set widget](mins)] } else { set minsstr [set [set widget](mins)] }
    return $hrsstr:$minsstr
}

proc timenow {widget} {
    global $widget
    set [set widget](hrs) [lindex [gettimenow] 3]
    set [set widget](mins) [lindex [gettimenow] 4]
    if {[set [set widget](mins)] < 30} {
	set [set widget](mins) "00"
    } else {
	set [set widget](mins) 30
    }
    return [set [set widget](hrs)]:[set [set widget](mins)]
}

proc timethen {widget t} {
    global $widget
    set [set widget](hrs) [lindex [gettime $t] 3]
    set [set widget](mins) [lindex [gettime $t] 4]
    return [set [set widget](hrs)]:[set [set widget](mins)]
}

proc duration_widget {widget duration} {
    global $widget 
    set [set widget](durationix) [get_duration_ix_by_time $duration]
    #max time of 8 weeks
    set [set widget](duration_max) 4838400 
    set [set widget](duration_min) 0
    if {$duration!=0} {
	frame $widget
	label $widget.bx -relief sunken -width 10 \
	    -text [get_duration [set [set widget](durationix)]]
	frame $widget.f
	button $widget.f.up -bitmap uparrow -relief flat -borderwidth 0 \
	    -highlightthickness 0 \
	    -command [format {
                incr %s(durationix)
		if {[set %s(durationix)] > 28} {
		    set %s(durationix) 28
		}
		if {[expr [get_realduration [set %s(durationix)]]*60] > [set %s(duration_max)]} {
		    incr %s(durationix) -1
		}
		%s.bx configure -text \
		    [get_duration [set %s(durationix)]]
	    } $widget $widget $widget $widget $widget $widget $widget $widget]
	button $widget.f.down -bitmap downarrow -relief flat -borderwidth 0 \
	    -highlightthickness 0 \
	    -command [format {\
		incr %s(durationix) -1;
		if {[set %s(durationix)] < 0} {
		    set %s(durationix) 0
		};
		if {[expr [get_realduration [set %s(durationix)]]*60] < [set %s(duration_min)]} {
		    incr %s(durationix) 1
		}
		%s.bx configure -text \
		    [get_duration [set %s(durationix)]]
	    } $widget $widget $widget $widget $widget $widget $widget $widget]
	pack $widget.f.up -side top
	pack $widget.f.down -side top
	pack $widget.bx -side left
	pack $widget.f -side left
	pack $widget -side top -fill x -padx 3 -pady 2
    } else {
	label $widget -text [tt "Permanent Session"]
	pack $widget -side top -anchor ne
	set timeofday 0
	set dayix 0
	set [set widget](durationix) 0
    }
    proc $widget.workaround {command args} [format {
	global %s
        case $command {
            configure { configure_duration_widget %s [lindex $args 0] [lindex $args \
1] }
	    set {
		#args 1 is time in minutes
		set tmp [lindex $args 0]
		catch {set tmp %s(duration_min)}
		if {$tmp > [lindex $args 0]} {return 0}
		set tmp [get_duration_ix_by_time [expr [lindex $args 0] * 60]]
		set %s(durationix) $tmp
		%s.bx configure -text \
		    [get_duration $tmp]
	    }
	    minval {
		#args 1 is time in minutes
		set %s(duration_min) [expr [lindex $args 0] * 60]
	    }
            get {
		return [get_realduration [set %s(durationix)]]
            }
        }
    } $widget $widget $widget $widget $widget $widget $widget $widget]

}

proc configure_duration_widget {widget flag value} {
    global $widget
    case $flag {
	"-state" {
	    case $value {
		disabled {
		    $widget.f.up configure -state disabled
		    $widget.f.down configure -state disabled
		    $widget.bx configure \
			-fg [option get . background Sdr]\
			-relief groove
		}
		normal {
		    $widget.f.up configure -state normal
		    $widget.f.down configure -state normal
		    $widget.bx configure \
			-fg [option get . foreground Sdr]\
			-relief sunken
		}
	    }
	}
	"-time" {
	    set [set widget](durationix) [get_duration_ix_by_time $value]
	    $widget.bx configure -text [get_duration [set [set widget](durationix)]]
	}
    }
}

proc enter_phone_details {cmd} {
    global yourphone youremail yourname

    if {($yourname=="" || $youremail=="") && [file exists "~/.RTPdefaults"]} {
	option readfile "~/.RTPdefaults"
	if {$yourname==""} {
	    set yourname [option get . rtpName Sdr]
	}
	if {$youremail==""} {
	    set youremail [option get . rtpEmail Sdr]
	}
    }
    catch {destroy .phone}
    toplevel .phone
    wm title .phone "Sdr: Configure"
    frame .phone.f -borderwidth 2 -relief groove
    pack .phone.f -side top
    message .phone.f.l -text "Please configure sdr with your name, email address and phone number.  

These will be given as the defaults when you create a session, but you will still be able to override them for each session"
    pack .phone.f.l -side top
    frame .phone.f.f0 
    pack .phone.f.f0 -side top -fill x -expand true
    label .phone.f.f0.l -text "Name:"
    pack .phone.f.f0.l -side left -anchor e -fill x -expand true
    entry .phone.f.f0.e -width 40 -relief sunken -borderwidth 1 \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0
    if {$yourname!=""} {
	.phone.f.f0.e insert 0 $yourname
    }
    pack .phone.f.f0.e -side left

    frame .phone.f.f1 
    pack .phone.f.f1 -side top -fill x -expand true
    label .phone.f.f1.l -text "Email:"
    pack .phone.f.f1.l -side left -anchor e -fill x -expand true
    entry .phone.f.f1.e -width 40 -relief sunken -borderwidth 1 \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0
    if {$youremail!=""} {
	.phone.f.f1.e insert 0 $youremail
    } else {
	.phone.f.f1.e insert 0 "[getemailaddress]"
    }
    pack .phone.f.f1.e -side left

    frame .phone.f.f2 
    pack .phone.f.f2 -side top -fill x -expand true
    label .phone.f.f2.l -text "Phone:"
    pack .phone.f.f2.l -side left -anchor e -fill x -expand true
    entry .phone.f.f2.e -width 40 -relief sunken -borderwidth 1 \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0
    pack .phone.f.f2.e -side left

    frame .phone.f.f3 
    pack .phone.f.f3 -side top -fill x -expand true

    button .phone.f.f3.ok -text OK -command "\
        set yourphone \[.phone.f.f2.e get\];\
        set youremail \[.phone.f.f1.e get\];\
        set yourname \[.phone.f.f0.e get\];\
	if {\$yourname=={}} {\
	    errorpopup {Please enter your name} {Please enter your name};\
	    focus .phone.f.f0.e;\
	} elseif {\$youremail=={}} {\
	    errorpopup {Please enter your email address} {Please enter your email address};\
	    focus .phone.f.f1.e;\
	} elseif {\$yourphone=={}} {\
 	    errorpopup {Please enter a phone number} {Please enter your telephone number};\
	    focus .phone.f.f2.e;\
	}\
        save_prefs; \
        destroy .phone; \
	eval $cmd \
    "
    pack .phone.f.f3.ok -side left -fill x -expand true
    button .phone.f.f3.cancel -text Cancel \
	    -command {set wait_on_me 0;destroy .phone}
    pack .phone.f.f3.cancel -side left -fill x -expand true
    move_onscreen .phone
}

proc configure_rpt_menu {box win} {
    global has_times rpt_menu_value rpt_times duration_max
    global [set win].day
    global [set win].duration
    .new.f2.act.fb$box.m configure -text [lindex $rpt_times $rpt_menu_value($box)]
    if {[lindex $has_times $rpt_menu_value($box)] == 0} {
	foreach i {day.workaround time.workaround duration.workaround} {
	    $win.$i configure -state disabled
	}
	foreach i {l l1 l2 } {
	    $win.$i configure -fg [option get . disabledForeground Sdr]
	}
    } else {
	foreach i {day.workaround time.workaround duration.workaround} {
	    $win.$i configure -state normal
	}
	foreach i {l l1 l2 } {
	    $win.$i configure -fg [option get . foreground Sdr]
	}
	set [set win].duration(duration_max) [lindex $duration_max $rpt_menu_value($box)]
    }
}

proc configure_duration_box {win no_of_boxes} {
    global rpt_menu_value needs_lifetime rpt_min_values
    set flag 0
    set duration 0
    for {set i 1} {$i<=$no_of_boxes} {incr i} {
	set flag [expr $flag + [lindex $needs_lifetime $rpt_menu_value($i)]]
	if {[lindex $rpt_min_values $rpt_menu_value($i)]> $duration} {
	    set duration [lindex $rpt_min_values $rpt_menu_value($i)]
	}
    }
    if {$flag==0} {
	$win.duration.workaround configure -state disabled
	$win.l configure -foreground [option get . disabledForeground Sdr]
    } else {
	$win.duration.workaround configure -state normal 
	$win.duration.workaround set $duration
	$win.duration.workaround minval $duration
	$win.l configure -foreground [option get . foreground Sdr]
   }
}

proc get_expiry_time {basewin ix durationwin} {
    global rpt_menu_value needs_lifetime has_times
    set dayix [$basewin.day.workaround get]
    set timeofday [$basewin.time.workaround get]
    set duration [expr [$basewin.duration.workaround get]*60]
    set rval $rpt_menu_value($ix)
    set durationmod [expr [lindex $needs_lifetime $rval] * [$durationwin.workaround get] * 60]
    set starttime [expr [lindex $has_times $rval]*[unix_to_ntp [expr $timeofday+($dayix*86400)]]]
    set stoptime [expr [lindex $has_times $rval]*[expr $starttime + $duration + $durationmod]]
    case $rval {
	0 { set rpt_str "0 0 0" }
	1 { set rpt_str "0 $duration 0"}
	2 { set rpt_str "86400 $duration 0"}
	3 { set rpt_str "604800 $duration 0"}
	4 { set rpt_str "1209600 $duration 0"}
	5 { set rpt_str "0 0 0"}
        6 { set rpt_str "604800 $duration 0 86400 172800 259200 345600"}
    }
    return "$starttime $stoptime $rpt_str"
}

proc create_menu {mname mlist defattrlist media mode} {
    global media_attr
    if {$mode=="create"} {
	menu $mname -tearoff 0
    } else {
	#delete old menus if we're using this to modify a menu
	if {[$mname index end]!="none"} {
	    for {set i 0} {$i <= [$mname index end]} {incr i} {
#		puts "$i [$mname index end]"
		catch {destroy [$mname entrycget $i -menu]}
	    }
	    $mname delete 0 end
	}
    }

    #parse the default attributes for this media/protocol/format
    foreach defattr $defattrlist {
	set tmpattr [lindex [split $defattr ":"] 0]
	set tmpvalue [lindex [split $defattr ":"] 1]
	catch {set tmpvalue $media_attr($media,$tmpattr)}
	set media_attr($media,$tmpattr) $tmpvalue
    }

    #parse the list of attributes this media had last time (empty string if new announcement)
#    foreach attr [array names media_attr] {
#	set tmpmedia [lindex [split $attr ','] 0]
#	set tmpattr [lindex [split $attr ','] 1]
#	if {$tmpmedia==$media} {
#	    if {$tmpattr==""} {
#		set pitem($tmpattr) 1
#	    } else {
#		set pitem($tmpattr) $media_attr($attr)
#	    }
#	}
#    }


#    set previtems [split $mediavars ',']
#    foreach previtem $previtems {
#	set pitemlist [split $previtem ':']
#	if {[llength $pitemlist]==1} {
#	    set pitem([lindex $pitemlist 0]) 1
#	} else {
#	    set pitem([lindex $pitemlist 0]) [lindex $pitemlist 1]
#	}
#    }

    #now create the menus with the above data
#    puts $mlist
    set mitems [split $mlist "\n"]
    foreach item $mitems {
	set itemlist [split $item ':']
	set itemname [lindex $itemlist 0]
        set itemlist [lindex $itemlist 1]
        set code [catch {set media_attr($media,$itemname)}]
	if {$code==1} {set media_attr($media,$itemname) ""}
	if {[llength $itemlist]<=1} {
	    $mname add checkbutton -label [get_attr_name $itemname] \
		-variable media_attr\($media,$itemname\) \
		-command "mtk_ImbUnpost {}"
#	    set media_attr($media,$itemname) $pitem($itemname)
	} else {
	    $mname add cascade -label [get_attr_name $itemname] \
		-menu $mname.$itemname -command "mtk_ImbUnpost {}"
	    menu $mname.$itemname -tearoff 0
	    foreach subitem $itemlist {
		$mname.$itemname add radiobutton \
		    -label [get_attrvalue_name $itemname $subitem] \
		    -variable media_attr\($media,$itemname\) \
		    -value $subitem -command "mtk_ImbUnpost {}"
#		set media_attr($media,$itemname) $pitem($itemname)
	    }
	}
    }
}
proc create_fmt_menu {win mname layersmname proto fmtlist media} {
    menu $mname.menu -tearoff 0
    foreach item $fmtlist {
	$mname.menu add radiobutton -label [get_fmt_name $item] \
	    -variable media_fmt\($media\) \
	    -value $item \
	    -command "reset_media_attrs;\
                      $mname configure -text \[get_fmt_name $item\];\
		      set_layers_menu $win $layersmname $media \
		          [get_max_layers $media $proto $item];\
                      setmediamode $media $win 1 0"
    }
}

proc set_fmt_menu {win mname layersmname proto fmtlist media} {
    global media_fmt
    $mname.menu delete 0 end
    foreach item $fmtlist {
	$mname.menu add radiobutton -label [get_fmt_name $item] \
	    -variable media_fmt\($media\) \
	    -value $item \
	    -command "reset_media_attrs;\
                      $mname configure -text \[get_fmt_name $item\];\
		      set_layers_menu $win $layersmname $media \
		          [get_max_layers $media $proto $item];\
                      setmediamode $media $win 1 0"
    }
    set media_fmt($media) [lindex $fmtlist 0]
}

proc create_proto_menu {win mname layersmname fmtmname fmtlist media} {
    menu $mname.menu -tearoff 0
    foreach item $fmtlist {
	$mname.menu add radiobutton -label [get_proto_name $item] \
	    -variable media_proto\($media\) \
	    -value $item \
	    -command "reset_media_attrs;\
                      $mname configure -text \[get_proto_name $item\];\
                      set_fmt_menu $win $layersmname $item $fmtmname \
                         \[get_media_fmts $media $item\] $media;\
                      setmediamode $media $win 1 0"
    }
}

proc create_layers_menu {win mname media} {
    menu $mname.menu -tearoff 0
    foreach item {1 2 3 4} {
	$mname.menu add radiobutton -label $item \
	    -variable media_layers\($media\) \
	    -value $item \
	    -command "$mname configure -text $item"
    }
}

proc set_layers_menu {win mname media layers} {
    global media_layers
    $mname.menu delete 0 end
    for {set item 1} {$item <= $layers} {incr item} {
	$mname.menu add radiobutton -label $item \
            -variable media_layers\($media\) \
            -value $item \
            -command "$mname configure -text $item"
    }
    $mname configure -text $layers
    set media_layers($media) $layers
}

proc reset_media_attrs {} {
    global media_attr
    foreach attr [array names media_attr] {
	unset media_attr($attr)
    }
}
#proc paste_buffer {w} {
#    set ipos [$w index insert]
#    $w insert $ipos [selection get]
#    set str [$w get 1.0 end]
#    $w delete 1.0 end
#    $w insert 1.0 [text_wrap $str 40]
#}

proc create {} {
    global ttl dayix durationix send zone
    global timeofday minoffset hroffset media_attr media_fmt media_proto
    global media_layers medialist new_createtime sess_type
    global rtp_payload sdrversion security
    log "creating a session"
    if {$ttl==0} { set ttl [.new.f3.rr.f.e get] }
    if {($ttl < 0)|($ttl > 255)} {
	errorpopup "Illegal Scope Value" "Scope value must be between 0 and 255"
	log "user had entered an illegal scope value"
	return
    }
    set sess "v=0"
    set sess "$sess\no=[getusername] $new_createtime [unix_to_ntp [gettimeofday]] IN IP4 [gethostname]"
    set sess "$sess\ns=[get_new_session_name .new]"
    if {[get_new_session_name .new]==""} {
	errorpopup "No Session Name" "You must give the session a name"
	log "user had entered no session name"
	return 0
    }

    if {[get_new_session_desc]==""} {
	errorpopup "No Session Description" "You must give some description of your session"
	log "user had entered no session description"
	return 0
    }

    set desc [get_new_session_desc]
    regsub -all "\n" $desc " " desc
    set sess "$sess\ni=$desc"
    set uri [get_new_session_uri]
    if {$uri!=""} {
	set sess "$sess\nu=$uri"
    }
    set email [.new.you.f0.e get]
    set phone [.new.you.f1.e get]
    if {$email!=""} {
	set sess "$sess\ne=$email"
    }
    if {$phone!=""} {
	set sess "$sess\np=$phone"
    }

    foreach i {1 2 3} {
      #the catch is here because the simple i/f only has one time entry
      catch {
	set tmp [get_expiry_time .new.f2.act.fb$i $i .new.f2.act.fd.duration]
	    if {[lindex $tmp 0]!=0} {
	    set starttime [lindex $tmp 0]
	    set stoptime [lindex $tmp 1]
	    set sess "$sess\nt=[format %u $starttime] [format %u $stoptime]"
            if {[lindex $tmp 2]!=0} {
		set sess "$sess\nr=[lrange $tmp 2 end]"
	    }
	}
      }
    }
    if {[valid_mcast_address [get_new_session_addr conference]]==0} {
	errorpopup "Invalid Multicast Address" \
	    "The multicast address specified in not a valid IP Class D address"
	log "user had entered an invalid multicast address"
	return 0
    }
    set sess "$sess\na=tool:sdr $sdrversion"
    set sess "$sess\na=type:$sess_type"
    foreach media $medialist {
	if {$send($media)==1} {
	    if {([get_new_session_port $media]<1024)|([get_new_session_port $media]>65535)} {
		errorpopup "Bad $media port number" \
		    [tt "Port numbers should be between 1024 and 65535"]
		log "user had entered a bad port number"
		return 0
	    }
	    if {$media_proto($media)=="rtp"} {
		set sess "$sess\nm=$media [get_new_session_port $media] RTP/AVP $rtp_payload(pt:$media_fmt($media))"
	    } else {
		set sess "$sess\nm=$media [get_new_session_port $media] $media_proto($media) $media_fmt($media)"
	    }
	    set sess "$sess\nc=IN IP4 [get_new_session_addr $media]/$ttl"
	    if {$media_layers($media)>1} {
		set sess "$sess/$media_layers($media)"
	    }
	    foreach attr [array names media_attr] {
		set m [lindex [split $attr ","] 0]
		set a [lindex [split $attr ","] 1]
		if {$m==$media} {
		    if {$media_attr($attr)==1} {
			set sess "$sess\na=$a"
		    } elseif {($media_attr($attr)!=0)&&\
			($media_attr($attr)!="")} {
			    set sess "$sess\na=$a:$media_attr($attr)"
			}
		}
	    }
	} 
    }
#    puts "$sess send to $zone(sd_addr,$zone(cur_zone)) $zone(sd_port,$zone(cur_zone)) $ttl"
    if {[info exists security]&&($security == "private")} {
	set keyname [string trim [get_new_session_key] "\n"]
	if {$keyname==0} {return 0};
	log "new session was encrypted"
    } else {
	set keyname ""
	log "new session was not encrypted"
    }
    createsession "$sess\n" [ntp_to_unix $stoptime] $zone(sd_addr,$zone(cur_zone)) $zone(sd_port,$zone(cur_zone)) $ttl $keyname
    update
    after 3000 write_cache
    log "new session announced at [getreadabletime]"
    return 1
}

proc togglemedia {win media} {
    global send
    if {$send($media) == 0} {
        setmediamode $media $win 1 1
    } else {
        setmediamode $media $win 0 1
    }
}


#############
#setmediamode is used to set a line of media widgets to active or inactive
#
#$media is typically "audio", "video", "whiteboard" or "text"
#$state is 0 (media is inactive) or 1 (media is active)
#$mediabase is the base of the media frame.
#############
proc setmediamode {media mediabase state realloc} {
    global send media_fmt media_proto media_attr media_layers
    global zone scope defattrlist
    set base $mediabase.$media
    set send($media) $state
    if {$state==0} {
	$base.cb configure -bitmap cross -foreground red

	$base.fmt configure -text " " -state disabled -relief groove
	#I thought -state disabled would do this but no....
	bind $base.fmt <ButtonRelease> { break }

	$base.proto configure -text " " -state disabled -relief groove
	bind $base.proto <ButtonRelease> { break }

	$base.addr  delete 0 end
	$base.addr configure -bg [option get . background Sdr] \
	    -relief groove -state disabled

	$base.layers configure -text " " -state disabled -relief groove

	$base.port  delete 0 end
	$base.port configure -bg [option get . background Sdr] \
	    -relief groove -state disabled

	$base.mb.workaround configure -relief groove -state disabled
	set media_fmt($media) [lindex [get_media_fmts $media $media_proto($media)] 0]
	set media_proto($media) [lindex [get_media_protos $media] 0]
    } else {
	if {[string compare $media_proto($media) ""]==0} {
	    msgpopup "No tool installed" "You have no tool installed that could participate in a session with this media"
	    set send($media) 0
	    return 0
	}
	$base.cb configure -bitmap tick -foreground green4

	$base.fmt configure -text [get_fmt_name $media_fmt($media)] -state normal \
	     -relief raised
	bind $base.fmt <ButtonRelease> "tkMbButtonUp $base.fmt"

	$base.proto configure -text [get_proto_name $media_proto($media)] \
	    -state normal -relief raised
	bind $base.proto <ButtonRelease> "tkMbButtonUp $base.proto"

	if {$media_layers($media)==1} {
	    $base.layers configure -text $media_layers($media) \
		    -state disabled -relief groove
	} else {
	    $base.layers configure -text $media_layers($media) \
		    -state normal -relief raised
	}

	$base.addr configure -bg [option get . entryBackground Sdr] \
	     -state normal -relief sunken

	$base.port configure -bg [option get . entryBackground Sdr] \
	    -relief sunken -state normal

	if {$realloc==1} {
	    $base.addr delete 0 end
	    if {$scope=="admin"} {
		$base.addr insert 0 [generate_address $zone(base_addr,$zone(cur_zone)) $zone(netmask,$zone(cur_zone))]
	    } else {
		$base.addr insert 0 [generate_address]
	    }
	    $base.port delete 0 end
	    $base.port insert 0 [generate_port $media]
	}

	set attrlist "[get_proto_attrs $media $media_proto($media)] [get_fmt_attrs $media $media_proto($media) $media_fmt($media)]"
#	puts $attrlist
	set attrlist [fix_up_attr_list $attrlist]
#	puts "fmt: $media_fmt($media)"
	create_menu $base.mb.menu $attrlist $defattrlist($media.$media_proto($media).$media_fmt($media)) $media change

	$base.mb.workaround configure -relief raised -state normal
    }
}

proc fix_up_attr_list {origattrlist} {
    #takes an attrlist in the form "attr1:value attr1:value2 attr2:value3"
    #and forms an attrlist in the form "attr1:value1 value2\nattr2:value3"
    #this is needed because we merge protocol and format attrs and they
    #may have the same attributes
    set mainattrs {}
    foreach attr $origattrlist {
	set key [lindex [split $attr ":"] 0]
	set value [lindex [split $attr ":"] 1]
	if {[lsearch $mainattrs $key]==-1} {
	    set mainattrs "$mainattrs $key"
	    set values($key) \{$value\}
	} else {
	    if {[lsearch $values($key) $value]==-1} {
		set values($key) "$values($key) \{$value\}"
	    }
	}
    }
    set newattrlist ""
    foreach key $mainattrs {
	if {$newattrlist==""} {
	    set newattrlist $key
	} else {
	    set newattrlist "$newattrlist\n$key"
	}
	if {$values($key)!=""} {
	    set newattrlist "$newattrlist:$values($key)"
	}
    }
    return $newattrlist
}

proc setmediaflags {media win aid} {
    global ldata media_fmt media_proto media_layers
    set base $win.$media
    for {set mnum 0} {$mnum<$ldata($aid,medianum)} {incr mnum} {
	if {$ldata($aid,$mnum,media)==$media} {
	    $base.proto configure -text \
		[get_proto_name $ldata($aid,$mnum,proto)]
	    set media_proto($media) $ldata($aid,$mnum,proto)
	    $base.fmt configure -text [get_fmt_name $ldata($aid,$mnum,fmt)]
	    set media_fmt($media) $ldata($aid,$mnum,fmt)
	    set media_layers($media) $ldata($aid,$mnum,layers)
	    $base.port delete 0 end
	    $base.port insert 0 $ldata($aid,$mnum,port)
	    $base.addr delete 0 end
	    $base.addr insert 0 $ldata($aid,$mnum,addr)
	    return 0
	}
    }
}


proc generate_address {args} {
    global zone
    if {[llength $args]==0} {
	return [ui_generate_address]
    } elseif {[llength $args]==2} {
	return [eval "ui_generate_address $args"]
    } elseif {([llength $args]==3)||([llength $args]==1)} {
	if {([llength $args]==3)} {
	    set baseaddr [lindex $args 0]
	    set netmask [lindex $args 1]
	    set aid [lindex $args 2]
	} else {
	    set z $zone(ttl_scope)
	    set baseaddr $zone(base_addr,$z)
	    set netmask $zone(netmask,$z)
	    set aid [lindex $args 0]
	}
	if {[string compare $aid "new"]==0} {
	    return [ui_generate_address $baseaddr $netmask]
	} else {
	    #we check if we really need to generate a new address or
	    #if the old one is still OK...
	    global ldata
	    set pa [split $ldata($aid,tmpmulticast) "."]
	    #it's simpler to subtract 224 from the msb than fix Tcl's 
	    #concept of what's positive and what's negative...
	    set paddr [expr ((((((([lindex $pa 0]-224)*256)\
				 +[lindex $pa 1])*256)\
				     +[lindex $pa 2])*256)\
				     +[lindex $pa 3])]
	    set ba [split $baseaddr "."]
	    set baddr [expr ((((((([lindex $ba 0]-224)*256)\
				 +[lindex $ba 1])*256)\
				     +[lindex $ba 2])*256)\
				     +[lindex $ba 3])]
	    set paddr [expr $paddr >> (32-$netmask)]
	    set baddr [expr $baddr >> (32-$netmask)]
	    if {$paddr==$baddr} {
		#we don't really need to generate a new address in 
		#these circumstances, so don't do so (avoid confusion).
		return 1
	    } else {
		#should really warn the user when we have to do this
		toplevel .warn
		wm title .warn "Sdr: [tt "Warning"]"
		frame .warn.f -borderwidth 2 -relief groove
		pack .warn.f -side top -fill both
		message .warn.f.msg -aspect 400 -text \
		    [tt "To make this scope change I need to allocate new multicast addresses.\n\nThis means that anyone who is already using this annoucement will need to restart their applications\n\nIs this OK?"]
		pack .warn.f.msg -side top -fill x -expand true
		frame .warn.f.f -borderwidth 0
		pack .warn.f.f -side top -fill x -expand true
		button .warn.f.ok -text [tt "OK"] -command \
		    "set ldata($aid,tmpmulticast2) \
                    \[ui_generate_address $baseaddr $netmask\];\
                    destroy .warn"
		pack .warn.f.ok -side left -fill x -expand true
		button .warn.f.cancel -text [tt "Cancel"] -command \
		    "set ldata($aid,tmpmulticast2) 0;
		    destroy .warn"
		pack .warn.f.cancel -side left -fill x -expand true
		tkwait visibility .warn
		grab set .warn
		tkwait window .warn
		if {$ldata($aid,tmpmulticast2)==0} {
		    unset ldata($aid,tmpmulticast2)
		    return 0
		} else {
		    set ldata($aid,tmpmulticast) $ldata($aid,tmpmulticast2)
		    unset ldata($aid,tmpmulticast2)
		    return $ldata($aid,tmpmulticast)
		}
	    }
	}
    }
}

proc generate_port {media} {
    ui_generate_port $media
}
