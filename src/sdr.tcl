#sdr.tcl
#Copyright University College London 1995, 1996
#Copyright USC/ISI, 1997, 1996, 1998
#see ui_fns.c for information on usage and redistribution of this file
#and for a DISCLAIMER OF ALL WARRANTIES.

# set the following to 1 to disable enc/auth and 0 to enable it
set pgpdisable  1
set x509disable 1

set initWait 400
set last_widget foo
set showwhich all

set yourname ""
set yourphone ""
set youremail ""
set youralias ""
set sip_server_url "sip:north.east.isi.edu"
set keylist ""

set lang C
catch {set lang $env(LANG)}
proc debug {str} {
    global debug1 tcl_platform
    if {$debug1} {
		if {$tcl_platform(platform)=="windows"} {Debug $str}
		else {puts $str}
    }
}

proc putlogfile {text} {
    global logfile
#    puts "In putlogfile - logfile = $logfile"
##   set out [open $logfile a]
##   puts $out "$text"
##   close $out
# change to just the following if on unix and want all output to screen
#  puts "$text"
}

#set langtab [open "/tmp/langtab" "w"]
proc tt {english} {
    global langtab trdone
    global lang trs
    if {$lang=="C"} {
	set tmp ""
	catch {set tmp $trdone($english)}
	if {$tmp == ""} {
	    regsub -all "\"" $english "\\\"" tmp
#	    puts $langtab "t \"$tmp\" XX \"$tmp\""
	}
	return "$english"
    } else {
	set res "$english"
	catch {set res "$trs($lang,$english)"}
	return "$res"
    }
}
proc t {english lang other} {
    global trs
#    putlogfile "tranlating $english to $other in $lang"
    set trs($lang,$english) $other
}
t "New" de "Neu"
t "New" fr "Neuf"
t "Heard from" fr "Ecoutee de"
t "Session Name:" fr "Nom de Session:"
catch {source [resource sdrHome]/$lang}

proc gettime {sec} {
    set res [clock format $sec -format {%Y %m %d %H %M %w %B %a %A}]
    #do TZ separately because of a bug in IRIX which returns TZ with an
    #unmatched quote preceding it
    set tz [clock format $sec -format { %Z }]
    lappend res $tz
    return $res
}

proc gettimeofday {} {
    clock seconds
}

proc gettimenow {} {
    gettime [clock seconds]
}

proc getreadabletime {} {
    return [clock format [clock seconds] -format {%H:%M, %d/%m/%Y}]
}

set sdrversion "v2.7"
set titlestr "Multicast Session Directory $sdrversion"

proc initialise_resources {} {
    global gui tcl_platform
    if {$gui=="NO_GUI"} { return }
    #Tk4.0 standard bg
    option add *background gray85 
    #Use same colours as vat
    option add *foreground black 
    option add *activeBackground gray95 
    option add *activeForeground black 
    option add *hotForeground blue 
    option add *activehotForeground red 
    option add *selectBackground gray95 
    option add *scrollbarBackground gray50 
    option add *scrollbarForeground gray80 
    option add *scrollbarActiveForeground gray95 
    option add *canvasBackground gray95 
    option add *prefsBackground gray50 
    option add *balloonBg gray50 
    option add *balloonFg white 
    #test
    option add *disabledBackground gray80 
    option add *disabledForeground gray50 
    option add *entryBackground lightsteelblue 
    if { [winfo depth .] == 1 } {
	# make mono look better
	option add *background white 
	option add *selectBackground black 
	option add *selectForeground white 
	option add *activeBackground white 
	option add *activeForeground black 
	option add *activehotForeground black 
	option add *balloonBg black 
	option add *balloonFg white 
	option add *scrollbarBackground white 
	option add *scrollbarForeground black 
	option add *scrollbarActiveForeground black 
	option add *entryBackground white 
    }


if {$tcl_platform(platform) == "unix"} {
    option add *infoFont   -*-helvetica-medium-r-normal--*-100-*-*-*-*-iso8859-1 
    option add *headerFont -*-helvetica-bold-r-normal--*-140-*-*-*-*-iso8859-1 
    option add *largeFont  -*-helvetica-bold-r-normal--*-240-*-*-*-*-iso8859-1 
    option add *mediumFont -*-helvetica-medium-r-normal--*-120-*-*-*-*-iso8859-1 
    option add *font       -*-helvetica-medium-r-normal--*-120-*-*-*-*-iso8859-1 
    option add *italfont   -*-helvetica-bold-o-normal--*-120-*-*-*-*-iso8859-1 
} else {
	option add *font		-*-helvetica-medium-r-normal--14-*-iso8859-1
	option add *infoFont	-*-helvetica-medium-r-normal--12-*-iso8859-1 
	option add *largeFont	-*-helvetica-bold-r-normal--24-*-iso8859-1
	option add *mediumFont	-*-helvetica-bold-r-normal--12-*-iso8859-1
	option add *italfont	-*-helvetica-bold-o-normal--12-*-iso8859-1
	option add *headerFont	-*-helvetica-bold-r-normal--14-*-iso8859-1
}

    set tmp 0
    catch {set tmp [label .test -font [option get . font Sdr]];destroy .test}
    if {$tmp==0} {
        option add *font 8x13 100
        option add *infoFont 6x9 100
	option add *largeFont 9x15bold 100
        option add *headerFont 9x15 100
        option add *mediumFont 8x13 100
        option add *italfont 8x13bold 100
    }




    #fix odd little bug in tk4.0 Entry deletion
    bind Entry <Delete> {
	if [%W selection present] {
	    %W delete sel.first sel.last
	} else {
	    set tk_fix(ix) [expr [%W index insert] -1]
	    if {$tk_fix(ix)>=0} {
		%W delete $tk_fix(ix)
	    }
	}
    }
    bind Entry <BackSpace> {
	if [%W selection present] {
	    %W delete sel.first sel.last
	} else {
	    set tk_fix(ix) [expr [%W index insert] -1]
	    if {$tk_fix(ix)>=0} {
		%W delete $tk_fix(ix)
	    }
	}
    }
    bind Text <Delete> {
	if {[%W tag nextrange sel 1.0 end] != ""} {
	    %W delete sel.first sel.last
	} else {
	    %W delete insert-1c
	    %W see insert
	}
    }
    bind Text <BackSpace> {
	if {[%W tag nextrange sel 1.0 end] != ""} {
	    %W delete sel.first sel.last
	} elseif [%W compare insert != 1.0] {
	    %W delete insert-1c
	    %W see insert
	}
    }
    bind Text <Return> {
	#nothing
    }
}

proc scroll_to_session {key list} {
    global ldata items ix sessbox

    if {[string length $key] != 1} {
	return
    }
    set key [string tolower $key]
    for {set i 0} {$i < $items($list)} {incr i} {
	if {[string tolower [string index $ldata($ix($list,$i),session) 0]] >= $key} {
	    break
	}
    }
    $sessbox($list) see $i.0
}

proc build_interface {first} {
    global tcl_platform ifstyle gui sessbox 
    global logfile argv0 argv
    if {$gui=="NO_GUI"} { return }
    log "Sdr started by [getusername] at [getreadabletime]"
    set lb $ifstyle(labels)
    global titlestr
    wm title . "sdr:[getemailaddress]"
    wm iconname . "sdr:[getemailaddress]"
    wm iconbitmap . sdr
    wm group . .
    wm command . [concat $argv0 $argv]
    wm protocol . WM_DELETE_WINDOW quit
    if {$first=="first"} {

        set tmpfile [clock format [clock seconds]  -format {%H%M%S}]
        set logfile "[glob -nocomplain [resource sdrHome]]/log$tmpfile.txt"
#       puts "debug - logfile will be $logfile"
        set startlogtime "[clock format [clock seconds]]"
        putlogfile "logfile started at $startlogtime"

	frame .f1  -relief groove -borderwidth 2
#	label .f1.l2 -bitmap ucl
#	pack .f1.l2 -side left -fill x
	label .f1.l -text $titlestr -width 32
	pack .f1.l -side left -fill x
	frame .f2 -relief sunken -borderwidth 2 
	label .f2.l -text "Public Sessions" -font [option get . infoFont Sdr] \
	    -relief raised -borderwidth 1
	pack .f2.l -side top -fill x
	text .f2.lb -width 20 -height 15 -yscroll ".f2.sb set" \
	    -relief flat -wrap none\
	    -selectforeground [resource activeForeground] \
	    -selectbackground [resource activeBackground] \
	    -highlightthickness 0
	init_session_list norm .f2.lb

	scrollbar .f2.sb -command ".f2.lb yview" \
		-background [resource scrollbarForeground] \
		-troughcolor [resource scrollbarBackground] \
		-borderwidth 1 -relief flat \
		-highlightthickness 0



	pack .f2.lb -side left -fill both -expand true
	pack .f2.sb -side right -fill y

	frame .f4 -relief sunken -borderwidth 2
	label .f4.l -text "Private Sessions" \
	    -font [option get . infoFont Sdr] \
	    -relief raised -borderwidth 1
	pack .f4.l -side top -fill x
	text .f4.lb -width 20 -height 3 -yscroll ".f4.sb set" \
		-relief flat -wrap none \
		-selectforeground [resource activeForeground] \
		-selectbackground [resource activeBackground] \
		-highlightthickness 0
	init_session_list priv .f4.lb
	scrollbar .f4.sb -command ".f4.lb yview" \
	    -background [resource scrollbarForeground] \
	    -troughcolor [resource scrollbarBackground] \
	    -borderwidth 1 -relief flat \
	    -highlightthickness 0

	pack .f4.lb -side left -fill both -expand true
	pack .f4.sb -side right -fill y


    } else {
	destroy .f3
    }

    frame .f3
    menubutton .f3.new -relief raised -menu .f3.new.m \
	-padx 0 -pady 1 -borderwidth 1 -highlightthickness 0 -takefocus 1
    menu .f3.new.m -tearoff 0
    .f3.new.m add command -label [tt "Create advertised session"] \
	    -command {new new}
    .f3.new.m add command -label [tt "Quick Call"] -command {qcall}

    button .f3.cal -relief raised -command {calendar} \
	-padx 0 -pady 1 -borderwidth 1 -highlightthickness 0
    tixAddBalloon .f3.cal Button [tt "Display a calendar listing booked sessions"]

    button .f3.prefs -relief raised -command {preferences2} \
	-padx 0 -pady 1 -borderwidth 1 -highlightthickness 0
    tixAddBalloon .f3.prefs Button [tt "Set the way sdr does things"]
#AUTH
 menubutton .f3.help -relief raised -menu .f3.help.m \
        -padx 0 -pady 1 -borderwidth 1 -highlightthickness 0 -takefocus 1
    menu .f3.help.m -tearoff 0
    .f3.help configure -text [tt "Help"]
#AUTH
    .f3.help.m add command -label [tt "sdr Help"] \
            -command {help}
    #tixAddBalloon .f3.help.m Button "Turn these help messages on and off"
    .f3.help.m add command -label [tt "key setup"] -command {Help_asym asym_help}
 
   # button .f3.help -text [tt "Help"] -relief raised -command {help} \
    #   -padx 0 -pady 1 -borderwidth 1 -highlightthickness 0
 


   # button .f3.help -text [tt "Help"] -relief raised -command {help} \
#	-padx 0 -pady 1 -borderwidth 1 -highlightthickness 0
#    tixAddBalloon .f3.help Button "Turn these help messages on and off"

    button .f3.quit -text [tt "Quit"] -relief raised -command quit  \
	-padx 0 -pady 1 -borderwidth 1 -highlightthickness 0
    tixAddBalloon .f3.quit Button [tt "Quit from sdr.  Conference tools already running will continue."]
    
    if {$lb=="short"} {
	.f3.new configure -text [tt "New"]
	.f3.cal configure -text [tt "Calendar"]
	.f3.prefs configure -text [tt "Prefs"]
    } else {
	.f3.new configure -text "  [tt "Create Session"]  "
	.f3.cal configure -text "  [tt "Daily Listings"]  "
	.f3.prefs configure -text "  [tt "Preferences"]  "
	.f3.help configure -text "  [tt Help]  "
	.f3.quit configure -text "  [tt Quit]  "
    }

    hlfocus .f3.new
    hlfocus .f3.cal
    hlfocus .f3.prefs
    hlfocus .f3.help
    hlfocus .f3.quit
    
    pack .f3.new -side left  -fill both -pady 0 -expand true
    pack .f3.cal -side left -fill both -pady 0 -expand true
    pack .f3.prefs -side left -fill both -pady 0 -expand true
    pack .f3.help -side left -fill both -pady 0 -expand true
    pack .f3.quit -side left -fill both -pady 0 -expand true
    if {$first=="first"} {
	pack .f3 -side top -fill x
	pack .f1 -side bottom -fill x
	pack .f2 -side top -fill both -expand true
	bind_listbox norm
	bind_listbox priv
    } else {
	pack .f3 -side top -before .f2 -fill x
    }
}

proc bind_listbox {list} {
    global sessbox ix tcl_platform
    set lb $sessbox($list)

#XXX
    bind $lb <1> {break}
    bind $lb <2> {break}
    bind $lb <ButtonRelease-2> {break}
    bind $lb <B1-Motion> {break}
    bind $lb <B1-Leave> {break}
    bind $lb <B2-Motion> {break}
    bind $lb <B2-Leave> {break}
    bind $lb <Enter> "focus $lb"
    bind $lb <Leave> "focus ."
    bind $lb <KeyPress> "scroll_to_session %K $list; break"
    tixAddBalloon $lb Listbox "Click button 1 on a listed session for more information on it or to participate in it.

    Click button 2 on a listed session to participate in it without displaying the session information

    Click button 3 on a listed session to hide the session if you're showing only preferred sessions"

    return 0

all this lot is obsolete...
    bind $lb <1> [format {
	tkListboxBeginSelect %%W [%%W index @%%x,%%y];
	set tmp 0;
	catch {
	    set tmp $ix(%s,[lindex [%s curselection] 0 ]);
	    if {[ispopped $tmp]==1} {
		popdown $tmp
	    } else {
		popup $tmp $ifstyle(view) advert
	    }
	}
    } $list $lb]

    if {$tcl_platform(platform) == "windows"} {
	# tcl under windows only has buttons 1 & 3
	bind $lb <3> [format {
	    tkListboxBeginSelect %%W [%%W index @%%x,%%y]
	    immediate_start %s [lindex [%s curselection] 0 ]
	} $list $lb]
	bind $lb <B3-Motion> {break}
	bind $lb <2> [format {
	    tkListboxBeginSelect %%W [%%W index @%%x,%%y]
	    hide_session %s [lindex [%s curselection] 0 ]
	} $list $lb]
    } else {
	bind $lb <2> [format {
	    tkListboxBeginSelect %%W [%%W index @%%x,%%y]
	    immediate_start %s [lindex [%s curselection] 0 ]
	} $list $lb]
	bind $lb <B2-Motion> {break}
	bind $lb <3> [format {
	    tkListboxBeginSelect %%W [%%W index @%%x,%%y]
	    hide_session %s [lindex [%s curselection] 0 ]
	} $list $lb]
    }
    bind $lb k {tkListboxUpDown %W -1}
    bind $lb j {tkListboxUpDown %W 1}
}

proc quit {} {
  global log
  give_status_msg "Writing cache files..."
  update idletasks
  write_cache
  log "Sdr exiting (Quit button pressed) at [getreadabletime]"
  savelog
  ui_quit
  destroy .
}

proc give_status_msg {text} {
    global titlestr
    .f1.l configure -text $text -font [option get . italfont Sdr]
    after 2000 .f1.l configure -text \"$titlestr\" -font [option get . font Sdr]
}

set fullnumitems 0
set medianum 0
#set tfrom 0
#set tto 0

proc reset_media {} {
#ensure that Tcl's error recovery hasn't left any unwanted state around
  global vars port proto fmt medianum advertid 
  global session multicast recvttl recvsap_addr recvsap_port desc advertid creator tfrom tto
  global source heardfrom timeheard
  global starttime endtime uri email phone
  catch {unset media}
  catch {unset vars}
  catch {unset port}
  catch {unset proto}
  catch {unset fmt}
  set medianum 0
  catch {unset advertid}
  catch {unset session}
  set multicast 0
  catch {unset recvttl}
  catch {unset recvsap_addr}
  catch {unset recvsap_port}
  catch {unset desc}
  catch {unset creator}
#  set tto 0
#  set tfrom 0
  set uri 0
  catch {unset source}
  catch {unset heardfrom}
  catch {unset timeheard}
  catch {unset starttime}
  catch {unset endtime}
  catch {unset sessvars}
  catch {unset trust}
  catch {
      foreach i [array names email] {
	  unset email($i)
      }
  }
  catch {
      foreach i [array names phone] {
	  unset phone($i)
      }
  }
}

proc media_changed_warning {aid medianum} {
    global ldata ifstyle tcl_platform
    if {$tcl_platform(platform) == "unix"} {
	set pid $ldata($aid,$medianum,pid)
	if {$pid!=0} {
	    switch $tcl_platform(os) {
		#wouldn't it be nice if this was portable...
		SunOS { set ps "/usr/ucb/ps " }
		Linux { set ps "ps " }
		default {set ps "ps -p "}
	    }
	} else {
	    return 1
	}
	set psout ""
	catch {set psout [eval exec $ps $pid]}
	if {[string first $pid $psout] == -1} {
	    set ldata($aid,$medianum,pid) 0
	    return 1
	}
	
	catch {destroy .mediawarn}
	sdr_toplevel .mediawarn$aid "Warning"
	frame .mediawarn$aid.f -borderwidth 2 -relief groove
	set win .mediawarn$aid.f
	pack $win -side top -fill both
	label $win.l -text [tt "Warning: Session has been modified"]
	pack $win.l -side top -fill x -expand true
	message $win.m -aspect 500 -text \
	    [concat [tt "The session called:\n"] \
	     $ldata($aid,session) \
		 [tt "has been modified.\n\n"]\
		 [tt "You are advised to restart the tools you have running for this session."]]
	pack $win.m -side top -fill x -expand true
	frame $win.f -borderwidth 0 
	pack $win.f -side top -fill x -expand true
	button $win.f.show -text "Show details" \
	    -command "catch {destroy .mediawarn$aid};popup $aid $ifstyle(view) advert"
	pack $win.f.show -side left -fill x -expand true
	button $win.f.dismiss -text "Dismiss" \
	    -command "catch {destroy .mediawarn$aid}" \
	     -highlightthickness 0
	pack $win.f.dismiss -side left -fill x -expand true
	return 0
    } else {
	return 0
    }
}

proc set_media {} {
    global media vars port proto fmt medianum ldata advertid 
    global mediaaddr mediattl medialayers rtp_payload
    global mediakey 
    set origaddr 0
    set aid $advertid
    catch {
	set origaddr $ldata($aid,$medianum,addr)
	set origport $ldata($aid,$medianum,port)
    }
    if {($origaddr!=0)&&($ldata($aid,started)==1)} {
	if {($origaddr!=$mediaaddr)||($origport!=$port)} {
	    set $ldata($aid,started) \
		    [media_changed_warning $aid $medianum]
	}
    }
    set ldata($aid,$medianum,media)    $media
    set ldata($aid,$medianum,port)     $port
    set ldata($aid,$medianum,proto)    $proto
    set ldata($aid,$medianum,fmt)      $fmt
    set ldata($aid,$medianum,vars)     $vars
    set ldata($aid,$medianum,addr)     $mediaaddr
    set ldata($aid,$medianum,layers)   $medialayers
    set ldata($aid,$medianum,ttl)      $mediattl
    set ldata($aid,$medianum,pid)      0
    set ldata($aid,$medianum,mediakey) $mediakey

    incr medianum
    set ldata($aid,medianum) $medianum
    debug "medianum=$medianum"
}

#
# Compare two arbitrary strings of digits.
# The SDP session ID and session version are strings of digits that
# are not required to be representable as tcl numbers.
proc sesscmp {mt1 mt2} {
    set mt1 [string trimleft $mt1 "0"]
    set mt2 [string trimleft $mt2 "0"]
    set l1 [string length $mt1]
    set l2 [string length $mt2]
    if {$l1 < $l2} {
	return -1
    } elseif {$l1 == $l2} {
	return [string compare $mt1 $mt2]
    } else {
	return 1
    }
}

proc add_to_list {} {
  global session multicast recvttl recvsap_addr recvsap_port desc 
  global advertid creator tfrom tto
  global ldata fullnumitems fullix medianum source items
  global heardfrom timeheard 
  global starttime endtime showwhich phone email uri rctr repeat 
  global sessid sessvers createaddr sessvars trust recvkey
  global debug1

  global asym_cur_keyid
  global sess_auth_status
  global sess_auth_type
  global sess_auth_message
  global enc_asym_cur_keyid
  global sess_enc_status
  global sess_enc_type
  global sess_enc_message
  global asympse

  if {$debug1 == 1} {
    putlogfile "add_to_list $advertid"
  }

  set aid $advertid

  if {[info exists ldata($aid,sessid)] && [sesscmp $ldata($aid,sessid) $sessid] == 0} {
    if {[sesscmp $ldata($aid,sessvers) $sessvers] == 0} {
      # This is the same version we already have.
      set ldata($aid,heardfrom) $heardfrom
      set ldata($aid,theard) $timeheard
      set ldata($aid,lastheard) [gettimeofday]
      # only skip updating it if we've updated it within the last minute.
      # We could also add "&& [random] < .75" to only update it
      # randomly after a minute, but for now this is probably OK since
      # the goal is to skip the hundreds of copies from rabid looping
      # need to update if authenticated or encrypted as message changes
      set ldata($aid,authtype) $sess_auth_type
      set ldata($aid,enctype)  $sess_enc_type
      if {$ldata($aid,authtype)=="none" && $ldata($aid,enctype)=="none"} {
        set limit 60
      } else {
        set limit 0
      }
      if {$ldata($aid,lastheard) < [expr $ldata($aid,lastupdated) + $limit]} {
          debug "aid $aid name $session already have this version"
          popup_update $aid heard "Heard from $ldata($aid,heardfrom) at $ldata($aid,theard)"
          return
      }
      debug "aid $aid name $session already have this version but updating anyway"
    } elseif {[sesscmp $ldata($aid,sessvers) $sessvers] > 0} {
      debug "aid $aid name $session got version $sessvers but already have $ldata($aid,sessvers)"
      return
    }
  }
  set code 0
  debug "add_to_list $session key:$recvkey"
  catch {set code $ldata($aid,session);set code 1}
  if {$code==0} { 
      set ldata($aid,trust) $trust 
      set ldata($aid,started) 0
  } elseif {$ldata($aid,trust)=="sip"} {
      #we first heard the announcement via SIP and now hear it via SAP
      #update the trust accordingly
      set ldata($aid,trust) $trust
      #probably the session will also need to change listboxes...
      if {$ldata($aid,list)!=""} {
	  incr items($ldata($aid,list)) -1
	  set ldata($aid,list) ""
	  resort_sessions
	  set code 0
      }
  }

  set asympse {}
  set ldata($aid,authtype)       $sess_auth_type
  set ldata($aid,authstatus)     $sess_auth_status
  set ldata($aid,authmessage)    $sess_auth_message
  set ldata($aid,asym_keyid)     $asym_cur_keyid
  set ldata($aid,enctype)        $sess_enc_type
  set ldata($aid,encstatus)      $sess_enc_status
  set ldata($aid,enc_asym_keyid) $enc_asym_cur_keyid
  set ldata($aid,encmessage)     $sess_enc_message

  set ldata($aid,key)            $recvkey
  set ldata($aid,sessid)         $sessid
  set ldata($aid,sessvers)       $sessvers
  set ldata($aid,createaddr)     $createaddr
  set ldata($aid,source)         $source
  set ldata($aid,heardfrom)      $heardfrom
  set ldata($aid,session)        $session
  set ldata($aid,multicast)      $multicast
  set ldata($aid,ttl)            $recvttl
  set ldata($aid,sap_addr)       $recvsap_addr
  set ldata($aid,sap_port)       $recvsap_port
#  regsub -all {\\n} $desc "\n" desc
  set ldata($aid,desc)           $desc
  set ldata($aid,creator)        $creator
  set ldata($aid,theard)         $timeheard
  set ldata($aid,starttime)      0
  set ldata($aid,endtime)        0
  set ldata($aid,tto)            ""
  set ldata($aid,tfrom)          ""
  set ldata($aid,method)         advert
  set ldata($aid,vars)           $sessvars
  set ldata($aid,type)           unknown
  set ldata($aid,tool)           unknown

  foreach i [split $sessvars "\n"] {
      set attr [lindex [split $i ":"] 0]
      switch $attr {
	  tool {
	      set ldata($aid,tool) [lindex [split $i ":"] 1]
	  }
	  type {
	      set ldata($aid,type) [lindex [split $i ":"] 1]
	  }
      }
  }

  foreach i [array names starttime] {
      set ldata($aid,tto,$i) $tto($i)
      set ldata($aid,tfrom,$i) $tfrom($i)
      set ldata($aid,starttime,$i) $starttime($i)
      if {($starttime($i) < $ldata($aid,starttime)) || \
	  ($ldata($aid,starttime)==0)} {
	      set ldata($aid,starttime) $starttime($i)
	      set ldata($aid,tfrom) $tfrom($i)
      }
      set ldata($aid,endtime,$i) $endtime($i)
      if {$endtime($i) > $ldata($aid,endtime)} {
	  set ldata($aid,endtime) $endtime($i) 
	  set ldata($aid,tto) $tto($i)
      } 
      set ro 0
      for {set r 0} {$r < $rctr($i)} {incr r} {
	  #don't accept repeat intervals of zero or less
	  set interval [parse_rpt_time [lindex $repeat($i,$r) 0]]
	  if {$interval>0} {
	      set duration [parse_rpt_time [lindex $repeat($i,$r) 1]]
	      # If the duration is longer than or equal to the interval, then it
	      # effectively means "the whole time".
	      if {$duration >= $interval} {
		  # XXX
		  # Need to increment the start of the session by the
		  # first offset if it's not 0.
		  # set a [parse_rpt_time [lindex $repeat($i,$r) 0]]
		  # if {$a != 0} {
		  # 	add $a to tfrom
		  #	add $a to starttime
		  # }
		  set ro 0
		  break
	      }
	      set r2 -1
	      for {set j 0} {$j < $ro} {incr j} {
		  if {($ldata($aid,time$i,interval$j) == $interval) && \
		      ($ldata($aid,time$i,duration$j) == $duration)} {
		      set r2 $j
		      break
		  }
	      }
	      if {$r2 == -1} {
		  set ldata($aid,time$i,interval$ro) $interval
	          set ldata($aid,time$i,duration$ro) $duration
		  set ldata($aid,time$i,offset$ro) {}
		  set r2 $ro
		  incr ro
	      }
	      for {set j 2} {$j < [llength $repeat($i,$r)]} {incr j} {
		  lappend ldata($aid,time$i,offset$r2) \
			  [parse_rpt_time [lindex $repeat($i,$r) $j]]
	      }
	  } 
      }
      set ldata($aid,time$i,no_of_rpts) $ro
  }
  set ldata($aid,no_of_times) [array size starttime]
  set ldata($aid,lastheard) [gettimeofday]
  set ldata($aid,lastupdated) $ldata($aid,lastheard)
  set ldata($aid,emaillist) ""
  set ldata($aid,uri) $uri
  catch {
      foreach i [array names email] {
         lappend ldata($advertid,emaillist) $email($i)
      }
  }
  set ldata($aid,phonelist) ""
  catch {
      foreach i [array names phone] {
	  lappend ldata($advertid,phonelist) $phone($i)
      }
  }
  if {$medianum==0} {
      set ldata($aid,medianum) 0
  }
  set medianum 0
  display_session $aid $code
#  set tfrom 0
#  set tto 0
}

proc clear_session_state {aid} {
    global ldata
    #this way of doing things isn't very efficient but is effective
    foreach tag [array names ldata] {
	set lst [split $tag ","]
	if {[string compare [lindex $lst 0] $aid]==0} {
	    unset ldata($tag)
	}
    }
}

proc display_session {aid code} {
    global ldata session
    debug "display_session $aid $code"
    if {$code == 0} {
	#we haven't heard an announcement of this session before
	
	if {($ldata($aid,endtime)!=0)&&([gettimeofday] > $ldata($aid,endtime))} { 
	    #the session has now timed out (can only happen due to clock skew)
	    debug "\"$session\" out of date $ldata($aid,endtime)"
	    set medianum 0
	    #	  set tfrom 0
	    #	  set tto 0
	    #do a little cleaning up
	    clear_session_state $aid
	    return 
	}

	#is it a private session?
	#actually display it
        #AUTH
	if {$ldata($aid,key)!=""} {
            add_to_display_list $aid priv
        } else {
                if { ($ldata($aid,enctype) == "x509")||($ldata($aid,enctype) == "pgp") } {
                add_to_display_list $aid priv
                } else {
                add_to_display_list $aid norm
                }
 
        }

	set ldata($aid,is_popped) -1

	sdr_new_session_hook $aid

    } else {
	catch {
	    #we've heard it before
	    update_displayed_session $aid
	}
    }
}

proc add_to_display_list {aid list} {
    global items ix ldata sessbox showwhich fullnumitems fullix
    debug "new session $ldata($aid,session) in list $list"
#    debug "with endtime [gettime $ldata($aid,endtime)]"

    #check if it's already displayed
    foreach index [array names ix] {
        if {[string compare "[string range $index 0 3],$ix($index)" "$list,$aid"]==0} {
	    debug "session already displayed - why are we here?"
	    return 0
	}
    }

    set ldata($aid,list) $list

    #check it's not in the list of sessions not to show
    set vstate 1
    catch {set vstate $ldata($aid,vstate)}
    if {$vstate == 1} { 
	set ldata($aid,vstate) 1
    } else {
	debug "session is in list of sessions to hide"
	return 0
    }

    #check it satisfies the display criteria
    if {[listing_criteria $aid $showwhich]!=1} {
	catch {unset $ldata($aid,lastix)}
	return 0
    }

    set lsession [string tolower $ldata($aid,session)]
    set lastix 0
    set i 0
    debug a
    while {($i < $fullnumitems) && \
	    ([compare $aid $fullix($i)]<0)} {
	if {($lastix < $items($list)) && \
		([string compare $ix($list,$lastix) $fullix($i)]==0)} {
	    incr lastix
	}
	incr i
    }
    debug b
    for {set j $fullnumitems} {$j > $i} {incr j -1} {
	set fullix($j) $fullix([expr $j - 1])
    }
    incr fullnumitems
    set fullix($i) $aid
    debug c
    for {set j $items($list)} {$j > $lastix} {incr j -1} {
	set ix($list,$j) $ix($list,[expr $j - 1])
    }
    debug d
    #Display it
    set ix($list,$lastix) $aid
    list_session $aid $lastix $list

    if {$items($list) == 0} {
	show_session_list $list
    }
    incr items($list)
}

proc list_session {aid lastix list} {
    global sessbox ldata ifstyle 
         #puts "$ldata($aid,session)"
        set newname $ldata($aid,session)
        if  {$ldata($aid,trust)!="sip"} {
                 set autht $ldata($aid,authtype)
                 set enct $ldata($aid,enctype)
                if { $ldata($aid,authtype) != "none" } {
                set authtest $ldata($aid,authtype)
        set newname [concat $newname "(" $authtest ")"]
                }
                if { $ldata($aid,enctype)!="none" } {
                set enctest $ldata($aid,enctype)
        set newname [concat $newname "(" $enctest ")"]
                }
       } else {
         set autht "none"
         set enct "none"
       }

    if {$ifstyle(list)=="logo"} {
	set type $ldata($aid,type)
	if {[winfo exists $sessbox($list).win$aid]==0} {
	    putlogfile "creating new window $sessbox($list).win$aid"
	    label $sessbox($list).win$aid \
		    -bitmap [get_type_icon $ldata($aid,type) $autht $enct] \
		    -borderwidth 2 -relief groove
	    bind $sessbox($list).win$aid <Enter> \
		    "highlight_tag $aid enter"
	    bind $sessbox($list).win$aid <Leave> \
		    "highlight_tag $aid leave"
	    bind $sessbox($list).win$aid <1> "toggle_popup $aid"
	    bind $sessbox($list).win$aid <2> "start_all $aid"
	    bind $sessbox($list).win$aid <3> "hide_session $aid"
	}
	#puts "$sessbox($list) window create ..."
	$sessbox($list) window create [expr $lastix+1].0 -window \
		$sessbox($list).win$aid
	$sessbox($list) insert [expr $lastix+1].1 "$newname                                             \n"
    } else {
	#wish there was a better was to add a tag to the right margin
	$sessbox($list) insert [expr $lastix+1].0 "$newname                                             \n"
    }
    # PCs will crash here if the scrollbar is being used at the same time.....
    $sessbox($list) tag add t$aid [expr $lastix+1].0  [expr $lastix+1].end

    $sessbox($list) tag bind t$aid <1> "toggle_popup $aid"
    $sessbox($list) tag bind t$aid <2> "start_all $aid"
    $sessbox($list) tag bind t$aid <3> "hide_session $aid"
    $sessbox($list) tag bind t$aid <Enter> \
	    "highlight_tag $aid enter"    
    $sessbox($list) tag bind t$aid <Leave> \
	    "highlight_tag $aid leave"
    if {[ispopped $aid]==1} {
	$sessbox($list) tag configure t$aid \
                -foreground [option get . background Sdr] \
                -background [option get . foreground Sdr]
	catch {$sessbox($ldata($aid,list)).win$aid configure \
		-foreground [option get . background Sdr] \
                -background [option get . foreground Sdr] }
    } elseif {[listing_criteria $aid future]==1} {
	$sessbox($list) tag configure t$aid \
		-foreground [option get . disabledForeground Sdr] \
		-background [option get . background Sdr]
	catch {$sessbox($list).win$aid configure \
		-foreground [option get . disabledForeground Sdr] \
                -background [option get . background Sdr] }
    } else {
	$sessbox($list) tag configure t$aid \
		-foreground [option get . foreground Sdr] \
                -background [option get . background Sdr]
    }
}

proc relist_session {aid lastix list} {
    global sessbox ldata showwhich 
    putlogfile "relist_session"
    if {[listing_criteria $aid $showwhich]!=1} {
	#this session just became unshown - better redisplay everything.
	reshow_sessions $showwhich
	putlogfile "reshow_sessions"
	return 0
    }
    #did the session type or name change?
    set txt [$sessbox($list) get [expr $lastix+1].0 [expr $lastix+1].end+1c]
    set txt [string trim $txt "\n"]
    set txt [string trim $txt]
    putlogfile "new:>>$ldata($aid,session)<<, old:>>$txt<<"
    if {[string compare $ldata($aid,session) $txt]!=0} {
	$sessbox($list) delete [expr $lastix+1].0 [expr $lastix+1].end+1c
	list_session $aid $lastix $list
    }
    if {[ispopped $aid]==1} {
	highlight_tag $aid popup
    }
}

proc highlight_tag {aid mode} {
    global sessbox ldata

    set win 0
    catch {set win $sessbox($ldata($aid,list))}
    #don't worry about it if the session already timed out
    if {$win==0} {return 0}

    set icon $sessbox($ldata($aid,list)).win$aid
    switch $mode {
	enter {
	    if {[ispopped $aid]==1} {
		$win tag configure t$aid \
			-foreground [option get . activeBackground Sdr]
		catch {$icon configure \
			-foreground [option get . activeBackground Sdr]}
	    } else {
		$win tag configure t$aid -background \
			[option get . activeBackground Sdr]
		catch {$icon configure -background \
			[option get . activeBackground Sdr]}
	    }
	}
	leave {
	    if {[ispopped $aid]==1} {
		$win tag configure t$aid \
			-foreground [option get . background Sdr]
		catch {$icon configure \
			-foreground [option get . background Sdr]}
	    } else {
		$win tag configure t$aid \
			-background [option get . background Sdr]
		catch {$icon configure \
			-background [option get . background Sdr]}
	    }
	}
	popup {
	    $win tag configure t$aid \
		    -foreground [option get . background Sdr] \
		    -background [option get . foreground Sdr]
	    catch {$icon configure \
		    -foreground [option get . background Sdr] \
		    -background [option get . foreground Sdr]}
	}
	popdown {
	    if {[listing_criteria $aid future]==1} {
		$win tag configure t$aid \
			-foreground [option get . disabledForeground Sdr] \
			-background [option get . background Sdr]
		catch {$icon configure \
			-foreground [option get . disabledForeground Sdr] \
			-background [option get . background Sdr]}
	    } else {
		$win tag configure t$aid \
			-foreground [option get . foreground Sdr] \
			-background [option get . background Sdr]
		catch {$icon configure \
			-foreground [option get . foreground Sdr] \
			-background [option get . background Sdr]}
	    }
	}
    }
}

proc toggle_popup {aid} {
    global ifstyle
    if {[ispopped $aid]==1} {
	popdown $aid
	update
    } else {
	popup $aid $ifstyle(view) advert
	update
    }
}

proc show_session_list {list} {
    debug "show_session_list $list"
    if {$list=="priv"} {
	catch {pack .f4 -side top -fill both -expand true -after .f2}
    }
    debug "done"
}

set sesslists ""
proc init_session_list {list box} {
#initialise the data structures for a session listing box
    global items sessbox sesslists ifstyle
    if {$ifstyle(list)=="normal"} {
	$box configure -spacing1 4
    }
    set sesslists "$sesslists $list"
    set sessbox($list) $box
    set items($list) 0
    set ix($list) ""
}

proc update_displayed_session {aid} {
    global ldata sessbox showwhich
    if {[listing_criteria $aid $showwhich]!=1} {
	return 0
    }
    set list $ldata($aid,list)
    if {[set visix [find_listbox_index $aid $list]]!=-1} {
	set loc [lindex [$sessbox($list) yview] 0]
	relist_session $aid $visix $list
    }
    set win $ldata($aid,is_popped)
    if {[winfo exists $win]} {
	#the window is visible
	popup_update $aid name $ldata($aid,session)
	popup_update $aid desc $ldata($aid,desc)
	popup_update $aid heard "Heard from $ldata($aid,heardfrom) at $ldata($aid,theard)"
	if {$ldata($aid,endtime)!=0} {
	    popup_update $aid from "Session takes place from $ldata($aid,tfrom)"
	    popup_update $aid  to "        to $ldata($aid,tto)"
	}
	for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
	    set media $ldata($aid,$i,media)
	    popup_update_media $aid $i \
		    $ldata($aid,$i,fmt) \
		    $ldata($aid,$i,proto) \
		    $ldata($aid,$i,port) \
		    $ldata($aid,$i,ttl) \
		    $ldata($aid,$i,addr) \
		    $ldata($aid,$i,layers) \
                    $ldata($aid,$i,mediakey) \
		    $ldata($aid,$i,vars)
	}
    }
}

proc parse_rpt_time {timestr} {
    set mult(s) 1
    set mult(m) 60
    set mult(h) 3600
    set mult(d) 86400
    set timestr [string trim $timestr]
    if {[regexp {^([-0-9]+)([dhms])$} $timestr junk num m]} {
	return [expr $num * $mult($m)]
    } else {
	return $timestr
    }
}

proc make_rpt_time {secs} {
    if {$secs == 0} {
	return $secs
    } elseif {[expr $secs % 86400]==0} {
	return "[expr $secs/86400]d"
    } elseif {[expr $secs % 3600]==0} {
	return "[expr $secs/3600]h"
    } elseif {[expr $secs % 60]==0} {
	return "[expr $secs/60]m"
    } else {
	return $secs
    }
}

proc reshow_sessions {spec} {
    global ldata fullnumitems fullix items ix sessbox sesslists ifstyle
    foreach box [array names sessbox] {
	if {$ifstyle(list)=="normal"} {
	    $sessbox($box) configure -spacing1 4
	} else {
	    $sessbox($box) configure -spacing1 0
	}
	$sessbox($box) delete 1.0 end
    }
    foreach list $sesslists {
	set lastix($list) 0
    }
    foreach index [array names ix] {
	unset ix($index)
    }
    
    for {set i 0} {$i < $fullnumitems} {incr i} {
	set aid $fullix($i)
	set list $ldata($aid,list)
	if {$list==""} {continue}
#	if {$lastix < $items($list)} {
#	    set showing [expr [string compare $ix($list,$lastix) $aid] == 0]
#	} else {
#	    set showing 0
#	}
	set show [listing_criteria $aid $spec]
	if {$show} {
	    set ix($list,$lastix($list)) $aid
	    list_session $aid $lastix($list) $list
	    incr lastix($list)
	}
    }
}

proc resort_sessions {} {
    global ldata fullix fullnumitems ix sesslists showwhich
    #this is an insertion sort.
    #really should be something faster than this :-(
    set lastix 0
    foreach item [array names fullix] {
	set aid $fullix($item)
	set newi 0
	while {($newi<$lastix)&&([compare $aid $newfullix($newi)]<0)} {
	    incr newi
	}
	for {set i [expr $lastix-1]} {$i>=$newi} {incr i -1} {
	    set newfullix([expr $i+1]) $newfullix($i)
	}
	set newfullix($newi) $aid
	incr lastix
    }
    foreach item [array names newfullix] {
	set fullix($item) $newfullix($item)
	unset newfullix($item)
    }
    reshow_sessions $showwhich
}


set typevalue(test)      -1
set typevalue(meeting)    1
set typevalue(broadcast)  2
# secure sessions 
set typevalue(stest)     -1
set typevalue(smeeting)   1
set typevalue(sbroadcast) 2
#set typevalue(secure)    3

proc compare {aid1 aid2} {
    global ifstyle typevalue ldata
    set title1 [string toupper $ldata($aid1,session)]
    set title2 [string toupper $ldata($aid2,session)]
    switch $ifstyle(order) {
	alphabetic {
	    return [string compare $title2 $title1]
	}
	type {
	    set type1 $ldata($aid1,type)
	    set type2 $ldata($aid2,type)
	    if {$type1==$type2} {
		return [string compare $title2 $title1]
	    } else {
		set tv1 0
		set tv2 0
		catch {set tv1 $typevalue($type1)}
		catch {set tv2 $typevalue($type2)}
		return [expr $tv1-$tv2]
	    }
	}
    }
}

proc listing_criteria {aid spec} {
    global ldata showwhichfilter
    foreach filter [array names showwhichfilter] {
	if {($showwhichfilter($filter)==1) && \
		($ldata($aid,type)==$filter)} {
	    return 0
	}
    }
    case $spec {
	all { return 1 }
	pref { return $ldata($aid,vstate) }
	current { 
	    if {$ldata($aid,starttime)>[gettimeofday]} {
		return 0
	    } else {
		return 1
	    }
	}
	future {
	    if {$ldata($aid,starttime)>[gettimeofday]} {
		return 1
	    } else {
		return 0
	    }
	}
    }
}

proc find_listbox_index {aid list} {
    global ix items
    for {set i 0} {$i < $items($list)} {incr i} {
	if {[string compare $ix($list,$i) $aid]==0} { return $i }
    }
    return -1
}
proc find_full_index {aid} {
    global fullix
    for {set i 0} {$i < [array size fullix]} {incr i} {
	if {[string compare $fullix($i) $aid]==0} { return $i }
    }
    return -1
}
set timeout 3600
proc timeout_expired_sessions {} {
    global ix ldata items timeout fullnumitems fullix sessbox

    #run this again in 5 mins
    #set it before anything else to make it more robust to failures in
    #any of the following code
    after 120000 timeout_expired_sessions

    set time [gettimeofday]
    #search through the full index for timed out sessions
    set no_of_sess 0
    catch {set no_of_sess [array size fullix]}
    for {set i 0} {$i < $no_of_sess} {incr i} {
	set aid $fullix($i)
	set endtime $ldata($aid,endtime)
	set list $ldata($aid,list)
	#has it timed out?
	if {(($endtime!=0)&&($time>$endtime)) | \
	    ([expr $time-$ldata($aid,lastheard)]>$timeout)} {

	    sdr_delete_session_hook $aid
	    #if the session was displayed in the listbox, delete it
	    set visix [find_listbox_index $aid $list]
	    if {$visix != -1} {
		$sessbox($list) delete [expr $visix+1].0 [expr $visix+1].end+1c
		for {set j $visix} {$j < [expr $items($list)-1]} {incr j} {
		    set ix($list,$j) $ix($list,[expr $j + 1])
		}
		unset ix($list,[expr $items($list)-1])
		incr items($list) -1
	    } 
	    #clear out the old state
	    clear_session_state $aid
	    #remove it from the full index
	    for {set j $i} \
		{$j < [expr [array size fullix]-1]} {incr j} {
              set fullix($j) $fullix([expr $j + 1])
            }
	    unset fullix([expr [array size fullix]-1])
	    incr fullnumitems -1
	    incr no_of_sess -1
	}
    }
}

#and ensure it runs the first time
after 120000 timeout_expired_sessions

proc popdown {aid} {
    set wname .desc$aid
    highlight_tag $aid popdown
    catch "destroy $wname"
    update
}
proc ispopped {aid} {
    global ldata
    return [winfo exists .desc$aid]
}
proc null {} {
}

proc highlight_url {win {inbrowser 0}} {
   set tagnum 0
   regexp {[0-9]+} [$win index end] lastline
   for {set i 1} {$i < $lastline} {incr i} {
     set line [$win get $i.0 "$i.0 lineend"]
     set start [string first "http:/" $line]
     set begin 0
     while { $start  > -1 } {
       set begin [expr $begin+$start]
       set url [$win get $i.$begin "$i.0 lineend"]
       set end [string length $url]
       set tmp [string first " " $url]
       if { ($tmp < $end) && ($tmp > -1) } { set end $tmp }
       set tmp [string first ". " $url]
       if { ($tmp < $end) && ($tmp > -1) } { set end $tmp }
       set tmp [string first ", " $url]
       if { ($tmp < $end) && ($tmp > -1) } { set end $tmp }
       set tmp [string first ">" $url]
       if { ($tmp < $end) && ($tmp > -1) } { set end $tmp }
       set tmp [string first "\"" $url]
       if { ($tmp < $end) && ($tmp > -1) } { set end $tmp }
       set tmp [string first ")" $url]
       if { ($tmp < $end) && ($tmp > -1) } { set end $tmp }
       incr tagnum
       set url$tagnum [string range $url 0 [expr $end-1]]
       $win tag add url$tagnum $i.$begin $i.[expr $end+$begin]
       set begin [expr $end+$begin+1]
       set line [string range $line $begin end]
       set start [string first "http:/" $line]
     }
   }
   for {set i 1} {$i <= $tagnum} {incr i} {
     $win tag configure url$i \
        -foreground [option get . hotForeground Sdr]
     $win tag configure url$i -relief raised
     if {$inbrowser} {
       $win tag bind url$i <1> \
	 "set urilist \"\[lrange \$urilist 0 \$uriix] [set url$i]\"; \
	  set uriix \[expr \[llength \$urilist] -1];\
	  webdisp [set url$i]"
       $win tag bind url$i <Enter> \
	   "$win tag configure url$i \
	      -foreground [option get . activehotForeground Sdr];\
	    overhref [set url$i]"
       $win tag bind url$i <Leave> \
	   "$win tag configure url$i \
	      -foreground [option get . hotForeground Sdr];\
	    overhref"
     } else {
       $win tag bind url$i <1> \
	 "get_uri [set url$i]"
       $win tag bind url$i <Enter> \
	   "$win tag configure url$i \
	      -foreground [option get . activehotForeground Sdr]"
       $win tag bind url$i <Leave> \
	   "$win tag configure url$i \
	      -foreground [option get . hotForeground Sdr]"
     }
   }
}

proc bounce_phone {win} {
    if {[winfo exists $win]} {
	switch [lindex [$win configure -bitmap] 4] {
	    phone1 {
		$win configure -bitmap phone3
		after 70 "bounce_phone $win"
	    }
	    phone2 {
		$win configure -bitmap phone4
		after 70 "bounce_phone $win"
	    }
	    phone3 {
		$win configure -bitmap phone2
		after 70 "bounce_phone $win"
	    }
	    phone4 {
		$win configure -bitmap phone1
		after 400 "bounce_phone $win"
	    }
	}
    }
}

proc popup {aid ifstyle msgsrc} {
  global ldata lang
#  if {$i==""} {return}
#  set aid $ix($i)
  if {[string compare $aid ""]==0} return
  set wname .desc$aid
  catch {destroy $wname}
  toplevel $wname
  set ldata($aid,is_popped) .desc$aid
  catch {highlight_tag $aid popup}
#commented out because it destroys SIP popups incorrectly
#  uplevel trace variable ldata($aid,session) u "\"destroy .desc$aid\""
  frame $wname.f -relief groove -borderwidth 2
  set win $wname.f
  pack $win -side top -fill both -expand true
  set infofont "[option get . infoFont Sdr]"

# Determine the bgd colour of the title bar by checking auth and enc status.
# XXX This needs checking to see that all options are accounted for
# should get: green = everything okay; 
#               red = either auth or enc failed; 
#            orange = auth is "integrity" and enc didn't fail; 
#            yellow = got some strange enc or auth type which needs handling
#              cyan = SIP (no auth or enc supported by SIP yet)     
# The background to the auth/enc messages are red, green, orange 
# (bad, good, caution) and yellow (something unknown)

  if {($msgsrc=="advert") && ($ldata($aid,trust)!="sip")} {

    set auth  $ldata($aid,authstatus)
    set enc   $ldata($aid,encstatus)
    set autht $ldata($aid,authtype) 
    set enct  $ldata($aid,enctype) 
    set authm $ldata($aid,authmessage)
    set encm  $ldata($aid,encmessage)

    putlogfile "popup: auth=$auth, autht=$autht, authm=$authm" 
    putlogfile "popup:  enc=$enc,   enct=$enct,   encm=$encm" 

# sort out the authentication background 
# combined with enc for main status and on own in auth box

    switch $auth {

      trusted        -
      TRUSTED        -
      trustworthy    -
      TRUSTWORTHY    -
      authenticated  - 
      AUTHENTICATED  {
        set bgauth "okay"
        set authcol "green"
      }

      noauth -
      NOAUTH {
        set bgauth "none"
        set authcol "yellow"
      }

      integrity -
      INTEGRITY {
        set bgauth "careful"
        set authcol "orange"
      }

      failed -
      FAILED {
        set bgauth "failed"
        set authcol "red"
      }

      default {
        set bgauth "unknown"
        set authcol "yellow"
      }

    }

# sort out the encryption background 
# combined with auth for main status and on own in enc box


    switch $enc {

      encrypted  -
      success    -
      ENCRYPTED  -
      SUCCESS    { 
        set bgenc "okay"
        set enccol "green"
      }

      noenc      - 
      NOENC      {
        set bgenc "none"
        set enccol "yellow"
      }

      failed  -
      FAILED  {
        set bgenc "failed"
        set enccol "red"
      }

      default {
        set bgenc "unknown"
        set enccol "yellow"
      }

    }

# now combine for the main status bar

    switch $bgauth {
      none {
        switch $bgenc {
          none    {set bgcolour "lightblue"}
          okay    {set bgcolour "green"    }
          failed  {set bgcolour "red"      }
          unknown {set bgcolour "yellow"   }
        }
      }
      okay {
        switch $bgenc {
          none    -
          okay    {set bgcolour "green" }
          failed  {set bgcolour "red"   }
          unknown {set bgcolour "yellow"}
        }
      }
      failed {
        set bgcolour "red" 
      }
      careful {
        switch $bgenc {
          none    -
          okay    {set bgcolour "orange"}
          failed  {set bgcolour "red"   }
          unknown {set bgcolour "yellow"}
        }
      }
      unknown {
        switch $bgenc {
          none    -
          okay    -
          unknown {set bgcolour "yellow"}
          failed  {set bgcolour "red"   }
        }
      }
    }

  } else {

# handle the SIP adverts

    set auth   "sip"
    set enc    "sip"
    set autht  "none"
    set enct   "none"
    set authm  "none"
    set encm   "none"
  
# not sure what we should do about SIP colours - there is 
# no auth/encryption so set it to cyan

    switch $auth {
      sip {
        set bgcolour "cyan"
      }
    }
  }

  if {$msgsrc=="advert"} {
      wm title $wname "Sdr: Session Information"
      wm iconname $wname "Sdr: Session Information"
  } else {
      wm title $wname "Sdr: Incoming call from $msgsrc"
      wm iconname $wname "Sdr: Incoming call from $msgsrc"
      frame $win.inv -borderwidth 2 -relief groove
      pack $win.inv -side top -fill x -expand true
      label $win.inv.l -text "Incoming Call" -font [option get . largeFont Sdr]
      pack $win.inv.l -side top
      frame $win.inv.f -borderwidth 0 
      pack $win.inv.f -side top -fill x -expand true
      label $win.inv.f.phone -bitmap phone1
      after 200 "bounce_phone $win.inv.f.phone"
      pack $win.inv.f.phone -side left
      message $win.inv.f.m -aspect 800 -text "You have an incoming call from $msgsrc inviting you to join the following session"
      pack $win.inv.f.m -side left -fill x -expand true
      posn_win_midscreen $wname
  }

  frame $win.sn -borderwidth 0
  button $win.sn.icon -bitmap [get_type_icon $ldata($aid,type) $autht $enct]\
      -relief flat -borderwidth 0 \
      -padx 0 -pady 0 -highlightthickness 0 \
      -command "explain_icon $win.sn.icon \"session is a $ldata($aid,type)\""
  pack $win.sn.icon -side left
  #label $win.sn.l -text $ldata($aid,session) -anchor n
  #log "displaying details of session called:\n   $ldata($aid,session) \n   at [getreadabletime]"
  #pack  $win.sn.l -side left -fill x -expand true
  label $win.sn.l -text "Encryption: $enct ($enc)  $ldata($aid,session)    \
        Authentication: $autht ($auth)"  -anchor n -bg $bgcolour 
# label $win.sn.l -text "Session: $ldata($aid,session) Encryption: $enc $enct  \
#       Authentication: $auth $autht"  -anchor n -bg $bgcolour -fg $fgcolour
  pack  $win.sn.l -side left -fill x -expand true
 

  frame $win.f0  -relief ridge -borderwidth 2
  text $win.f0.desc -width 40 -height 5  -wrap word -relief flat \
      -yscroll "$win.f0.sb set" -highlightthickness 0
  bind $win.f0.desc <1> {null}
  bind $win.f0.desc <Any-KeyPress> {null}
  scrollbar $win.f0.sb -command "$win.f0.desc yview" \
      -background [resource scrollbarForeground] \
      -troughcolor [resource scrollbarBackground] \
      -borderwidth 1 -relief flat \
      -highlightthickness 0

#TBD
#  -activeforeground [option get . scrollbarActiveForeground Sdr] \
#  -foreground [option get . scrollbarForeground Sdr]
#  $win.f0.desc insert 0.0 [text_wrap $ldata($aid,desc) 40]
  $win.f0.desc insert 0.0 $ldata($aid,desc)
  $win.f0.desc configure -state disabled
  pack $win.sn -side top -fill x
  pack $win.f0.sb -side right -fill y
  pack $win.f0.desc -side left -fill both -expand true
  pack $win.f0 -side top -expand true -fill both

  highlight_url $win.f0.desc
  
  set mf [option get . mediumFont Sdr]
  pack [frame $win.hidden1 -width 1 -height 1] -side top -padx 0 -pady 0
  if {$ldata($aid,tfrom)!=0} {
#      if {($ldata($aid,no_of_times)>1)||($ldata($aid,time0,no_of_rpts)>0)} {
	  case $lang in {
	      {C En} {show_times_english $win $aid}
	      default {show_times_english $win $aid}
	  }
#      } else {
#	  pack [frame $win.linfo -borderwidth 2 -relief groove] -side top -fill x
#	  label $win.linfo.from  -font $mf
#	  label $win.linfo.to -font $mf
#	  $win.linfo.from configure -text "[tt "Session takes place from"] [cropdate $ldata($aid,tfrom)] [croptime $ldata($aid,tfrom)]"
#	  $win.linfo.to configure -text "[tt to] $ldata($aid,tto)"
#	  pack $win.linfo.from -side top
#	  pack $win.linfo.to -side top
#      }
  }

  pack [frame $win.hidden2 -width 1 -height 1] -side top -padx 0 -pady 0

  global $win.visible
  set $win.visible 0
  frame $win.buttons -borderwidth 2 -relief groove
  pack $win.buttons -side top -fill x -expand true
  if {$authm != "none" || $encm != "none" } {
    if {$authm != "none" } {
#     frame $win.authmsg -borderwidth 0
#     label $win.authmsg.l -text "$authm "  -anchor n -bg $bgcolour -fg $fgcolour
#     pack  $win.authmsg.l -side left -fill x -expand true
      iconbutton $win.buttons.authmsg -text "Authentication Info"  -relief raised \
        -borderwidth 1 -command "authinfo $win $authcol \"$authm\" "\
        -font [option get . mediumFont Sdr] -pad 1
      tixAddBalloon $win.buttons.authmsg Frame [tt "Display the Authentication Security Information."]
      incr $win.visible
      pack $win.buttons.authmsg -side left -fill x -expand true
    }
  if {$encm != "none" } {
    iconbutton $win.buttons.encmsg -text "Encryption Info"  -relief raised \
      -borderwidth 1 -command "encinfo $win $enccol \"$encm\" "\
      -font [option get . mediumFont Sdr] -pad 1
    tixAddBalloon $win.buttons.encmsg Frame [tt "Display the Encryption Security Information."]
    incr $win.visible
    pack $win.buttons.encmsg -side left -fill x -expand true
  }
}
#  label $win.buttons.l -text "Show:" -font $mf
#  pack $win.buttons.l -side left

  if {$ldata($aid,uri)!=0} {
      if {$ifstyle=="norm"} {
	  set str "More\nInformation"
	  set pad 0
      } else {
	  set str "More Information"
	  set pad 1
      }
      iconbutton $win.buttons.info -text $str -bitmap www -relief raised \
	  -borderwidth 1 -command "get_uri $ldata($aid,uri)" \
	  -font [option get . mediumFont Sdr] -pad $pad

      tixAddBalloon $win.buttons.info Frame [tt "Click here for more \
information about the session. The information will be in the \
form of a web page. In case of problems with your web browser, \
please choose Preferences in the main session window then \
choose Web"]

      pack $win.buttons.info -side left -fill x -expand true
      incr $win.visible
  }
  if {$ifstyle=="norm"} {
      set str "Contact\nDetails"
      set pad 0
  } else {
      set str "Contact Details"
      set pad 1
  }
  iconbutton $win.buttons.contact -text $str -bitmap phone -relief raised \
      -borderwidth 1 -command "contact $win $aid" \
      -font [option get . mediumFont Sdr] -pad $pad
  tixAddBalloon $win.buttons.contact Frame [tt "Display the name, email address, and phone number of the person who is responsible for this session."]
  incr $win.visible
  pack $win.buttons.contact -side left -fill x -expand true
#  if {($ldata($aid,no_of_times)>1)||($ldata($aid,time0,no_of_rpts)>0)} {
#      iconbutton $win.buttons.times -text "Detailed times" -bitmap clock -relief raised \
#	  -borderwidth 1 -command "show_times $win $aid" -font [option get . mediumFont Sdr]
#      tixAddBalloon $win.buttons.times Button [tt "Display detailed information about when this session is active."]
#      incr $win.visible
#      pack $win.buttons.times -side left -fill x -expand true
#  }
  if {$ifstyle=="norm"} {
      iconbutton $win.buttons.tech -text "Media\nDetails" -command \
	  "popup $aid tech $msgsrc;break" -borderwidth 1 -relief raised \
	  -bitmap tools -font [option get . mediumFont Sdr] -pad 0
      tixAddBalloon $win.buttons.tech Frame [tt "Click here for information \
about the media used in the session and their formats, and to start up the \
media tools individually."]
      pack $win.buttons.tech -side left -fill x -expand true
      incr $win.visible
  }

  #display the conf multicast address if it's not one per media
#  if {$ldata($aid,multicast)!=""} {
#      frame $win.f1 -relief groove -borderwidth 2
#      label $win.f1.l -text [tt "Multicast address: "] -font $infofont
#      label $win.f1.d -text $ldata($aid,multicast) -relief sunken \
#	  -borderwidth 1 -font $infofont
#      label $win.f1.l2 -text [tt "ttl:"] -font $infofont
#      label $win.f1.d2 -text $ldata($aid,ttl) -relief sunken \
#	  -borderwidth 1 -font $infofont
#      pack $win.f1.l -side left
#      pack $win.f1.d -side left
#      pack $win.f1.l2 -side left
#      pack $win.f1.d2 -side left
#      pack $win.f1 -side top -fill x -expand true
#  }

   frame $win.media -width 1 -height 1
   pack $win.media -side top -fill x -expand true
   for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
#    set fname $win.media.$ldata($aid,$i,media)
    set fname $win.media.$i
    frame $fname  -borderwidth 2
    if {$ldata($aid,medianum) > 1} {
      iconbutton $fname.l1 -bitmap [get_icon $ldata($aid,$i,media)] -width 10 -text $ldata($aid,$i,media) -relief raised -borderwidth 2\
	  -command "if {\[start_media \"$aid\" $i start\]} {\
          timedmsgpopup \"\[tt \"Please wait...\"\]\" \"the $ldata($aid,$i,media) tool is starting\" 3000}"
      tixAddBalloon $fname.l1 Frame "Starts the $ldata($aid,$i,media) tool for this session"
      if {$msgsrc!="advert"} {
	  $fname.l1.workaround configure -state disabled -relief flat
      }
    } else {
#      label $fname.l1 -text [tt "Media:"] -font $infofont
      label $fname.l1 -bitmap [get_icon $ldata($aid,$i,media)]
    }
#    label $fname.d1 -text $ldata($aid,$i,media) -relief sunken -borderwidth 1\
#	-font $infofont

    label $fname.l4 -text [tt "Addr:"] -font $infofont
    entry $fname.d4  -relief sunken -borderwidth 1\
	-width 13 -font $infofont -highlightthickness 0
    $fname.d4 insert 0 $ldata($aid,$i,addr)
    if {$ldata($aid,$i,layers)>1} {
	$fname.d4 insert end "/$ldata($aid,$i,layers)"
    }

    label $fname.l5 -text [tt "TTL:"] -font $infofont
    entry $fname.d5  -relief sunken -borderwidth 1\
	-width 3 -font $infofont -highlightthickness 0
    $fname.d5 insert 0 $ldata($aid,$i,ttl)

    label $fname.l2 -text [tt "Port:"] -font $infofont
    entry $fname.d2  -relief sunken -borderwidth 1\
	-width 5 -font $infofont -highlightthickness 0
    $fname.d2 insert 0 $ldata($aid,$i,port)

    label $fname.l3 -text [tt "Format:"] -font $infofont
    entry $fname.d3  -relief sunken -borderwidth 1\
	-width 5 -font $infofont -highlightthickness 0
    $fname.d3 insert 0 [get_fmt_name $ldata($aid,$i,fmt)]

    label $fname.l7 -text [tt "Proto:"] -font $infofont
    entry $fname.d7  -relief sunken -borderwidth 1\
	-width 5 -font $infofont -highlightthickness 0
    $fname.d7 insert 0 [get_proto_name $ldata($aid,$i,proto)]

    label $fname.l8 -text [tt "Key:"] -font $infofont
    entry $fname.d8  -relief sunken -borderwidth 1\
        -width 25 -font $infofont -highlightthickness 0
 
    tixAddBalloon $fname.d8 Entry [tt "The $ldata($aid,$i,media) encryption key is shown here.  If it is blank no encryption is being used."]
 
    if { [info exists ldata($aid,$i,mediakey)] && ($ldata($aid,$i,mediakey) != "")} {
      $fname.d8 insert 0 $ldata($aid,$i,mediakey)
    }

    foreach e "$fname.d4 $fname.d5 $fname.d2 $fname.d3 $fname.d7" {
	bind $e <KeyPress> {break}
	bind $e <2> {break}
	bind $e <1> {%W selection from @%x;break}
    }

#    pack $fname.d1 -side left -expand true -fill x
if {$ifstyle=="norm"} {
#    pack $fname.l1 -side left -fill x -expand true
#    pack $fname -side left -fill x -expand true
} else {
    pack $fname.l1 -side left
    pack $fname.l3 -side left
    pack $fname.d3 -side left
    pack $fname.l7 -side left
    pack $fname.d7 -side left
    pack $fname.l4 -side left
    pack $fname.d4 -side left
    pack $fname.l2 -side left
    pack $fname.d2 -side left
    pack $fname.l5 -side left
    pack $fname.d5 -side left
    pack $fname.l8 -side left
    pack $fname.d8 -side left
    if {$ldata($aid,$i,vars) != ""} {
      label $fname.l6 -text [tt "Vars:"] -font $infofont
      entry $fname.d6  -relief sunken -borderwidth 1\
	  -font $infofont  -highlightthickness 0
      $fname.d6 insert 0 [split $ldata($aid,$i,vars) "\n"]
      bind $fname.d6 <KeyPress> {break}
      bind $fname.d6 <2> {break}
      bind $fname.d6 <1> {%W selection from @%x;break}
      pack $fname.l6 -side left 
      pack $fname.d6 -side left -expand true -fill x
    }
    pack $fname -side top -fill x
  }
    
  }
  if {$ifstyle=="tech"} {
      label $win.heard -text \
	  "[tt "Heard from"] $ldata($aid,heardfrom) [tt at] $ldata($aid,theard)" \
	  -font [option get . infoFont Sdr]
      pack $win.heard -side top
      if {$ldata($aid,source)!=$ldata($aid,heardfrom)} {
	  label $win.src -text "[tt "Originally announced from"] $ldata($aid,source)" \
	      -font [option get . infoFont Sdr]
	  pack $win.src -side top
      }
  }
  frame $win.f3 
  button $win.f3.dismiss -text [tt "Dismiss"] -relief raised \
      -command "set tmp \"$aid,is_popped\";\
                highlight_tag $aid popdown;\
                set ldata(\$tmp) -1;\
                destroy $wname" -highlightthickness 0
  tixAddBalloon $win.f3.dismiss Button [tt "Click here to dismiss this window"]
  if {$ldata($aid,medianum) > 1} {
      button $win.f3.start -relief raised \
	  -command "start_all \"$aid\"" -highlightthickness 0
      $win.f3.start configure -text [tt "Join"]
      tixAddBalloon $win.f3.start Button [tt "Start all the media tools for this conference"]
  } elseif {$ldata($aid,medianum) != 0 } {
      button $win.f3.start -text [tt "Join"] -relief raised \
	  -command "start_all \"$aid\"" -highlightthickness 0
      tixAddBalloon $win.f3.start Button [tt "Start the media tool for this conference"]
  }
  button $win.f3.invite -text [tt "Invite"] -relief raised \
      -command "embed_invite \"$aid\" $win" -highlightthickness 0
  tixAddBalloon $win.f3.invite Button [tt "Click here to invite someone to join this session"]
  
  button $win.f3.record -text [tt "Record"] -relief raised \
      -command "record \"$aid\"" -highlightthickness 0
  tixAddBalloon $win.f3.record Button [tt "Click here to record the session"]

  #Is this a session we announced?  If so, let us modify it...
  set username $ldata($aid,creator)
  set mysess 0
  if {([gethostaddr]==$ldata($aid,source)) && \
	  ([getusername]==$username) && \
          ($ldata($aid,trust)=="trusted")} {
      set mysess 1
      button $win.f3.edit -text [tt "Edit"] -relief raised \
	  -command "new \"$aid\"" -highlightthickness 0
      tixAddBalloon $win.f3.edit Button [tt "This is a session you created.  Click here to modify the session details"]

      #note this window gets destroyed from the trace on ldata($aid,session)
      button $win.f3.delete -text [tt "Delete"] -relief raised \
	  -command "delete_session \"$aid\"; \
                    set tmp \"$aid,is_popped\";\
                    set ldata(\$tmp) -1;\
                    catch \"destroy $wname\"" -highlightthickness 0
      tixAddBalloon $win.f3.delete Button [tt "This is a session you created.  Click here to delete the session announcement"]
  }
  if {$msgsrc=="advert"} {
      if {$ldata($aid,medianum) != 0 } {
	  pack $win.f3.start -side left -fill x -expand true
	  pack $win.f3.invite -side left -fill x -expand true
	  pack $win.f3.record -side left -fill x -expand true
      }
      if {$mysess==1} {
	  pack $win.f3.edit -side left -fill x -expand true
	  pack $win.f3.delete -side left -fill x -expand true
      }
      pack $win.f3.dismiss -side left -fill x -expand true
  } else {
      button $win.f3.accept -text [tt "Accept Invitation"] -relief raised \
	      -highlightthickness 0 -command \
	      "accept_invite_fix_ui $win $aid;sip_accept_invite $aid" 
      button $win.f3.refuse -text [tt "Reject Invitation"] -relief raised \
	  -command "destroy $wname;sip_refuse_invite $aid" \
	   -highlightthickness 0
      pack $win.f3.accept -side left -fill x -expand true
      pack $win.f3.refuse -side left -fill x -expand true
  }
  pack $win.f3 -side top -fill x -expand true
  move_onscreen $wname
}

proc explain_icon {win txt} {
    set icon [lindex [$win configure -bitmap] 4]
    $win configure -bitmap "" -text [tt $txt]
    set cmd "after 3000 {catch {$win configure  -bitmap $icon}}"
    eval $cmd
}

proc accept_invite_fix_ui {win aid} {
    global ldata
    pack unpack $win.f3.accept
    pack unpack $win.f3.refuse
    pack $win.f3.start -side left -fill x -expand true
    pack $win.f3.record -side left -fill x -expand true
    pack $win.f3.dismiss -side left -fill x -expand true
    if {$ldata($aid,medianum)>1} {
	for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
#	    set fname $win.media.$ldata($aid,$i,media)
	    set fname $win.media.$i
	    $fname.l1.workaround configure -state normal -relief raised
	}
    }
}
proc popup_update {aid field value} {
    set win .desc$aid.f
    catch {
	case $field in {
	    heard {
		$win.heard configure -text $value
	    }
	    src {
		$win.src configure -text $value
	    }
	    name {
		$win.sn.l configure -text $value
	    }
	    desc {
		$win.f0.desc configure -state normal
		$win.f0.desc delete 0.0 end
		$win.f0.desc insert 0.0 $value
		$win.f0.desc configure -state disabled
		highlight_url $win.f0.desc
	    }
	    from {
		$win.linfo.from configure -text $value
	    }
	    to {
		$win.linfo.to configure -text $value
	    }
	}
    }
}

proc popup_update_media {aid medianum fmt proto port ttl addr layers mediakey vars} {
    set fname .desc$aid.f.media.$medianum
    catch {
	$fname.d3 delete 0 end
	$fname.d3 insert 0 [get_fmt_name $fmt]
	$fname.d7 delete 0 end
	$fname.d7 insert 0 [get_proto_name $proto]
	$fname.d2 delete 0 end
	$fname.d2 insert 0 $port
	$fname.d5 delete 0 end
	$fname.d5 insert 0 $ttl
	$fname.d4 delete 0 end
	$fname.d4 insert 0 $addr
        $fname.d8 delete 0 end
        $fname.d8 insert 0 $mediakey
	if {$layers>1} {
	    $fname.d4 insert end "/$layers"
	}
	if {$vars != ""} {
	    set code 0
	    catch {set code [$fname.d6 delete 0 end;$fname.d6 insert 0 $vars]}
	    if {$code==0} {
		set infofont "[option get . infoFont Sdr]"
		label $fname.l6 -text "Vars:" -font $infofont
		entry $fname.d6 -relief sunken -borderwidth 1\
			-font $infofont
		$fname.d6 insert 0 $vars
		bind $fname.d6 <KeyPress> {break}
		bind $fname.d6 <1> {%W selection from @%x;break}
		bind $fname.d6 <2> {break}
		pack $fname.l6 -side left
		pack $fname.d6 -side left -expand true -fill x
	    }
	} else {
	    $fname.d6 delete 0 end
	}
    }
}

proc sameday {t1 t2} {
    if {[cropdate $t1] == [cropdate $t2]} {
	return 1
    } else {return 0}
}
proc croptime {time} {
    return "[lindex $time 3]"
}
proc croptz {time} {
    return "[lindex $time 4]"
}
proc cropdate {time} {
    return "[lindex $time 0] [lindex $time 1] [lindex $time 2]"
}
proc nicedate {time {s {}} {s2 {}}} {
    set date [cropdate $time]
    # must coordinate following "clock format" with sd_listen.c
    if {$date == [clock format [clock seconds] -format {%d %b %Y}]} {
	set hour [fixint [lindex [split [croptime $time] ":"] 0]]
	if {$hour < 8} {
		return "early this morning$s2"
	} elseif {$hour < 12} {
		return "this morning$s2"
	} elseif {$hour < 18} {
		return "this afternoon$s2"
	} elseif {$hour < 22} {
		return "this evening$s2"
	} else {
		return "tonight$s2"
	}
    }
    return "$s$date"
}

proc contact {win aid} {
    global ldata
    global $win.visible
    pack forget $win.buttons.contact
    incr $win.visible -1
    if {[set $win.visible]==0} {pack forget $win.buttons}
    frame $win.cinfo -borderwidth 2 -relief groove
    set mf [option get . mediumFont Sdr]
    pack $win.cinfo -side top -fill x -after $win.hidden2
    label $win.cinfo.created -text "Created by: $ldata($aid,creator)@$ldata($aid,createaddr)" -font $mf
    pack $win.cinfo.created  -side top
    if {$ldata($aid,tool)!="unknown"} {
	label $win.cinfo.tool -font $mf \
	    -text "Session announced using $ldata($aid,tool)"
	pack $win.cinfo.tool -after $win.cinfo.created -side top
    }
    set i 0
    foreach p $ldata($aid,phonelist) {
	pack [frame $win.cinfo.p$i] -after $win.cinfo.created -side top
	label $win.cinfo.p$i.icon -bitmap phone
	pack $win.cinfo.p$i.icon -side left

	#make this an entry not a label so we can cut from it
	entry $win.cinfo.p$i.phone -font $mf -relief flat \
	    -width [string length $p] -highlightthickness 0
	$win.cinfo.p$i.phone insert 0 $p
	bind $win.cinfo.p$i.phone <KeyPress> {break}
	bind $win.cinfo.p$i.phone <1> {%W selection from @%x;break}
	bind $win.cinfo.p$i.phone <2> {break}

	pack $win.cinfo.p$i.phone -side left
	incr i
    }
    set i 0
    foreach e $ldata($aid,emaillist) {
	pack [frame $win.cinfo.e$i] -after $win.cinfo.created -side top
	label $win.cinfo.e$i.icon -bitmap mail
        pack $win.cinfo.e$i.icon -side left

	#make this an entry not a label so we can cut from it
	entry $win.cinfo.e$i.email -font $mf -relief flat \
	    -width [string length $e] -highlightthickness 0
	$win.cinfo.e$i.email insert 0 $e
	bind $win.cinfo.e$i.email <KeyPress> {break}
	bind $win.cinfo.e$i.email <1> {%W selection from @%x;break}
	bind $win.cinfo.e$i.email <2> {break}

	pack $win.cinfo.e$i.email -side left
	incr i
    }
}
proc show_times {win aid} {
    global lang
    global $win.visible
    pack forget $win.buttons.times
    incr $win.visible -1
    if {[set $win.visible]==0} {pack forget $win.buttons}
    case $lang in {
	{C En} {show_times_english $win $aid}
	default {show_times_english $win $aid}
    }
}

proc todaytime {time} {
    #We're given a time on a particular date.  What we want is the same 
    #time today - ignoring DST changes.
    #eg given 10am July 1st EDT, on Dec 1st we want 9am EST

    if {$time > [clock seconds]} {
	return $time
    }

    set diff [expr [clock seconds] - $time]
    set days [expr $diff / 86400]
    set todaytime [expr $time + $days*86400]
    return $todaytime
}

proc text_times_english {aid} {
    global ldata
    set timestr [tt "Session will take place\n"]
    for {set i 0} {$i<$ldata($aid,no_of_times)} {incr i} {
      if {$i!=0} { set timestr "$timestr\nand "}
      if {$ldata($aid,time$i,no_of_rpts)!=0} {
	  for {set r 0} {$r<$ldata($aid,time$i,no_of_rpts)} {incr r} {
	      if {$r!=0} { append timestr "\nand " }
	      set durationstr [get_duration \
		      [get_duration_ix_by_time $ldata($aid,time$i,duration$r)]]
	      set begintime $ldata($aid,starttime,$i)
              set fromdate [cropdate $ldata($aid,tfrom,$i)]
	      if {$ldata($aid,endtime) == 0} {
		set todate "forever"	;#XXX handle this better
	      } else {
                set todate [cropdate $ldata($aid,tto,$i)]
	      }
	      for {set rno 0} {$rno<[llength $ldata($aid,time$i,offset$r)]} {incr rno} {
	      if {$rno!=0} { append timestr "\nand " }
	      set rtime [clock format \
		      [expr [todaytime $begintime]+\
			[lindex $ldata($aid,time$i,offset$r) $rno]] \
			-format {%H:%M %Z}]
	      case $ldata($aid,time$i,interval$r) in {
		  86400 {
		      append timestr "daily at $rtime for $durationstr between $fromdate and $todate"
		  }
		  604800 {
		      append timestr "weekly at $rtime on "
		      set offsets $ldata($aid,time$i,offset$r)
		      set rno [llength $offsets]
		      foreach offset $offsets {
			  if {$offset==[lindex $offsets 0]} {
			      set pad ""
			  } elseif {$offset==[lindex $offsets \
					      [expr [llength $offsets]-1]]} {
			      set pad " and "
			  } else {set pad ", "}
			  append timestr $pad
			  set curstart [expr $begintime + $offset]
			  set currtime [clock format $curstart -format {%H:%M %Z}]
			  if {[string compare $rtime $currtime] != 0} {
				append timestr "$currtime on "
				set rtime $currtime
			  }
			  append timestr [lindex [gettime $curstart] 8]
		      }
		      append timestr " for $durationstr\nfrom $fromdate to $todate"
		  }
		  1209600 {
		      set dayofweek [lindex [gettime $ldata($aid,starttime,$i)] 8]
		      append timestr "every 2 weeks at $rtime on $dayofweek for $durationstr\nfrom $fromdate to $todate"
		  }
		  default {
		      set dayofweek [lindex [gettime $ldata($aid,starttime,$i)] 8]
		      set secs $ldata($aid,time$i,interval$r)
		      set seperator {}
		      set int(604800) "weeks"
		      set int(86400) "days"
		      set int(3600) "hours"
		      set int(60) "minutes"
		      set int(1) "seconds"
		      append timestr "every "
		      foreach ix {604800 86400 3600 60 1} {
			  if {$secs > $ix} {
			      append timestr $seperator "[expr $secs/$ix] $int($ix)"
			      set seperator ", "
			      set secs [expr $secs % $ix]
			  }
		      }
		      append timestr " starting at $rtime on $dayofweek $fromdate for $durationstr until $todate"
		  }
	      }
#here	      
	      }
	      
	  }
      } else {
	  if {$ldata($aid,endtime) == 0} {
	      set timestr [format "%sstarting at %s %s %s" $timestr\
			[croptime $ldata($aid,tfrom,$i)]\
			[croptz $ldata($aid,tfrom,$i)]\
			[nicedate $ldata($aid,tfrom,$i) {on }]]
	  } elseif {[sameday $ldata($aid,tfrom,$i) $ldata($aid,tto,$i)]} {
	      set timestr [format "%sfrom %s to %s %s %s" $timestr\
			   [croptime $ldata($aid,tfrom,$i)]\
			       [croptime $ldata($aid,tto,$i)]\
			       [croptz $ldata($aid,tto,$i)]\
			       [nicedate $ldata($aid,tfrom,$i) {on }]]
	  } else {
	      set timestr [format "%sfrom %s %s to %s %s %s" $timestr\
			       [nicedate $ldata($aid,tfrom,$i) {} { at}]\
			       [croptime $ldata($aid,tfrom,$i)]\
			       [nicedate $ldata($aid,tto,$i) {} { at}]\
			       [croptime $ldata($aid,tto,$i)]\
			       [croptz $ldata($aid,tto,$i)]]
	  }
      }
  }
  return $timestr
}

proc show_times_english {win aid} {
    global ldata
    pack [message $win.msg -width 400 -justify center -borderwidth 2 -relief groove -font [option get . mediumFont Sdr]] -after $win.hidden1 -side top -fill x -expand true
    $win.msg configure -text [text_times_english $aid]
}

#proc text_wrap {t width} {
#    set rt ""
#    regsub -all "( *)(\n)( *)" $t " " t
#    if {[string length $t]<=$width} {return $t}
#    while {[string length $t]>$width} {
#	set thisline [string range [string trimleft $t] 0 [expr $width-1]]
#	
#	set eol [string last " " $thisline]
#	if {$eol<=0} {set eol [string last "\n" $thisline]}
#	if {$eol>0} {
#	    if {$rt!=""} { set rt "$rt\n[string range $t 0 $eol]"
#	    } else {set rt [string range $t 0 $eol]}
#	    set t [string trimleft [string range $t [expr $eol+1] end]]
#	} else {
#           set eol [string first " " $t]
#           if {$eol<=0} {set eol [string last "\n" $thisline]}
#           if {$eol>0} {
#	       set rt "$rt\n[string range $t 0 $eol]"
#	       set t [string trimleft [string range $t [expr $eol+1] end]]
#
#	   } else {
#	       set rt "$rt\n$t"
#	       set t ""
#	   }
#	}
#    }
#    set rt "$rt\n$t"
#    return $rt
#}
proc delete_session {aid} {
    global ldata
    ui_stop_session_ad $aid
    set ldata($aid,endtime) 1
    timeout_expired_sessions
    msgpopup [tt "Session Deleted"] [tt "The session will no longer be announced, but may take some time before it is deleted from everyone's sdr display"]
    after 1000 write_cache
}

proc record {aid} {
    global ldata
    catch {destroy .record}
    sdr_toplevel .record "Record Session"
    frame .record.f -borderwidth 2 -relief groove
    label .record.f.l -text $ldata($aid,session)
    pack .record.f.l -side top
    frame .record.f.f0 -relief sunken -borderwidth 2
    listbox .record.f.f0.lb -width 50 -height 10 \
	-yscroll ".record.f.f0.sb set" \
	-selectforeground [resource activeForeground] \
        -selectbackground [resource activeBackground] \
        -highlightthickness 0

     scrollbar .record.f.f0.sb -command ".record.f.f0.lb yview" \
	-background [resource scrollbarForeground] \
	-troughcolor [resource scrollbarBackground] \
	-highlightthickness 0

#TBD
#	-foreground [option get . scrollbarForeground Sdr] \
#	-activeforeground [option get . scrollbarActiveForeground Sdr]
    foreach i [exec ls -a] {
	.record.f.f0.lb insert end $i
    }

    pack .record.f.f0.lb -side left
    pack .record.f.f0.sb -side left -fill y
    pack .record.f.f0 -side top
    label .record.f.l2 -text [tt "File to save to:"]
    pack .record.f.l2 -side top -anchor w
    entry .record.f.entry -width 50 -relief sunken
    bind .record.f.entry <Return> "start_record \$rectime \[.record.f.entry get\] \"$aid\" record"
    .record.f.entry insert 0 [pwd]
    bind .record.f.f0.lb <1> {%W selection set [%W nearest %y];\
	.record.f.entry delete 0 end;\
	    .record.f.entry insert 0 "[pwd]/[lindex [selection get] 0]"}
    
    bind .record.f.f0.lb <Double-Button-1> "start_record \$rectime \[lindex \[selection get\] 0\] \"$aid\" record"
    pack .record.f.entry -side top -anchor w -fill x -expand true


    frame .record.f.f1
    label .record.f.f1.l -text [tt "Start Recording:"]
    global rectime
    set rectime now
    radiobutton .record.f.f1.b1 -text "now" -variable rectime \
	-value [tt "now"] \
	-highlightthickness 0 \
	-relief flat
    radiobutton .record.f.f1.b2 -text [tt "when session starts"] \
	-highlightthickness 0 \
	-variable rectime -value "start" -relief flat
    if {$ldata($aid,starttime)<[gettimeofday]} {
	.record.f.f1.b2 configure -state disabled
	.record.f.f1.b2 configure -text [tt "session has started"]
    }
    global record
    catch {unset record}
    for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
	set media $ldata($aid,$i,media)
	set record($media) 1
    }
    if {$ldata($aid,medianum)>1} {
	frame .record.f.f3 -relief groove -borderwidth 2
	for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
	    set media $ldata($aid,$i,media)
	    checkbutton .record.f.f3.b$i -text "[tt Record] $media" \
		-variable record($media)
	    pack .record.f.f3.b$i -side top -anchor w -fill x -expand true
	}
	pack .record.f.f3 -side top -fill x
    }
    pack .record.f.f1.l -side top -anchor w
    pack .record.f.f1.b1 -side top -padx 10 -anchor w
    pack .record.f.f1.b2 -side top -padx 10 -anchor w
    pack .record.f.f1 -side top -fill x
    frame .record.f.f2 -relief groove -borderwidth 2
    button .record.f.f2.rec -text [tt Record] -relief raised \
	-command "start_record  \$rectime \[.record.f.entry get\] \"$aid\" record" 

    button .record.f.f2.dismiss -text [tt Dismiss] -relief raised \
	-command {destroy .record}  -highlightthickness 0
    pack .record.f.f2.rec -side left -fill x -expand true
    pack .record.f.f2.dismiss -side left -fill x -expand true
    pack .record.f.f2 -side top -fill x
    pack .record.f -side top
    move_onscreen .record
}

proc start_record {time file aid rname} {
    global ldata
    if {[file isdirectory $file]} {
	.record.f.f0.lb delete 0 end
	cd $file
	foreach i [exec ls -a] {
	    .record.f.f0.lb insert end $i
	}
	.record.f.entry delete 0 end
	.record.f.entry insert 0 [pwd]
	msgpopup [tt "Error"] [tt "Please give a filename in addition to a directory"]
    } else {
	if {$time=="now"} {
	  timedmsgpopup [tt "Starting Recording"] "" 3000
	  start_recorder $aid $file $rname
	  destroy .record
	} else {
	  timedmsgpopup [tt "Recording Prepared"] \
	      [tt "The recording will start at $ldata($aid,tfrom)"] 6000
	  msgpopup [tt "Error"] [tt "feature is not yet implemented - sorry"]
	  
	  destroy .record
	}
    }
}

proc start_recorder {aid fname rname} {
    global ldata $rname
    set file [open "|record_session $fname" w]
    set source [dotted_decimal_to_decimal $ldata($aid,source)]
    set heardfrom [dotted_decimal_to_decimal $ldata($aid,heardfrom)]
    set lastheard $ldata($aid,lastheard)
    set sap_addr $ldata($aid,sap_addr)
    set sap_port $ldata($aid,sap_port)
    set trust $ldata($aid,trust)
    # XXX there should be a subroutine which returns an n= line
    puts $file "n=$source $heardfrom $lastheard $sap_addr $sap_port $trust"
    puts $file [make_session $aid $rname]
    close $file
}

proc get_uri {uri} {
    global webtype webclient 
    case $webtype {
	sendmosaic {
	    putlogfile "Sending to Browser"
	    exec xm $uri &
	}
	startmosaic {
	    putlogfile "Starting $webclient"
	    exec $webclient $uri &
	}
	builtin {
	    webdisp $uri
	}
    }
}

proc stuff_mosaic {} {
    global webtype webclient
    if { [catch {selection get} text] == 0 } {
        get_uri $text
    }
}

proc preferences2 {} {
    global showwhich balloonHelp binder_tags prefprocs
    catch {destroy .prefs}
    sdr_toplevel .prefs "Preferences"
    posn_win .prefs

    frame .prefs.f3 -relief groove -borderwidth 2
    label .prefs.f3.l -text [tt "Help mode:"]
    global balloonHelp
    checkbutton .prefs.f3.mode -text [tt "Balloon Help"] \
	-highlightthickness 0 \
	-variable balloonHelp -command {set_balloon_help $balloonHelp}\
	-onvalue 1 -offvalue 0 -relief flat
    tixAddBalloon .prefs.f3.mode Button [tt "Turn Balloon Help on and off"]
    hlfocus .prefs.f3.mode
    pack .prefs.f3.l -side left -anchor w
    pack .prefs.f3.mode -side left -anchor w
    pack .prefs.f3 -side top -anchor w -fill x -expand true

    frame .prefs.f0
    pack .prefs.f0 -side top
    canvas .prefs.f0.c -width 600 -height 300 
#-background [option get . prefsBackground Sdr]
    pack .prefs.f0.c -side top

    set xpos 20
    foreach pref $prefprocs {
	set wname ".prefs.f0.c.$pref"
	pref_$pref copyin
	set bname [pref_$pref create $wname 580 200]
	set balloon [pref_$pref balloon]
	set xpos \
	    [add_binder_tag $pref .prefs.f0.c $xpos $bname $balloon $wname]
    }


    bind .prefs.f3.mode <Tab> "focus $binder_tags(show,button)"
    post_binder .prefs.f0.c show
    label .prefs.help -relief raised -borderwidth 1 \
	    -font [option get . infoFont Sdr]
    pack  .prefs.help -side top -fill x -expand true 
    frame .prefs.f1
    button .prefs.f1.cancel -text [tt "Cancel"] -command {destroy .prefs}
    tixAddBalloon .prefs.f1.cancel Button [tt "Discard the changes you've made"]
    pack .prefs.f1.cancel -side left -fill x -expand true
    button .prefs.f1.ok -text [tt "Apply Preferences"] -command {\
      allprefprocs copyout;\
      reshow_sessions $showwhich;\
      catch {destroy .ps};\
      destroy .prefs}
    tixAddBalloon .prefs.f1.ok Button [tt "Apply the changes you've made"]
    pack .prefs.f1.ok -side left -fill x -expand true
    button .prefs.f1.save -text [tt "Save & Apply Preferences"] -command {\
      allprefprocs copyout;\
      reshow_sessions $showwhich;\
      save_prefs;\
      catch {destroy .ps};\
      destroy .prefs}
    tixAddBalloon .prefs.f1.save Button [tt "Apply the changes you've made and also save them for next time you start up sdr"]
    pack .prefs.f1.save -side left -fill x -expand true
    pack .prefs.f1 -side top -fill x -expand true
    move_onscreen .prefs
    log "showing preferences at [getreadabletime]"
}

proc bind_help {win str} {
    global last_help
    bind $win <Enter> "prefs_help \"$str\""
    bind $win <Leave> "after 1000 \
	    {if {\[set last_help\]==\"$str\"} { prefs_help \"\"}}"
}
proc prefs_help {str} {
    global last_help
    catch {.prefs.help configure -text $str}
    set last_help $str
}

proc allprefprocs {what {arg2 {}}} {
    global prefprocs

    foreach i $prefprocs {
	catch { pref_$i $what $arg2 }
    }
    debug "allprefprocs $what .. done"
}

set binder_taglist {}
set binder_winlist {}
proc add_binder_tag {tag canv xpos txt balloon win} {
    global font binder_taglist binder_winlist binder_tags
    set wth [expr [string length $txt] * 8]
    button $canv.b$xpos -text $txt -relief raised -borderwidth 1\
	-highlightthickness 0
    tixAddBalloon $canv.b$xpos Button $balloon
    bind $canv.b$xpos <Return> "focus $win"
    hlfocus $canv.b$xpos
    frame $canv.h$xpos -width [expr [winfo reqwidth $canv.b$xpos]+4] -height 5
    $canv addtag b$xpos withtag \
	[$canv create window $xpos 5 -window $canv.b$xpos -anchor nw]
    set binder_tags($tag,x) $xpos
    set binder_tags($tag,win) $win
    set binder_tags($tag,hack) $canv.h$xpos
    set binder_tags($tag,button) $canv.b$xpos
    set binder_tags($tag,w) w$xpos
    set binder_tags($tag,h) h$xpos
    set binder_tags($tag,b) b$xpos
    $canv.b$xpos configure -command "post_binder $canv $tag"
    set binder_taglist "$binder_taglist $canv.b$xpos"
    set binder_winlist "$binder_winlist w$xpos h$xpos"
    return [expr $xpos+[winfo reqwidth $canv.b$xpos]+10]
}

proc post_binder {canv tag} {
    global binder_tags
    lower_binder_tags $canv
    $canv addtag $binder_tags($tag,w) withtag \
	[$canv create window 10 \
	 [expr [winfo reqheight $binder_tags($tag,button)]+5]\
	     -window $binder_tags($tag,win) -anchor nw]
    $canv addtag $binder_tags($tag,h) withtag \
	[$canv create window [expr $binder_tags($tag,x)+0] \
	 [expr [winfo reqheight $binder_tags($tag,button)]+5]\
	     -window $binder_tags($tag,hack) -anchor nw]
    $binder_tags($tag,button) configure -borderwidth 3
    $canv raise $binder_tags($tag,h) $binder_tags($tag,b)
}

proc lower_binder_tags {canv} {
    global binder_taglist binder_winlist
    foreach tag $binder_taglist {
	$tag configure -borderwidth 1
    }
    foreach win $binder_winlist {
	$canv delete $win
    }
}

# Variables:
# prefs(show_showwhich) is a copy of $showwhich
# prefs(show_aids) is a copy of the aids in $fullix; this is private to
#  the preferences routine so that added sessions don't make things confusing
# prefs(show_aid_$aid) is a copy of ldata($aid,vstate)
#
proc pref_show {cmd {arg1 {}} {arg2 {}} {arg3 {}}} {
    global showwhich showwhichfilter filters prefs fullix fullnumitems ldata

    switch $cmd {
	copyin		{
			set prefs(show_showwhich) $showwhich
                        foreach filter [array names showwhichfilter] {
			    set prefs(show_showwhichfilter,$filter) \
				    $showwhichfilter($filter)
			}
			foreach i [array names prefs "show_aid_*"] {
			    unset prefs($i)
			}
			set prefs(show_aids) {}
			for {set i 0} {$i < $fullnumitems} {incr i} {
			    set aid $fullix($i)
			    lappend prefs(show_aids) $aid
			    set prefs(show_aid_$aid) $ldata($aid,vstate)
			}
			}

	copyout		{
			set showwhich $prefs(show_showwhich)
                        foreach tag [array names prefs] {
			    set lst [split $tag ","]
			    if {[lindex $lst 0]==\
				    "show_showwhichfilter"} {
				set showwhichfilter([lindex $lst 1]) \
					$prefs($tag)
			    }
			}
			foreach aid $prefs(show_aids) {
			    set ldata($aid,vstate) $prefs(show_aid_$aid)
			}
			}

	defaults	{
	                foreach filter $filters {
			    set prefs(show_showwhichfilter,$filter) 1
			}
			set prefs(show_showwhich) all
			set prefs(show_aids) {}
			for {set i 0} {$i < $fullnumitems} {incr i} {
			    set aid $fullix($i)
			    lappend prefs(show_aids) $aid
			    set prefs(show_aid_$aid) 1
			}
			}

	create		{
			select_show_sess $arg1 $arg2 $arg3
			return "Sessions"
			}
	balloon         {
	                return "Select the sessions you would like listed in the main session window"
		        }
	save		{
			puts $arg1 [list set showwhich $showwhich]
	                foreach filter [array names showwhichfilter] {
			    puts $arg1 [list set showwhichfilter($filter) \
				    $showwhichfilter($filter)]
			}
			for {set i 0} {$i < $fullnumitems} {incr i} {
			    set aid $fullix($i)
			    if {$ldata($aid,vstate)==0} {
				puts $arg1 "set t $aid; # $ldata($aid,session)"
				puts $arg1 {set ldata($t,vstate) 0}
			    }
			}
			}
    }
}

set filters ""

proc select_show_sess {win width height} {
    global prefs showwhichfilter filters

    frame $win -relief raised -borderwidth 3
    frame $win.setw -borderwidth 0 -height 1 -width $width
    pack $win.setw -side top
    frame $win.f
    pack $win.f -side top -fill x -expand true -pady 5
    frame $win.f.l
    pack $win.f.l -side left -fill x -anchor n -expand true
    frame $win.f.r
    pack $win.f.r -side right -anchor n
    frame $win.f.l.f -borderwidth 2 -relief groove
    pack $win.f.l.f -side top -anchor n -ipadx 10 -ipady 10
    label $win.f.l.f.l -text "Show which sessions:" 
    pack $win.f.l.f.l -side top -pady 5
    #yeuch - hate making this global
    radiobutton $win.f.l.f.r1 -text [tt "all sessions"] \
	-highlightthickness 0 -command "pref_sess_enable $win.f.r"\
	-variable prefs(show_showwhich) -value all -relief flat 
    bind_help $win.f.l.f.r1 [tt "Select this to show all the currently advertised sessions in the main sdr window"]
    tixAddBalloon $win.f.l.f.r1 Button [tt "Select this to show all the currently advertised sessions"]
    pack $win.f.l.f.r1 -side top -anchor w -pady 5
    radiobutton $win.f.l.f.r2 -text [tt "preferred sessions"] \
	-highlightthickness 0 -command "pref_sess_enable $win.f.r"\
	-variable prefs(show_showwhich) -value pref -relief flat
    bind_help $win.f.l.f.r2 [tt "Select this to show only sessions you chose, then select the sessions by clicking on them in this window."]
    tixAddBalloon $win.f.l.f.r2 Button [tt "Select this to show only the sessions you've chosen."]
    pack $win.f.l.f.r2 -side top -anchor w -pady 5
    radiobutton $win.f.l.f.r3 -text [tt "current sessions"] \
	-highlightthickness 0 -command "pref_sess_enable $win.f.r"\
	-variable prefs(show_showwhich) -value current -relief flat
    bind_help $win.f.l.f.r3 [tt "Select this to show only sessions that are currently taking place"]
    tixAddBalloon $win.f.l.f.r3 Button [tt "Select this to show only sessions that are currently taking place."]
    pack $win.f.l.f.r3 -side top -anchor w -pady 5
    radiobutton $win.f.l.f.r4 -text [tt "future sessions"] \
	-highlightthickness 0 -command "pref_sess_enable $win.f.r"\
	-variable prefs(show_showwhich) -value future -relief flat
    bind_help $win.f.l.f.r4 [tt "Select this to show only future sessions in the main sdr window"]
    tixAddBalloon $win.f.l.f.r4 Button [tt "Select this to show only future sessions"]
    pack $win.f.l.f.r4 -side top -anchor w -pady 5

    label $win.f.l.f.l2 -text "Additional filters:"
    pack $win.f.l.f.l2 -side top -pady 5

    checkbutton $win.f.l.f.c1 -text "Hide test sessions" \
	    -variable prefs(show_showwhichfilter,test) -relief flat \
	    -highlightthickness 0
    #extend the list of filters
    lappend filters test
    pack $win.f.l.f.c1 -side top -anchor w -pady 5

    message $win.f.l.msg -aspect 500 -text ""
    pack $win.f.l.msg -side top
    uplevel trace variable showwhich w "\"set_showmsg $win\""
    hlfocus $win.f.l.f.r1
    hlfocus $win.f.l.f.r2
    hlfocus $win.f.l.f.r3
    hlfocus $win.f.l.f.r4
#    pack $win.f.l.f.mod -side top -anchor w
    pref_sessions $win.f.r
    pref_sess_enable $win.f.r
    frame $win.f2 -borderwidth 0 -relief flat -width 1 -height \
        [expr $height - [winfo reqheight $win]]
    pack $win.f2 -side top
}

proc set_showmsg {win args} {
    global showwhich
    if {[winfo exists $win.f.l.msg]} {
	if {$showwhich == "pref"} {
	    $win.f.l.msg configure -text "Select the sessions you wish to be visible."
	} else {
	    $win.f.l.msg configure -text ""
	}
    }
}

proc pref_web {cmd {arg1 {}} {arg2 {}} {arg3 {}}} {
    global prefs webproxy webclient webtype

    switch $cmd {
	copyin		{
			set prefs(web_webproxy) $webproxy
			set prefs(web_webclient) $webclient
			set prefs(web_webtype) $webtype
			}

	copyout		{
			set webproxy $prefs(web_webproxy)
			set webclient $prefs(web_webclient)
			set webtype $prefs(web_webtype)
			}

	defaults	{
			set prefs(web_webproxy) {}
			set prefs(web_webclient) Mosaic
			set prefs(web_webtype) builtin
			}

	create		{
			select_show_web $arg1 $arg2 $arg3
			return "Web"
			}

        balloon         {
	                return "Select the way you would like to access web pages"
		        }

	save		{
			puts $arg1 [list set webtype $webtype]
			puts $arg1 [list set webclient $webclient]
			puts $arg1 [list set webproxy $webproxy]
			}
    }
}

proc select_show_web {win width height} {
    global prefs

    frame $win -borderwidth 3 -relief raised
    frame $win.setw -borderwidth 0 -height 1 -width $width
    pack $win.setw -side top
    frame $win.f -borderwidth 2 -relief groove
    pack $win.f -side top -anchor n -pady 5 -ipadx 10 -ipady 10
    label $win.f.l -text "Web Links:"
    radiobutton $win.f.r1 -text [tt "Use web browser already running"] \
	    -highlightthickness 0 \
	    -variable prefs(web_webtype) -value sendmosaic -relief flat \
	    -command {msgpopup [tt "Note..."] [tt "this works with Mosaic and Netscape, not other browsers - you need the xm script"]}
    bind_help $win.f.r1 [tt "Select this to send URLs to a copy of netscape or Mosaic already running on your machine"]
    frame $win.f.f
    radiobutton $win.f.f.r2 -text [tt "Start web browser"] \
	    -highlightthickness 0 \
	    -variable prefs(web_webtype) -value startmosaic -relief flat
    bind_help  $win.f.f.r2 [tt "Select this to start a new copy of the web browser for each URL."]
    entry $win.f.f.wwwname -width 10 -relief sunken -background [option get . entryBackground Sdr] -textvariable prefs(web_webclient)

    frame $win.f.f2
    radiobutton $win.f.f2.r4 -text [tt "Use sdr's built in web browser"] \
	    -highlightthickness 0 \
	    -variable prefs(web_webtype) -value builtin -relief flat
    bind_help $win.f.f2.r4 [tt "Select this to use sdr's built in web browser.  This won't use additional colours, so is recommended on 8 bit displays"]
    frame $win.f.f2.f
    label $win.f.f2.f.l1 -text [tt "      Proxy:"]
    label $win.f.f2.f.l2 -text [tt "in the form \"host:port\""] \
	    -font [option get . infoFont Sdr]
    entry $win.f.f2.f.wwwproxy -width 25 -relief sunken -background [option get . entryBackground Sdr] -textvariable prefs(web_webproxy)
    bind_help $win.f.f2.f.wwwproxy [tt "Enter your web proxy in the form ``host:port''.  This is optional."]
    tixAddBalloon $win.f.f2 Frame [tt "Enter your web proxy in the form \"host:port\"."]
    

    radiobutton $win.f.r3 -text [tt "Add URL to clipboard"] \
	    -highlightthickness 0 \
	    -variable prefs(web_webtype) -value cutbuffer -relief flat
    bind_help $win.f.r3  [tt "Select this to only copy URLs to the clipboard"]
    hlfocus $win.f.r1
    hlfocus $win.f.f.r2
    hlfocus $win.f.f2.r4
    hlfocus $win.f.r3
    pack $win.f.l -side top -pady 5
    pack $win.f.r1 -side top -anchor w -pady 5
    pack $win.f.f -side top -anchor w -pady 5
    pack $win.f.f.r2 -side left -anchor w -pady 5

    pack $win.f.f2 -side top -anchor w -pady 5
    pack $win.f.f2.r4 -side top -anchor w -pady 5
    pack $win.f.f2.f -side top
    pack $win.f.f2.f.l1 -side left
    pack $win.f.f2.f.l2 -side left
    pack $win.f.f2.f.wwwproxy -side left

    pack $win.f.r3 -side top -anchor w -pady 5
    pack $win.f.f.wwwname -side right
    frame $win.f3 -borderwidth 0 -relief flat -width 1 -height \
        [expr $height - [winfo reqheight $win]]
    pack $win.f3 -side top
}

proc pref_ifstyle {cmd {arg1 {}} {arg2 {}} {arg3 {}}} {
    global prefs ifstyle showwhich

    switch $cmd {
	copyin		{
			set prefs(ifstyle_create) $ifstyle(create)
			set prefs(ifstyle_view) $ifstyle(view)
			set prefs(ifstyle_labels) $ifstyle(labels)
			set prefs(ifstyle_list) $ifstyle(list)
			set prefs(ifstyle_order) $ifstyle(order)
			}

	copyout		{
			set ifstyle(create) $prefs(ifstyle_create)
			set ifstyle(view) $prefs(ifstyle_view)
			if {[info exists ifstyle(labels)]\
			    &&($ifstyle(labels)!=$prefs(ifstyle_labels))} {
				set ifstyle(labels) $prefs(ifstyle_labels)
				build_interface again
			}
			set ifstyle(labels) $prefs(ifstyle_labels)
			if {([info exists ifstyle(list)]\
			    &&($ifstyle(list)!=$prefs(ifstyle_list)))\
			    ||([info exists ifstyle(order)]\
                            &&($ifstyle(order)!=$prefs(ifstyle_order)))} {
			    set ifstyle(list) $prefs(ifstyle_list)
			    set ifstyle(order) $prefs(ifstyle_order)
			    resort_sessions
		        } else {
			    set ifstyle(order) $prefs(ifstyle_order)
			    set ifstyle(list) $prefs(ifstyle_list)
			}
			}

	defaults	{
			set prefs(ifstyle_create) norm
			set prefs(ifstyle_view) tech
			set prefs(ifstyle_labels) short
			set prefs(ifstyle_list) logo
			set prefs(ifstyle_order) alphabetic
			}

	create		{
			select_if_style $arg1 $arg2 $arg3
			return "Interface"
			}

        balloon         {
	                return "Select whether you want a normal interface or a technical interface when creating and viewing sessions"
	  	        }
 
	save		{
			puts $arg1 [list set ifstyle(create) $ifstyle(create)]
			puts $arg1 [list set ifstyle(view) $ifstyle(view)]
			puts $arg1 [list set ifstyle(labels) $ifstyle(labels)]
			puts $arg1 [list set ifstyle(list) $ifstyle(list)]
			puts $arg1 [list set ifstyle(order) $ifstyle(order)]
			}
    }
}
proc select_if_style {win width height} {
    frame $win -borderwidth 3 -relief raised
    frame $win.setw -borderwidth 0 -height 1 -width $width
    pack $win.setw -side top

    label $win.l -text "Interface Style"
    pack $win.l -side top
    frame $win.f
    pack $win.f -side top -expand true -fill x
    frame $win.f.l -relief groove -borderwidth 2
    pack $win.f.l -side left -fill y -expand true
    label $win.f.l.l -text "Create Session:"
    pack $win.f.l.l -side top -anchor w
    radiobutton $win.f.l.a -text "Normal Interface" \
	-highlightthickness 0 \
	-variable prefs(ifstyle_create) -value norm
    bind_help $win.f.l.a [tt "Select this to use the normal interface to create new sessions"]
    pack $win.f.l.a -side top -anchor w
    radiobutton $win.f.l.b -text "Technical Interface" \
	-highlightthickness 0 \
	-variable prefs(ifstyle_create) -value tech    
    bind_help $win.f.l.b [tt "Select this to use the more complicated technical interface to create new sessions"]
    pack $win.f.l.b -side top -anchor w

    frame $win.f.m -relief groove -borderwidth 2
    pack $win.f.m -side left -fill y -expand true
    label $win.f.m.l -text "View Session:"
    pack $win.f.m.l -side top -anchor w
    radiobutton $win.f.m.a -text "Normal Interface" \
	-highlightthickness 0 \
	-variable prefs(ifstyle_view) -value norm
    bind_help $win.f.m.a [tt "Select this to use the normal interface to view the details of sessions"]
    pack $win.f.m.a -side top -anchor w
    radiobutton $win.f.m.b -text "Technical Interface" \
	-highlightthickness 0 \
	-variable prefs(ifstyle_view) -value tech
    bind_help  $win.f.m.b [tt "Select this to use the more complicated technical interface to view the details of sessions"]
    pack $win.f.m.b -side top -anchor w

    frame $win.f.r -relief groove -borderwidth 2
    pack $win.f.r -side left -fill y -expand true
    label $win.f.r.l -text "Label Detail:"
    pack $win.f.r.l -side top -anchor w
    radiobutton $win.f.r.a -text "Long labels (beginnner mode)" \
	-highlightthickness 0 \
	-variable prefs(ifstyle_labels) -value long
    bind_help $win.f.r.a [tt "Select this to obtain long labels and additional explanations as to what to do"]
    pack $win.f.r.a -side top -anchor w
    radiobutton $win.f.r.b -text "Short Labels (expert mode)" \
	-highlightthickness 0 \
	-variable prefs(ifstyle_labels) -value short
    bind_help $win.f.r.b [tt "Select this to obtain short labels and an interface less cluttered with help messages"]
    pack $win.f.r.b -side top -anchor w

    frame $win.f2
    frame $win.f2.r -relief groove -borderwidth 2
    pack $win.f2.r -side left -fill y -expand true
    label $win.f2.r.l -text "Session Listing:"
    pack $win.f2.r.l -side top -anchor w
    radiobutton $win.f2.r.r1 -text "List Alphabetically" \
	    -variable prefs(ifstyle_order) -value alphabetic \
	    -highlightthickness 0
    pack $win.f2.r.r1  -side top -anchor w
    radiobutton $win.f2.r.r2 -text "List by Session Type" \
	    -variable prefs(ifstyle_order) -value type \
	    -highlightthickness 0
    pack $win.f2.r.r2  -side top -anchor w
    checkbutton $win.f2.r.b -text "Show session type" \
	    -variable prefs(ifstyle_list) -onvalue logo -offvalue normal \
	    -highlightthickness 0
    pack $win.f2.r.b -side top
    pack $win.f2 -side top -anchor w -pady 10 -padx 15
    

    frame $win.f3 -borderwidth 0 -relief flat -width 1 -height \
        [expr $height - [winfo reqheight $win]]

    hlfocus $win.f.l.a
    hlfocus $win.f.l.b
    hlfocus $win.f.m.a
    hlfocus $win.f.m.b
    hlfocus $win.f.r.a
    hlfocus $win.f.r.b

    pack $win.f3 -side top
}

proc pref_pers {cmd {arg1 {}} {arg2 {}} {arg3 {}}} {
    global prefs yourname youremail yourphone youralias sip_server_url

    switch $cmd {
	copyin		{
			set prefs(pers_name) $yourname
			set prefs(pers_email) $youremail
			set prefs(pers_phone) $yourphone
	                set prefs(pers_alias) $youralias
	                set prefs(pers_sipserv) $sip_server_url
			}

	copyout		{
			set yourname $prefs(pers_name)
			set youremail $prefs(pers_email)
			set yourphone $prefs(pers_phone)
	                set youralias $prefs(pers_alias)
	                set sip_server_url $prefs(pers_sipserv)
			}

	defaults	{
			# XXX this is *wrong*
			# if there is going to be a UI "defaults" button
			set prefs(pers_name) {}
			set prefs(pers_email) {}
			set prefs(pers_phone) {}
			set prefs(pers_alias) {}
			set prefs(pers_sipserv) {}
			}

	create		{
			select_your_info $arg1 $arg2 $arg3
			return "You"
			}

        balloon         {
                        return "Enter your personal details here. They will be added to sessions you create so people can contact you if there is a problem."
		        }

	save		{
			puts $arg1 [list set yourname $yourname]
			puts $arg1 [list set youremail $youremail]
			puts $arg1 [list set yourphone $yourphone]
	                puts $arg1 [list set youralias $youralias]
	                puts $arg1 [list set sip_server_url $sip_server_url]
			}
    }
}


proc select_your_info {win width height} {
    global prefs

    frame $win -borderwidth 3 -relief raised
    frame $win.setw -borderwidth 0 -height 1 -width $width
    pack $win.setw -side top

    label $win.l -text [tt "Your Name, Email Address and Phone Number"]
    bind  $win.l <Map> {prefs_help [tt "These will be added to sessions you create so people can contact you if there is a problem"]}
    bind $win.l <Unmap> {prefs_help ""}
    pack $win.l -side top
    frame $win.f
    pack $win.f -side top
    frame $win.f.n
    pack $win.f.n -side top -fill x -expand true -pady 5
    label $win.f.n.l -text [tt "Name:"]
    pack $win.f.n.l -side left
    entry $win.f.n.e -width 30 -relief sunken -background [option get . entryBackground Sdr] -textvariable prefs(pers_name)
    pack $win.f.n.e -side right
    frame $win.f.e
    pack $win.f.e -side top -fill x -expand true -pady 5
    label $win.f.e.l -text [tt "Email:"]
    pack $win.f.e.l -side left
    entry $win.f.e.e -width 30 -relief sunken -background [option get . entryBackground Sdr] -textvariable prefs(pers_email)
    pack $win.f.e.e -side right
    frame $win.f.p
    pack $win.f.p -side top -fill x -expand true -pady 5
    label $win.f.p.l -text [tt "Phone:"]
    pack $win.f.p.l -side left
    entry $win.f.p.e -width 30 -relief sunken -background [option get . entryBackground Sdr] -textvariable prefs(pers_phone)
    pack $win.f.p.e -side right
    message $win.f.sipa -aspect 400 -font [option get . infoFont Sdr] -text \
	    "A SIP alias is a name people can put in a session invitation to call you.  Normally they will use your username, but if you want sdr to answer calls addressed to a more human-readable name, you can add it here.  You cannot add another valid username."
    pack $win.f.sipa -side top
    frame $win.f.a
    pack $win.f.a -side top -fill x -expand true -pady 5
    label $win.f.a.l -text [tt "SIP Alias:"]
    pack $win.f.a.l -side left
    entry $win.f.a.e -width 30 -relief sunken -background [option get . entryBackground Sdr] -textvariable prefs(pers_alias)
    pack $win.f.a.e -side right

    frame $win.f.ss
    pack $win.f.ss -side top -fill x -expand true -pady 5
    label $win.f.ss.l -text [tt "SIP Server URL:"]
    pack $win.f.ss.l -side left
    entry $win.f.ss.e -width 30 -relief sunken -background [option get . entryBackground Sdr] -textvariable prefs(pers_sipserv)
    pack $win.f.ss.e -side right

    frame $win.f2 -borderwidth 0 -relief flat -width 1 -height \
        [expr $height - [winfo reqheight $win]]
    pack $win.f2 -side top
}

proc pref_people {cmd {arg1 {}} {arg2 {}} {arg3 {}}} {
    global prefs

    switch $cmd {
	copyin		{
	                address_book_copyin
			}

	copyout		{
	                address_book_copyout
			}

	defaults	{
			}

	create		{
			select_address_book $arg1 $arg2 $arg3
			return "People"
			}

        balloon         {
                        return "Use the address book to store the addresses of people you call frequently."
		        }

	save		{
	                save_address_book $arg1
			}
    }
}


proc preferences {} {
    global showwhich webtype webclient webproxy balloonHelp
    catch {destroy .prefs}
    sdr_toplevel .prefs "Preferences"
    posn_win .prefs

    frame .prefs.f3 -relief groove -borderwidth 2
    label .prefs.f3.l -text [tt "Help mode:"]
    global balloonHelp
    checkbutton .prefs.f3.mode -text [tt "Balloon Help"] \
	-highlightthickness 0 \
	-variable balloonHelp -command {set_balloon_help $balloonHelp}\
	-onvalue 1 -offvalue 0 -relief flat
    tixAddBalloon .prefs.f3.mode Button [tt "Turn Balloon Help on and off"]
    pack .prefs.f3.l -side left -anchor w
    pack .prefs.f3.mode -side left -anchor w
    pack .prefs.f3 -side top -anchor w -fill x -expand true

    frame .prefs.f0
    frame .prefs.f0.f0 -relief groove -borderwidth 2
    label .prefs.f0.f0.l -text "Show which sessions:" 
    #yeuch - hate making this global
    radiobutton .prefs.f0.f0.r1 -text [tt "all sessions"] \
	-highlightthickness 0 \
	-variable showwhich -value all -relief flat
    tixAddBalloon .prefs.f0.f0.r1 Button [tt "Select this to show all the currently advertised sessions"]
    radiobutton .prefs.f0.f0.r2 -text [tt "preferred sessions"] \
	-highlightthickness 0 \
	-variable showwhich -value pref -relief flat
    tixAddBalloon .prefs.f0.f0.r2 Button [tt "Select this to show only the sessions you've chosen.  Press \"Specify Preferred Sessions\" to view your chosen sessions"]
    radiobutton .prefs.f0.f0.r3 -text [tt "current sessions"] \
	-highlightthickness 0 \
	-variable showwhich -value current -relief flat
    tixAddBalloon .prefs.f0.f0.r3 Button [tt "Select this to show only sessions that are currently active"]
    radiobutton .prefs.f0.f0.r4 -text [tt "future sessions"] \
	-highlightthickness 0 \
	-variable showwhich -value future -relief flat
    tixAddBalloon .prefs.f0.f0.r4 Button [tt "Select this to show only future sessions"]
    button .prefs.f0.f0.mod -text [tt "Specify Preferred Sessions"] \
        -command "pref_sessions"
    tixAddBalloon .prefs.f0.f0.mod Button [tt "Press to view or change your chosen list of sessions"]
    pack .prefs.f0.f0.l -side top
    pack .prefs.f0.f0.r1 -side top -anchor w
    pack .prefs.f0.f0.r2 -side top -anchor w
    pack .prefs.f0.f0.r3 -side top -anchor w
    pack .prefs.f0.f0.r4 -side top -anchor w
    pack .prefs.f0.f0.mod -side top -anchor w
    pack .prefs.f0.f0 -side left -anchor n
    frame .prefs.f0.f1 -relief groove -borderwidth 2
    label .prefs.f0.f1.l -text "Web Links:"
     radiobutton .prefs.f0.f1.r1 -text [tt "Send to Web Browser"] \
	-highlightthickness 0 \
	-variable webtype -value sendmosaic -relief flat \
	-command {msgpopup [tt "Note..."] [tt "this works with Mosaic and Netscape, not other browsers - you need the xm script"]}
     radiobutton .prefs.f0.f1.r2 -text [tt "Start WWW Client"] \
	-highlightthickness 0 \
	-variable webtype -value startmosaic -relief flat
     radiobutton .prefs.f0.f1.r4 -text [tt "Built in"] \
	-highlightthickness 0 \
	-variable webtype -value builtin -relief flat
     radiobutton .prefs.f0.f1.r3 -text [tt "Add to cut buffer"] \
	-highlightthickness 0 \
	-variable webtype -value cutbuffer -relief flat
    frame .prefs.f0.f1.f
    label .prefs.f0.f1.f.l -text [tt "WWW Client"]
    entry .prefs.f0.f1.f.wwwname -width 10 -relief sunken
    .prefs.f0.f1.f.wwwname insert 0 $webclient
    frame .prefs.f0.f1.f2
    label .prefs.f0.f1.f2.l -text [tt "WWW Proxy"]
    entry .prefs.f0.f1.f2.wwwproxy -width 15 -relief sunken
    .prefs.f0.f1.f2.wwwproxy insert 0 $webproxy
    tixAddBalloon .prefs.f0.f1.f2 Frame [tt "Enter your web proxy in the form \"host:port\"."]
    pack .prefs.f0.f1.l -side top
    pack .prefs.f0.f1.r1 -side top -anchor w
    pack .prefs.f0.f1.r2 -side top -anchor w
    pack .prefs.f0.f1.r4 -side top -anchor w
    pack .prefs.f0.f1.r3 -side top -anchor w
    pack .prefs.f0.f1.f.l -side left
    pack .prefs.f0.f1.f.wwwname -side right
    pack .prefs.f0.f1.f -side top -anchor w
    pack .prefs.f0.f1.f2.l -side left
    pack .prefs.f0.f1.f2.wwwproxy -side right
    pack .prefs.f0.f1.f2 -side top -anchor w
    pack .prefs.f0.f1 -side left -anchor n -fill y -expand true

    pack .prefs.f0 -side top

    frame .prefs.f2 -borderwidth 2 -relief groove
    pack .prefs.f2 -side top
    button .prefs.f2.b -text "Specify Tools for Media Formats" \
	-command select_startup_rule
    pack .prefs.f2.b -side left

    frame .prefs.f4 -borderwidth 2 -relief groove
    pack .prefs.f4 -side top

    label .prefs.f4.l -text "User Interface Style"
    pack .prefs.f4.l -side top
    frame .prefs.f4.f
    pack .prefs.f4.f -side top -expand true -fill x
    frame .prefs.f4.f.l -relief groove -borderwidth 2
    pack .prefs.f4.f.l -side left -fill y -expand true
    label .prefs.f4.f.l.l -text "Create Session:"
    pack .prefs.f4.f.l.l -side top -anchor w
    global ifstyle
    radiobutton .prefs.f4.f.l.a -text "Normal Interface" \
	-highlightthickness 0 \
	-variable ifstyle(create) -value norm
    pack .prefs.f4.f.l.a -side top -anchor w
    radiobutton .prefs.f4.f.l.b -text "Technical Interface" \
	-highlightthickness 0 \
	-variable ifstyle(create) -value tech
    pack .prefs.f4.f.l.b -side top -anchor w

    frame .prefs.f4.f.m -relief groove -borderwidth 2
    pack .prefs.f4.f.m -side left -fill y -expand true
    label .prefs.f4.f.m.l -text "View Session:"
    pack .prefs.f4.f.m.l -side top -anchor w
    global ifstyle
    radiobutton .prefs.f4.f.m.a -text "Normal Interface" \
	-highlightthickness 0 \
	-variable ifstyle(view) -value norm
    pack .prefs.f4.f.m.a -side top -anchor w
    radiobutton .prefs.f4.f.m.b -text "Technical Interface" \
	-highlightthickness 0 \
	-variable ifstyle(view) -value tech
    pack .prefs.f4.f.m.b -side top -anchor w
    

    frame .prefs.f1
    button .prefs.f1.ok -text [tt "Apply Prefs"] -command {\
      set webclient [.prefs.f0.f1.f.wwwname get];\
      set webproxy [.prefs.f0.f1.f2.wwwproxy get];\
      reshow_sessions $showwhich;\
      catch {destroy .ps};\
      destroy .prefs}
    tixAddBalloon .prefs.f1.ok Button [tt "Apply the changes you've made"]
    pack .prefs.f1.ok -side left -fill x -expand true
    button .prefs.f1.save -text [tt "Apply & Save Prefs"] -command {\
      set webclient [.prefs.f0.f1.f.wwwname get];\
      set webproxy [.prefs.f0.f1.f2.wwwproxy get];\
      reshow_sessions $showwhich;\
      save_prefs;\
      catch {destroy .ps};\
      destroy .prefs}
    tixAddBalloon .prefs.f1.save Button [tt "Apply the changes you've made and also save them for next time"]
    pack .prefs.f1.save -side left -fill x -expand true
    pack .prefs.f1 -side top -fill x -expand true
    move_onscreen .prefs
}

proc save_prefs {} {
    global balloonHelp
    if {[file isdirectory [resource sdrHome]]==0} {
	catch {file mkdir [resource sdrHome]} msg
    }
    if {[file isdirectory [resource sdrHome]]==0} {
	errorpopup "Error Creating Directory" "I can't save your preferences because I can't create the directory [resource sdrHome] $msg"
	return 
    }
    set file [open "[resource sdrHome]/prefs" w]
    allprefprocs save $file
    puts $file "set balloonHelp $balloonHelp"
    puts $file "set_balloon_help $balloonHelp"
    close $file
    give_status_msg [tt "Preferences Saved"]
}

proc help {} {
    global balloonHelp
    catch {destroy .help}
    sdr_toplevel .help "Help"
    posn_win .help
    frame .help.f -relief groove -borderwidth 2
    pack .help.f -side top
    message .help.f.l -aspect 150 -text  "Sdr is a session directory tool.  It is rather like a TV Guide, except it lists sessions to be multicast on the Mbone rather than programmes broadcast on radio and television.

What's more, sdr allows you to join the sessions listed, sdr allows you to create and advertise sessions yourself, and sdr affords calling people directly to participate in a session.

So essentially, sdr does the following:

1. Allows you to see what sessions are on and to join them.

2. Allows you to advertise sessions yourself.

3. Allows you to make calls to people.

Select \"balloon help\" if you'd like to know what sdr's buttons and controls do.  Select \"more help\" to view the full sdr help system."

    pack .help.f.l -side top
    pack [frame .help.f.f] -side top -fill x -expand true
    checkbutton .help.f.f.mode -text [tt "Balloon Help"] -variable balloonHelp \
	-onvalue 1 -offvalue 0 -command {set_balloon_help $balloonHelp} \
	-relief raised
    pack .help.f.f.mode -side left -fill x -expand true
    button .help.f.f.about -text [tt "More Help!"] -command "destroy .help;webdisp help:about" -pady 0 -highlightthickness 0
    pack .help.f.f.about -side left -fill x -expand true
    tixAddBalloon .help.f.f.mode Button [tt "Click here to disable balloon help"]
    tixAddBalloon .help.f.f.about Button [tt "Click here to access sdr's full help system"]

    label .help.f.bugs -text "Please report bugs and suggestions to sdr@cs.ucl.ac.uk"
    pack .help.f.bugs -side top -anchor w

    button .help.f.dismiss -text [tt "Dismiss"] -command "destroy .help" \
	 -highlightthickness 0
    tixAddBalloon .help.f.dismiss Button [tt "Click here to hide this window"]
    pack .help.f.dismiss -side bottom -fill x
    move_onscreen .help
    log "showing help at [getreadabletime]"
}
proc hide_session {aid} {
    global ldata showwhich sessbox
    set list $ldata($aid,list)
    set box $sessbox($list)
    set posn [lindex [$box yview] 0]
    set ldata($aid,vstate) 0
    if {[string compare $showwhich "pref"]==0} {
	save_prefs
	reshow_sessions $showwhich
    }
    $box yview moveto $posn
}
proc pref_sessions {win} {
    global ldata prefs fullix fullnumitems
#    catch {destroy .ps}
#    toplevel .ps
#    wm title .ps [tt "Preferred Session List"]
#    posn_win_rel .ps .prefs
    frame $win.f1 -relief sunken -borderwidth 1
#   set height $fullnumitems
    set height 15
#    if {$height ==0} {set height 1}
    listbox $win.f1.l1 -width 25 -height $height \
	-yscroll "set_prefs_lbscroll $win"\
	-relief flat \
	-selectforeground [resource activeForeground] \
        -selectbackground [resource activeBackground] \
        -highlightthickness 0

    tixAddBalloon $win.f1.l1 ListBox [tt "Click on a session name to make it visible/hidden in the main session window"]
    listbox $win.f1.l2 -width 7 -height $height \
	-yscroll "set_prefs_lbscroll $win"\
	-relief flat \
	-selectforeground [resource activeForeground] \
        -selectbackground [resource activeBackground] \
        -highlightthickness 0

    tixAddBalloon $win.f1.l2 ListBox [tt "Click on a session to make it visible/hidden in the main session window"]
    scrollbar $win.f1.sb \
	-command "set_prefs_scroll $win" \
	-background [resource scrollbarForeground] \
	-troughcolor [resource scrollbarBackground] \
	-borderwidth 1 -relief flat \
	-highlightthickness 0

#TBD
#	-foreground [option get . scrollbarForeground Sdr] \
#	-activeforeground [option get . scrollbarActiveForeground Sdr] 
    foreach aid $prefs(show_aids) {
	$win.f1.l1 insert end $ldata($aid,session)
	if {$prefs(show_aid_$aid)==1} {
	    $win.f1.l2 insert end "visible"
	} else {
	    $win.f1.l2 insert end "--"
	}
    }
    bind $win.f1.l1 <1> "%W selection set \[%W nearest %y\];update;\
              toggle_pref_session $win \[%W nearest %y\]"
    bind $win.f1.l2 <1> "%W selection set \[%W nearest %y\];update;\
              toggle_pref_session $win \[%W nearest %y\]"
    #packing order determines which disappear first if you shrink
    #the window
    pack $win.f1.sb -side right -fill y
    pack $win.f1.l2 -side right -fill y -expand true
    pack $win.f1.l1 -side left -fill y -expand true
    pack $win.f1 -side top -fill both -expand true
}
proc set_prefs_scroll {win args} {
    eval $win.f1.l1 yview $args
    eval $win.f1.l2 yview $args
}
proc set_prefs_lbscroll {win args} {
    eval $win.f1.l1 yview moveto [lindex $args 0]
    eval $win.f1.l2 yview moveto [lindex $args 0]
    eval $win.f1.sb set $args
}
proc toggle_pref_session {win i} {
    global prefs
    if {[string compare $i ""]==0} {return 0}
    set aid [lindex $prefs(show_aids) $i]
    set prefs(show_aid_$aid) [expr 1-$prefs(show_aid_$aid)]
    if {$prefs(show_aid_$aid)==1} {
	$win.f1.l2 insert $i [tt "visible"]
    } else {
	$win.f1.l2 insert $i "--"
    }
    $win.f1.l2 delete [expr $i+1]
}

proc pref_sess_enable {win} {
    global prefs
    if {$prefs(show_showwhich)=="pref"} {
	$win.f1.l1 configure -foreground [option get . foreground Sdr]	
	$win.f1.l2 configure -foreground [option get . foreground Sdr]
    } else {
	$win.f1.l1 configure -foreground [option get . disabledForeground Sdr]
	$win.f1.l2 configure -foreground [option get . disabledForeground Sdr]
    }
}

set durationix 2
set monthix 0
set dayix 0
set hrix 0
set ttl 16
proc unix_to_ntp {unixtime} {
    set oddoffset 2208988800
    if {$unixtime==0} {return 0}
    return [format %u [expr $unixtime + $oddoffset]]
}
proc ntp_to_unix {ntptime} {
    set oddoffset 2208988800
    if {($ntptime==0)||($ntptime==1)} {return $ntptime}
    return [format %u [expr $ntptime - $oddoffset]]
}

set zone(no_of_zones) 0
set zone(cur_zone) 0
proc add_ttl_scope {sap_addr sap_port base_addr netmask} {
    #
    #note this must be done after all admin scope zones have been added.
    #this must not be called more than once!
    #
    global zone
    set no_of_zones $zone(no_of_zones)
    set zone(sap_addr,$no_of_zones) $sap_addr
    set zone(sap_port,$no_of_zones) $sap_port
    set zone(base_addr,$no_of_zones) $base_addr
    set zone(netmask,$no_of_zones) $netmask
    sd_listen $sap_addr $sap_port
    set zone(ttl_scope) $no_of_zones
}

proc add_admin {name sap_addr sap_port base_addr netmask ttl} {
    #
    #add a new admin scope zone, modify an existing one or remove
    #an old one.
    #to remove one, specify its name and set sap_addr to ""
    #
    global zone
    set no_of_zones $zone(no_of_zones)
    for {set i 0} {$i < $no_of_zones} {incr i} {
	if {$zone(name,$i)==$name} {
	    if {$sap_addr==""} {
		for {set j $i} {$j<[expr $no_of_zones-1]} {incr j} {
		    set zone(name,$j) $zone(name,[expr $j+1])
		    set zone(sap_addr,$j) $zone(sap_addr,[expr $j+1])
		    set zone(sap_port,$j) $zone(sap_port,[expr $j+1])
		    set zone(base_addr,$j) $zone(base_addr,[expr $j+1])
		    set zone(netmask,$j) $zone(netmask,[expr $j+1])
		    set zone(ttl,$j) $zone(ttl,[expr $j+1])
		}
		incr zone(no_of_zones) -1
		return 0
	    } else {
		set no_of_zones $i
		incr zone(no_of_zones) -1
	    }
	}
    }
    set zone(name,$no_of_zones) $name
    set zone(sap_addr,$no_of_zones) $sap_addr
    set zone(sap_port,$no_of_zones) $sap_port
    sd_listen $sap_addr $sap_port
    set zone(base_addr,$no_of_zones) $base_addr
    set zone(netmask,$no_of_zones) $netmask
    set zone(ttl,$no_of_zones) $ttl
    incr zone(no_of_zones)
}

proc sdr_new_session_hook {advert} {
}

proc sdr_delete_session_hook {advert} {
}

set fh [font metrics -adobe-courier-bold-r-normal--*-120-*-*-m-*-iso8859-1 -linespace]
set fw [font measure -adobe-courier-bold-r-normal--*-120-*-*-m-*-iso8859-1 m]
set font -adobe-courier-bold-r-normal--*-120-*-*-m-*-iso8859-1
set tmp 0
catch {set tmp [label .test -font $font];destroy .test}
if {$tmp==0} {
    set font 8x13
    set fh 13
    set fw 8
}
 

for {set i 1} {$i <= 31} {incr i} {
    set ending($i) "th"
}
foreach i {1 21 31} {
    set ending($i) "st"
}
foreach i {2 22} {
    set ending($i) "nd"
}
foreach i {3 23} {
    set ending($i) "rd"
}

proc calendar {} {
    global ldata fullix fullnumitems daysinmonth taglist fh fw font ifstyle
    catch {destroy .cal}
    catch {unset taglist}
    sdr_toplevel .cal "Daily Listings" "Calendar"
    posn_win .cal
    frame .cal.f0 -borderwidth 2 -relief groove
    if {$ifstyle(labels)=="long"} {
	label .cal.f0.l -text "Click on a day to show what's on." \
		-anchor w -font [option get . infoFont Sdr]
	pack .cal.f0.l -side top -fill x -expand true
    }
	
    canvas .cal.f0.c -height [expr 8 * $fh] -width [expr 96 * $fw] \
	-relief flat -highlightthickness 0

    tixAddBalloon .cal.f0.c Frame [tt "Highlighted dates are days that \
have sessions scheduled. Click on a date to get the listing for that \
day."]

    set fg [option get . foreground Sdr]
    set tstr [gettimenow]
    set daynow [fixint [lindex $tstr 2]]
    set monnow [fixint [lindex $tstr 1]]
    set yearnow [fixint [lindex $tstr 0]]
    for {set i 0} {$i < 3} {incr i} {
	set mon [expr $monnow + $i]
	set year $yearnow
	if {$mon>12} {
	    incr mon -12
	    incr year
	}
	.cal.f0.c addtag mon$i withtag \
	    [.cal.f0.c create text [expr $i*$fw*32] 0 -anchor nw\
             -fill $fg -font $font]
	if {$i==0} {
	    set utime [gettimeofday]
	    set day [fixint [clock format $utime -format {%d}]]
	    set begin [expr $utime - (($day-1)*86400)]
	    set first($mon) [clock format $begin -format {%w}]
	    set mname [clock format $begin -format {%B}]
	} else {
	    set utime [expr $begin+($i*2678400)]
	    set day [fixint [clock format $utime -format {%d}]]
	    set next [expr $utime - (($day-1)*86400)]
	    set first($mon) [clock format $next -format {%w}]
	    set mname [clock format $next -format {%B}]
	}
	for {set d 1} {$d <= [lindex $daysinmonth [expr $mon - 1]]} {incr d} {
            highlight_day $d $mon $year $first($mon) $monnow grey $fg "" 0 -1 -1
	}
	#do the month and day names
	.cal.f0.c insert mon$i 0 "$mname\n"
	for {set d 0} {$d < 7} {incr d} {
	    set str [getdayname $d]
	    .cal.f0.c insert mon$i end "[getdayname $d] "
	    if {[string length $str]==2} {.cal.f0.c insert mon$i end " "}
	}
    }

    pack .cal.f0 -side top
    pack .cal.f0.c -side top

    frame .cal.f2 -borderwidth 2 -relief groove
    button .cal.f2.dismiss -text [tt "Dismiss"] \
	-command {catch {unset taglist};destroy .cal} \
	-highlightthickness 0
    pack .cal.f2.dismiss -side left -expand true -fill x
    pack .cal.f2 -side top -expand true -fill x
#    highlight_day $daynow 0 $year $first([expr $monnow+0]) $monnow white blue today
    for {set i 0} {$i < $fullnumitems} {incr i} {
	set aid $fullix($i)
	for {set t 0} {$t < $ldata($aid,no_of_times)} {incr t} {
	    set starttime $ldata($aid,starttime,$t)
	    set endtime $ldata($aid,endtime,$t)
	    #don't show continuous sessions
	    if {$starttime==0} { 
		continue
	    }
	    if {$ldata($aid,time$t,no_of_rpts)==0} {

		#don't show sessions continuously active for more than 2 weeks
		if {[expr $endtime-$starttime]>1209600} {
		    continue
		}

		if {$starttime < [gettimeofday]} {set starttime [gettimeofday]}
		if {$endtime > ([gettimeofday]+8035200)} {
		    set endtime [expr [gettimeofday]+8035200]
		}
		set startstr [gettime $starttime]
		set sday [fixint [lindex $startstr 2]]
		set smon [fixint [lindex $startstr 1]]
		set endstr [gettime $endtime]
		set eday [fixint [lindex $endstr 2]]
		set emon [fixint [lindex $endstr 1]]
		set syear [fixint [lindex $startstr 0]]
		set remon $emon
		if {$emon<$smon} {
		    set remon [expr $emon+12]
		}
		for {set tmon $smon} {$tmon <= $remon} {incr tmon} {
		    if {$tmon>12} {
			set mon [expr $tmon-12]
			incr syear
		    } else {
			set mon $tmon
		    }
		    if {$mon==$smon} {
			set som $sday
		    } else {
			set som 1
		    }
		    if {$mon==$emon} {
			set eom $eday
		    } else {
			set eom [lindex $daysinmonth [expr $mon - 1]]
		    }
		    for {set day $som} {$day <= $eom} {incr day} {
			catch { highlight_day $day $mon $syear $first([expr $mon+0]) $monnow [option get . activeBackground Sdr] [option get . hotForeground Sdr] \"$aid\" $t -1 -1}
		    }
		}
	    } else {
		set realendtime $endtime
		for {set r 0} {$r<$ldata($aid,time$t,no_of_rpts)} {incr r} {
		  for {set o 0} {$o<[llength $ldata($aid,time$t,offset$r)]} {incr o} {
		    set rctr 0
		    set starttime [expr $ldata($aid,starttime,$t) + [lindex $ldata($aid,time$t,offset$r) $o]]
		    while {$starttime < $realendtime} {
			set endtime [expr $starttime + $ldata($aid,time$t,duration$r)]
			#8035200 is 3 months in seconds...
			if {$starttime > ([gettimeofday]+8035200)} {
			    break;
			}
			if {$endtime > ([gettimeofday]+8035200)} {
			    set endtime [expr [gettimeofday]+8035200]
			}
			if {$endtime < [gettimeofday]} {
			    set starttime [expr $starttime + $ldata($aid,time$t,interval$r)]
			    incr rctr
			    continue
			}
			if {$starttime < [gettimeofday]} {
			    set startstr [gettime [gettimeofday]]
			} else {
			    set startstr [gettime $starttime]
			}
			set sday [fixint [lindex $startstr 2]]
			set smon [fixint [lindex $startstr 1]]
			set endstr [gettime $endtime]
			set syear [fixint [lindex $startstr 0]]

			set etime [expr [fixint [lindex $endstr 3]]*60 + \
				   [fixint [lindex $endstr 4]]]
			#anything running < 30 mins into the next day isn't
			#worth showing...
			if {$etime<30} {
			    set endtime [expr $endtime-1800]
			    set endstr [gettime $endtime]
			}

			set eday [fixint [lindex $endstr 2]]
			set emon [fixint [lindex $endstr 1]]
			set remon $emon
			if {$emon<$smon} {
			    set remon [expr $emon+12]
			}
			for {set tmon $smon} {$tmon <= $remon} {incr tmon} {
			    if {$tmon>12} {
				set mon [expr $tmon-12]
				incr syear
			    } else {
				set mon $tmon
			    }
			    if {$mon==$smon} {
				set som $sday
			    } else {
				set som 1
			    }
			    if {$mon==$emon} {
				set eom $eday
			    } else {
				set eom [lindex $daysinmonth [expr $mon - 1]]
			    }
			    for {set day $som} {$day <= $eom} {incr day} {
				catch { highlight_day $day $mon $syear $first([expr $mon+0]) $monnow [option get . activeBackground Sdr] [option get . hotForeground Sdr] \"$aid\" $t $r $rctr $o}
			    }
			}
			set starttime [expr $starttime + $ldata($aid,time$t,interval$r)]
			incr rctr
		    }
		  }
		}
	    }
	}
    }
    move_onscreen .cal
    log "calendar displayed at [getreadabletime]"
}

proc highlight_day {day mon yr offset monnow col fgcol aid tindex rindex rctr {off 0}} {
    global taglist fh fw font
    set tday [expr $day+$offset]
    set tmon [expr $mon-$monnow]
    if {$tmon<0} {
	incr tmon 12
    }
    set code 0
    set dow [getdayname [expr ($day+$offset-1)%7] -long]
    catch {set code $taglist($day.$mon)}
    if {$code==0} {
	set xpos [expr ((($tday-1)%7) + ($tmon*8))*$fw*4 ]
	set ypos [expr ((($tday-1) / 7)+2)*$fh]
	if {$day < 10} {
	    set daystr " $day"
	} else {
	    set daystr $day
	}
	if {[string compare $aid ""]!=0} {
	    .cal.f0.c addtag $day.$mon withtag \
		[.cal.f0.c create rectangle [expr $xpos - 2] $ypos \
		 [expr $xpos + ($fw*2) +2] [expr $ypos + $fh - 1] -fill $col \
		    -outline [option get . foreground Sdr]]
	    .cal.f0.c addtag t.$day.$mon withtag \
		[.cal.f0.c create text $xpos $ypos -anchor nw \
		 -fill [option get . hotForeground Sdr] -font $font \
		    -text "$daystr"]
	    set taglist($day.$mon) "$aid $tindex $rindex $rctr $off"
	    .cal.f0.c bind t.$day.$mon <1> \
		"display_bookings $dow $day $mon $yr \$taglist($day.$mon)"
	    .cal.f0.c bind t.$day.$mon <Enter> \
		".cal.f0.c itemconfigure t.$day.$mon -fill \
                   [option get . activehotForeground Sdr]"
	    .cal.f0.c bind t.$day.$mon <Leave> \
		".cal.f0.c itemconfigure t.$day.$mon -fill $fgcol"
	} else {
	    .cal.f0.c create text $xpos $ypos -anchor nw -fill $fgcol \
		 -text "$daystr" -font $font
	}
    } else {
	set taglist($day.$mon) "$taglist($day.$mon)\n$aid $tindex $rindex $rctr $off"
    }
}

proc display_bookings {dow day mon yr bookings} {
    global ldata ifstyle ending
    set title \
	"[tt "Sessions on"] $dow $day$ending($day) [getmonname $mon -long]"
    set blist [split $bookings "\n"]
    set fg [option get . foreground Sdr]
    set hotfg [option get . hotForeground Sdr]
    set ahotfg [option get . activehotForeground Sdr]
    set booknum 0
    set aid ""
    foreach booking $blist {
	if {[string compare [lindex $booking 0] $aid] != 0} {
	    incr booknum 1
	}
	set aid [lindex $booking 0]
    }
    set win .cal.day$day,$mon
    if {[winfo exists $win]} { return 0 }
    frame $win -borderwidth 2 -relief groove
    pack $win -before .cal.f2 -side top -fill x -expand true
    frame $win.f -borderwidth 2 -relief groove
    pack $win.f -side top -fill both -expand true
    frame $win.f.f -borderwidth 0
    pack $win.f.f -side top -fill x -expand true
    label $win.f.f.l -text $title
    pack $win.f.f.l -side left
    label $win.f.f.exp -font [option get . infoFont Sdr] -text "" \
	    -justify l -anchor w
    pack $win.f.f.exp -side left -fill x -expand true 
    if {$ifstyle(labels)=="long"} {
	$win.f.f.exp configure -text [tt "Click on a session to see details of it"]
    }
    canvas $win.f.c -height [expr ($booknum*15)+30] -width 650 -relief sunken \
	 -highlightthickness 0
    for {set t 0} {$t < 24} {incr t} {
	$win.f.c addtag hour$t withtag \
            [$win.f.c create text [expr ($t * 20)+10] 5 -anchor n\
             -fill $fg -font [option get . font Sdr]]
	$win.f.c create line  [expr ($t * 20) +20 ] 20\
	                      [expr ($t * 20) +20 ] 30 -fill $fg
	$win.f.c create line  [expr ($t * 20) +10 ] 20\
	                      [expr ($t * 20) +10 ] [expr ($booknum*15)+20]\
	                      -fill $fg
	if {$t<10} {
	    set time "0$t"
	} else {
	    set time $t
	}
	$win.f.c insert hour$t 0 "$time"
    }
    $win.f.c create line 490 20 490 [expr ($booknum*15)+20] -fill $fg
    $win.f.c create line 10 20 490 20 -fill $fg
     $win.f.c create line 10 [expr ($booknum*15)+20] 490 [expr ($booknum*15)+20] -fill $fg
    set lnum -15
    set prevaid ""
    foreach booking $blist {
	if {[string compare $booking "today"]!=0} {
	    set aid [string trim [lindex $booking 0] "\""]

	    #check the session information does still exist
	    set tmp 0
	    catch {set tmp $ldata($aid,session)}
	    if {$tmp==0} { break }

	    set t [lindex $booking 1]
	    set r [lindex $booking 2]
	    set rctr [lindex $booking 3]
	    set offset [lindex $booking 4]
	    if {[string compare $aid $prevaid]!=0} {
		incr lnum 15
	    }
	    set starttime $ldata($aid,starttime,$t)
	    if {$r!=-1} {
		set starttime [expr $starttime + [lindex $ldata($aid,time$t,offset$r) $offset] \
			       + ($rctr*$ldata($aid,time$t,interval$r))]
		set endtime [expr $starttime +$ldata($aid,time$t,duration$r)]
	    } else {
		set endtime $ldata($aid,endtime,$t)
	    }
	    set startstr [gettime $starttime]
	    set sday [fixint [lindex $startstr 2]]
	    set smon [fixint [lindex $startstr 1]]
	    set syr [fixint [lindex $startstr 0]]
	    set endstr [gettime $endtime]

	    set etime [expr [fixint [lindex $endstr 3]]*60 + \
		       [fixint [lindex $endstr 4]]]
	    #anything running < 30 mins into the next day isn't
	    #worth showing as ending the next day
	    if {$etime<30} {
		set endtime [expr $endtime-(60*($etime+1))]
		set endstr [gettime $endtime]
	    }

	    set eday [fixint [lindex $endstr 2]]
	    set emon [fixint [lindex $endstr 1]]
	    set eyr [fixint [lindex $endstr 0]]
	    if {($day==$sday)&&($mon==$smon)&&($yr==$syr)} {
		set shr  [string trimleft [lindex $startstr 3] "0"]
		set smin [expr [lindex $startstr 4]/3]
		set larrow 1
	    } else {
		set shr 0
		set smin 0
		set larrow 0
	    }
	    if {($day==$eday)&&($mon==$emon)&&($yr==$eyr)} {
		set ehr [string trimleft [lindex $endstr 3] "0"]
		set emin [expr [lindex $endstr 4]/3]
		set rarrow 1
	    } else {
		set ehr 24
		set emin 0
		set rarrow 0
	    }

	    #need to be able to cope with multiple active times per entry
	    set tag "$sday:$shr:$smin:$lnum"

	    if {$shr==""} {set shr 0}
	    if {$ehr==""} {set ehr 0}
	    $win.f.c addtag l$tag withtag [\
	        $win.f.c create line \
		    [expr ($shr * 20)+10+($smin)]\
		    [expr 25+$lnum] \
		    [expr ($ehr * 20)+10+($emin)] \
		    [expr 25+$lnum] \
		    -fill $hotfg -width 4
	   ]
	    if {$larrow==1} {
		if {$rarrow==1} {
		     $win.f.c itemconfigure l$tag -arrow both
		 } else {
		     $win.f.c itemconfigure l$tag -arrow first
		 }
	    } else {
		if {$rarrow==1} {
		    $win.f.c itemconfigure l$tag -arrow last
		}
	    }
	    $win.f.c bind l$tag <1> "popup $aid \$ifstyle(view) advert"
	    $win.f.c bind l$tag <Enter> \
		"$win.f.c itemconfigure t$lnum -fill $ahotfg;\
		 $win.f.c itemconfigure l$tag -fill $ahotfg"
	    $win.f.c bind l$tag <Leave> \
		"$win.f.c itemconfigure t$lnum -fill $hotfg;\
		 $win.f.c itemconfigure l$tag -fill $hotfg"

	    $win.f.c create line \
		[expr ($ehr * 20)+10+($emin)] \
		[expr 25+$lnum] \
		495 [expr 25+$lnum] \
		-fill $hotfg
	    if {[string compare $aid $prevaid]!=0} {
		$win.f.c addtag t$lnum withtag \
		    [$win.f.c create text 495 \
		     [expr 25+$lnum] -anchor w\
			 -fill $hotfg -font [option get . font Sdr]]
		$win.f.c insert t$lnum 0 $ldata($aid,session)
		$win.f.c bind t$lnum <1> "popup $aid \$ifstyle(view) advert"
		$win.f.c bind t$lnum <Enter> \
		    "$win.f.c itemconfigure t$lnum -fill $ahotfg;\
                     $win.f.c itemconfigure l$tag -fill $ahotfg"
		$win.f.c bind t$lnum <Leave> \
		    "$win.f.c itemconfigure t$lnum -fill $hotfg;\
                     $win.f.c itemconfigure l$tag -fill $hotfg"
	    }
	    set prevaid $aid
	}
    }
    button $win.f.f.dismiss -text "[tt Hide] $day [getmonname $mon -long]" \
	-command "destroy $win" -font [option get . infoFont Sdr] \
	-borderwidth 1 -relief raised -pady 0 -padx 1 \
	-highlightthickness 0
    pack $win.f.f.dismiss -side right
    pack $win.f.c -side bottom -fill both -expand true
#    wm minsize $win 650 50
#    move_onscreen $win
    
}

proc sdr2.2_fix_cache {} {
    set shortname [glob -nocomplain ~]
    if { $shortname != "" } {
      set dirname "$shortname/.sdr"
    } else {
      set dirname "/.sdr"
    }
#    set dirname "[glob -nocomplain ~]/.sdr"
    if {$dirname=="//.sdr"} {
        set dirname "/.sdr"
    }
    if {[file isdirectory $dirname]!=0} {
	#we have a .sdr dir
	if {[file isdirectory $dirname/cache]==0} {
	    #but no cache subdir
	    #this means the last version was pre-sdr2.2a5
	    catch {file mkdir $dirname/cache}
	    if {[file isdirectory $dirname/cache]==0} {
		catch {puts "couldn't create cache directory `$dirname/cache'"}
		return 0
	    }
	    set filelist [glob -nocomplain $dirname/*]
	    foreach file $filelist {
		set fname [file tail $file]
		if {($fname!="plugins")&&($fname!="cache")} {
		    exec mv $dirname/$fname $dirname/cache
		}
	    }
	}
    }
}

proc dotted_decimal_to_decimal {dd} {
    set blist [split $dd "."]
    set res 0
    for {set i 0} {$i < 4} {incr i} {
	set res [expr (($res * 256)+[lindex $blist $i]) ]
    }
    return [format %u $res]
}


proc make_session {aid {mediavar {}}} {
    global ldata
    set msg "v=0"
    set msg "$msg\no=$ldata($aid,creator) $ldata($aid,sessid) $ldata($aid,sessvers) IN IP4 $ldata($aid,createaddr)"
    set msg "$msg\ns=$ldata($aid,session)"
    set desc $ldata($aid,desc)
    regsub -all "\n" $desc " " desc
    set msg "$msg\ni=$desc"
    if {$ldata($aid,uri)!=0} {
	set msg "$msg\nu=$ldata($aid,uri)"
    }
    foreach i $ldata($aid,emaillist) {
	set msg "$msg\ne=$i"
    }
    foreach i $ldata($aid,phonelist) {
	set msg "$msg\np=$i"
    }
#AUTH commented next one
#    if {$ldata($aid,multicast)!=""} {
	#set msg "$msg\nc=IN IP4 $ldata($aid,multicast)/$ldata($aid,ttl)"
    #}
    for {set i 0} {$i < $ldata($aid,no_of_times)} {incr i} {
	if {$ldata($aid,starttime,$i)==0} {set start 0} \
	    else {
		set start [format %u [unix_to_ntp $ldata($aid,starttime,$i)]]
	    }
	if {$ldata($aid,endtime,$i)==0} {set stop 0} \
	    else {set stop [format %u [unix_to_ntp $ldata($aid,endtime,$i)]]}
	set msg "$msg\nt=$start $stop"
	for {set r 0} {$r < $ldata($aid,time$i,no_of_rpts)} {incr r} {
	    set offsets {}
	    foreach offset $ldata($aid,time$i,offset$r) {
		lappend offsets [make_rpt_time $offset]
	    }
	    set msg "$msg\n[format "r=%s %s %s"\
			[make_rpt_time $ldata($aid,time$i,interval$r)]\
			[make_rpt_time $ldata($aid,time$i,duration$r)]\
			$offsets]"
	}
    }
    foreach i [split $ldata($aid,vars) "\n"] {
	set msg "$msg\na=$i"
    }
    if {[string compare $mediavar ""] != 0} {
	global $mediavar
    }
    for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
	set media $ldata($aid,$i,media)
	if {[string compare $mediavar ""] != 0 && [set [set mediavar]($media)] == 0} {
	    continue
	}
	set port $ldata($aid,$i,port)
	set proto $ldata($aid,$i,proto)
	set fmt $ldata($aid,$i,fmt)
	set msg "$msg\nm=$media $port $proto $fmt"
	set addr $ldata($aid,$i,addr)
	set newttl $ldata($aid,$i,ttl)
	set msg "$msg\nc=IN IP4 $addr/$newttl"
        if {[info exists ldata($aid,$i,mediakey)]} {
          set key $ldata($aid,$i,mediakey)
        } else {
         set key ""
        }
        if { [ string compare $key ""] !=0 } {
          set msg "$msg\nk=clear:$key"
        }
	if {$ldata($aid,$i,layers)>1} {
	    set msg "$msg/$ldata($aid,$i,layers)"
	}
	set varlist [split $ldata($aid,$i,vars) "\n"]
	foreach var $varlist {
	    set msg "$msg\na=$var"
	}
    }
    return $msg
}

proc valid_mcast_address {addr} {
    if {$addr==""} {return 1}
    set parts [split $addr "."]
    if {[llength $parts]!=4} {
#	putlogfile "Invalid address format"
	return 0
    }
    set b1 [lindex $parts 0]
    if {($b1<224)|($b1>239)} {
#	putlogfile "Invalid most significant byte"
	return 0
    }
    for {set b 1} {$b <= 3} {incr b} {
	set byte [lindex $parts $b]
	if {($byte<0)|($byte>255)} {
	    return 0
	}
    }
    return 1
}

set durations "30 minutes\n1 hour\n2 hours\n3 hours\n4 hours\n5 hours\n6 hours\n7 hours\n8 hours\n9 hours\n10 hours\n11 hours\n12 hours\n1 day\n2 days\n3 days\n4 days\n5 days\n6 days\n1 week\n8 days\n9 days\n10 days\n11 days\n12 days\n13 days\n2 weeks\n3 weeks\n4 weeks"
set realdurations "30\n60\n120\n180\n240\n300\n360\n420\n480\n540\n600\n\
660\n720\n\
1440\n2880\n4320\n5760\n7200\n8640\n10080\n11520\n12960\n14400\n\
15840\n17280\n18720\n20160\n30240\n40320"
set months "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"
set daysinmonth "31 28 31 30 31 30 31 31 30 31 30 31"

set langstrs(fr,minutes) minutes
set langstrs(fr,hour) heur
set langstrs(fr,hours) heures
set langstrs(fr,day) jour
set langstrs(fr,days) jours
set langstrs(fr,week) semaine
set langstrs(fr,weeks) semaines
set langstrs(de,minutes) minuten
set langstrs(de,hour) uhr
set langstrs(de,hours) uhr
set langstrs(de,day) tag
set langstrs(de,days) tag
set langstrs(de,week) woche
set langstrs(de,weeks) wochen
set availlangs {fr de}

proc map_duration {str lang} {
    global availlangs langstrs
    set p1 [lindex [split $str " "] 0]
    set p2 [lindex [split $str " "] 1]
    if {[lsearch $availlangs $lang]!=-1} {
	set p2 $langstrs($lang,$p2)
    }
    return "$p1 $p2"
}



proc get_duration {ix} {
    global durations lang
    set l [split $durations "\n"]
    return [map_duration [lindex $l $ix] $lang]
}

proc get_realduration {ix} {
    global realdurations
    set l [split $realdurations "\n"]
    return [lindex $l $ix]
}

proc get_duration_ix_by_time {secs} {
    global realdurations
    set l [split $realdurations "\n"]
    set mindiff 20160
    set mins [expr $secs / 60]
    for {set i 0} {$i < [llength $l]} {incr i} {
	if {$mins<= [lindex $l $i]} {
	    return $i
	}
    }
    return 1
}

proc is_known_media {media} {
    global medialist
    return [lsearch $medialist $media]
}

proc get_icon {media} {
    global mediadata medialist
    if {[lsearch $medialist $media]==-1} {
	return unknown
    } else {
	return $mediadata(icon:$media)
    }
}

set typedata(icon:test) test
set typedata(icon:meeting) meeting
set typedata(icon:broadcast) broadcast
set typedata(icon:stest) stest
set typedata(icon:smeeting) smeeting
set typedata(icon:sbroadcast) sbroadcast
#AUTH
#set typedata(icon:secure) secure
#name mapping allows for internationalisation
set typedata(name:test) [tt Test]
set typedata(name:meeting) [tt Meeting]
set typedata(name:broadcast) [tt Broadcast]
set typelist {test meeting broadcast}
#AUTH
#set typedata(name:secure) [tt Secure]
#set typelist {test meeting broadcast secure}

#AUTH
proc get_type_icon {type authtype enctype} {
    global typedata typelist
    if {[lsearch $typelist $type]==-1} {
	return unknown
    } else {
if { [string compare $authtype "none"] !=0  || [string compare $enctype "none"] !=0} {
             set type "s$type"
          }

	return $typedata(icon:$type)
    }
}

proc get_type_name {type} {
    global typedata typelist
    if {[lsearch $typelist $type]==-1} {
	return Unknown
    } else {
	return $typedata(name:$type)
    }
}

proc periodic_save {interval} {
    after $interval "write_cache;periodic_save $interval"
}

# default user_hook is a noop - users should redefine it in
# [sdrHome]/sdr.tcl to modify the tool's behavior.
proc user_hook {} {
}

proc authinfo {win bgcolour authm} {
    global ldata
    global $win.visible
    pack forget $win.buttons.authmsg
    incr $win.visible -1
    if {[set $win.visible]==0} {pack forget $win.buttons}
    frame $win.authinfo -borderwidth 2 -relief groove
    set mf [option get . mediumFont Sdr]
    pack $win.authinfo -side top -fill x -after $win.hidden2
    message $win.authinfo.authmsg -aspect 600 -text "Authentication Information: $authm " -font $mf -bg $bgcolour
    pack $win.authinfo.authmsg  -side top -expand true
}
proc encinfo {win bgcolour encm} {
    global ldata
    global $win.visible
    pack forget $win.buttons.encmsg
    incr $win.visible -1
    if {[set $win.visible]==0} {pack forget $win.buttons}
    frame $win.encinfo -borderwidth 2 -relief groove
    set mf [option get . mediumFont Sdr]
    pack $win.encinfo -side top -fill x  -after $win.hidden2
    message $win.encinfo.encmsg -aspect 800 -text "Encryption Information: $encm " -font $mf -bg $bgcolour
    pack $win.encinfo.encmsg  -side top -expand true
}

proc sdr_toplevel {win title {iconname {}}} {
    set ret [eval "toplevel $win"]
    wm group $ret .
    wm title $ret "Sdr: [tt $title]"
    if {$iconname == ""} {
	set iconname $title
    }
    wm iconname $ret "Sdr: [tt $iconname]"
    wm iconbitmap $ret sdr
    return $ret
}

#set where to read config files from
if {$tcl_platform(platform) == "windows"} {
    option add *sdrHome ~/sdr 
} else {
    set_resource Sdr.sdrHome [glob ~]/.sdr
}

initialise_resources
parse_plugins "/usr/local/etc/sdr/plugins" yes
parse_plugins "[resource sdrHome]/plugins" yes

#fix up pre-sdr2.2a5 cache files into the proper location
sdr2.2_fix_cache

# Set up the order of items in the preferences window
set prefprocs "show ifstyle tools web pers people security"

#Check for old ~/.sdr.tcl
if {([file isfile [glob -nocomplain ~]/.sdr.tcl]) && !([file isfile [resource sdrHome]/sdr.tcl])} {
    set movedmsg "Note: moved .sdr.tcl"
    exec mv [glob -nocomplain ~]/.sdr.tcl [glob -nocomplain [resource sdrHome]]/sdr.tcl
}

set flag 1
catch {source "/usr/local/etc/sdr/sdr.tcl";set flag 0}
if {($flag)&&([file isfile /usr/local/etc/sdr/sdr.tcl])} {
    set tmp $errorInfo
    errorpopup [tt "Error executing /usr/local/etc/sdr/sdr.tcl"] $tmp
}
set flag 1
catch {source "[resource sdrHome]/sdr.tcl";set flag 0}
if {($flag)&&([file isfile [resource sdrHome]/sdr.tcl])} {
    set tmp $errorInfo
    errorpopup [tt "Error executing [resource sdrHome]/sdr.tcl"] $tmp
}



#
# Set all preferences to their defaults
#
allprefprocs defaults
allprefprocs copyout
set save_interval 3600000

#Check for old ~/.sdr_prefs
if {([file isfile [glob -nocomplain ~]/.sdr_prefs]) && !([file isfile [resource sdrHome]/prefs])} {
    if ![info exists movedmsg] {
	set movedmsg "Note: moved .sdr_prefs"
    } else {
	set movedmsg "$movedmsg and .sdr_prefs"
    }
    exec mv [glob -nocomplain ~]/.sdr_prefs [glob -nocomplain [resource sdrHome]]/prefs
}

if [info exists movedmsg] {
    timedmsgpopup {Moved Files} "$movedmsg to the new location in [resource sdrHome]." 15000
}

set flag 1
catch {source "[resource sdrHome]/prefs";set flag 0}
if {($flag)&&([file isfile [resource sdrHome]/prefs])} {
    errorpopup "Error executing [resource sdrHome]/prefs" $errorInfo
}
foreach media $medialist {
    set send($media) 0
}
set send([lindex $medialist 0]) 1

# add_admin     name           sap_addr     sap_port   base_addr  netmask ttl
add_admin "Local Scope"     239.255.255.255   9875    239.255.0.0   16    15
add_admin "Region (ttl 63)" 224.2.127.254     9875    224.2.128.0   17    63
add_admin "World (ttl 127)" 224.2.127.254     9875    224.2.128.0   17    127
# add_admin                    sap_addr     sap_port   base_addr  netmask ttl
add_ttl_scope               224.2.127.254     9875    224.2.128.0   17

#create the interface
build_interface first

#save the session listing every so often
periodic_save $save_interval

#set the SIP alias for incoming calls
set_sipalias $youralias

#Run the user's hook.
user_hook
