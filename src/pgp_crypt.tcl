proc clear_asym_keys {win type} {
    global user_id, key_id

    set  key_id($type,auth_cur_key_sel) ""
    set user_id($type,auth_cur_key_sel) ""

    $win.auth.keys.lb configure -state normal
    $win.auth.keys.lb delete 1.0 end

    $win.auth.pwd.l configure -text "" -font [resource infoFont]
    $win.auth.pwd.e delete 0 end
    $win.auth.pwd.e configure -state disabled
}

proc enc_clear_asym_keys {win type} {
    global user_id, key_id

    set  key_id($type,enc_cur_key_sel) ""
    set user_id($type,enc_cur_key_sel) ""
#    $win.enc.keys.lb configure -state normal
    $win.enc.keys.lb delete 0 end
}

#--------------------------------------------------------------------#
# pgpstate - returns 1 if env(PGPSTATE) is set in environment        #
#--------------------------------------------------------------------#
proc pgpstate { } {
  global env
  global pgpdisable
  if [info exists env(PGPSTATE)] {
    if { $env(PGPSTATE) == 1 } {
      if {$pgpdisable == 1} {
        return 0
      } else {
        return 1
      }
    } else {
      return 0
    }
  } else {
    return 0
  }
}

#--------------------------------------------------------------------#
# Get the list of keys in the public keyring                         #
# Return: 0 if succeeded; 1 if failed                                #
#--------------------------------------------------------------------#
proc enc_pgp_get_key_list {win aid} {
  global no_of_keys e_user_id e_key_id e_sig_id ldata env

  if { [ get_pgppath ] == 1 } {
    return 1
  }

# view the keys on the public keyring

  set tclcmd [ list exec pgp -kv $env(PGPPATH)/pubring.pgp ]
  catch $tclcmd keylist
  pgp_InterpretOutput $keylist pgpresult 1

  if {$pgpresult(ok) != 1} {
    timedmsgpopup "PGP problem" "Couldn't view $env(PGPPATH)/pubring.pgp" 10000
    return 1
  }

# Extract the user and key ids of keys found in the PGP public keyring.

  set keylist [split $keylist "\n"]
  set i 0
  $win.enc.keys.lb delete 0 end

  foreach line $keylist {
    if [regexp {^(pub) +[0-9]+/([0-9A-F]+) [0-9/]+ (.*)$} \
        $line {} sigid keyid userid] {
      set e_user_id(pgp,$i) $userid
      set e_key_id(pgp,$i) $keyid
      set e_sig_id(pgp,$i) $sigid
      if { [string length $userid] > 60 } {
        set dotdot "..."
      } else {
        set dotdot ""
      }
      set keyn [string range $userid 0 60]$dotdot
      $win.enc.keys.lb insert $i "$keyn"
      incr i
    }
  }

# sort out the key selection

  set no_of_keys $i
  bind  $win.enc.keys.lb <1> "%W selection clear 0 end;\
     %W selection set \[%W nearest %y\];\
     [ format { 
       global no_of_keys
       global  e_user_id e_key_id
       set selkey [%s.enc.keys.lb curselection]
       %s.enc.keys.lb  get [lindex $selkey 0]
       set pgpkey [lindex $selkey 0]
       set user_id(pgp,enc_cur_key_sel) $e_user_id(pgp,$pgpkey)
       set key_id(pgp,enc_cur_key_sel) $e_key_id(pgp,$pgpkey)
     } $win $win $win $win] "
 
  if {([string compare $aid "new"]!=0)&&($ldata($aid,enc_asym_keyid)!="")} {
    for {set i 0} {$i < $no_of_keys} {incr i} {
      if {[string compare $ldata($aid,enc_asym_keyid) $e_key_id(pgp,$i)] == 0} {
        $win.enc.keys.lb  selection set $i
        set user_id(pgp,enc_cur_key_sel) $e_user_id(pgp,$i)
        break
      }
    }
  }
  return
}

# ---------------------------------------------------------------------------
# checks the signature of the received packets 
# ---------------------------------------------------------------------------
proc pgp_check_authentication {irand} {
    update
    global env 
    global recv_asym_keyid
    global recv_authstatus
    global recv_authmessage
    putlogfile "entered pgp_check authentication: irand = $irand"

# set up the filenames -should already exist 

    set local_authtxt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"
    set local_authsig_file "[glob -nocomplain [resource sdrHome]]/$irand.sig"
    set local_key_file     "[glob -nocomplain [resource sdrHome]]/$irand.pgp"

# find the PGPPATH

    if { [ get_pgppath ] == 1 } {
      set recv_authstatus  "failed"
      set recv_asym_keyid  "nonenone"
      set recv_authmessage "No Key Ring Path"
      return 1
    }

# set up command to check the authentication
# pgp +batchmode=on SIGFILE TXTFILE 

    set tclcmd [ list exec pgp +batchmode=on $local_authsig_file $local_authtxt_file ]
    set result [ catch $tclcmd output ]
 
# The error information must be conveyed to the user - more work needed
# Need a mechanism to identify the session announcement to the user.

    pgp_InterpretOutput $output pgpresult 1

    if {$pgpresult(ok) == 1} {
      set pgpresult(msg) [pgp_ShortenOutput $pgpresult(msg) $pgpresult(summary)  $pgpresult(keyid) $pgpresult(userid) $pgpresult(siglen) $pgpresult(date) $pgpresult(sigdate)]
      regsub -all {\"} $pgpresult(msg) {} mess
      set recv_authstatus   "trustworthy"
      set recv_authmessage  $mess
      set recv_asym_keyid   $pgpresult(keyid)
    } else {

      set pgpresult(msg) [pgp_ShortenOutput $pgpresult(msg) $pgpresult(summary) $pgpresult(keyid) "none" "none" "none" "none" ]
      set recv_authstatus "failed"
      set recv_asym_keyid $pgpresult(keyid)
      regsub -all {\"} $pgpresult(msg) {} mess
      set recv_authmessage $mess
    }

#    putlogfile "pgp_chk_auth: About to return"
#    putlogfile "pgp_chk_auth: pgpresult(msg)   = $pgpresult(msg)"
#    putlogfile "pgp_chk_auth: recv_authstatus  = $recv_authstatus"
#    putlogfile "pgp_chk_auth: recv_authmessage = $recv_authmessage"
#    putlogfile "pgp_chk_auth: recv_asym_keyid  = $recv_asym_keyid"

    return 1
}
proc pgp_cleanup {irand} {
   set txtfile "[glob -nocomplain [resource sdrHome]]/$irand.txt"
   set sigfile "[glob -nocomplain [resource sdrHome]]/$irand.sig"
   set pgpfile "[glob -nocomplain [resource sdrHome]]/$irand.pgp"

   putlogfile "entered pgp_cleanup: irand = $irand"

     if { [file exists $sigfile] } {
       #putlogfile "pgp_cleanup: attempting to delete $sigfile"
       file delete $sigfile
     }

     if { [file exists $txtfile] } {
       #putlogfile "pgp_cleanup: attempting to delete $txtfile"
       file delete $txtfile
     }

     if { [file exists $pgpfile] } {
       #putlogfile "pgp_cleanup: attempting to delete $pgpfile"
       file delete $pgpfile
     }
}

proc enc_pgp_cleanup {irand} {
   set txtfile "[glob -nocomplain [resource sdrHome]]/$irand.txt"
   set sigfile "[glob -nocomplain [resource sdrHome]]/$irand.pgp"
   set pgpfile "[glob -nocomplain [resource sdrHome]]/x$irand"
 
   putlogfile "entered enc_pgp_cleanup: irand = $irand"

 
   if { [file exists $sigfile] } {
     #putlogfile "pgp_cleanup: attempting to delete $sigfile"
     file delete $sigfile
   }
 
   if { [file exists $txtfile] } {
     #putlogfile "pgp_cleanup: attempting to delete $txtfile"
     file delete $txtfile
   }
 
   if { [file exists $pgpfile] } {
     #putlogfile "pgp_cleanup: attempting to delete $pgpfile"
     file delete $pgpfile
   }
}


#--------------------------------------------------------------------#
# Get the list of keys in the secret keyring                         #
# Return: 0 if succeeded; 1 if failed                                #
#--------------------------------------------------------------------#
# Removed smartcard code as it is messy enough as it is              #
#--------------------------------------------------------------------#
proc pgp_get_key_list { win } {

  global no_of_keys user_id key_id sig_id env

  putlogfile "entered pgp_get_key_list"
  set resultkey 0

# If can't find the PGP directory then forget it 

  if { [ get_pgppath ] == 1 } {
    return 1
  }

# view the keys on the secret keyring

  set tclcmd [ list exec pgp -kv $env(PGPPATH)/secring.pgp ]
  catch $tclcmd keylist
  pgp_InterpretOutput $keylist pgpresult 1

  if {$pgpresult(ok) == 1} {
    set resultkey 1
  } else {
    timedmsgpopup "PGP problem" "Couldn't view $env(PGPPATH)secring.pgp" 10000
    return 0
  }

# Extract the user and keyid of the keys from the secret keyring.

  set keylist [split $keylist "\n"]
  set i 0

  foreach line $keylist {
# just looking for keys we can sign with so need secret only not public
   if [regexp {^(sec) +[0-9]+/([0-9A-F]+) [0-9/]+ (.*)$} \
         $line {} sigid keyid userid] {
      set user_id(pgp,$i) $userid
      set  key_id(pgp,$i) $keyid
      set  sig_id(pgp,$i) $sigid
 
# make sure userid isn't too long to see in the window 

      if { [string length $userid] > 60 } {
        set dotdot "..."
      } else {
        set dotdot ""
      }
 
      $win.auth.keys.lb insert [expr $i+1].0 [string range $userid 0 60]$dotdot
      $win.auth.keys.lb insert end " \n"
      $win.auth.keys.lb tag add line$i [expr $i+1].0 [expr $i+1].end
      $win.auth.keys.lb tag configure line$i -background \
            [option get . background Sdr]
 
# Set-up bind on key selection

      $win.auth.keys.lb tag bind line$i <1>\
        [format {
          global no_of_keys
          for {set i 0} {$i < $no_of_keys} {incr i} {
            %s.auth.keys.lb tag configure line$i\
              -background [option get . background Sdr]
          }

          %s.auth.keys.lb tag configure line%s -background\
              [option get . activeBackground Sdr]
          %s.auth.keys.lb configure -state disabled
          set user_id(pgp,auth_cur_key_sel) $user_id(pgp,%s)
          set key_id(pgp,auth_cur_key_sel) $key_id(pgp,%s)
          if { [string length $user_id(pgp,auth_cur_key_sel)] > 60} {
            set dotdot "..."
          } else {
            set dotdot ""
          }

          %s.auth.pwd.l configure -text "Enter passphrase for \
                 [string range $user_id(pgp,auth_cur_key_sel) 0 60]$dotdot" \
                 -font [resource infoFont]
        } $win $win $i $win $i $i $win]
        incr i
    }
  }
 
  set no_of_keys $i
 
  if {  $key_id(pgp,auth_cur_key_sel) == ""} {
    set user_id(pgp,auth_cur_key_sel) $user_id(pgp,0)
    set  key_id(pgp,auth_cur_key_sel) $key_id(pgp,0)
    set  sig_id(pgp,auth_cur_key_sel) $sig_id(pgp,0)
  }
 
# Need to highlight previously used key in list or, if a new
# session is being created, the first key in the list

  for {set i 0} {$i < $no_of_keys} {incr i} {
    if {$key_id(pgp,auth_cur_key_sel)==$key_id(pgp,$i)} {
      $win.auth.keys.lb tag configure line$i -background\
          [option get . activeBackground Sdr]
      set user_id(pgp,auth_cur_key_sel) $user_id(pgp,$i)
    }
  }
 
# Restrict how much we display of the user id of each key

  if { [string length $user_id(pgp,auth_cur_key_sel)] > 60} {
    set dotdot "..."
  } else {
    set dotdot ""
  }
 
  $win.auth.pwd.l configure -text "Enter passphrase for\
      [string range $user_id(pgp,auth_cur_key_sel) 0 60]$dotdot" \
      -font [resource infoFont]

  return
}

#--------------------------------------------------------------------#
# Create the PGP signature file                                      #        
# 1) call pgp to create signature file irand.sig                     # 
# 2) call pgp to extract key used to file irand.pgp                  # 
# Returns:  0 = okay; 1 = problems                                   #
#--------------------------------------------------------------------#
proc pgp_create_signature {irand} {
  global recv_result
  global asympass
  global user_id
  global key_id
  global recv_authmessage
  global env

  putlogfile "Entered pgp_create_signature : irand = $irand"

# set up the text and signature files

  set local_authkey_file "[glob -nocomplain [resource sdrHome]]/$irand.pgp"
  set local_authsig_file "[glob -nocomplain [resource sdrHome]]/$irand.sig"
  set local_authtxt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"

# find PGPPATH 

  if { [ get_pgppath ] == 1 } {
    return 1
  }

# set up the cmd for signing: 
# pgp -sb -z pwd +batchmode=on +verbose=0 -u keyid txt_file -o sig_file

  set tclcmd [ list exec pgp -sb -z $asympass +batchmode=on -u ]
  set tclcmd [ concat $tclcmd 0x$key_id(pgp,auth_cur_key_sel) ]
  set tclcmd [ concat $tclcmd [ list $local_authtxt_file -o $local_authsig_file ] ]

# execute the command to create the signature file 

  putlogfile "pgp_create_sig: about to execute tclcmd = $tclcmd"
# [catch { $tclcmd } output]
  set result [catch $tclcmd output]
 
# check the call was okay (0 = something wrong)

  pgp_InterpretOutput $output pgpresult 1
  set pgpresult(msg) [pgp_ShortenOutput $pgpresult(msg) $pgpresult(summary)  $pgpresult(keyid) $pgpresult(userid) $pgpresult(siglen) $pgpresult(date) $pgpresult(sigdate)]

  if {$pgpresult(ok) == 0} {
    set recv_result "1"
    return 1
  }
    
  set mess [concat "The message is signed using keyid" 0x$key_id(pgp,auth_cur_key_sel)]
  set recv_authmessage $mess

# set up the cmd for extracting the key to a keyfile:
# pgp -kx +batchmode=on +verbose=0 key_id keyfile
    
  set tclcmd [ list exec pgp -kx +batchmode=on ]
  set tclcmd [ concat $tclcmd 0x$key_id(pgp,auth_cur_key_sel) ]
  set tclcmd [ concat $tclcmd $local_authkey_file ]

# execute the command to extract key from keyring to file

  putlogfile "pgp_create_sig: about to execute tclcmd = $tclcmd"
  set result [catch $tclcmd output]
  putlogfile "result = $result"

# check the call was okay (0 = something wrong)

  pgp_InterpretOutput $output pgpresult 1

  if {$pgpresult(ok) == 0} {
    set recv_result "1"
    return 1
  }
 
  set recv_result "0"
  return 0
}
#--------------------------------------------------------------------#
# Create the PGP encryption                                          #        
# 1) call pgp to encrypted file irand.pgp                            # 
# Returns: 0 if okay and 1 if not                                    #
#--------------------------------------------------------------------#
proc pgp_encrypt {irand} {

  global user_id
  global key_id
  global env
  global recv_encmessage
  global recv_result

  putlogfile "Entered pgp_create_encryption: irand = $irand"

# set up the txt and encrypted pgp files 

  set local_sapenc_file "[glob -nocomplain [resource sdrHome]]/$irand.pgp"
  set local_enctxt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"

# find the PGPPATH

  if { [ get_pgppath ] == 1 } {
    putlogfile "pgp_encrypt: failed to find PGPPATH"
    return 1
  }

# find the config file and set to encrypt to self as well as recipient

  set configfile $env(PGPPATH)/config.txt

  if { [file exists $configfile] } {
    putlogfile "pgp_encrypt: $configfile exists"
    set config [open $configfile r]
    set contents [read $config ] 
    if { [regexp {.*EncryptToSelf = on.*} $contents {} contents] == 1} {
      putlogfile "pgp_encrypt: EncryptToSelf is already on"
    } else {
      set config [open $configfile a 0600]
      puts $config "EncryptToSelf = on"
      close $config
    }
  } else {
    putlogfile "pgp_encrypt: $configfile does not exist"
    set config [open $configfile a 0600]
    puts $config "EncryptToSelf = on"
    close $config
  }

# set up cmd for encrypting the file:
# pgp -e +batchmode=on txt_file key_id -o pgp_file

  set tclcmd [ list exec pgp -e +batchmode=on]
  set tclcmd [ concat $tclcmd [ list $local_enctxt_file  ]]
  set tclcmd [ concat $tclcmd 0x$key_id(pgp,enc_cur_key_sel) ]
  set tclcmd [ concat $tclcmd [ list -o $local_sapenc_file  ]]

# execute the command to encrypt the file 

  putlogfile "pgp_encrypt: about to execute tclcmd = $tclcmd"
#  [catch $tclcmd output]
  set result [catch $tclcmd output]
  putlogfile "debug a"
  putlogfile "result = $result"
  putlogfile "debug b"
  putlogfile "pgp_encrypt: output = $output"

# check the call was okay (0 = something wrong)

  pgp_InterpretOutput $output pgpresult 1

  if {$pgpresult(ok) == 0} {
    set recv_result "1"
    return 1
  }

  set mess [concat "The message is encrypted for yourself using the most recent key on your secret key ring and user with keyid" 0x$key_id(pgp,enc_cur_key_sel)]
  set  recv_encmessage $mess

  set recv_result "0"
  return 0
}

#--------------------------------------------------------------------#
# Try to find out where the PGP files are located                    #
# Returns: 0 if directory containing pubring.pgp and secring.pgp     #
#          1 if can't find directory or files                        #
#--------------------------------------------------------------------#
proc get_pgppath {} {

  global env

# set the default location to be the .pgp directory 

  putlogfile " Entered get_pgppath"

  set default_pgpdir "[glob -nocomplain ~]/.pgp"
  set pgppathset 0

# if PGPPATH is set make sure its not set to "none" (?) or blank

  if { [info exists env(PGPPATH)] } {
     if { [string compare $env(PGPPATH) "none"] == 0 || 
          [string compare $env(PGPPATH) ""    ] == 0  } {
       set pgppathset 0
     } else {
       set pgppathset 1
     }
   }
  
# set PGPPATH to something sensible if its not set or silly

  if { $pgppathset == 0 } {
    if { [file isdirectory $default_pgpdir ] == 1} {
      set env(PGPPATH) $default_pgpdir
      set pgppathset 1
    } else {
      if { [ enter_pgp_path ] == 0 } {
        set pgppathset 0
      } else {
        set pgppathset 1
      }
    }
  }

# should have env(PGPPATH) set so expand any ~ etc
# check the directory and pubring.pgp and secring.pgp files exist

  set env(PGPPATH) [glob -nocomplain $env(PGPPATH)]

  if { [file isdirectory $env(PGPPATH)] == 1} {
    if { [file exists $env(PGPPATH)/secring.pgp] && 
         [file exists $env(PGPPATH)/pubring.pgp]    } {
      putlogfile "get_pgppath: returning with rc 0"
      return 0
    } else {
      timedmsgpopup "PGP file problem" "The directory $env(PGPPATH) doesn't seem to contain secret and public keyrings (secring.pgp/pubring.pgp)" 10000
      putlogfile "get_pgppath: returning with rc 1 - no files found"
      return 1
    }
  } else {
    putlogfile "get_pgppath: returning with rc 1 - not directory"
    timedmsgpopup "PGP file problem" "Cannot find $env(PGPPATH)" 10000
    return 1
  }

}

#--------------------------------------------------------------------#
# Pop up window to prompt user to enter their PGP directory          #
# Returns: 1 = OK ; 0 = problems !!                                  #
# sets $yourkey to be the PGPPATH and $pgpinfo(ok) = 1 when finish   # 
#--------------------------------------------------------------------#
proc enter_pgp_path {} {
  global  env pgpinfo yourkey 

  set w .pgpinfo
  catch {destroy $w}
  sdr_toplevel "$w -borderwidth 2" "PGP Configuration"

  frame $w.f -borderwidth 5 -relief groove
  pack  $w.f -side top

  message $w.f.l -aspect 500  -text "Please provide the name of the directory holding your PGP key files"
  pack    $w.f.l -side top

  frame $w.f.f0 
  pack  $w.f.f0 -side top -fill x -expand true

  label $w.f.f0.l -text "Key File Directory"
  pack  $w.f.f0.l -side left -anchor e -fill x -expand true

  entry $w.f.f0.e -width 30 -relief sunken -borderwidth 1 \
    -bg [option get . entryBackground Sdr] \
    -highlightthickness 0 -textvariable yourkey
  pack  $w.f.f0.e -side left
  bind  $w.f.f0.e <Key-Return> "set pgpinfo(ok) 1"

  frame $w.f.f3 
  pack  $w.f.f3 -side top -fill x -expand true

  button $w.f.f3.ok -text OK -command {set pgpinfo(ok) 1 }
  pack   $w.f.f3.ok -side left -fill x -expand true
  button $w.f.f3.cancel -text Cancel \
    -command {set pgpinfo(ok) 0 }
  pack   $w.f.f3.cancel -side left -fill x -expand true

  grab $w
  tkwait variable pgpinfo(ok)
  grab release $w
  destroy .pgpinfo

  if { $pgpinfo(ok) == 1} {
    set env(PGPPATH) $yourkey
    return 1
  } else {
    set env(PGPPATH) "none"
    return 0
  }
}

#------------------------------------------------------------------------#
# Invoke PGP to decrypt the file $irand.pgp and output to $irand.txt     #
# need to check this code as I'm not sure where it should return etc     #
#------------------------------------------------------------------------#
proc pgp_check_encryption { irand } {
    update

    global env
    global recv_enc_asym_keyid
    global recv_encstatus
    global recv_encmessage 

    putlogfile "Entered pgp_check_encryption: irand = $irand"

    set resultkey 0

# set up the encrypted and plaintext filenames 

    set local_sapenc_file "[glob -nocomplain [resource sdrHome]]/$irand.pgp"
    set local_enctxt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"

# find PGPPATH

    if { [ get_pgppath ] == 1 } {
      set recv_encstatus      "failed"
      set recv_enc_asym_keyid "nonenone"
      set recv_encmessage     "No Key Ring Path"
      return 1
    }

# set up the cmd to decrypt the file 
# pgp +batchmode=on irand.pgp -o irand.txt

    set tclcmd [ list exec pgp +batchmode=on $local_sapenc_file -o $local_enctxt_file]

# execute the tclcmd 

    putlogfile "pgp_check_encryption: about to execute tclcmd = $tclcmd"
#    [ catch $tclcmd output ]
    set result [ catch $tclcmd output ]
    putlogfile "pgp_check_encryption: output= $output"

# check the call was okay (0 = something wrong)

    pgp_InterpretOutput $output pgpresult 1

    if {$pgpresult(ok) == 1} {

# it all worked okay 

      set recv_encstatus "success"
      regsub -all {\"} $pgpresult(msg) {} mess
      set recv_encmessage $mess
      set recv_encmessage [concat "\n Message Decryption: Success\n " "\n Key Information: \n Key Length: " $pgpresult(siglen) "\n Key Creation Date:" $pgpresult(date) "\n Key ID:" $pgpresult(keyid)]
      set recv_enc_asym_keyid $pgpresult(keyid)
      return 0

    } else {

# something went wrong  - not sure what this code is doing 

      #set result [pgpExecw [list $local_sapenc_file -o $local_enctxt_file] output]
      set test [regexp -nocase {user id: (.+)} $output {} userw]
      set mykeylist [split $userw \n ]

      if {$test == 1} {
        set key [lindex $mykeylist 0]
        set interactive 0
    	set result [pgpExec [list $local_sapenc_file -o $local_enctxt_file] output $key $irand $interactive]
      } else {
        set recv_encstatus "failed"
        set recv_enc_asym_keyid "nonenone"
        set pgpresult(msg) [pgp_ShortenOutput $pgpresult(msg) $pgpresult(summary) "none" "none" "none" "none" "none"] 
        regsub -all {\"} $pgpresult(msg) {} mess
        set recv_encmessage $mess
        return 1
      }
    }
        

# The error information must be conveyed to the user - more work required
# Need a mechanism to identify the session announcement to the user.

    pgp_InterpretOutput $output pgpresult $key

    if {$pgpresult(ok) == 1} {

# it all worked okay 

      set recv_enc_asym_keyid $pgpresult(keyid)
      set recv_encstatus "success"
      set recv_encmessage [concat ". \n Message Decryption: Success\n User:" $key ". \n key information:\n Key ID:" $pgpresult(keyid) ".\n Key Length: " $pgpresult(siglen) "Bits \n Key Creation Date:" $pgpresult(date) ]
      return 0

    } else {

# there was some problem 

      set result [pgpExec [list $local_sapenc_file -o $local_enctxt_file] output  $key $irand 0]
      pgp_InterpretOutput $output pgpresult $key
      if {$pgpresult(ok) == 1} {
        set recv_encmessage [concat ". \n Message Decryption: Success\n User:" $key ". \n key information:\n  Key ID:" $pgpresult(keyid) ".\n Key Length: " $pgpresult(siglen) "Bits \n Key Creation Date:" $pgpresult(date) ]
        set recv_encstatus "success"
        set recv_enc_asym_keyid $pgpresult(keyid)
        return 0
      } else {
        set recv_encstatus "failed"
        set recv_enc_asym_keyid "nonenone"
        set recv_encmessage $pgpresult(msg)
      }
    }

  return 0
}

#------------------------------------------------------------------------#
# pgp_InterpretOutput handles a lot of the error output                  #
# I haven't checked it yet                                               #
#------------------------------------------------------------------------#
proc pgp_InterpretOutput { in outvar key} {
    global env
 
    # This function is supposed to take the output given by the other
    # pgp exec procedures and writes different information to the
    # given array.  It is probably best to put all the code that
    # change from PGP version to version in a single place.  This is
    # based on 2.6.2
 
    upvar $outvar pgpresult

    putlogfile "entered pgp_InterpretOutput"
    putlogfile "   pgp_InterpretOutput: in     = $in"
    putlogfile "   pgp_InterpretOutput: outvar = $outvar"
    putlogfile "   pgp_InterpretOutput: key    = $key"
 
# find PGPPATH

    if { [ get_pgppath ] == 1 } {
      return 1
    }

#    putlogfile "   pgp_InterpretOutput: env(PGPPATH) = $env(PGPPATH)"

# child process exited abnormally

    if {[regexp {(.*)child process exited abnormally} $in {} in] == 1} {
      set in [string trim $in]
    }
   #set pgpresult(long) $in 

#    putlogfile "   pgp_InterpretOutput: setting pgpresult(ok) to be 1"
    set pgpresult(ok) 1

# find the key ID - or set to "nonenone" if not found

    if { [ regexp -nocase {key id ([0-9a-f]+)} $in {} pgpresult(keyid)] == 1} {
	putlogfile "   pgp_InterpretOutput: keyid == $pgpresult(keyid)"
     } elseif {  [ regexp -nocase {Key ID ([0-9a-f]+)} $in {}  pgpresult(keyid)] == 1} {
          putlogfile "   pgp_InterpretOutput: keyid == $pgpresult(keyid)"
     } else {
          set pgpresult(keyid) "nonenone"
     }

# find the user ID - set to "none" if not found

     if { [regexp {user ("[^"]*")} $in {} pgpresult(userid)] == 1} {
	putlogfile "   pgp_InterpretOutput: USER = $pgpresult(userid) "
     } else {
       if { $key != 1 } {
	 set pgpresult(userid) \"$key\"
       } else {
	 set pgpresult(userid) "none"
       }
     }

# if found userid then find the date etc
#  pgp -kv  +batchmode=on USERID

     if { $pgpresult(userid) != "none" } {
       set tclcmdkey [ list exec pgp -kv  +batchmode=on]
       set tclcmdkey [ concat $tclcmdkey $pgpresult(userid) ]
       putlogfile "  pgp_InterpretOutput: $tclcmdkey"
       set resultkey [ catch $tclcmdkey output1 ]
       putlogfile "output1 = \n$output1"
       set keyinfo   [split $output1 "\n"]
       set i  0

       foreach line $keyinfo {
        if { [regexp {^(pub|sec) +([0-9]+)/([0-9A-F]+) +([0-9]+)/([0-9]+)/([0-9]+) +(.*)$} $line pgpresult(line) sigid pgpresult(siglen) pgpresult(keyid) year month day pgpresult(userid)] == 1} {
          set pgpresult(date) [concat $year $month $day]
          putlogfile "  pgp_InterpretOutput: $pgpresult(date) $pgpresult(siglen) $pgpresult(keyid) $pgpresult(userid)"
        }
        incr i
      }

    } else {
       set pgpresult(date)   "none"
       set pgpresult(siglen) "none"
     }

# find the date the signature was made 

    set pgpresult(sigdate) "Unknown"
    if {[regexp {.*Signature made (.*) GMT.*} $in {} pgpresult(sigdate)]==1} {
	putlogfile "   pgp_InterpretOutput: $pgpresult(sigdate)"
    }

# look for errors and set summary information

    if [regexp {This.*do not have the secret key.*file.} $in pgpresult(msg)] {
      set pgpresult(summary) "SecretMissing"
      set pgpresult(ok) 0
    } elseif [regexp {File is encrypted.*} $in pgpresult(msg)] {
      if [regexp {Pass phrase is good} $pgpresult(msg)] {
        set pgpresult(summary) "GoodPass Phrase"
      } else {set pgpresult(summary) "BadPass Phrase"}
    } elseif [regexp {Can't.*can't check signature integrity.*} $in \
		  pgpresult(msg)] {
      set pgpresult(summary) "PublicMissing"
      set pgpresult(ok) 0
    } elseif [regexp {WARNING:Bad signature,.*match file contents.*} $in \
                  pgpresult(msg)] {
      set pgpresult(summary) "BadContent"
      set pgpresult(ok) 0
    } elseif [regexp {.*Bad pass phrase.*} $in \
                  pgpresult(msg)] {
      set pgpresult(summary) "BadPassA"
      set pgpresult(ok) 0
    } elseif [regexp {WARNING:Can't.*can't check signature integrity.*} $in \
                  pgpresult(msg)] {
      set pgpresult(summary) "PublicMissing"
      set pgpresult(ok) 0
    } elseif [regexp {Key matching expected Key .* not found in .*} $in \
                  pgpresult(msg)] {
      set pgpresult(summary) "PublicMissing"
      set pgpresult(ok) 0
    } elseif [regexp {Keyring view error.*} $in \
                  pgpresult(msg)] {
      set pgpresult(summary) "SecringMissing"
      set pgpresult(ok) 0
    } elseif [regexp {Can't open key ring file .*} $in \
                  pgpresult(msg)] {
      set pgpresult(summary) "SecringMissing"
      set pgpresult(ok) 0
    } elseif [regexp {0 matching keys .*} $in \
                  pgpresult(msg)] {
      set pgpresult(summary) "SecringMissing"
      set pgpresult(ok) 0
    } elseif [regexp {Good signature.*} $in pgpresult(msg)] {
        if [regexp {WARNING:.*confidence} $pgpresult(msg)] {
            set pgpresult(summary) "GoodSignatureUntrusted"
        } else {set pgpresult(summary) "GoodSignatureTrusted"}
    } elseif [regexp {WARNING:.*doesn't match.*} $in \
                  pgpresult(msg)] {
      if [regexp {WARNING:.*confidence.*} $pgpresult(msg)] {
        set pgpresult(summary) "BadSignatureUntrusted"
      } else {set pgpresult(summary) "BadSignatureTrusted" }
      set pgpresult(ok) 0
    } elseif [regexp {Error:.*is not a ciphertext, signature, or key file.* } \
                 $in pgpresult(msg)] {
      set pgpresult(summary) "PublicMissing"
      set pgpresult(msg) $in
      set pgpresult(ok) 0
    } elseif [regexp {Error:.*Badly-formed or corrupted signature .* } \
                 $in pgpresult(msg)] {
      set pgpresult(summary) "BadCert"
      set pgpresult(msg) $in
      set pgpresult(ok) 0
    } elseif [regexp {ERROR} $in \
                  pgpresult(msg)] {
        set pgpresult(summary) "UnknownError"
        set pgpresult(msg) $in
        set pgpresult(ok) 0
    } elseif [regexp {Enter.*Pass phrase is good.*} $in \
                  pgpresult(msg)] {
        set pgpresult(summary) "GoodPass Phrase"
        set pgpresult(ok) 1
    } else {
        set pgpresult(summary) "Other"
        set pgpresult(msg) $in
    }
 
# DecryptExpect sometimes notifies the user that the file is not encrypted.
 
    if [regexp {Note: File may not have been encrypted} $in] {
        set pgpresult(msg) \
            "Note: File may not have been encrypted.\n\n$pgpresult(msg)"
    }
}
 
#------------------------------------------------------------------------#
# pgp_ShortenOutput - shorten the long message                           #
#------------------------------------------------------------------------#
proc pgp_ShortenOutput { pgpresult summary idkey user siglen date sigdate} {

    putlogfile "entered pgp_ShortenOutput"

    switch $summary {

       SecretMissing {return "\n Cannot decrypt, missing secret key for \n User: $user \n Keyid: $idkey \n key Length: $siglen Bits \n  Key Createdion Date: $date."}

       PublicMissing {return "\n Missing Public Key \n Key matching expected \n Key ID: $idkey \n not found in the Public Key ring "}

       GoodSignatureUntrusted {return "\n Good untrusted Signature \n From: $user \n Keyid: $idkey \n Signature Length: $siglen Bits \n Key Created date: $date \n Signature date: $sigdate."}

       GoodSignatureTrusted {return "\n Good trusted Signature \n From: $user \n Keyid: $idkey \n Signature Length: $siglen Bits \n Key Creation date: $date \n Signature date: $sigdate. "}

       BadSignatureTrusted {return "\n WARNING: Bad trusted signature doesnot match file content, \n From user: $user \n keyid: $idkey \n Signature Length: $siglen Bits \n Signature created date: $date \n Signature date:  $pgpresult(sigdate)."}

       BadSignatureUntrusted {return "\n WARNING: Bad untrusted signature, does not match file content \n From: $user \n  Keyid $idkey \n  Signature Length: $siglen Bits \n Key Creation Date: $date \n Signature date:  $pgpresult(sigdate)."}

       GoodPass {return " Good Pass $user with keyid $idkey and Signature Lenght $siglen created $date."}

       BadPass {return "\n Bad Password \n From: $user \n Keyid: $idkey\n  Signature Length $siglen Bits \n Key Creation Date: $date."}

       BadPassA {return "\n Bad Password \n From: $user \n Keyid: $idkey\n  Signature Length $siglen Bits \n Key Creation Date: $date."}

       BadCert {return " \n Bad Signature File ."}

       BadContent {return "\n Does not Match Content ."}

       UnknownError {return "PGP Error while processing message:\n$pgpresult"}

       SecringMissing {return "PGP Secretering is missing Please enter your smart card detail to decrypt secring"}

       Other {return $pgpresult}
    }
}
proc pgpExec { arglist outvar key  irand  interactive  } {
 upvar $outvar output
 global  env

 putlogfile "entered pgpExec"
# putlogfile "arglist     = $arglist"
# putlogfile "outvar      = $outvar"
# putlogfile "key         = $key"
# putlogfile "irand       = $irand"
# putlogfile "interactive = $interactive"

 if {$interactive !=0 } {
   return [pgpExec_Interactive $arglist output $irand]
 } else {
   if {$key == {}} {
     return [pgpExec_Batch $arglist output $irand]
   } else {
     set p [pgp_GetPass $key]
     if {[string length $p] == 0} {
       return 0
     }
     return [pgpExec_Batch $arglist output $p]
   }
 }

}

proc pgpExec_Interactive { arglist outvar irand } {
    upvar $outvar output
    putlogfile "entered pgpExec_Interactive"

    set args [concat [list +armorlines=0 +keepbinary=off] $arglist]
    set shcmd "unset PGPPASSFD;
        pgp \"[join [Misc_Map x {
            regsub {([$"\`])} $x {\\1} x
            set dummy $x
        } $args] {" "}]\";
        echo
        echo press Return...;
        read dummy"
#    putlogfile "shcmd = $shcmd"
    set logfile "[glob -nocomplain [resource sdrHome]]/x$irand"
    set tclcmd {exec xterm -l -lf $logfile -title PGP -e sh -c $shcmd}
#    putlogfile "tclcmd = $tclcmd"
    set result [catch $tclcmd]
    if [catch {open $logfile r} log] {
        set output ""
    } else {
        set output [read $log]
        close $log
    }
 
    # clean up the output
   # regsub -all "\[\x0d\x07]" $output "" output
    #regsub "^.*\nEnter pass phrase:" $output "" output
    #regsub "\nPlaintext filename:.*" $output "" output
    #regsub "^.*Just a moment\\.\\.+" $output "" output
    #regsub "^.*Public key is required \[^\n]*\n" $output "" output
    #set output [string trim $output]
 
#    putlogfile "pgpExec_Interactive returning $result"
    return $result
}
proc Misc_Map { var expr list } {
    upvar $var elem
 
    set result ""
 
    foreach elem $list {
        lappend result [uplevel $expr]
    }
    return $result
}
proc pgpExecw { arglist outvar } {
    upvar $outvar output
    global env
 
            set p [pgp_GetPass ]
            if {[string length $p] == 0} {
                return 0
             }
     return [pgpExec_Batch $arglist output $p]
}

#-------------------------------------------------------------------------#
# prompt the user for the password                                        #
#  - needs rewriting as if you don't know the password it doesn't go away #
#-------------------------------------------------------------------------#

proc pgp_GetPass { key } {
    global  pgpPass
    global sspass
    global ppass
 
    set keyname $key

    if [info exists sspass] {

# info on sspass

      if {$sspass == 0} {

# sspass = 0

        if [info exists pgpPass($keyname)] {
          return $pgpPass($keyname)
        }
        set passtimeout 60

        while 1 {

          set result [catch {Misc_GetPass "Enter PGP passphrase" "You have received an announcement encrypted for $key.\n\nA passphrase is needed to unlock the required secret key.\n\n(Your passphrase may be compromised if SDR is not running\nlocally and a secure connection is not being used)"} passw ]

          putlogfile "pgp_GetPass - result is >$result< and passw is >$passw<"

          if { $passw == "" } {
            putlogfile "pgp_GetPass - Error: key = >$key< and passw = >$passw<"
            return ""
          } elseif {[pgpExec_CheckPassword $passw $key]} {
            putlogfile "pgp_GetPass - Okay: key = >$key< and passw = >$passw<"
            set pgpPass($keyname) $passw
#           after [expr $passtimeout * 60 * 1000] [list pgp_ClearPassword $key]
            return $passw
          }
        }
 
      } else {

# sspass != 0

       	set pgpPass($keyname) $ppass
        return $pgpPass($keyname)
      }

   } else {

# no info on sspass 

    if [info exists pgpPass($keyname)] {
      return $pgpPass($keyname)
    }
     
    set passtimeout 60

    while 1 {

      set result [catch {Misc_GetPass "Enter PGP passphrase" "You have received an announcement encrypted for $key.\n\nA passphrase is needed to unlock the required secret key.\n\n(Your passphrase may be compromised if SDR is not running\nlocally and a secure connection is not being used)"} passw ]

      putlogfile "pgp_GetPass - result is >$result< and passw is >$passw<"

      if { $passw == "" } {
        putlogfile "pgp_GetPass - Error: key = >$key< and passw = >$passw<"
        return ""
      } elseif {[pgpExec_CheckPassword $passw $key]} {
        putlogfile "pgp_GetPass - Okay: key = >$key< and passw = >$passw<"
        set pgpPass($keyname) $passw
#       after [expr $passtimeout * 60 * 1000] [list pgp_ClearPassword $key]
        return $passw
      }
    }

   }
}
proc pgp_ClearPassword {{keyname {}}} {
    global pgpPass
    if {[string length $keyname] == 0} {
        catch {unset pgpPass}
        set pgpPass() {}
    } else {
       #putlogfile "$keyname"
        catch {unset pgpPass($keyname)}
    }
}

proc pgpExec_Batch { arglist outvar passw } {
    upvar $outvar output
    global env
    putlogfile "entered pgpExec_Batch"
 
    # pgp 4.0 command doesn't like the +keepbinary=off option

    if { [ get_pgppath ] == 1 } {
      return 1
    }

    set tclcmd [concat \
            [list exec pgp +armorlines=0 +batchmode=on +pager=cat] \
            $arglist]
    putlogfile "password= $passw"
 
    if {$passw == {}} {
        catch { unset env(PGPPASSFD) }
    } else {
        lappend tclcmd << $passw
        set env(PGPPASSFD) 0
    }
    putlogfile " tclcmd = $tclcmd "
    set result [catch $tclcmd output]
    putlogfile "result = $result "
    putlogfile "output = $output "
    regsub -all "\x07" $output "" output
    putlogfile "output = $output"
 
    catch { unset env(PGPPASSFD) }
 
    putlogfile "pgpExec_Batch returning $result"
    return $result
}
proc certExec { arglist outvar irand} {
    upvar $outvar output
    global  env
        return [certExec_Interactive $arglist output $irand]
}
 
proc certExec_Interactive { arglist outvar irand } {
    upvar $outvar output
    set args [concat [list +armorlines=0 +keepbinary=off] $arglist]
    set shcmd "unset PGPPASSFD;
        pgp \"[join [Misc_Map x {
            regsub {([$"\`])} $x {\\1} x
            set dummy $x
        } $args] {" "}]\";
        echo
        echo press Return...;
        read dummy"
    #putlogfile " $shcmd"
 
    set logfile "[glob -nocomplain [resource sdrHome]]/x$irand"
    set tclcmd {exec xterm -l -lf $logfile -title PGP -e sh -c $shcmd}
    #putlogfile "$tclcmd"
    set result [catch $tclcmd]
    if [catch {open $logfile r} log] {
        set output ""
    } else {
        set output [read $log]
        #putlogfile "$output"
        close $log
    }
 
 
    return $result
}
proc toggle_pass {} {
global spass
global sspass
   if {$spass=="yes"} {
     set sspass 1 
    } else {
     set sspass 0
   }
}

# --------------------------------------------------------------------------- #
# Misc_GetPass - pops up window for PGP passphrase and asks if using same one #
# --------------------------------------------------------------------------- #
proc Misc_GetPass { title label } {
    global getpass ppass spass sspass

    set w .getpass
    catch {destroy $w}
    sdr_toplevel "$w -borderwidth 10" $title

    checkbutton $w.b1 -text "Click this box if all your PGP private keys have the same passphrase" -variable spass\
        -highlightthickness 0 -justify l \
        -relief flat -onvalue yes -offvalue no \
        -command "toggle_pass"
    #tixAddBalloon $w.b1 Button [tt "Select \"Same PASS\"  If you are using the same passphrase for all your secret Keys in the secrekey ring.  "]
     pack $w.b1 -side top -anchor nw

     label $w.lab -text  $label
     pack $w.lab -side top  -anchor w

     #password $w.entry -width 30 -relief sunken -borderwidth 1 \
        -variable ppass
     password $w.entry -width 30 -relief sunken -borderwidth 1 -variable ppass \
         -background [option get . entryBackground Sdr]
     pack $w.entry -side top  -anchor w
     bind $w.entry <Key-Return> "set getpass(ok) 1"

     frame  $w.but
     pack   $w.but -side top -fill x -expand true

     button $w.but.ok -text OK -command {set getpass(ok) 1 }
     pack $w.but.ok -side left -fill x -expand true

     button $w.but.cancel -text Cancel -command { set getpass(ok) 0} 
     pack $w.but.cancel -side left -fill x -expand true

     grab $w
     tkwait variable getpass(ok)
     grab release $w
     destroy $w
     if { $getpass(ok) == 1} {
       #putlogfile " PASSWORD from MIS_GetPass "
       return $ppass
     } else {
       return {}
     }
}
proc Misc_Gettext { title label } {
    global gettext
    global ptext

     set w .gettext
     catch {destroy $w}
     sdr_toplevel "$w -borderwidth 10" $title
     label $w.lab -text  $label
     pack $w.lab -side top  -anchor w
     entry $w.entry  -width 30 -relief sunken -borderwidth 1 \
                  -bg [option get . entryBackground Sdr] \
                  -highlightthickness 0 -textvariable gettext(result)
     pack $w.entry -side left  
     frame $w.but
     pack $w.but -side top -fill x -expand true
     button $w.but.ok -text OK -command {set gettext(ok) 1 }
     button $w.but.cancel -text Cancel -command { set gettext(ok) 0} 
      pack $w.but.ok -side left -fill x -expand true
pack $w.but.cancel -side left -fill x -expand true
      foreach f [list $w.entry $w.but.ok $w.but.cancel] {
        bindtags $f [list .gettext [winfo class $f] $f all]
          }
 
        bind .gettext <Alt-o> "focus $w.but.ok ; break"
        bind .gettext <Alt-c> "focus $w.but.cancel ; break"
        bind .gettext <Alt-Key> break
        bind .gettext <Return> { set gettext(ok) 1}
        bind .gettext <Control-c> { set gettext(ok) 0}
       focus $w.entry
       grab $w
       tkwait variable gettext(ok)
       grab release $w
       destroy $w
       if { $gettext(ok) == 1} {
          #putlogfile "$gettext(result)"
        return $gettext(result)
       } else {
             return 0
       }
}

proc certExec { arglist outvar irand} {
    upvar $outvar output
    global  env
        return [certExec_Interactive $arglist output $irand]
}
 
proc certExec_Interactive { arglist outvar irand } {
    upvar $outvar output
    set args [concat [list +armorlines=0 +keepbinary=off] $arglist]
    set shcmd "unset PGPPASSFD;
        pgp \"[join [Misc_Map x {
            regsub {([$"\`])} $x {\\1} x
            set dummy $x
        } $args] {" "}]\";
        echo
        echo press Return...;
        read dummy"
    #putlogfile " $shcmd"
 
    set logfile "[glob -nocomplain [resource sdrHome]]/x$irand"
    set tclcmd {exec xterm -l -lf $logfile -title PGP -e sh -c $shcmd}
    #putlogfile "$tclcmd"
    set result [catch $tclcmd]
    if [catch {open $logfile r} log] {
        set output ""
    } else {
        set output [read $log]
        close $log
    }
 
 
    return $result
}


proc pgpExec_CheckPassword { passw key } {
 
    set tmpfile "[glob -nocomplain [resource sdrHome]]/pwdin"
    set outfile "[glob -nocomplain [resource sdrHome]]/pwdout"
 
    set out [open $tmpfile w 0600]
    puts $out "salut"
    close $out
   
    pgpExec_Batch [list -as $tmpfile -o $outfile -u [lindex $key 0]] err $passw
    file delete $tmpfile
 
    # pgp thinks he knows better how to name files !
    if {![file exists $outfile] && [file exists "$outfile.asc"]} {
        pgp_Rename "$outfile.asc" $outfile
    }
    if {![file exists $outfile]} {
        if {![regexp "PGP" $err]} {
            # Probably cannot find pgp to execute.
            putlogfile "<PGP> can't find pgp"
	   } else {
            if [regexp {(Error:[^\.]*)\.} $err x match] {
            putlogfile " some error "
            }
        }
        return 0
    } else {
        file delete $outfile
        #putlogfile "CHECKPASS"
        return 1
    }
}
proc pgp_Rename { old new } {
        file rename -force $old $new
}

proc pgp_AddCert { filename title label } {
    global getans env

    if { [ get_pgppath ] == 1 } {
      return 1
    }

     set w .getans
     catch {destroy $w}
     sdr_toplevel "$w -borderwidth 10" $title
     label $w.lab -text  $label
     pack $w.lab -side top -fill x -expand true
     frame $w.but
     pack $w.but -side top -fill x -expand true
     button $w.but.yes -text YES -command {set getans(yes) 1 }
     button $w.but.no -text NO -command { set getans(yes) 0} 
      pack $w.but.yes -side left -fill x -expand true
      pack $w.but.no -side left -fill x -expand true
      foreach f [list $w.but.yes $w.but.no] {
        bindtags $f [list .getans [winfo class $f] $f all]
          }
        bind .getans <Alt-o> "focus $w.but.yes ; break"
        bind .getans <Alt-c> "focus $w.but.no ; break"
        bind .getans <Alt-Key>  break
        bind .getans <Return> { set getans(yes) 1}
        bind .getans <Control-c> { set getans(yes) 0}
       grab $w
       tkwait variable getans(yes)
       grab release $w
       destroy $w
       if { $getans(yes) == 1} {
        set tclcmd [ list exec pgp -ka +batchmode=on $filename]
        #putlogfile "$tclcmd"
        set result [catch $tclcmd output]
        return 1
       } else {
         return 0 
       }
}

proc Sdr_Focus {} {
    global exwin
    focus $exwin(mtext)
}

