#new.tcl Copyright (c) 1995 University College London
#see ui_fns.c for information on usage and redistribution of this file
#and for a DISCLAIMER OF ALL WARRANTIES.

#If you need to add more panels, create a function called 
#new_wiz_panel_XYZ, and add XYZ to these lists in the order you want it
#called.
set new_wiz_norm_panels \
	"info type timing_norm scope_norm media_norm contact accept"
set new_wiz_tech_panels \
	"info type timing_tech scope_tech media_tech contact accept"

proc new {aid {w .w0}} {
    global ifstyle ldata
    if {[string compare $aid "new"]!=0} {
	#we need a working variable while we think about editing sessions,
	#in case we don't commit the changes.
	set ldata($aid,tmpmulticast) $ldata($aid,multicast)
    }
 
    # Hack to handle multiple directory windows:
    # Temporarily change the available 'zones' to those that are
    # appropriate for creating a new session in this directory:
    global zone savedZoneData zoneDataForWindow
    set savedZoneData [array get zone]
    array set zone $zoneDataForWindow($w)
 
    new_wiz_init $aid $ifstyle(create)
}

proc cleanup_after_new {} {
    destroy .new

    # Restore the original zone data:
    global zone savedZoneData
    catch {array set zone $savedZoneData}
}

proc new_wiz_init {aid iftype} {
    global new_wiz_norm_panels new_wiz_tech_panels 
    global send new_sessid medialist ldata
    catch {destroy .new}
    sdr_toplevel .new "Session Creation Wizard" "Session Creation"

    frame .new.f -borderwidth 2 -relief groove
    pack .new.f -side top -fill both -expand true
    label .new.f.l -text ""
    pack .new.f.l -side top -fill x
    text .new.f.t -width 80 -height 5 -relief flat -highlightthickness 0 \
	    -wrap word
    pack .new.f.t -side top 
    frame .new.f.f -borderwidth 2 -relief groove
    pack .new.f.f -side top -fill x
    frame .new.f.f.spacer -width 1 -height 200 -borderwidth 0
    pack .new.f.f.spacer -side right
    frame .new.f.b -borderwidth 2 -relief groove
    pack .new.f.b -side top -fill x
    button .new.f.b.back -text "<< Back" -command "" -relief raised \
	    -borderwidth 1 -highlightthickness 0 -state disabled
    pack .new.f.b.back -side left -fill x    -expand true
    button .new.f.b.next -text "Next >>" -command "" -relief raised \
	    -borderwidth 1 -highlightthickness 0 -state disabled
    pack .new.f.b.next -side left -fill x    -expand true
    button .new.f.b.accept -text "Accept" \
	    -relief raised \
	    -borderwidth 1 -highlightthickness 0
    pack .new.f.b.accept -side left -fill x    -expand true
    button .new.f.b.cancel -text "Cancel" -command {cleanup_after_new} \
	    -relief raised \
	    -borderwidth 1 -highlightthickness 0
    pack .new.f.b.cancel -side left -fill x    -expand true

    if {[string compare $aid "new"]!=0} {
	wm title .new "Sdr: [tt "Edit Session"]"
	wm iconname .new "Sdr: [tt "Edit Session"]"
	foreach i $medialist {
            set send($i) 0
        }
  	set new_sessid $ldata($aid,sessid)
    } else {
	wm title .new "Sdr: [tt "Create New Session"]"
	wm iconname .new "Sdr: [tt "Create New Session"]"
	foreach i $medialist {
	    set send($i) 0
	}
	set send(audio) 1
	set new_sessid [unix_to_ntp [gettimeofday]]
    }
    
    if {$iftype=="tech"} {
	eval "new_wiz_panel_[lindex $new_wiz_tech_panels 0] 0 \"$new_wiz_tech_panels\" $aid"
    } else {
	eval "new_wiz_panel_[lindex $new_wiz_norm_panels 0] 0 \"$new_wiz_norm_panels\" $aid"
    }
}

proc new_wiz_change_panels {} {
    .new.f.t configure -state normal
    .new.f.t delete 1.0 end
    set children [winfo children .new.f.f]
    foreach child $children {
	pack unpack $child
    }
    pack .new.f.f.spacer -side right
}

proc new_wiz_panel_info {panelnum panels aid} {
    new_wiz_change_panels
    .new.f.l configure -text "Step $panelnum: Information About the Session"
    .new.f.t insert 1.0 "You need to give a title to your session and provide information about it.  The information should be a paragraph or so describing the purpose of the session.  If you need to refer people to more information, add a URL below.  The URL can be left blank, but the title and information must be given.  When you've filled in this information, click on Next."
    set next_panel [expr $panelnum + 1]
    .new.f.t configure -state disabled
    .new.f.b.next configure -state normal -command "new_wiz_panel_[lindex $panels $next_panel] $next_panel \"$panels\" $aid"
    .new.f.b.back configure -state disabled
    .new.f.b.accept configure -state disabled
    new_mk_session_name .new.f.f $aid
    new_mk_session_desc .new.f.f $aid
    new_mk_session_url .new.f.f $aid
}

proc new_wiz_panel_type {panelnum panels aid} {
    new_wiz_change_panels
    .new.f.l configure -text "Step $panelnum: What Type of Session is this?"
    .new.f.t insert 1.0 "You need to specify the type of session.  Use \"broadcast\" for sessions that are largely non-interactive, \"meeting\" for interactive sessions and private meetings, and \"test\" for anything that isn't intended for real listeners."
    .new.f.t configure -state disabled
    set next_panel [expr $panelnum + 1]
    set back_panel [expr $panelnum - 1]
    .new.f.b.next configure -state normal -command "new_wiz_panel_[lindex $panels $next_panel] $next_panel \"$panels\" $aid"
    .new.f.b.back configure -state normal -command "new_wiz_panel_[lindex $panels $back_panel] $back_panel \"$panels\" $aid"
    .new.f.b.accept configure -state disabled    
    new_mk_session_type .new.f.f.type top $aid
}

proc new_wiz_panel_timing_norm {panelnum panels aid} {
    global ldata
    new_wiz_change_panels
    .new.f.l configure -text "Step $panelnum: When will the session be active?"
    .new.f.t insert 1.0 "You need to configure when the session will be active so people will know when to join it.  For example, if the session is active on Monday and Thursday each week for four weeks, configure Monday's start time and duration in the first row, Thursday's start time and duration in the second row, set both to be \"Weekly\" and configure \"Repeat for\" to be \"4 weeks\"."
    .new.f.t configure -state disabled
    set next_panel [expr $panelnum + 1]
    set back_panel [expr $panelnum - 1]
    .new.f.b.next configure -state normal -command "new_wiz_panel_[lindex $panels $next_panel] $next_panel \"$panels\" $aid"
    .new.f.b.back configure -state normal -command "new_wiz_panel_[lindex $panels $back_panel] $back_panel \"$panels\" $aid"

    if {[winfo exists .new.f.f.f2]==0} {
	frame .new.f.f.f2
	frame .new.f.f.f2.act -relief groove -borderwidth 2
	frame .new.f.f.f2.act.l
	label .new.f.f.f2.act.l.icon -bitmap clock
	label .new.f.f.f2.act.l.l -text "Session will take place ..." 
	tixAddBalloon .new.f.f.f2.act.l.l Label [tt "When and how often is the session going to be on"]

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
		new_mk_session_time_box .new.f.f.f2.act $box $ldata($aid,no_of_times) $rpt_times $menu_disabled
	    }
	} else {
	    set rpt_menu_value(1) 1
	    new_mk_session_time_box .new.f.f.f2.act 1 1 $rpt_times $menu_disabled
	}

	label .new.f.f.f2.act.expl2 -text [tt "Length of this series of sessions"] \
		-font [resource infoFont]
	frame .new.f.f.f2.act.fd
	label .new.f.f.f2.act.fd.l -text [tt "Repeat for:"]
	duration_widget .new.f.f.f2.act.fd.duration 3600
	if {[string compare $aid "new"]!=0} {
	    configure_duration_box .new.f.f.f2.act.fd $ldata($aid,no_of_times)
	} else {
	    configure_duration_box .new.f.f.f2.act.fd 1
	}
	if {[string compare $aid "new"]!=0} {
	    set rpts 0
	    set maxdiff 0
	    for {set t 0} {$t < $ldata($aid,no_of_times)} {incr t} {
		if {$ldata($aid,time$t,no_of_rpts)==0} {
		    .new.f.f.f2.act.fb[expr $t+1].day.workaround configure \
			    -time $ldata($aid,starttime,$t)		
		    .new.f.f.f2.act.fb[expr $t+1].time.workaround configure \
			    -time $ldata($aid,starttime,$t)
		    .new.f.f.f2.act.fb[expr $t+1].duration.workaround configure -time \
			    [expr $ldata($aid,endtime,$t) - $ldata($aid,starttime,$t)]
		    set rpt_menu_value([expr $t+1]) 1
		    configure_rpt_menu [expr $t+1] .new.f.f.f2.act.fb[expr $t+1]
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
			.new.f.f.f2.act.fb[expr $t+1].day.workaround configure -time $start
			.new.f.f.f2.act.fb[expr $t+1].time.workaround configure -time $start
			.new.f.f.f2.act.fb[expr $t+1].duration.workaround configure -time $dur
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
			configure_rpt_menu [expr $t+1] .new.f.f.f2.act.fb[expr $t+1]
		    }
		}
	    }
	    if {$rpts==1} {
		.new.f.f.f2.act.fd.duration.workaround configure -time $maxdiff
		.new.f.f.f2.act.fd.duration.workaround configure -state normal
	    }
	}
    }
    pack .new.f.f.f2 -side top -pady 5 -fill x -expand true
    pack .new.f.f.f2.act -side left -fill both -expand true
    pack .new.f.f.f2.act.l -side top -anchor w
    pack .new.f.f.f2.act.l.icon -side left
    pack .new.f.f.f2.act.l.l -side left
    pack .new.f.f.f2.act.expl2 -side top -anchor w
    pack .new.f.f.f2.act.fd -side top -anchor w
    pack .new.f.f.f2.act.fd.l -side left -anchor w
}
proc new_wiz_panel_timing_tech {panelnum panels aid} {
    global ldata
    new_wiz_change_panels
    .new.f.l configure -text "Step $panelnum: When will the session be active?"
    .new.f.t insert 1.0 "You need to configure when the session will be active so people will know when to join it.  For example, if the session is active on Monday and Thursday each week for four weeks, configure Monday's start time and duration in the first row, Thursday's start time and duration in the second row, set both to be \"Weekly\" and configure \"Repeat for\" to be \"4 weeks\"."
    .new.f.t configure -state disabled
    set next_panel [expr $panelnum + 1]
    set back_panel [expr $panelnum - 1]
    .new.f.b.next configure -state normal -command "new_wiz_panel_[lindex $panels $next_panel] $next_panel \"$panels\" $aid"
    .new.f.b.back configure -state normal -command "new_wiz_panel_[lindex $panels $back_panel] $back_panel \"$panels\" $aid"
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

    if {[winfo exists .new.f.f.f2]==0} {
	frame .new.f.f.f2
	label .new.f.f.f2.l -text "Session will be active:"
	frame .new.f.f.f2.act -relief groove -borderwidth 2
	foreach box {1 2 3} {
	    new_mk_session_time_box .new.f.f.f2.act $box 3 $rpt_times $menu_disabled
	}
	frame .new.f.f.f2.act.fd
	label .new.f.f.f2.act.fd.l -text "Repeat for:"
	duration_widget .new.f.f.f2.act.fd.duration 3600
	configure_duration_box .new.f.f.f2.act.fd 3
	if {[string compare $aid "new"]!=0} {
	    set rpts 0
	    set maxdiff 0
	    for {set t 0} {$t < $ldata($aid,no_of_times)} {incr t} {
		if {$ldata($aid,time$t,no_of_rpts)==0} {
		    .new.f.f.f2.act.fb[expr $t+1].day.workaround configure \
			    -time $ldata($aid,starttime,$t)		
		    .new.f.f.f2.act.fb[expr $t+1].time.workaround configure \
			    -time $ldata($aid,starttime,$t)
		    .new.f.f.f2.act.fb[expr $t+1].duration.workaround configure -time \
			    [expr $ldata($aid,endtime,$t) - $ldata($aid,starttime,$t)]
		    set rpt_menu_value([expr $t+1]) 1
		    configure_rpt_menu [expr $t+1] .new.f.f.f2.act.fb[expr $t+1]
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
			.new.f.f.f2.act.fb[expr $t+1].day.workaround configure -time $start
			.new.f.f.f2.act.fb[expr $t+1].time.workaround configure -time $start
			.new.f.f.f2.act.fb[expr $t+1].duration.workaround configure -time $dur
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
			configure_rpt_menu [expr $t+1] .new.f.f.f2.act.fb[expr $t+1]
		    }
		}
	    }
	    if {$rpts==1} {
		.new.f.f.f2.act.fd.duration.workaround configure -time $maxdiff
		.new.f.f.f2.act.fd.duration.workaround configure -state normal
	    }
	}
    }
    pack .new.f.f.f2 -side top
    pack .new.f.f.f2.l -side top
    pack .new.f.f.f2.act -side left -fill both -expand true
    pack .new.f.f.f2.act.fd -side top -anchor w
    pack .new.f.f.f2.act.fd.l -side left -anchor w
}

proc new_wiz_panel_scope_norm {panelnum panels aid} {
    new_wiz_change_panels
    .new.f.l configure -text "Step $panelnum: Select the Distribution Scope"
    .new.f.t insert 1.0 "You need to decide how far away you wish the traffic from this session to be received.  You can set this using TTL scoping or Admin Scoping.  TTL Scoping is the old method - we recommend Admin Scoping."
    .new.f.t configure -state disabled
    set next_panel [expr $panelnum + 1]
    set back_panel [expr $panelnum - 1]
    .new.f.b.next configure -state normal -command "new_wiz_panel_[lindex $panels $next_panel] $next_panel \"$panels\" $aid"
    .new.f.b.back configure -state normal -command "new_wiz_panel_[lindex $panels $back_panel] $back_panel \"$panels\" $aid"
    .new.f.b.accept configure -state disabled
    new_mk_session_norm_scope .new.f.f $aid
}

proc new_wiz_panel_scope_tech {panelnum panels aid} {
    new_wiz_change_panels
    .new.f.l configure -text "Step $panelnum: Select the Distribution Scope"
    .new.f.t insert 1.0 "You need to decide how far away you wish the traffic from this session to be received.  You can set this using TTL scoping or Admin Scoping.  TTL Scoping is the old method - we recommend Admin Scoping."
    .new.f.t configure -state disabled
    set next_panel [expr $panelnum + 1]
    set back_panel [expr $panelnum - 1]
    .new.f.b.next configure -state normal -command "new_wiz_panel_[lindex $panels $next_panel] $next_panel \"$panels\" $aid"
    .new.f.b.back configure -state normal -command "new_wiz_panel_[lindex $panels $back_panel] $back_panel \"$panels\" $aid"
    .new.f.b.accept configure -state disabled
    new_mk_session_tech_scope .new.f.f $aid
}

proc new_wiz_panel_media_norm {panelnum panels aid} {
    global scope
    new_wiz_change_panels
    .new.f.l configure -text "Step $panelnum: Choose and configure the media?"
    .new.f.t insert 1.0 "You need to decide which media the session will use.  For each medium, you need to choose the protocol and format.  Some formats also let you choose the number of layers in the encoding."
    .new.f.t configure -state disabled
    set next_panel [expr $panelnum + 1]
    set back_panel [expr $panelnum - 1]
    .new.f.b.next configure -state normal -command "new_wiz_panel_[lindex $panels $next_panel] $next_panel \"$panels\" $aid"
    .new.f.b.back configure -state normal -command "new_wiz_panel_[lindex $panels $back_panel] $back_panel \"$panels\" $aid"
    set show_details 0
    new_mk_session_media .new.f.f.media $aid $scope $show_details
}

proc new_wiz_panel_media_tech {panelnum panels aid} {
    global scope
    new_wiz_change_panels
    .new.f.l configure -text "Step $panelnum: Choose and configure the media?"
    .new.f.t insert 1.0 "You need to decide which media the session will use.  For each medium, you need to choose the protocol and format.  Some formats also let you choose the number of layers in the encoding."
    .new.f.t configure -state disabled
    set next_panel [expr $panelnum + 1]
    set back_panel [expr $panelnum - 1]
    .new.f.b.next configure -state normal -command "new_wiz_panel_[lindex $panels $next_panel] $next_panel \"$panels\" $aid"
    .new.f.b.back configure -state normal -command "new_wiz_panel_[lindex $panels $back_panel] $back_panel \"$panels\" $aid"
    set show_details 1
    new_mk_session_media .new.f.f.media $aid $scope $show_details
}

proc new_wiz_panel_contact {panelnum panels aid} {
    global scope
    new_wiz_change_panels
    .new.f.l configure -text "Step $panelnum: Provide Contact Details"
    .new.f.t insert 1.0 "You need to provide contact details for the session so that people can get in touch if there is a problem."
    .new.f.t configure -state disabled
    set next_panel [expr $panelnum + 1]
    set back_panel [expr $panelnum - 1]
    .new.f.b.next configure -state normal -command "new_wiz_panel_[lindex $panels $next_panel] $next_panel \"$panels\" $aid"
    .new.f.b.back configure -state normal -command "new_wiz_panel_[lindex $panels $back_panel] $back_panel \"$panels\" $aid"
    .new.f.b.accept configure -state disabled
    new_mk_session_contact .new.f.f.you $aid
}

proc new_wiz_panel_accept {panelnum panels aid} {
    global scope
    new_wiz_change_panels
    .new.f.l configure -text "Review session details"
    .new.f.t insert 1.0 "Check the details below are correct.  If they are correct, press \"Accept\".  If they're incorrect, go back and amend the information.  \"Cancel\" will abort and lose any information you've entered."
    .new.f.t configure -state disabled
    set next_panel [expr $panelnum + 1]
    set back_panel [expr $panelnum - 1]
    .new.f.b.next configure -state disabled
    .new.f.b.accept configure -state normal -command \
	"if {\[create\]==1} \
	  {cleanup_after_new}"
    .new.f.b.back configure -state normal -command "new_wiz_panel_[lindex $panels $back_panel] $back_panel \"$panels\" $aid"
    new_mk_session_accept .new.f.f.accept .new.f.f $aid
}

proc new_mk_session_accept {win base aid} {
    global ldata
    if {[winfo exists $win]==0} {
	frame $win

	frame $win.r1
	pack $win.r1 -side top -anchor w
	label $win.r1.l1 -text "Title:"
	pack $win.r1.l1 -side left
	label $win.r1.l2
	pack $win.r1.l2 -side left
	label $win.r1.l3 -text "Type:"
	pack $win.r1.l3 -side left
	label $win.r1.l4
	pack $win.r1.l4 -side left

	frame $win.r2
	pack $win.r2 -side top -anchor w
	label $win.r2.l1 -text "Description:"
	pack $win.r2.l1 -side left -anchor nw
	text $win.r2.m -width 65 -height 1 -relief flat -borderwidth 1 \
		-highlightthickness 0 
	pack $win.r2.m -side left

	frame $win.r3 
	pack $win.r3 -side top -anchor w
	label $win.r3.l1 -text "URL for more info:"
	pack $win.r3.l1 -side left
	label $win.r3.l2
	pack $win.r3.l2 -side left
	
	frame $win.r4 
	pack $win.r4 -side top -anchor w
	text $win.r4.m -width 80 -height 1 -relief flat -borderwidth 1 \
		-highlightthickness 0
	pack $win.r4.m -side left

	frame $win.r5
	pack $win.r5 -side top -anchor w
        label $win.r5.l1 -text "Email:"
        pack $win.r5.l1 -side left
        label $win.r5.l2
        pack $win.r5.l2 -side left
        label $win.r5.l3 -text "Phone:"
        pack $win.r5.l3 -side left
        label $win.r5.l4
        pack $win.r5.l4 -side left

	frame $win.r6 
	pack $win.r6 -side top -anchor w
	label $win.r6.l1 -text "Session Scope:"
	pack $win.r6.l1 -side left
	label $win.r6.l2
	pack $win.r6.l2 -side left
	
	frame $win.r7 
	pack $win.r7 -side top -anchor w
	text $win.r7.m -width 80 -height 1 -relief flat -borderwidth 1 \
		-highlightthickness 0 -wrap none
	pack $win.r7.m -side left

    }
    pack $win -side top -fill x
    set title [get_new_session_name $base]
    if {$title!=""} {
            $win.r1.l2 configure -text $title \
		    -foreground [option get . foreground Sdr]
    } else {
            $win.r1.l2 configure -text "TITLE MISSING" -foreground red
    }
    global sess_type
    $win.r1.l4 configure -text $sess_type
    set desc [get_new_session_desc]
    if {$desc!=""} {
	set lines [expr 1+[string length $desc]/65]
	$win.r2.m configure -foreground [option get . foreground Sdr] \
		-state normal -height $lines
	$win.r2.m delete 1.0 end
	$win.r2.m insert 1.0 $desc
	$win.r2.m configure -state disabled
    } else {
	$win.r2.m configure -foreground red -state normal
	$win.r2.m delete 1.0 end
	$win.r2.m insert 1.0 "DESCRIPTION MISSING"
	$win.r2.m configure -state disabled
    }
    set url [get_new_session_uri]
    if {$url!=""} {
            $win.r3.l2 configure -text $url
    } else {
            $win.r3.l2 configure -text "no url given"
    }
    set email [.new.f.f.you.f0.e get]
    $win.r5.l2 configure -text $email
    set phone [.new.f.f.you.f1.e get]
    $win.r5.l4 configure -text $phone
    set no_of_times 0
    set ldata(new,starttime) 0
    set ldata(new,endtime) 0
    foreach i {1 2 3} {
	#the catch is here because the simple i/f only has one time entry
	catch {
	    set tmp [get_expiry_time .new.f.f.f2.act.fb$i $i .new.f.f.f2.act.fd.duration]
	    if {[lindex $tmp 0]!=0} {
		set starttime [ntp_to_unix [lindex $tmp 0]]
		set endtime [ntp_to_unix [lindex $tmp 1]]
		set ldata(new,starttime,$no_of_times) $starttime
		set ldata(new,tfrom,$no_of_times) \
			[clock format $starttime -format {%d %b %Y %H:%M %Z}]
		set ldata(new,endtime,$no_of_times) $endtime
		set ldata(new,tto,$no_of_times) \
			[clock format $endtime -format {%d %b %Y %H:%M %Z}]
		if {($starttime < $ldata(new,starttime)) || \
			($ldata(new,starttime)==0)} {
		    set ldata(new,starttime) $starttime
		    set ldata(new,tfrom) test1
		}
		if {($endtime > $ldata(new,endtime)) } {
		    set ldata(new,endtime) $endtime
		    set ldata(new,tto) test2
		}
		
		if {[lindex $tmp 2]!=0} {
		    set ldata(new,time$no_of_times,no_of_rpts) 1
		    set ldata(new,time$no_of_times,interval0) \
			    [lindex $tmp 2]
		    set ldata(new,time$no_of_times,duration0) \
			    [lindex $tmp 3]
		    set ldata(new,time$no_of_times,offset0) \
			    [lindex $tmp 4]
#		    set sess "$sess\nr=[lrange $tmp 2 end]"
		} else {
		    set ldata(new,time$no_of_times,no_of_rpts) 0
		}
		incr no_of_times
	    }
	}
    }
    set ldata(new,no_of_times) $no_of_times
    set timing [text_times_english new]
    regsub -all "\n" $timing " " timing
    set lines [expr 1+[string length $timing]/80]
    $win.r4.m configure -state normal -height $lines
    $win.r4.m delete 1.0 end
    $win.r4.m insert 1.0 $timing
    $win.r4.m configure -state disabled
    global zone scope
    if {$scope=="admin"} {
	$win.r6.l2 configure -text $zone(name,$zone(cur_zone))
    } else {
	$win.r6.l2 configure -text "TTL [get_ttl_scope] scoped"
    }
    set ms "Media:"
    global medialist send media_proto media_fmt media_layers media_attr
    set ctr 1
    foreach media $medialist {
	if {$send($media)==1} {
	    incr ctr
	    set ms "$ms\n  $media:"
	    set ms "$ms proto [get_proto_name $media_proto($media)]"
	    set ms "$ms, fmt [get_fmt_name $media_fmt($media)]"
	    if {$media_layers($media)>1} {
		set ms "$ms, $media_layers($media) layers"
	    }
	    set ms "$ms, [get_new_session_addr $media]/[get_new_session_port $media]"
	    set attrs ""
	    foreach attr [array names media_attr] {
                set m [lindex [split $attr ","] 0]
                set a [lindex [split $attr ","] 1]
                if {$m==$media} {
                    if {$media_attr($attr)==1} {
                        set attrs "$attrs $a"
                    } elseif {($media_attr($attr)!=0)&&\
			    ($media_attr($attr)!="")} {
                            set attrs "$attrs $a:$media_attr($attr)"
		    }
                }
            }
	    set attrs [string trimleft $attrs]
	    if {$attrs!=""} {
		set ms "$ms, $attrs"
	    }
	}
    }

    $win.r7.m configure -state normal -height $ctr
    $win.r7.m delete 1.0 end
    $win.r7.m insert 1.0 $ms
    $win.r7.m configure -state disabled
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
	#secure {
	#    $win.m configure -text Secure
	#}
	other {
	    $win.m configure -text Unspecified
	}
    }
}

proc new_mk_session_norm_scope {win aid} {
    global zone scope ldata ttl
    if {[winfo exists $win.f3]==0} {
	if {[string compare $aid "new"]!=0} {
	    set sap_addr $ldata($aid,sap_addr)
	    set ttl $ldata($aid,ttl)
	    set scope ttl
	    set zone(cur_zone) $zone(ttl_scope)
	    for {set i 0} {$i<$zone(no_of_zones)} {incr i} {
		#	    puts "$zone(sap_addr,$i)==$sap_addr)&&($zone(ttl,$i)==$ttl)"
		if {($zone(sap_addr,$i)==$sap_addr)&&($zone(ttl,$i)==$ttl)} {
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

	frame $win.f3
	frame $win.f3.m -width 1 -height 1
	frame $win.f3.m2 -width 1 -height 1
    }
    pack $win.f3 -side top -pady 5
    pack $win.f3.m -side left -fill y -padx 3
    pack $win.f3.m2 -side left -fill y -padx 3

    new_mk_session_admin $win.f3.admin $aid $scope
}

proc new_mk_session_tech_scope {win aid} {
    global zone scope ldata medialist send ttl
    if {[winfo exists $win.f3]==0} {
	if {[string compare $aid "new"]!=0} {
	    set sap_addr $ldata($aid,sap_addr)
	    set ttl $ldata($aid,ttl)
	    set scope ttl
	    set zone(cur_zone) $zone(ttl_scope)
	    for {set i 0} {$i<$zone(no_of_zones)} {incr i} {
		if {($zone(sap_addr,$i)==$sap_addr)&&($zone(ttl,$i)==$ttl)} {
		    set scope admin
		    set zone(cur_zone) $i
		    break
		}
	    }
	    for {set mnum 0} {$mnum < $ldata($aid,medianum)} {incr mnum} {
		set send($ldata($aid,$mnum,media)) 1
	    }
	} else {
	    set scope admin
	    set zone(cur_zone) 0
	    set ttl $zone(ttl,$zone(cur_zone))
	}
	frame $win.f3
	frame $win.f3.r
	label $win.f3.r.l2 -text "Scope Mechanism:"
	radiobutton $win.f3.r.b3 -text "TTL Scope" \
		-highlightthickness 0 \
		-variable scope -value ttl -relief flat -command \
		[format { 
	    set addr [generate_address %s]
	    if {$addr!=0} {
		pack %s.f3.rr -after %s.f3.m2 -side left -fill both \
		    -expand true
		pack forget %s.f3.admin
		if {$addr!=1} {
		    foreach media $medialist {
			if {$send($media)==1} {
			    store_new_session_addr $media [generate_address]
			}
		    }
		}
		set zone(cur_zone) $zone(ttl_scope)
		set scope ttl
		set_ttl_scope %s $ttl
	    } else {
		set scope admin
	    }
	} $aid $win $win $win $win]
	    radiobutton $win.f3.r.b4 -text "Admin Scope" \
		    -highlightthickness 0 \
		    -variable scope -value admin -relief flat -command \
		    [format { 
		# Recover the previously-selected scope if one clicks
		# on "admin" then "ttl" then "admin".
		#
		set tmpzone 0
		for {set i 0} {$i < $zone(no_of_zones)} {incr i} {
		    if {[string compare \
			    [%s.f3.admin.f.lb tag cget line$i -background] \
			    [option get . activeBackground Sdr]]==0} {
			set tmpzone $i
			break
		    }
		}
		set addr [generate_address $zone(base_addr,$tmpzone) \
			$zone(netmask,$tmpzone) %s]
		if {$addr!=0} {
		    set zone(cur_zone) $tmpzone
		    pack %s.f3.admin -after %s.f3.m2 -side left -fill both \
			    -expand true
		    pack forget %s.f3.rr
		    if {$addr!=1} {
			foreach media $medialist {
			    if {$send($media)==1} {
				store_new_session_addr $media \
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
	    } $win $aid $win $win $win]
		
		hlfocus $win.f3.r.b3
		hlfocus $win.f3.r.b4
		#padding frame
		frame $win.f3.m2 -width 1 -height 1

		#admin scope frame
		frame $win.f3.admin -relief groove -borderwidth 2
		label $win.f3.admin.l -text Scope:
		frame $win.f3.admin.f -relief sunken -borderwidth 1
		text $win.f3.admin.f.lb -width 15 -height 6 -relief flat -wrap none
		for {set i 0} {$i < $zone(no_of_zones)} {incr i} {
		    $win.f3.admin.f.lb insert [expr $i+1].0 "$zone(name,$i)"
		    $win.f3.admin.f.lb tag add line$i [expr $i+1].0 end-1c
		    $win.f3.admin.f.lb tag configure line$i -background\
			    [option get . background Sdr]
		    $win.f3.admin.f.lb insert end " \n"
		    $win.f3.admin.f.lb tag bind line$i <1> \
			    [format {
			set addr [generate_address $zone(base_addr,%s) \
				$zone(netmask,%s) %s]
			if {$addr!=0} {
			    #the change of scope is OK
			    for {set i 0} {$i < $zone(no_of_zones)} {incr i} {
				%s.f3.admin.f.lb tag configure line$i -background\
					[option get . background Sdr]
			    }
			    %s.f3.admin.f.lb tag configure line%s -background\
				    [option get . activeBackground Sdr]
			    set ttl $zone(ttl,%s)
			    if {$addr!=1} {
				#and we can reallocated the addresses too.
				foreach media $medialist {
				    if {$send($media)==1} {
					store_new_session_addr $media \
						[generate_address $zone(base_addr,%s) \
						$zone(netmask,%s)]
				    }
				}
			    }
			    set zone(cur_zone) %s
			}
		    } $i $i $aid $win $win $i $i $i $i $i]
		    }
		    $win.f3.admin.f.lb configure -state disabled
		    $win.f3.admin.f.lb tag configure line$zone(cur_zone) -background\
			    [option get . activeBackground Sdr]

    
		    frame $win.f3.rr -relief groove -borderwidth 2
		    tixAddBalloon $win.f3.rr Frame [tt "The scope determines how far your session will reach.  The default values are:
		    
Local net: 1
Site:      15
Region:    63
World:     127

Specify the smallest scope that will reach the people you want to communicate with."]

        label $win.f3.rr.l -text [tt "Scope"]
        radiobutton $win.f3.rr.r1 -relief flat -text [tt "Site"] -variable ttl\
		-highlightthickness 0 \
		-value 15 -command {disable_scope_entry 15}
	radiobutton $win.f3.rr.r2 -relief flat -text [tt "Region"] -variable ttl\
		-highlightthickness 0 \
		-value 63 -command {disable_scope_entry 63}
	radiobutton $win.f3.rr.r3 -relief flat -text [tt "World"] -variable ttl\
		-highlightthickness 0 \
		-value 127 -command {disable_scope_entry 127}
	hlfocus $win.f3.rr.r1
	hlfocus $win.f3.rr.r2
	hlfocus $win.f3.rr.r3
	frame $win.f3.rr.f
	if {[string compare $aid "new"]==0} {
	    radiobutton $win.f3.rr.f.r4 -relief flat -variable ttl\
		    -highlightthickness 0 \
		    -command "enable_scope_entry 1" -value 0
	} else {
	    radiobutton $win.f3.rr.f.r4 -relief flat -variable ttl\
		    -highlightthickness 0 \
		    -command "enable_scope_entry $ttl" -value 0
	}
	entry $win.f3.rr.f.e -relief sunken -width 4 -text 1 \
		-bg [option get . entryBackground Sdr] \
		-highlightthickness 0
	$win.f3.rr.f.e insert 0 $ttl
	proc disable_scope_entry {value} [format {
	    %s.f3.rr.f.e configure -state normal
	    %s.f3.rr.f.e delete 0 end
	    %s.f3.rr.f.e insert 0 $value
	    %s.f3.rr.f.e configure -state disabled \
		    -background [option get . background Sdr]\
		    -relief groove
	} $win $win $win $win ]
	proc enable_scope_entry {ttl} [format {
	    %s.f3.rr.f.e configure -state normal \
		    -background [option get . entryBackground Sdr]\
		    -relief sunken
	    %s.f3.rr.f.e delete 0 end
	    %s.f3.rr.f.e insert 0 $ttl
	} $win $win $win ]
	proc get_ttl_scope {} [format {
	    return [%s.f3.rr.f.e get]
	} $win ]
	bind $win.f3.rr.f.e <1> [format {
	    %s.f3.rr.f.r4 invoke
	    %s.f3.rr.f.e icursor end
	    focus %s.f3.rr.f.e
	} $win $win $win ]
	if {[string compare $aid "new"]!=0} {
	    set ttl $ldata($aid,ttl)
	    if {$scope=="ttl"} {
		set_ttl_scope $win $ttl
	    }
	} else {
	    if {$scope=="ttl"} {
		$win.f3.rr.r1 invoke
	    }
	}
    }
    pack $win.f3 -side top
    pack $win.f3.r -side left
    pack $win.f3.r.l2 -side top -anchor nw
    pack $win.f3.r.b3 -side top -anchor nw
    pack $win.f3.r.b4 -side top -anchor nw
    pack $win.f3.m2 -side left -fill y -padx 3
    pack $win.f3.admin.l -side top -anchor w
    pack $win.f3.admin.f -side top -fill both -expand true
    pack $win.f3.admin.f.lb -side top -fill both -expand true
    pack $win.f3.rr.f.r4 -side left
    pack $win.f3.rr.f.e -side left
    pack $win.f3.rr.l -side top -anchor w
    pack $win.f3.rr.r1 -side top -anchor w
    pack $win.f3.rr.r2 -side top -anchor w
    pack $win.f3.rr.r3 -side top -anchor w
    pack $win.f3.rr.f -side top -anchor w
    if {$scope=="admin"} {
	pack unpack $win.f3.rr
	pack $win.f3.admin -side left -fill both -expand true
    }
    if {$scope=="ttl"} {
	pack unpack $win.f3.rr
	pack $win.f3.rr -side left -fill both -expand true
    }

}

proc new_mk_session_type {win order aid} {
    global ldata typelist
    if {[winfo exists $win]==0} {
	frame $win
	label $win.l -text "Type of Session:"
	menubutton $win.m -menu $win.m.menu -width 10\
		-borderwidth 1 -relief raised
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
    pack $win -side top
    pack $win.l -side $order -anchor nw
    pack $win.m -side $order -anchor nw -padx 10
}

proc new_mk_session_name {win aid} {
    global ldata
    if {[winfo exists $win.f0]==0} {
	frame $win.f0
	label $win.f0.l -text [tt "Session Name:"]
	entry $win.f0.entry -width 30 -relief sunken\
		-bg [option get . entryBackground Sdr] \
		-highlightthickness 0
	tixAddBalloon  $win.f0.entry Entry [tt "Enter the name of the session here"]
	if {[string compare $aid "new"]!=0} { $win.f0.entry insert 0 $ldata($aid,session) }
	proc get_new_session_name {win} {
	    $win.f0.entry get
	}
    }
    pack $win.f0.l -side left
    pack $win.f0.entry -side left -fill x -expand true
    pack $win.f0 -side top -anchor w -fill x
}

proc new_mk_session_desc {win aid} {
    global ldata
    if {[winfo exists $win.descl]==0} {
	label $win.descl -text [tt "Description:"]
	frame $win.df
	text $win.df.desc -width 40 -height 5 -relief sunken -borderwidth 2 \
		-bg [option get . entryBackground Sdr] \
		-yscroll "$win.df.sb set"\
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
	if {[string compare $aid "new"]!=0} { 
	    #	$win.df.desc insert 0.0 [text_wrap $ldata($aid,desc) 40] 
	    $win.df.desc insert 0.0 $ldata($aid,desc)
	}    
	proc get_new_session_desc {} [format {
	    %s.df.desc get 0.0 end-1c
	} $win ]
    }
    pack $win.descl -side top -anchor w
    pack $win.df.desc -side left -fill both -expand true
    pack $win.df.sb -side left -fill y
    pack $win.df -side top -fill both -expand true
}

proc new_mk_session_url {win aid} {
    global ldata
    if {[winfo exists $win.url]==0} {
	frame $win.url -borderwidth 2 -relief groove
	frame $win.url.f0 
	label $win.url.f0.l -text URL:
	entry $win.url.f0.e -width 30 -relief sunken -borderwidth 2 \
		-bg [option get . entryBackground Sdr] \
		-highlightthickness 0
	tixAddBalloon $win.url.f0.e Entry [tt "You can enter a URL here to provide additional information about your session.\n\nA URL is a reference to a web page. E.g. http://www"]
	button $win.url.f0.b -text "Test URL" \
		-highlightthickness 0 \
		-command [format { \
		%s.url.f0.e select from 0; \
		%s.url.f0.e select to end; \
		catch {selection get} url; \
		timedmsgpopup "Testing URL - please wait" $url 5000; \
		stuff_mosaic } $win $win]
	tixAddBalloon $win.url.f0.b Button [tt "Click here to test the URL entered in the box to the left of this button"]
	if {[string compare $aid "new"]!=0} {
	    if {$ldata($aid,uri)!=0} {
		$win.url.f0.e insert 0 $ldata($aid,uri)
	    }
	}
	proc get_new_session_uri {} [format {
	    %s.url.f0.e get
	} $win ]
    }
    pack $win.url -side top -fill x -expand true -ipady 2 -ipadx 2 -pady 2
    pack $win.url.f0 -side top -fill x -expand true
    pack $win.url.f0.l -side left
    pack $win.url.f0.e -side left -fill x -expand true
    pack $win.url.f0.b -side left
}

proc new_mk_session_admin {win aid scope} {
    global zone send medialist ttl ldata
    #admin scope frame
    if {[winfo exists $win]==0} {
	frame $win -relief groove -borderwidth 2
	label $win.l -text "Area Reached:"

	tixAddBalloon $win.l Label [tt "The area reached determines the \
range of the session.  People outside this area will not be able to receive it."]

        frame $win.f
        text $win.f.lb -width 15 -height 6 -relief flat \
	    -relief sunken -borderwidth 1 -yscroll "$win.f.sb set" \
	    -highlightthickness 0
        scrollbar $win.f.sb -borderwidth 1 -command "$win.f.lb yview" \
	    -highlightthickness 0
	if {[string compare $aid "new"]!=0} {
	    for {set mnum 0} {$mnum < $ldata($aid,medianum)} {incr mnum} {
		set send($ldata($aid,$mnum,media)) 1
	    }
	}
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
		    foreach media $medialist {
			if {$send($media)==1} {
			    store_new_session_addr $media \
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
    if {$scope=="admin"} {pack $win -side left -fill both -expand true}
    pack $win.l -side top -anchor w
    pack $win.f -side top -fill both -expand true
    pack $win.f.lb -side left -fill both -expand true
    pack $win.f.sb -side right -fill y -expand true
}


proc store_new_session_addr {media str} {
    global tmpdata
    #we need to set this before we retrieve it in new_mk_session_media
    set tmpdata($media) $str
}

proc retrieve_new_session_addr {media} {
    global tmpdata
    set res $tmpdata($media)
    unset tmpdata($media)
    return $res
}

proc new_mk_session_media {win aid scope show_details} {
    global ldata tmpdata zone medialist sd_menu send 
    global media_fmt media_proto media_attr media_layers
    global mediaenc sessionkey
    #multicast address and ttl
    if {[winfo exists $win]==0} {
	frame $win -relief groove -borderwidth 2

	#Media
	frame $win.l
	label $win.l.1 -text [tt "Media:"] -anchor w -width 15
	label $win.l.5 -text [tt "Protocol"] -anchor w -width 8
	label $win.l.2 -text [tt "Format"] -anchor w -width 9
	label $win.l.3 -text [tt "Address"] -anchor w -width 13
	label $win.l.6 -text [tt "Layers"] -anchor w -width 6
	label $win.l.4 -text [tt "Port"] -anchor w -width 6

	label $win.l.7 -text [tt "Encryption"] -anchor w -width 12

	foreach attr [array names media_attr] {
	    unset media_attr($attr)
	}
	if {[string compare $aid "new"]!=0} {
	    for {set mnum 0} {$mnum < $ldata($aid,medianum)} {incr mnum} {
		set send($ldata($aid,$mnum,media)) 1
		#set media_attr($ldata($aid,$mnum,media)) $ldata($aid,$mnum,vars)
		#puts "vars: $ldata($aid,$mnum,vars)"
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
	    if {[string compare $aid "new"]!=0} {
 
		for {set mnum 0} {$mnum < $ldata($aid,medianum)} {incr mnum} {
		    if {$ldata($aid,$mnum,media)==$media} {
			set localmnum $mnum
			if { $ldata($aid,$mnum,mediakey) != "" } {
			    set mediaenc($media) 1
			} else {
			    set mediaenc($media) 0
			}
		    }
		}
		
	    } else {
# default to unencrypted media streams
		set mediaenc($media) 0
	    }

	    frame $win.$media

	    button $win.$media.cb -command "togglemedia $win $media"
	    if {[is_creatable $media]==0} {
		$win.$media.cb configure -state disabled
	    }
	    iconbutton $win.$media.mb -text $media -bitmap [get_icon $media] -width 10 -relief raised\
		    -menu $win.$media.mb.menu 
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

	    checkbutton $win.$media.b1 -variable mediaenc($media) \
		    -highlightthickness 0  \
		    -command "toggleenc $media $win"
 
	    tixAddBalloon $win.$media.b1 Button [tt "Click here to toggle the $media encryption on/off."]
 
	    entry $win.$media.enc -width 25 -relief sunken \
		    -bg [option get . entryBackground Sdr] \
		    -highlightthickness 0
 
	    tixAddBalloon $win.$media.enc Entry [tt "The $media encryption key is shown here. You can replace the random key by typing your own key in this field."]

	    #not all media are creatable 
	    #if we don't have the tools installed, don't let the 
	    #media be configured because we won't be able to join
	    #our own session
	    if {[is_creatable $media]==0} {
		setmediamode $media $win $send($media) 0		
		continue
	    }

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
 
		if {[string compare $aid "new"]!=0} {
 
		    if { $mediaenc($media) == 1} {
			$win.$media.enc configure -bg [option get . entryBackground Sdr] \
				-state normal -relief sunken
			$win.$media.enc  delete 0 end
			$win.$media.enc  insert 0 $ldata($aid,$localmnum,mediakey)
		    } else {
			$win.$media.enc  delete 0 end
			$win.$media.enc configure -bg [option get . background Sdr] \
				-relief groove -state disabled
		    }
 
		} else {
 
		    if { $mediaenc($media) == 1 } {
			$win.$media.enc configure -bg [option get . entryBackground Sdr] \
				-state normal -relief sunken
			$win.$media.enc  delete 0 end
			$win.$media.enc  insert 0 $sessionkey($media)
		    } else {
			$win.$media.enc  delete 0 end
			$win.$media.enc configure -bg [option get . background Sdr] \
				-relief groove -state disabled
		    }
		    
		}
		
	    } else {
		if {[string compare $aid "new"]!=0} {
		    if { $mediaenc($media) == 1} {
			set sessionkey($media) $ldata($aid,$localmnum,mediakey)
		    }
		}
	    }
	    
	    # end of media loop
	}
    

	proc get_new_session_addr {media} [format {
	    if {$media=="conference"} {
		#XXX delete this when create no longer asks for it
		return 224.0.0.0
	    } else {
		%s.$media.addr get
	    }
	} $win $win]



	proc get_new_session_port {media} [format {
	    %s.$media.port get
	} $win ]
	proc get_new_session_proto {media} {
	}
	proc get_new_session_format {media} {
	}
    }

    foreach media $medialist {
	if {[info exists tmpdata($media)]} {
	    $win.$media.addr delete 0 end
	    $win.$media.addr insert 0 [retrieve_new_session_addr $media]
	}

	pack $win.$media -side top -anchor w  -padx 10 -pady 2
	pack $win.$media.cb -side left
	pack $win.$media.mb -side left -fill y
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

	if {$show_details==1} {
	    pack $win.$media.b1 -side left
	} else {
	    pack $win.$media.b1 -side left -padx 10m
	}
	if {$show_details==1} {
	    pack $win.$media.enc -side left -padx 2
	}
    }
 
    pack $win.l.1 -side left -anchor w
    if {$show_details==1} {
	pack $win.l.5 -side left -anchor w
    }
    pack $win.l.2 -side left -anchor w
    if {$show_details==1} {
	pack $win.l.3 -side left -anchor w
    }
    pack $win.l.6 -side left -anchor w
    if {$show_details==1} {
	pack $win.l.4 -side left -anchor w 
    }
    pack $win.l.7 -side left -anchor w 
    if {$show_details==1} {
	pack $win -fill x -side top -anchor w -pady 5
    } else {
	pack $win -fill both -expand true -side top -anchor nw
    }
}


proc new_mk_session_time_box {win box maxbox rpt_times menu_disabled} {
    global ifstyle
    if {($box==1)&&($ifstyle(create)=="norm")} {
	label $win.expl -font [resource infoFont] -text \
	    "how often it takes place               when it first takes place                                      how long each time"
	pack $win.expl -side top
    }
    frame $win.fb$box
    set mb $win.fb$box.m
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
                    configure_rpt_menu $box $win.fb$box;\
                    configure_duration_box $win.fd $maxbox"
	} else {
	    $mb.m add command -label $i -state disabled
	}
	incr ctr
    }
    pack $win.fb$box -side top
    pack [label $win.fb$box.l -text "from:"] -side left
    day_widget $win.fb$box.day now
    pack [label $win.fb$box.l1 -text "at"] -side left
    time_widget $win.fb$box.time now
    pack [label $win.fb$box.l2 -text "for"] -side left
    duration_widget $win.fb$box.duration 7200
    pack [frame $win.pad$box -height 10] -side top
    configure_rpt_menu $box $win.fb$box
}

proc new_mk_session_contact {win aid} {
    global ldata yourname yourphone youremail
    if {[winfo exists $win]==0} {
	frame $win -relief groove -borderwidth 2
	label $win.l -text "Person to contact about this session:"

	tixAddBalloon $win.l Label [tt "Name, email address and telephone \
number of person to be contacted about the session. You can \
edit the suggested address and telephone number. To edit the \
default, choose \"Preferences\" in the session main session \
window, then \"You\"."]

        frame $win.f0 

        label $win.f0.l -bitmap mail -anchor w
        entry $win.f0.e -width 35 -relief sunken \
		-bg [option get . entryBackground Sdr] \
		-highlightthickness 0
        tixAddBalloon $win.f0.e Entry [tt "Enter your name and email address here"]


        frame $win.f1 
        label $win.f1.l -bitmap phone -anchor w
        entry $win.f1.e -width 35 -relief sunken \
	    -bg [option get . entryBackground Sdr] \
	    -highlightthickness 0
        tixAddBalloon $win.f1.e Entry [tt "Enter your telephone number here"]

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
    pack $win.l -side top -anchor nw
    pack $win.f0 -side top -pady 3
    pack $win.f0.l -side left -fill x -anchor s
    pack $win.f0.e -side bottom -anchor sw
    pack $win.f1 -side top
    pack $win.f1.l -side left -fill x
    pack $win.f1.e -side left -fill x -expand true
    pack $win -side top -fill both -expand true
}
#AUTH do_add creatation
proc new_mk_session_buttons {win aid} {
    frame $win
    if {[string compare $aid "new"]!=0} {
	button $win.create -text [tt "Modify"] -command \
	    "if {\[create\]==1} \
                { do_ad_creation $aid;\
                  cleanup_after_new}"
	tixAddBalloon $win.create Button [tt "Click here to advertise the modified session.  

Changing the session name may result in some sites seeing duplicate announcements for a while."]
    } else {
	button $win.create -text [tt "Create"] -command \
	    "if {\[create\]==1} {cleanup_after_new}" \
	     -highlightthickness 0
	tixAddBalloon $win.create Button [tt "When you've filled out all the above information, click here to create and advertise this session"]
    }
    button $win.cal -text [tt "Show Daily Listings"] -command "calendar" \
	 -highlightthickness 0
    tixAddBalloon $win.cal Button [tt "Click here to show a calendar of current sessions"]
    button $win.help -text [tt "Help"] -command "help" \
	 -highlightthickness 0
    tixAddBalloon $win.help Button [tt "Click here for more help or to turn balloon help off"]

    button $win.dismiss -text "Dismiss" -command "cleanup_after_new" \
	 -highlightthickness 0
    tixAddBalloon $win.dismiss Button [tt "Click here to close this window"]
    pack $win.create -side left -fill x -expand true
    pack $win.cal -side left -fill x -expand true
    pack $win.help -side left -fill x -expand true
    pack $win.dismiss -side left -fill x -expand true
    pack $win -fill x
}

proc set_ttl_scope {win ttl} {
    case $ttl {
	15 { $win.f3.rr.r1 invoke;return}
	63 { $win.f3.rr.r2 invoke;return}
	127 {$win.f3.rr.r3 invoke;return}
	default {
#	    puts $ttl
	    $win.f3.rr.f.r4 invoke
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

	set year [clock format [clock seconds] -format %Y]
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
		if {[set [set widget](monthix)]==13} {
			set [set widget](monthix) 1
			incr year
			fixdaysinmonth $year
		}
    } 
    if {[set [set widget](dayofmonth)]==0} {
		incr [set widget](monthix) -1
		if {[set [set widget](monthix)]==0} {
			set [set widget](monthix) 12
			incr year -1
			fixdaysinmonth $year
		}
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
    sdr_toplevel .phone "Configure"
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
    $win.m configure -text [lindex $rpt_times $rpt_menu_value($box)]
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
    set endtime [expr [lindex $has_times $rval]*[expr $starttime + $duration + $durationmod]]
    case $rval {
	0 { set rpt_str "0 0 0" }
	1 { set rpt_str "0 $duration 0"}
	2 { set rpt_str "86400 $duration 0"}
	3 { set rpt_str "604800 $duration 0"}
	4 { set rpt_str "1209600 $duration 0"}
	5 { set rpt_str "0 0 0"}
        6 { set rpt_str "604800 $duration 0 86400 172800 259200 345600"}
    }
    return "$starttime $endtime $rpt_str"
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

proc togglemedia {win media} {
    global send
    if {$send($media) == 0} {
        setmediamode $media $win 1 1
    } else {
        setmediamode $media $win 0 1
    }
}

proc toggleenc { media win } {
 
  global mediaenc sessionkey tempkey ifstyle
 
# win is: SAP(norm)=.new.f3.media; SAP(tech)=.new.f1;SAP QCall=.qc.f.media
 
  if { $mediaenc($media) == 0} {

# switch encryption off for media 

    set sessionkey($media) ""
    if {$ifstyle(create)=="tech" && [string compare [string range $win 1 2] "qc"] != 0 } {
      $win.$media.enc  delete 0 end
      $win.$media.enc configure -bg [option get . background Sdr] \
        -relief groove -state disabled
    }

  } else {

# switch encryption on for media

    make_random_key
    set  sessionkey($media)  $tempkey
    if {$ifstyle(create)=="tech" && [string compare [string range $win 1 2] "qc"] != 0 } {
      $win.$media.enc configure -bg [option get . entryBackground Sdr] \
        -state normal -relief sunken
      $win.$media.enc  delete 0 end
      $win.$media.enc  insert 0 $sessionkey($media)
    }

  }
}
 
proc get_new_media_key {media} {

  global ifstyle sessionkey
 
  if {$ifstyle(create)=="tech"} {
    set win .new.f.f.media
    set sessionkey($media) [$win.$media.enc get]
  }
 
  return $sessionkey($media)
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
    global mediaenc sessionkey tempkey
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

        $base.enc delete 0 end
        $base.enc configure -text "" -bg [option get . background Sdr] \
            -relief groove -state disabled
 
        $base.b1 configure -state disabled
        set mediaenc($media) 0
 
	$base.layers configure -text " " -state disabled -relief groove

	$base.port  delete 0 end
	$base.port configure -bg [option get . background Sdr] \
	    -relief groove -state disabled

	$base.mb.workaround configure -relief groove -state disabled
	if {[is_creatable $media]==1} {
	    set media_fmt($media) [lindex [get_media_fmts $media $media_proto($media)] 0]
	    set media_proto($media) [lindex [get_media_protos $media] 0]
	}
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

# set encryption to off state if not just changing formats etc
# but enable the encryption button to be used

         if {$realloc == 1} {
           $base.enc delete 0 end
           $base.enc configure -text "" -bg [option get . background Sdr] \
               -relief groove -state disabled

           $base.b1 configure -state normal
           set mediaenc($media) 0
         }

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
    global ldata tmpdata media_fmt media_proto media_layers
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
	    if {[info exists tmpdata($media)]} {
		$base.addr insert 0 [retrieve_new_session_addr $media]
	    } else {
		$base.addr insert 0 $ldata($aid,$mnum,addr)
	    }
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
		sdr_toplevel .warn "Warning"
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


