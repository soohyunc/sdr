proc select_security_info {win width height} {
    global prefs

    frame $win -borderwidth 3 -relief raised
    frame $win.setw -borderwidth 0 -height 1 -width $width
    pack $win.setw -side top

    label $win.l -text [tt "Security Configuration"]
    pack $win.l -side top

    frame $win.f
    pack $win.f -side top -fill both -expand true

    frame $win.f.l 
    pack $win.f.l -side right -fill both -expand true

    frame $win.f.l.pad -height 30
    pack $win.f.l.pad -side top 

    frame $win.f.l.f -borderwidth 2 -relief groove
    pack $win.f.l.f -side top -anchor w

    label $win.f.l.f.title -text "Encryption Group" -relief ridge \
	-borderwidth 2
    pack $win.f.l.f.title -side top -fill x -expand true
    

    label $win.f.l.f.l1 -text "Group name:"
    pack $win.f.l.f.l1 -side top -anchor w
    entry $win.f.l.f.e1 -width 40 -relief sunken -borderwidth 1 \
	-highlightthickness 0
    pack $win.f.l.f.e1 -side top -anchor w
    label $win.f.l.f.l2 -text "Key:"
    pack $win.f.l.f.l2 -side top -anchor w
    password $win.f.l.f.e2 -width 40 -relief sunken -borderwidth 1 \
	-variable tmpeditpass
    pack $win.f.l.f.e2 -side top -anchor w
    label $win.f.l.f.l2b -text "Re-type Key:"
    pack $win.f.l.f.l2b -side top -anchor w
    password $win.f.l.f.e2b -width 40 -relief sunken -borderwidth 1 \
	-variable tmpeditpass2
    pack $win.f.l.f.e2b -side top -anchor w

    frame $win.f.l.f.f 
    pack $win.f.l.f.f -side top -anchor w -fill x 
    button $win.f.l.f.f.b2 -text "Modify group" \
	-command "select_modify_key $win" -state disabled -pady 1
    pack $win.f.l.f.f.b2 -side left -anchor w -fill x -expand true
    button $win.f.l.f.f.b3 -text "Delete group" \
	-command "select_delete_key $win" -state disabled -pady 1
    pack $win.f.l.f.f.b3 -side left -anchor w -fill x -expand true

    frame $win.f.r 
    pack $win.f.r -side left -fill y -expand true

    label $win.f.r.l -text "Encryption Groups"
    pack $win.f.r.l -side top
    
    frame $win.f.r.f
    pack $win.f.r.f -side top

    listbox $win.f.r.f.lb -height 10 -width 20 -yscroll "$win.f.r.f.sb set" \
	-relief sunken -borderwidth 1 -selectmode single \
        -selectforeground [resource activeForeground] \
	-selectbackground [resource activeBackground] \
	-highlightthickness 0

    bind $win.f.r.f.lb <1> "%W selection clear 0 end;\
                            %W selection set \[%W nearest %y\];\
                            show_encryption_group $win"
    pack $win.f.r.f.lb -side left -fill x

    button $win.f.r.b -text "Add encryption group" -command register_key
    pack $win.f.r.b -side top -fill x

    global keylistbox 
    set keylistbox $win.f.r.f.lb
    scrollbar $win.f.r.f.sb -command "$win.f.r.f.lb yview" \
	-borderwidth 1
    pack $win.f.r.f.sb -side right -fill y
    $win.f.l.f.l1 configure -foreground [resource disabledForeground]
    $win.f.l.f.e1 configure -state disabled
    $win.f.l.f.l2 configure -foreground [resource disabledForeground]
    $win.f.l.f.e2 configure -state disabled
    $win.f.l.f.l2b configure -foreground [resource disabledForeground]
    $win.f.l.f.e2b configure -state disabled
    $win.f.l.f.f.b2 configure -state disabled
    if {[get_passphrase]==""} {
	$win.f.r.l configure -foreground [resource disabledForeground]
	set keyfile "[glob -nocomplain [resource sdrHome]]/keys"
	if {[file exists $keyfile]&&([file size $keyfile]>0)} {
	    $win.f.r.b configure -state disabled
	}
    }
    
    frame $win.f2 -borderwidth 0 -relief flat -width 1 -height \
        [expr $height - [winfo reqheight $win]]
    pack $win.f2 -side top

    show_keys prefs
}

proc show_keys {win} {
    global keylist keylistbox
    catch {
	if {$win == "prefs"} {
	    set win $keylistbox
	}
	$win delete 0 end
	foreach keyname $keylist {
	    $win insert end "$keyname"
	}
    }
}

proc clear_keys {win} {
    global keylistbox
    catch {
	if {$win == "prefs"} {
	    set win $keylistbox
	}
	$win delete 0 end
    }
}

proc show_encryption_group {win} {
    set sel [$win.f.r.f.lb curselection]
    if {$sel==""} return
    set keyname [string trimright [$win.f.r.f.lb get $sel] "\n"]
    set tmp [find_key_by_name $keyname]
    set key [lindex $tmp 0]
    
    $win.f.l.f.l1 configure -foreground [resource foreground]
    $win.f.l.f.e1 configure -state normal \
	-background [resource entryBackground]
    $win.f.l.f.l2 configure -foreground [resource foreground]
    $win.f.l.f.e2 configure -state normal \
	-background [resource entryBackground]
    $win.f.l.f.l2b configure -foreground [resource foreground]
    $win.f.l.f.e2b configure -state normal \
	-background [resource entryBackground]
    $win.f.l.f.e1 delete 0 end
    $win.f.l.f.e1 insert 0 $keyname
    $win.f.l.f.e2.workaround set $key
    $win.f.l.f.e2b.workaround set $key
    $win.f.l.f.f.b2 configure -state normal
    $win.f.l.f.f.b3 configure -state normal
}

proc select_delete_key {win} {
    set sel [$win.f.r.f.lb curselection]
    if {$sel==""} return
    set keyname [string trimright [$win.f.r.f.lb get $sel] "\n"]
    clear_prefs_keys
    delete_key $keyname
    $win.f.l.f.e1 delete 0 end
    $win.f.l.f.e2.workaround set ""
    $win.f.l.f.e2b.workaround set ""
    $win.f.l.f.f.b2 configure -state disabled
    $win.f.l.f.f.b3 configure -state disabled
    $win.f.l.f.l1 configure -foreground [resource disabledForeground]
    $win.f.l.f.e1 configure -state disabled -background [resource background]
    $win.f.l.f.l2 configure -foreground [resource disabledForeground]
    $win.f.l.f.e2 configure -state disabled -background [resource background]
    $win.f.l.f.l2b configure -foreground [resource disabledForeground]
    $win.f.l.f.e2b configure -state disabled -background [resource background]
}

proc select_modify_key {win} {
    global tmpeditpass tmpeditpass2 keylistbox
    set sel [$win.f.r.f.lb curselection]
    if {$sel==""} {
	bell
	prefs_help "No group to replace is selected in the encryption groups list"
	after 3000 prefs_help "\"\""
	return
    }
    set keyname [string trimright [$win.f.r.f.lb get $sel] "\n"]
    set newkeyname [$win.f.l.f.e1 get]
    if {[string compare $tmpeditpass $tmpeditpass2]!=0} {
	bell
	prefs_help "You must enter the same key twice"
	after 3000 prefs_help "\"\""
	return
    }
    if {[string length $tmpeditpass]<8} {
        bell
        prefs_help "Encryption keys must be at least 8 characters"
        after 3000 prefs_help "\"\""
        return
    }
    clear_prefs_keys
    delete_key $keyname
    clear_prefs_keys
    add_key $tmpeditpass $newkeyname
    save_keys
    unset tmpeditpass
    unset tmpeditpass2
    $win.f.l.f.e1 delete 0 end
    $win.f.l.f.e2.workaround set ""
    $win.f.l.f.e2b.workaround set ""
    $win.f.l.f.f.b2 configure -state disabled
    $win.f.l.f.f.b3 configure -state disabled
    $win.f.l.f.l1 configure -foreground [resource disabledForeground]
    $win.f.l.f.e1 configure -state disabled -background [resource background]
    $win.f.l.f.l2 configure -foreground [resource disabledForeground]
    $win.f.l.f.e2 configure -state disabled -background [resource background]
    $win.f.l.f.l2b configure -foreground [resource disabledForeground]
    $win.f.l.f.e2b configure -state disabled -background [resource background]
    focus $keylistbox
}

proc register_key {} {
    catch {destroy .key}
    toplevel .key
    wm title .key "Sdr: Enter a new encryption key"
    frame .key.f -relief groove -borderwidth 2
    pack .key.f -side top

    label .key.f.l1 -text "Name of encryption group:"
    pack .key.f.l1 -side top -anchor w
    entry .key.f.e1 -width 60 -background [option get . entryBackground Sdr] \
	-highlightthickness 0
    pack .key.f.e1 -side top -anchor w

    frame .key.f.f
    pack .key.f.f -side top

    frame .key.f.f.l
    pack .key.f.f.l -side left
    label .key.f.f.l.l -text "Encryption key (at least 8 characters):"
    pack .key.f.f.l.l -side top -anchor w
    password .key.f.f.l.e -width 30 -variable tmpkey \
	 -background [option get . entryBackground Sdr]
    pack .key.f.f.l.e -side top -anchor w

    frame .key.f.f.r
    pack .key.f.f.r -side left
    label .key.f.f.r.l -text "Encryption key: (again)"
    pack .key.f.f.r.l -side top -anchor w
    password .key.f.f.r.e -width 30 -variable tmpkey2 \
	 -background [option get . entryBackground Sdr]
    pack .key.f.f.r.e -side top -anchor w

#    frame .key.f.f1
#    pack .key.f.f1 -side top
#    new_mk_session_admin .key.f.f1.admin new admin
    
    label .key.f.msg -borderwidth 1 -relief raised
    pack .key.f.msg -side top -fill x -expand true

    frame .key.f.f2
    pack .key.f.f2 -side top -fill x -expand true
    button .key.f.f2.ok -text "OK" -command submit_key
    pack .key.f.f2.ok -side left -fill x -expand true
    button .key.f.f2.cancel -text "Cancel" -command {destroy .key}
    pack .key.f.f2.cancel -side left -fill x -expand true
}

proc submit_key {} {
    global keylist tmpkey tmpkey2
    if {[string length [.key.f.e1 get]]<2} {
	bell
	.key.f.msg configure -text "You must configure a name for the encryption group"
	after 3000 "catch {.key.f.msg configure -text \"\"}"
	return
    }
    if {[string compare $tmpkey $tmpkey2]!=0} {
	.key.f.msg configure -text "You have not entered the same key twice"
	 after 3000 "catch {.key.f.msg configure -text \"\"}"
	return
    }

    if {[string length $tmpkey]<8} {
	bell
	.key.f.msg configure -text "Encryption keys must be at least 8 characters"
	after 3000 "catch {.key.f.msg configure -text \"\"}"
	return
    }
    add_key $tmpkey [.key.f.e1 get]
    unset tmpkey
    catch {destroy .key}

    #this will get re-installed by the re-load that happens after saving...
    set keylist ""

    #this is needed to allow the first key to be shown on freeBSD
    save_prefs

    if {[get_passphrase] == ""} {
	enter_long_passphrase save
    } else {
	save_keys
    }
}

proc query_passphrase { win } {
  catch {destroy .qpass}
  toplevel .qpass
  global querypass
  wm title .qpass "Sdr: Enter the pass phrase for your key file"

  frame .qpass.f -relief groove -borderwidth 2
  pack  .qpass.f -side top

  message .qpass.f.m -text "You must enter your passphrase to be able to load your encryption keys." -aspect 600
  pack .qpass.f.m -side top
 
  frame    .qpass.f.f
  pack     .qpass.f.f -side top -fill x -expand true
  label    .qpass.f.f.l -text "Password:"
  pack     .qpass.f.f.l -side left -anchor e -fill x -expand true
  password .qpass.f.f.e -width 40 -variable querypass \
                        -background [option get . entryBackground Sdr]
  pack  .qpass.f.f.e -side left
  bind  .qpass.f.f.e <Key-Return> "submit_qpass .qpass $win .qpass.f.msg \"\""

  label .qpass.f.msg -borderwidth 1 -relief raised
  pack  .qpass.f.msg -side top -fill x -expand true
 
  frame  .qpass.f.f2
  pack   .qpass.f.f2        -side top -fill x -expand true
  button .qpass.f.f2.ok     -text "OK" \
        -command "submit_qpass .qpass $win .qpass.f.msg \"\""
  pack   .qpass.f.f2.ok     -side left -fill x -expand true
  button .qpass.f.f2.cancel -text "Cancel" -command "destroy_query .qpass"
  pack   .qpass.f.f2.cancel -side left -fill x -expand true
}

proc destroy_query { win } {
  global security
  set security public
  catch {destroy $win}
}

proc submit_qpass { qwin createwin msgwin str } {
  global querypass
  set_passphrase $querypass
  $msgwin configure -text "Checking passphrase"
  update
  if {[load_keys]==1} {
    show_keys $createwin.enc.keys.lb
    $msgwin configure -text "Loading cached sessions"
    load_from_cache_crypt
    $msgwin configure -text "$str"
   } else {
    bell
    $msgwin configure -text "Pass phrase incorrect"
    set querypass ""
    after 3000 "catch {$msgwin configure -text \"$str\"}"
    return
   }
   catch {destroy $qwin}
   catch {destroy .f5}
}

proc enter_passphrase {} {
    global ifstyle
    if {$ifstyle(labels)=="long"} {
	enter_long_passphrase load
    } else {
	pack .f4 -side top -fill both -expand true -after .f2
	enter_short_passphrase .f5 .f4
    }
}

proc enter_long_passphrase {mode} {
    catch {destroy .pass}
    toplevel .pass
    wm title .pass "Sdr: Enter the pass phrase for your key file"
    frame .pass.f -relief groove -borderwidth 2
    pack .pass.f -side top
    
    message .pass.f.m -text "You must enter a passphrase to be able to load and save the keys for encrypted sessions." -aspect 600
    pack .pass.f.m -side top

    frame .pass.f.f
    pack  .pass.f.f -side top
 
    frame .pass.f.f.f0
    pack  .pass.f.f.f0 -side top -fill x -expand true
    label .pass.f.f.f0.l -text "Password:"
    pack .pass.f.f.f0.l -side left -anchor e -fill x -expand true
    password .pass.f.f.f0.e -width 40 -variable tmppass \
         -background [option get . entryBackground Sdr]
    pack .pass.f.f.f0.e -side left

##ed     bind .pass.f.f.f0.e <Key-Return> "submit_pass .pass $mode .pass.f.msg \"\""
    bind .pass.f.f.f0.e <Key-Return> "submit_pass .pass $mode .pass.f.msg \"\""

# only want to retype passphrase if saving the keys file for the first time
    if { $mode == "save" } { 
      frame .pass.f.f.f1
      pack  .pass.f.f.f1 -side top -fill x -expand true
      label .pass.f.f.f1.l -text "Retype Password:"
      pack .pass.f.f.f1.l -side left -anchor e -fill x -expand true
      password .pass.f.f.f1.e -width 40 -variable tmppass1 \
           -background [option get . entryBackground Sdr]
      pack .pass.f.f.f1.e -side left
 
      bind .pass.f.f.f1.e <Key-Return> "submit_pass .pass $mode .pass.f.msg \"\""
    }

    label .pass.f.msg -borderwidth 1 -relief raised
    pack .pass.f.msg -side top -fill x -expand true

    frame .pass.f.f2
    pack .pass.f.f2 -side top -fill x -expand true
    button .pass.f.f2.ok -text "OK" \
	-command "submit_pass .pass $mode .pass.f.msg \"\""
    pack .pass.f.f2.ok -side left -fill x -expand true
    button .pass.f.f2.cancel -text "Cancel" -command "destroy_pass .pass $mode"
    pack .pass.f.f2.cancel -side left -fill x -expand true
}

proc destroy_pass {win mode} {
    global tmpkey2

# destroy key which has been created and saved even though no passphrase
# entered and now cancelled from passphrase screen

# only want to remove key if we are cancelling from a save keyfile for the
# first time rather than a load keys at startup with Long labels selected
    if {$mode == "save"} {
      set tmpdel [find_keyname_by_key $tmpkey2]
      set delkey [lindex $tmpdel 0]
      clear_prefs_keys
      delete_key $delkey
      unset tmpkey2
    }
 
# destroy passphrase window
    catch {destroy $win}
}


proc enter_short_passphrase {win after} {
    frame $win -relief groove -borderwidth 2
    pack $win -side top -after $after -fill x
    
    set str "Enter passphrase to view encrypted sessions:"
    label $win.msg -borderwidth 1 -text $str\
	-font [option get . infoFont Sdr] -anchor nw
    pack $win.msg -side top -fill x -expand true
    frame $win.f
    pack $win.f -side top -fill x -expand true
#    entry $win.f.e -width 30 -font [option get . infoFont Sdr] \
	-background [option get . entryBackground Sdr]
    password $win.f.e -width 30 -font [option get . infoFont Sdr] \
        -background [option get . entryBackground Sdr] -variable tmppass \
	-command "submit_pass $win load $win.msg \"$str\""
    pack $win.f.e -side left -fill x -expand true
#    bind $win.f.e <Key-Return> "submit_pass $win load"
    


}

proc submit_pass {win mode msgwin str} {
    global tmppass tmppass1 ifstyle
#    if {[string length [$win.f.e get]]<8} \{
    if {([string length $tmppass]<8)&&($mode == "save")} {
	bell
	$msgwin configure -text "Please choose a longer pass phrase"
	after 5000 "catch {$win.f.msg configure -text $str}"
	return
    }

    if { $mode == "save" } {
      if { [string compare $tmppass $tmppass1]!=0 } {
        bell
        $msgwin configure -text "You have not entered the same password twice"
        after 3000 "catch {.$win.f.msg configure -text \"\"}"
        return
       }
     }

#    set_passphrase [$win.f.e get]
    set_passphrase $tmppass
    if {$mode == "save"} {
	save_keys
    } elseif {$mode == "load"} {
	$msgwin configure -text "Checking passphrase"
	update
	if {[load_keys]==1} {
	    $msgwin configure -text "Loading cached sessions"
	    update
	    load_from_cache_crypt
	    $msgwin configure -text "$str"
	} else {
            if {$ifstyle(labels)=="long"} {
              $win.f.f.f0.e.workaround set ""
            } else {
              $win.f.e.workaround set ""
            }
	    bell
	    $msgwin configure -text "Pass phrase incorrect"
	    set tmppass ""
	    after 3000 "catch {$msgwin configure -text \"$str\"}"
	    return
	}
    }
    catch {destroy $win}
}

set keylist ""

proc clear_prefs_keys {} {
    global keylist
    set keylist ""
    show_keys prefs
}

proc install_key {keyname} {
    global keylist
    lappend keylist $keyname
    show_keys prefs
}

proc new_mk_session_security {win aid} {
    global ldata security keylist user_id key_id 
    global enc_old_key_sel auth_old_key_sel asympass asympse
    if {[winfo exists $win]==0} {
	    frame $win -relief groove -borderwidth 2
	 
	    # Authentication code [dlh]
	    # Creates a button to select the authentication type and a text box
	    # for selecting the required (PGP)key.
	    frame $win.auth
	    frame $win.auth.sel
	    label $win.auth.sel.lauth -text "Authentication:"
	    menubutton $win.auth.sel.mauth -menu $win.auth.sel.mauth.menu -width 10 -borderwidth 1 -relief raised
	    menu $win.auth.sel.mauth.menu -tearoff 0
	    $win.auth.sel.mauth.menu add command -label "None"\
		-command "set_auth_type $win none"
	    $win.auth.sel.mauth.menu add command -label "PGP"\
		-command "set_auth_type $win pgp"

# comment out the X.509 option until they are added in properly
#	    $win.auth.sel.mauth.menu add command -label "X509"\
#		-command "set_auth_type $win x509"
# comment out these as they won't be used
#	    $win.auth.sel.mauth.menu add command -label "PGP+CERT"\
#		-command "set_auth_type $win cpgp"
#	    $win.auth.sel.mauth.menu add command -label "X509+CERT"\
#		-command "set_auth_type $win cx50"
	 
	    frame $win.auth.keys
	    text $win.auth.keys.lb -width 15 -height 5 -relief flat\
		 -relief sunken -borderwidth 1 -yscroll "$win.auth.keys.ysb set"\
		 -highlightthickness 0
	    scrollbar $win.auth.keys.ysb -command "$win.auth.keys.lb yview" -borderwidth 1 -highlightthickness 0
	 
	    frame $win.auth.pwd
	    label $win.auth.pwd.l -text "Password For PGP:"
	    label $win.auth.pwd.m -text "Passphrase:"
	    password $win.auth.pwd.e -width 30 -relief sunken\
		-variable asympass -borderwidth 1\
		-background [option get . entryBackground Sdr]
	     if {$aid=="new"} {
		set_auth_type $win none
		set auth_old_key_sel ""
	    } else {
	 
		# We are modifying an announcement so display old state of
		# authentication and encryption selection
		set asym $ldata($aid,authtype)
		set key_id($asym,auth_cur_key_sel) $ldata($aid,asym_keyid)
		set auth_old_key_sel $ldata($aid,asym_keyid)
		set_auth_type $win $ldata($aid,authtype)
	#       puts "Advert id: $aid"
	#       puts "Auth Type: $ldata($aid,authtype)"
	    }
	    frame $win.enc
	    frame $win.enc.sel
	    label $win.enc.sel.lenc -text "Encryption:"
	    menubutton $win.enc.sel.menc -menu $win.enc.sel.menc.menu -width 10 -borderwidth 1 -relief raised
	    menu $win.enc.sel.menc.menu -tearoff 0
	    $win.enc.sel.menc.menu add command -label "None"\
		-command "set_enc_type $win none $aid"
	    $win.enc.sel.menc.menu add command -label "Des"\
		-command "set_enc_type $win des $aid"
	    $win.enc.sel.menc.menu add command -label "PGP"\
		-command "set_enc_type $win pgp $aid"

# comment out X.509 until it is added properly
#	    $win.enc.sel.menc.menu add command -label "X509"\
#		-command "set_enc_type $win x509 $aid"
	 
	    frame $win.enc.keys
	    listbox $win.enc.keys.lb -width 15 -height 5 -yscroll\
	    "$win.enc.keys.ysb set" -relief sunken -borderwidth 1 \
	     -selectmode single  -selectforeground [resource activeForeground] \
		-selectbackground [resource activeBackground] \
		-highlightthickness 0
	    #text $win.enc.keys.lb -width 15 -height 5 -relief flat\
	    #     -relief sunken -borderwidth 1 -yscroll "$win.enc.keys.ysb set"\
	    #     -highlightthickness 0
	    scrollbar $win.enc.keys.ysb\
	    -command "$win.enc.keys.lb yview" -borderwidth 1 -highlightthickness 0

	    if {$keylist==""} {
		#$win.enc.keys.lb configure -state disabled
		set security public
	    }
	 
	    if {$aid=="new"} {
		set_enc_type $win none $aid
		set enc_old_key_sel ""
		set ldata($aid,key) ""
		set security public
	    } else {

	    if {([string compare $aid "new"]!=0)&&($ldata($aid,key)!="")} {
		set security private
	    } else {
		set security public
	    }
		# We are modifying an announcement so display old state of
		# authentication and encryption selection
		set asym $ldata($aid,enctype)
		set key_id($asym,enc_cur_key_sel) $ldata($aid,enc_asym_keyid)
		set enc_old_key_sel $ldata($aid,enc_asym_keyid)
		set_enc_type $win $ldata($aid,enctype) $aid
	#       puts "Advert id: $aid"
	#       puts "Enc Type: $ldata($aid,enctype)"
	    }
    	}
	pack $win -side left -fill both -expand true
	pack $win.auth -side top -fill both -expand true
	pack $win.auth.sel -side top -pady 5 -fill both -expand true
	pack $win.auth.sel.lauth $win.auth.sel.mauth -anchor nw -side left -padx 5
	pack $win.auth.keys -side top -pady 2 -fill both -expand true
	pack $win.auth.keys.lb -side left -fill both -expand true
	pack $win.auth.keys.ysb -side right -fill y
	pack $win.auth.pwd -side top -pady 2 -fill both -expand true
	pack $win.auth.pwd.l -side top -anchor w
	pack $win.auth.pwd.m -side top -anchor w
	pack $win.auth.pwd.e -side top -anchor w
	pack $win.enc -side top -fill both -expand true
	pack $win.enc.sel -side top -pady 5 -fill both -expand true
	pack $win.enc.sel.lenc $win.enc.sel.menc -anchor nw -side left -padx 5
	pack $win.enc.keys -side top -pady 2 -fill both -expand true
	pack $win.enc.keys.lb -side left -fill both -expand true
	pack $win.enc.keys.ysb -side right -fill y
}

proc enc_show_keys {win aid} {
    global keylist security

     set keyfile "[glob -nocomplain [resource sdrHome]]/keys"
    if {([file exists $keyfile] == 0)} {
        #$win.enc.keys.lb configure -state disabled
    }

    toggle_security $win
    if {([string compare $aid "new"]!=0)&&($ldata($aid,key)!="")} {
        update
        global keylist
        set ctr 0
        foreach keyname $keylist {
            set key [lindex [find_key_by_name $keyname] 0]
            if {[string compare $key $ldata($aid,key)]==0} {
                     $win.enc.keys.lb selection set $ctr
                     break
                 }
            incr ctr
        }
 
     }
}

proc get_new_session_key { } {
  set selkey [.new.f.f.security.enc.keys.lb curselection]
  if {$selkey==""} {
    errorpopup "No Key Selected" "You must select a key for encryption"
    log "user selected no key"
    return 0
  }
  .new.f.f.security.enc.keys.lb get [lindex $selkey 0]
}

 

proc toggle_security {win} {
    global security
    if {$security=="public"} {
	clear_keys $win.enc.keys.lb
    } else {
    if {[get_passphrase]==""} {
        query_passphrase $win
      } else {
        show_keys $win.enc.keys.lb
      }
    }
}
proc pref_security {cmd {arg1 {}} {arg2 {}} {arg3 {}}} {
    global prefs

    switch $cmd {
	copyin		{
			}

	copyout		{
			}

	defaults	{
			}

	create		{
			select_security_info $arg1 $arg2 $arg3
			return "Security"
			}

        balloon         {
                        return "Specify encryption keys for private sessions"
		        }

	save		{
			}
    }
}

#If you need to add more panels, create a function called 
#new_wiz_panel_XYZ, and add XYZ to these lists in the order you want it
#called.
set new_wiz_norm_panels \
	"info type timing_norm scope_norm media_norm contact security accept"
set new_wiz_tech_panels \
	"info type timing_tech scope_tech media_tech contact security accept"

proc create {} {
    global ttl dayix durationix send zone
    global timeofday minoffset hroffset media_attr media_fmt media_proto
    global media_layers medialist new_sessid sess_type
    global rtp_payload sdrversion security
    global mediaenc security

    global auth_type
    global enc_type
    global sess_auth_status
    global sess_enc_status
    global user_id asympass key_id
    global validpassword
    global validauth
    global validfile
    global validkey

    log "creating a session"
    if {$ttl==0} { set ttl [.new.f.f.f3.rr.f.e get] }
    if {($ttl < 0)|($ttl > 255)} {
        errorpopup "Illegal Scope Value" "Scope value must be between 0 and 255"
        log "user had entered an illegal scope value"
        return
    }
#     puts "create: ttl = $ttl"

    set sess "v=0"
    set sess "$sess\no=[getusername] $new_sessid [unix_to_ntp [gettimeofday]] IN IP4 [gethostname]"
    set sess "$sess\ns=[get_new_session_name .new.f.f]"
    if {[get_new_session_name .new.f.f]==""} {
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
    set email [.new.f.f.you.f0.e get]
    set phone [.new.f.f.you.f1.e get]
    if {$email!=""} {
        set sess "$sess\ne=$email"
    }
    if {$phone!=""} {
        set sess "$sess\np=$phone"
    }

    foreach i {1 2 3} {
      #the catch is here because the simple i/f only has one time entry
      catch {
        set tmp [get_expiry_time .new.f.f.f2.act.fb$i $i .new.f.f.f2.act.fd.duration]
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

            if { $mediaenc($media) == 1 } {

# check length of media key

              if { [ string length [get_new_media_key $media] ] < 8 } {
                  errorpopup "$media key too short" \
                      [tt "Encryption keys must be at least 8 characters"]
                  log "user had entered short key for $media"
                  return 0
              }

# the following cause problems inside sdr: \ / "
# the following cause problems from command line outside sdr: $ `
# the following (as well as $) are tcl special characters: [ ]
# disallow all so that people can join sessions using sdr and via command line

              if { [string first "\\" "[get_new_media_key $media]" ] != -1 ||
                   [string first "/"  "[get_new_media_key $media]" ] != -1 ||
                   [string first "\"" "[get_new_media_key $media]" ] != -1 ||
                   [string first "`"  "[get_new_media_key $media]" ] != -1 ||
                   [string first "$"  "[get_new_media_key $media]" ] != -1 ||
                   [string first "\["  "[get_new_media_key $media]" ] != -1 ||
                   [string first "\]"  "[get_new_media_key $media]" ] != -1 } {
                   errorpopup "$media key has forbidden characters" \
                      [tt "Encryption keys should not contain \\, /, \", \`, $, \[ or \] as these may cause problems when starting the tools "]
                  log "user had entered forbidden characters in key for $media, key was [get_new_media_key $media] ] "
                  return 0

              }
            }

            if {$media_proto($media)=="rtp"} {
                set sess "$sess\nm=$media [get_new_session_port $media] RTP/AVP $rtp_payload(pt:$media_fmt($media))"
            } else {
                set sess "$sess\nm=$media [get_new_session_port $media] $media_proto($media) $media_fmt($media)"
            }
            if {[valid_mcast_address [get_new_session_addr $media]]==0} {
                errorpopup "Invalid Multicast Address" \
                    "The multicast address specified is not a valid IP Class D address"
                log "user had entered an invalid multicast address"
                return 0
            }
            set sess "$sess\nc=IN IP4 [get_new_session_addr $media]/$ttl"
            if {$media_layers($media)>1} {
                set sess "$sess/$media_layers($media)"
            }

            if { $mediaenc($media) == 1 } {
              set sess "$sess\nk=clear:[get_new_media_key $media]"
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
#    puts "$sess send to $zone(sap_addr,$zone(cur_zone)) $zone(sap_port,$zone(cur_zone)) $ttl"

# if using DES (symmetric) encryption

    if {[info exists security]&&($security == "private")} {
        set keyname [string trim [get_new_session_key] "\n"]
        if {$keyname==0} {return 0};
        log "new session was encrypted"
    } else {
        set keyname ""
        log "new session was not encrypted"
    }

#    createsession "$sess\n" [ntp_to_unix $stoptime] $zone(sap_addr,$zone(cur_zone)) $zone(sap_port,$zone(cur_zone)) $ttl $keyname

# why is the first if "none" as well ?

    if { ($auth_type=="pgp" || $auth_type=="cpgp" || $auth_type=="none") } {
      set aauth "pgp"
    } elseif { ($auth_type == "x509" || $auth_type == "cx50" ) } {
      set aauth "x509"
    }

    if { $enc_type == "pgp" || $enc_type == "none" || $enc_type=="des"} {
      set asym "pgp"
    } elseif { $enc_type == "x509" || $enc_type == "none"} {
      set asym "x509"
    }

    if { $auth_type=="none" } {
      set key_id($aauth,auth_cur_key_sel) 0
      set user_id(pgp,auth_cur_key_sel) ""
    }

    if { $enc_type=="none" } {
      set key_id($asym,enc_cur_key_sel) 0
    }

# ensure passphrase entered if auth key selected

    if { ($user_id(pgp,auth_cur_key_sel)!="") && $asympass=="" } {
      errorpopup "No Passphrase!"\
         "The passphrase for $user_id(pgp,auth_cur_key_sel) must be\
         entered before authentication information can be \
         constructed for this session announcement."
      log "User did not enter a passphrase for key certificate"
      return 0
    }

    set validpassword 0
    set validauth     0
    set validfile     0
    set validkey      0

# do the work - calls ui_createsession in c code

    createsession "$sess\n" [ntp_to_unix $stoptime] $zone(sap_addr,$zone(cur_zone)) $zone(sap_port,$zone(cur_zone)) $ttl $keyname $auth_type $enc_type $key_id($aauth,auth_cur_key_sel) $key_id($asym,enc_cur_key_sel)

# check PGP password

    if {$validpassword==0 && ($auth_type =="pgp" || $auth_type =="cpgp"  )} {
      errorpopup "Bad Passphrase" "You entered the wrong passphrase for\
        $user_id($aauth,auth_cur_key_sel).  Try again."
      log "User entered an incorrect passphrase for key certificate"
      return 0
    }

    if {$validpassword==0 && ($auth_type =="x509" || $auth_type =="cx50"  )} {
      errorpopup "Secude failed" "The Signed DATA Failed for USER\
        $user_id($aauth,auth_cur_key_sel).  Try again."
      log "User entered an incorrect passphrase for key certificate"
      return 0
    }

    if {$validauth==0 && ($auth_type =="pgp" || $auth_type=="x509" || $auth_type =="cpgp" || $auth_type =="cx50" )} {
        errorpopup "Length" "Authentication Length very big for the Sap session\
           $user_id($aauth,auth_cur_key_sel).  Try again."
        log "User entered an incorrect ling Cert for key certificate"
        return 0
    }
    if {$validfile==0 && ($enc_type =="pgp" || $enc_type=="x509")} {
        errorpopup "File not created" "Probably public key is missing\
                                     $user_id($aauth,auth_cur_key_sel).  Try again."
        log "Cnnot create file on SDR home directory"
        return 0
    }
    update
    after 3000 write_cache
    log "new session announced at [getreadabletime]"
    return 1
}

# ------------------------------------------------------------
# start of this part of PGP AUTHentication code (AUTH)
# ------------------------------------------------------------
proc set_auth_type {win type} {
    global auth_type
    global cert
    set auth_type $type
    switch $type {
        none {
            $win.auth.sel.mauth configure -text None
            set cert "0"
            clear_asym_keys $win x509
            clear_asym_keys $win pgp
        }
        pgp {
            clear_asym_keys $win x509
            clear_asym_keys $win pgp
            $win.auth.sel.mauth configure -text PGP
            $win.auth.pwd.e configure -state normal
            pgp_get_key_list $win
        }
        x509 {
            clear_asym_keys $win x509
            clear_asym_keys $win pgp
            set cert "cert"
            $win.auth.sel.mauth configure -text X509
            show_pkcs7_keys $win
        }
        cpgp {
            clear_asym_keys $win x509
            clear_asym_keys $win pgp
            $win.auth.sel.mauth configure -text PGP+CERT
            $win.auth.pwd.e configure -state normal
            pgp_get_key_list $win
        }
       cx50 {
            clear_asym_keys $win x509
            clear_asym_keys $win pgp
            $win.auth.sel.mauth configure -text X509+CERT
            set cert "path"
            show_pkcs7_keys $win
        }
        other {
            $win.auth.sel.mauth configure -text Unspecified

        }
    }
}
# ------------------------------------------------------------
# end of this part of PGP AUTHentication code (AUTH)
# ------------------------------------------------------------

proc set_enc_type {win type aid} {
    global enc_type security
    set enc_type $type
    switch $type {
        none {
            $win.enc.sel.menc configure -text None
            enc_clear_asym_keys $win x509
            enc_clear_asym_keys $win pgp
            set security public
            clear_keys $win
        }
       des {
            enc_clear_asym_keys $win x509
            enc_clear_asym_keys $win pgp
            clear_keys $win
            $win.enc.sel.menc configure -text Des
            set security private
            enc_show_keys $win $aid

        }
        pgp {
            set security public
            enc_clear_asym_keys $win x509
            enc_clear_asym_keys $win pgp
            clear_keys $win
            $win.enc.sel.menc configure -text PGP
            enc_pgp_get_key_list $win $aid
        }
        x509 {
            set security public
            enc_clear_asym_keys $win x509
            enc_clear_asym_keys $win pgp
            $win.enc.sel.menc configure -text X509
            enc_show_x509_keys $win $aid
        }
        other {
            set security public
            $win.enc.sel.menc configure -text Unspecified

        }
    }
proc do_ad_creation {aid} {
    global auth_old_key_sel key_id
    global enc_old_key_sel
    if {[string compare $auth_old_key_sel $key_id(pgp,auth_cur_key_sel)]==0 || [string compare $enc_old_key_sel $key_id(pgp,enc_cur_key_sel)]==0} {
        ui_stop_session_ad $aid
        destroy .new
    } else {

        destroy .new
    }
}
}

proc new_wiz_panel_security {panelnum panels aid} {
    new_wiz_change_panels
    .new.f.l configure -text "Step $panelnum: Select security parameters for this session"
    .new.f.t insert 1.0 "You need to specify the security of session."
    set next_panel [expr $panelnum + 1]
    set back_panel [expr $panelnum - 1]

    .new.f.b.next configure -state normal -command "new_wiz_panel_[lindex $panels $next_panel] $next_panel \"$panels\" $aid"
    .new.f.b.back configure -state normal -command "new_wiz_panel_[lindex $panels $back_panel] $back_panel \"$panels\" $aid"
    .new.f.b.accept configure -state disabled    
    new_mk_session_security .new.f.f.security $aid
}

