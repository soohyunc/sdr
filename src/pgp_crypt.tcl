
# AUTH start
# ---------------------------------------------------------------------
proc show_pgp_keys {win} {
    $win.auth.pwd.e configure -state normal
    pgp_get_key_list $win
}
 
proc clear_asym_keys {win type} {
    global user_id
    global key_id
    set key_id($type,auth_cur_key_sel) ""
    set user_id($type,auth_cur_key_sel) ""
    $win.auth.keys.lb configure -state normal
    $win.auth.keys.lb delete 1.0 end
    $win.auth.pwd.l configure -text "" -font [resource infoFont]
    $win.auth.pwd.e delete 0 end
    $win.auth.pwd.e configure -state disabled
}
# ---------------------------------------------------------------------
# SYMT end
# ---------------------------------------------------------------------

proc enc_clear_asym_keys {win type} {
    global user_id
    global key_id
    set key_id($type,enc_cur_key_sel) ""
    set user_id($type,enc_cur_key_sel) ""
#    $win.enc.keys.lb configure -state normal
    $win.enc.keys.lb delete 0 end
}

proc enc_pgp_get_key_list {win aid} {
    global no_of_keys
    global user_id
    global key_id
    global sig_id
    global ldata
    global env
    #putlogfile "enc_pgp_get_key_list"
    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
      set env(PGPPATH) $env(PGPPATH)
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
                return 0
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }
    #set testpgp $testdir/pgp
    set tclcmd [ list exec pgp -kv ]

    set result [ catch $tclcmd keylist ]
      #putlogfile " $env(PGPPATH) $tclcmd $keylist"
    
    if {$result == 0} {
        putlogfile "Cannot open key-file \n"
        if { [ enter_pgp_path ] == 0} {
          return 0
        } else {
        enc_pgp_get_key_list $win $aid
        }
    } else {
        # Extract the user id and key id of each key found in the local
        # PGP public key-ring.
        set keylist [split $keylist "\n"]
        set i 0
	$win.enc.keys.lb delete 0 end
        foreach line $keylist {
           if [regexp {^(pub|sec) +[0-9]+/([0-9A-F]+) [0-9/]+ (.*)$} \
               $line {} sigid keyid userid] {
                  set user_id(pgp,$i) $userid
                  set key_id(pgp,$i) $keyid
                  set sig_id(pgp,$i) $sigid
                  if { [string length $userid] > 26 } {
                        set dotdot "..."
                  } else {
                        set dotdot ""
                  }
		  set keyn [string range $userid 0 26]$dotdot
		  #$win.enc.keys.lb delete $i end
		  $win.enc.keys.lb insert $i "$keyn"
 
                  incr i
 
             }
           }
		set no_of_keys $i
   		bind  $win.enc.keys.lb <1> "%W selection clear 0 end;\
                            %W selection set \[%W nearest %y\];\
				 [ format { 
		global no_of_keys
                global  user_id key_id
                set selkey [%s.enc.keys.lb curselection]
		if {$selkey==""} {
    		errorpopup "No Key Selected" "You must select a key for encryption"
    		log "user selected no key"
    		return 0
  		}
                %s.enc.keys.lb  get [lindex $selkey 0]
		#%s.enc.keys.lb configure -state normal
			set pgpkey [lindex $selkey 0]
	   	set user_id(pgp,enc_cur_key_sel) $user_id(pgp,$pgpkey)
	   	set key_id(pgp,enc_cur_key_sel) $key_id(pgp,$pgpkey)
 			if { [string length $user_id(pgp,enc_cur_key_sel)] > 18} {
                              set dotdot "..."
                            } else {
                                set dotdot ""
                            }
		    } $win $win $win $win] "
        }
 
  if {([string compare $aid "new"]!=0)&&($ldata($aid,enc_asym_keyid)!="")} {
         for {set i 0} {$i < $no_of_keys} {incr i} {
          if {[string compare $ldata($aid,enc_asym_keyid) $key_id(pgp,$i)] == 0} {
                $win.enc.keys.lb  selection set $i
                set user_id(pgp,enc_cur_key_sel) $user_id(pgp,$i)
		break
          }
 
        	}
	}
  return
}

# ---------------------------------------------------------------------
# SYMT end
# ---------------------------------------------------------------------


proc pgp_check_authentication {irand} {
    update
    global env 
    global recv_asym_keyid
    global recv_authstatus
    global recv_authmessage
    #putlogfile "Check authentication"
    set local_authtxt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"
    set local_authsig_file "[glob -nocomplain [resource sdrHome]]/$irand.sig"
    set local_key_file "[glob -nocomplain [resource sdrHome]]/$irand.pgp"
    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
       if {[string compare $env(PGPPATH) "none"] == 0 } {
      		set recv_authstatus "failed"
      		set recv_asym_keyid "nonenone"
      		set recv_authmessage "No Key Ring Path"
                set env(PGPPATH) "none"
                return 1
       } else {
      set env(PGPPATH) $env(PGPPATH)
      }
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
      		set recv_authstatus "failed"
      		set recv_asym_keyid "nonenone"
      		set recv_authmessage "No Key Ring Path"
                set env(PGPPATH) "none"
                return 1
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }

    set tclcmd [ list exec pgp +batchmode=on $local_authsig_file $local_authtxt_file ]
    #putlogfile "$tclcmd"
    set result [ catch $tclcmd output ]
    #putlogfile "PGPPATH $env(PGPPATH)" 
    putlogfile "output $output" 
 
    # The error information must be conveyed to the user - more work
    # required....Need a mechanism to identify the session announcement to
    # the user.
    pgp_InterpretOutput $output pgpresult 1
    #putlogfile "OK=$pgpresult(ok) summary: $pgpresult(summary)"
    if {$pgpresult(ok) == 1} {
    set pgpresult(msg) [pgp_ShortenOutput $pgpresult(msg) $pgpresult(summary)  $pgpresult(keyid) $pgpresult(userid) $pgpresult(siglen) $pgpresult(date) $pgpresult(sigdate)]
    set recv_authstatus "trustworthy"
    regsub -all {\"} $pgpresult(msg) {} mess
    set  recv_authmessage $mess
    set recv_asym_keyid $pgpresult(keyid)
    #timedmsgpopup "$pgpresult(msg)\n" "$recv_authstatus" 10000 
    } else {
        if { [ file exists $local_key_file ] } {
        update
        set oldpgppath $env(PGPPATH)
        catch { unset env(PGPPATH)}
        set env(PGPPATH) "[glob -nocomplain [resource sdrHome]]"
        #putlogfile "NEWPGPPATH $env(PGPPATH)"
        set localpub  "[glob -nocomplain [resource sdrHome]]/pubring.pgp"
        file copy  $local_key_file $localpub
        set tclcmd [ list exec pgp +batchmode=on $local_authsig_file $local_authtxt_file ]
         #putlogfile "$tclcmd"
        set result [ catch $tclcmd output ]
        #putlogfile "inteoutput $output"
     	pgp_InterpretOutput $output pgpresult 1
        #putlogfile "OK=$pgpresult(ok) summary: $pgpresult(summary)"
        file delete "[glob -nocomplain [resource sdrHome]]/pubring.pgp"
        catch { unset env(PGPPATH)}
        set env(PGPPATH) $oldpgppath
     		if {$pgpresult(ok) == 1} {
    set pgpresult(msg) [pgp_ShortenOutput $pgpresult(msg) $pgpresult(summary)  $pgpresult(keyid) $pgpresult(userid) $pgpresult(siglen) $pgpresult(date) $pgpresult(sigdate)]
      		set recv_authstatus "integrity"
                regsub -all {\"} $pgpresult(msg) {} mess
      		set recv_authmessage $mess
    		set recv_asym_keyid $pgpresult(keyid)
# Ask the user if he wants to add the certificate to the publicKey 
                #catch { unset env(PGPPATH)}
set pubkey [concat "Would you like to add Public key of \" " $pgpresult(userid) "\"to your public key ring"]
                 regsub -all {\"}  $pubkey {} pubkey1
                 pgp_AddCert $local_key_file "Adding Public Key" "$pubkey1"
                 
     		} else {
    set pgpresult(msg) [pgp_ShortenOutput $pgpresult(msg) $pgpresult(summary)  $pgpresult(keyid) "none" "none" "none" "none" ]
    	# 	set result [ certExec [list  $local_authsig_file $local_authtxt_file ] output $irand]
      		set recv_authstatus "failed"
      		set recv_asym_keyid $pgpresult(keyid)
                regsub -all {\"} $pgpresult(msg) {} mess
      		set recv_authmessage $mess
      		}
        
       # catch { unset env(PGPPATH)}
  } else {
    set pgpresult(msg) [pgp_ShortenOutput $pgpresult(msg) $pgpresult(summary) pgpresult(keyid) "none" "none" "none" "none" ]
      		set recv_authstatus "failed"
      		set recv_asym_keyid $pgpresult(keyid)
                regsub -all {\"} $pgpresult(msg) {} mess
      		set recv_authmessage $mess
     }
 }
    return 1
}
proc pgp_cleanup {irand} {
   set txtfile "[glob -nocomplain [resource sdrHome]]/$irand.txt"
   set sigfile "[glob -nocomplain [resource sdrHome]]/$irand.sig"
   set pgpfile "[glob -nocomplain [resource sdrHome]]/$irand.pgp"
 
   set filelist "[list $txtfile $sigfile $pgpfile]"
 
   foreach filename $filelist {
     if { [file exists $filename] } {
       file delete $filename
     }
   }
 
}

proc enc_pgp_cleanup {irand} {
   set txtfile "[glob -nocomplain [resource sdrHome]]/$irand.txt"
   set sigfile "[glob -nocomplain [resource sdrHome]]/$irand.sig"
   set pgpfile "[glob -nocomplain [resource sdrHome]]/x$irand"
 
   set filelist "[list $txtfile $sigfile $pgpfile]"
 
   foreach filename $filelist {
     if { [file exists $filename] } {
       file delete $filename
     }
   }
 
}
proc pgp_get_key_list { win } {
    global no_of_keys
    global user_id
    global key_id
    global sig_id
    global env
    set resultkey 0

    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
      set env(PGPPATH) $env(PGPPATH)
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
                return 0
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }
     set i 0
     set j 0
      if { [file exists $env(PGPPATH)/secring.enc] } {
     	if [info exists env(SMARTLOC)] {
     	putlogfile " SMART CARD Being Used"
     	set tclcmd [ list exec pgp -kv $env(PGPPATH)/secring.pgp ]
        set resultkey [ catch $tclcmd keylist ]
         pgp_InterpretOutput $keylist pgpresult 1
            if {$pgpresult(ok) == 1} { 
                                 set i 1
                                 set j 1
                                 } else {
                              timedmsgpopup "Secring view error" "Wrong smart card configration" 10000
                               return 0
                                 }
     	} else {
        if { [pgp_smart "SMARTCARD" " Place your smartcard"  "OK"] == 0 } {
           set resultkey 0
        } else {
     	while { $j == 0} {
     	if { [enter_smart_pse_details] == 0 } {
        if { [file exists $env(PGPPATH)/secring.pgp] } {
     	set tclcmd [ list exec pgp -kv $env(PGPPATH)/secring.pgp ]
        set resultkey [ catch $tclcmd keylist ]
         pgp_InterpretOutput $keylist pgpresult 1
            if {$pgpresult(ok) == 1} { 
                                 set i 1
                                 set j 1
                                 } else {
                              timedmsgpopup "Secring view error" "Wrong smart card configration" 10000
                               return 0
                                 }
          } elseif  { [file exists $env(PGPPATH)/secring.enc] } {
               timedmsgpopup "Secring view error" "You need SMART CARD Information" 10000 
      	           set j 0
                   catch { unset env(SMARTLOC)}
             } else {
                  timedmsgpopup "Secring view error" "You need pgp ring files in $env(PGPPATH)" 10000 
                   catch { unset env(SMARTLOC)}
              return 0
            }
     	} else {
     	set result [Misc_CheckSmart $env(SMARTPIN) $env(SMARTLOC)]
     	while {$i == 0 } {
                        	if { $result == 1} {
                        	#putlogfile "The SMART pse and pin check OK"
                         	set env(USERPIN) $env(SMARTPIN)
                         	set tclcmd [ list exec secude pkcs7dec -p $env(SMARTLOC) -i $env(PGPPATH)/secring.enc -o $env(PGPPATH)/secring.pgp]
                         	set result [ catch $tclcmd output ]
                                pkcs7_InterpretOutput $output pkcs7result 
                                if {$pkcs7result(ok) == 0} {
                              timedmsgpopup "Secring view error" "Wrong smart card configration" 10000
                                catch {unset env(SMARTLOC)}
                        	catch {unset env(SMARTPIN)}
				set i 1
                                set j 0
                               } else {
                               set i 1
                               set j 1
                         	set tclcmd [ list exec pgp -kv $env(PGPPATH)/secring.pgp ]
                                set resultkey [ catch $tclcmd keylist ]
                                pgp_InterpretOutput $keylist pgpresult 1
                                  if {$pgpresult(ok) == 1} { 
                                 set i 1
                                 set j 1
                                 } else {
                                  set i 1
                                  set j 0
                              timedmsgpopup "Secring view error" "Wrong smart card configration" 10000
                                 }
                                 }

                        	} else {
                        	catch {unset env(SMARTLOC)}
                        	catch {unset env(SMARTPIN)}
                        	if {[enter_smart_pse_details ] == 0} {
                          if { [file exists $env(PGPPATH)/secring.pgp] } {
     	                  set tclcmd [ list exec pgp -kv $env(PGPPATH)/secring.pgp ]
                          set resultkey [ catch $tclcmd keylist ]
                                pgp_InterpretOutput $keylist pgpresult 1
                                  if {$pgpresult(ok) == 1} { 
                                    set i 1
                                    set j 1
                                 } else {
                                  set i 1
                                  set j 0
                              timedmsgpopup "Secring view error" "Wrong smart card configration" 10000
                                catch {unset env(SMARTLOC)}
                                catch {unset env(SMARTPIN)}
                                 }
                            } elseif  { [file exists $env(PGPPATH)/secring.enc] } {
                                 timedmsgpopup "Secring view error" "You need SMART CARD Information" 10000 
                                     set i 1
      	                             set j 0
                               } else {
                                    timedmsgpopup "Secring view error" "You need pgp ring files in $env(PGPPATH)" 10000 
                                return 0
                              }
                         	} else {
                          	set result [Misc_CheckSmart $env(SMARTPIN)  $env(SMARTLOC) ]
                        	}
                              }
                      	   }
                  	}
           	}
            }
     	}
    } else {
     if { [file exists $env(PGPPATH)/secring.pgp] } {
     set tclcmd [ list exec pgp -kv $env(PGPPATH)/secring.pgp ]
     set resultkey [ catch $tclcmd keylist ]
     pgp_InterpretOutput $keylist pgpresult 1
     if {$pgpresult(ok) == 1} {
                             set resultkey 1
                                 } else {
                              timedmsgpopup "Secring view error" "Wrong smar
t card configration" 10000
                               return 0
                                 }
    } else {
           set resultkey 0
    }
    }
    #putlogfile "COMMAND= $tclcmd KEYLIST= $keylist"
    if {$resultkey == 0} {
        putlogfile "Cannot open key-file \n"
            if { [ enter_pgp_path] == 0 } {
                return 0
             } else {
        pgp_get_key_list $win
        }
    } else {
 
        # Extract the user id and key id of each key found in the local
        # PGP public key-ring.  A modification maybe required here to
        # ensure that only public-private key pairs are listed.  Otherwise
        # we'll see the keys (belonging to other PGP users) that we have
        # certified and obviously cannot use for authentication.
        set keylist [split $keylist "\n"]
        set i 0
        foreach line $keylist {
           if [regexp {^(pub|sec) +[0-9]+/([0-9A-F]+) [0-9/]+ (.*)$} \
               $line {} sigid keyid userid] {
                  set user_id(pgp,$i) $userid
                  set key_id(pgp,$i) $keyid
                  set sig_id(pgp,$i) $sigid
 
                  if { [string length $userid] > 26 } {
                        set dotdot "..."
                  } else {
                        set dotdot ""
                  }
 
                  $win.auth.keys.lb insert [expr $i+1].0 \
                                [string range $userid 0 26]$dotdot
                  $win.auth.keys.lb insert end " \n"
                  $win.auth.keys.lb tag add line$i [expr $i+1].0 \
                                [expr $i+1].end
                  $win.auth.keys.lb tag configure line$i -background\
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
                            if { [string length $user_id(pgp,auth_cur_key_sel)] > 18} {
                                set dotdot "..."
                            } else {
                                set dotdot ""
                            }
 
                            %s.auth.pwd.l configure -text "Enter passphrase\
 for [string range $user_id(pgp,auth_cur_key_sel) 0 18]$dotdot" \
                                -font [resource infoFont]
                        } $win $win $i $win $i $i $win]
                  incr i
           }
        }
 
        set no_of_keys $i
        if {$key_id(pgp,auth_cur_key_sel) == ""} {
                set user_id(pgp,auth_cur_key_sel) $user_id(pgp,0)
                set key_id(pgp,auth_cur_key_sel) $key_id(pgp,0)
                set sig_id(pgp,auth_cur_key_sel) $sig_id(pgp,0)
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
        if { [string length $user_id(pgp,auth_cur_key_sel)] > 18} {
             set dotdot "..."
        } else {
             set dotdot ""
        }
 
        $win.auth.pwd.l configure -text "Enter passphrase for\
[string range $user_id(pgp,auth_cur_key_sel) 0 18]$dotdot" -font [resource infoFont]
    }
  return
}

proc pgp_create_signature {irand} {
    global recv_result
    global asympass
    global user_id
    global key_id
    global recv_authmessage
    global env
   set local_authkey_file "[glob -nocomplain [resource sdrHome]]/$irand.pgp"
    set local_authsig_file "[glob -nocomplain [resource sdrHome]]/$irand.sig"
    set local_authtxt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"
 
 
    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
      set env(PGPPATH) $env(PGPPATH)
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
                return 0
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }
    putlogfile "PGPPATH $env(PGPPATH)"
    set tclcmd [ list exec pgp -sb -z $asympass +batchmode=on \
        +verbose=0 -u ]
    set tclcmd [ concat $tclcmd 0x$key_id(pgp,auth_cur_key_sel) ]
    set tclcmd [ concat $tclcmd [ list $local_authtxt_file \
        -o $local_authsig_file ] ]
    set result [catch $tclcmd output]
    putlogfile "tclcmd= $tclcmd"
    putlogfile "result= $result output= $output"
 
    # Either bad passphrase, we have not set-up the correct files properly
    # in 'generate_authentication_info, or PGP doesn't work properly...
    # May want to limit the error problem to a bad passphrase, only.  This
    # can be achieved by tighter control over errors incurred in previous
    # functions.
    #if { $result == 1 } {
    pgp_InterpretOutput $output pgpresult 1
    set pgpresult(msg) [pgp_ShortenOutput $pgpresult(msg) $pgpresult(summary)  $pgpresult(keyid) $pgpresult(userid) $pgpresult(siglen) $pgpresult(date) $pgpresult(sigdate)]

        	if {$pgpresult(ok) == 0} {
                    set recv_result "0"
                    return 0
		}
    
     #}
    set mess [concat "The message is signed using keyid" 0x$key_id(pgp,auth_cur_key_sel)]
    set  recv_authmessage $mess
    
   

    set tclcmd [ list exec pgp -kx +batchmode=on +verbose=0 ]
    set tclcmd [ concat $tclcmd 0x$key_id(pgp,auth_cur_key_sel) ]
    set tclcmd [ concat $tclcmd $local_authkey_file ]
    set result [catch $tclcmd output]
    if { $result == 1 } {
    #putlogfile "result= $result output= $output"
    pgp_InterpretOutput $output pgpresult 1
    if {$pgpresult(ok) == 0} {
        #putlogfile "Something wrong here...cannot extract key for $user_id(pgp,auth_cur_key_sel) \n"
        set recv_result "0"
        return 0
    } else {
        #putlogfile "$user_id(pgp,auth_cur_key_sel) key extracted...\n"
    }
 
    #putlogfile "Adding authentication to session announcement \n"

                    set recv_result "1"
    return 1
   }
                    set recv_result "1"
    return 1
}
# ---------------------------------------------------------------------
# AUTH end
# ---------------------------------------------------------------------
 
proc pgp_create_encryption {irand} {
    global user_id
    global key_id
    global env
    global recv_encmessage
    global recv_result
    set local_sapenc_file "[glob -nocomplain [resource sdrHome]]/$irand.pgp"
    set local_enctxt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"
    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
      set env(PGPPATH) $env(PGPPATH)
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
                return 0
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }
    set configfile $env(PGPPATH)/config.txt
    #putlogfile "env $env(PGPPATH)"
    if { [file exists $configfile] } {
     set config [open $configfile r]
     set contents [read $config ] 
     	if { [regexp {.*EncryptToSelf = on.*} $contents {} contents] == 1} {
	     #putlogfile " Config File is on"
     	} else {
	    	set config [open $configfile a 0600]
    		puts $config "EncryptToSelf = on"
    		close $config
	       }
    } else {
    set config [open $configfile a 0600]
    puts $config "EncryptToSelf = on"
    close $config
    }

    set tclcmd [ list exec pgp -e +batchmode=on]
    set tclcmd [concat $tclcmd [  list $local_enctxt_file  ]]
    set tclcmd [ concat $tclcmd 0x$key_id(pgp,enc_cur_key_sel) ]
    set tclcmd [concat $tclcmd [ list -o $local_sapenc_file  ]]
    set result [catch $tclcmd output]
    #putlogfile "env $env(PGPPATH) $tclcmd output= $output"
 
   # if {$result == 1} {
        #return 0
    #}
    set mess [concat "The message is encrypted for yourself using the most recent key on your secret key ring and user with keyid" 0x$key_id(pgp,enc_cur_key_sel)]
    #putlogfile " ENCRYPTION =$mess"
    set  recv_encmessage $mess
 
    #putlogfile "Adding PGP encryption to session announcement \n"
    set recv_result "1"
    return 1
}


proc pgp_check_encryption {irand } {
    update
    global recv_enc_asym_keyid
    global recv_encstatus
    global recv_encmessage
    global env
    set resultkey 0
    set local_sapenc_file "[glob -nocomplain [resource sdrHome]]/$irand.pgp"
    set local_enctxt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"
    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
     if {[string compare $env(PGPPATH) "none"] == 0 } {
                set recv_encstatus "failed"
                set recv_enc_asym_keyid "nonenone"
                set recv_encmessage "No Key Ring Path"
                set env(PGPPATH) "none"
                return 1
       } else {
      set env(PGPPATH) $env(PGPPATH)
      }
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
                set recv_encstatus "failed"
                set recv_enc_asym_keyid "nonenone"
                set recv_encmessage "No Key Ring Path"
                set env(PGPPATH) "none"
                return 1

                return 0
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }
     set i 0
     set j 0
        if { [file exists $env(PGPPATH)/secring.enc] } {
     	if [info exists env(SMARTLOC)] {
     	putlogfile " SMART CARD Being Used"
        set resultkey 1
     	} else {
          if { [pgp_smart "SMARTCARD" " Place your smartcard" "OK" ] == 0 } {
           set resultkey 0
          } else {
     	while { $j == 0} {
     	if { [enter_smart_pse_details] == 0 } {
        if { [file exists $env(PGPPATH)/secring.pgp] } {
     	set tclcmd [ list exec pgp -kv $env(PGPPATH)/secring.pgp ]
        set resultkey [ catch $tclcmd keylist ]
         pgp_InterpretOutput $keylist pgpresult 1
            if {$pgpresult(ok) == 1} { 
                                 set i 1
                                 set j 1
                                 } else {
                              timedmsgpopup "Secring view error" "Wrong smart card configration" 10000
                               set j 1
                               set resultkey 0
                                 }
          } elseif  { [file exists $env(PGPPATH)/secring.enc] } {
               timedmsgpopup "Secring view error" "You need SMART CARD Information" 10000 
      	           set j 0
                   catch { unset env(SMARTLOC)}
                               set resultkey 0
             } else {
                  timedmsgpopup "Secring view error" "You need pgp ring files in $env(PGPPATH)" 10000 
                   catch { unset env(SMARTLOC)}
                               set j 1
                               set resultkey 0
            }
     	} else {
     	set result [Misc_CheckSmart $env(SMARTPIN) $env(SMARTLOC)]
     	while {$i == 0 } {
                        	if { $result == 1} {
                        	#putlogfile "The SMART pse and pin check OK"
                         	set env(USERPIN) $env(SMARTPIN)
                         	set tclcmd [ list exec secude pkcs7dec -p $env(SMARTLOC) -i $env(PGPPATH)/secring.enc -o $env(PGPPATH)/secring.pgp]
                         	set result [ catch $tclcmd output ]
                                pkcs7_InterpretOutput $output pkcs7result 
                                if {$pkcs7result(ok) == 0} {
                              timedmsgpopup "Secring view error" "Wrong smart card configration" 10000
                                catch {unset env(SMARTLOC)}
                        	catch {unset env(SMARTPIN)}
				set i 1
                                set j 0
                               } else {
                               set i 1
                               set j 1
                         	set tclcmd [ list exec pgp -kv $env(PGPPATH)/secring.pgp ]
                                set resultkey [ catch $tclcmd keylist ]
                                pgp_InterpretOutput $keylist pgpresult 1
                                  if {$pgpresult(ok) == 1} { 
                                 set i 1
                                 set j 1
                                 } else {
                                  set i 1
                                  set j 0
                                 set resultkey 0
                              timedmsgpopup "Secring view error" "Wrong smart card configration" 10000
                                 }
                                 }

                        	} else {
                        	catch {unset env(SMARTLOC)}
                        	catch {unset env(SMARTPIN)}
                        	if {[enter_smart_pse_details ] == 0} {
                          if { [file exists $env(PGPPATH)/secring.pgp] } {
     	                  set tclcmd [ list exec pgp -kv $env(PGPPATH)/secring.pgp ]
                          set resultkey [ catch $tclcmd keylist ]
                                pgp_InterpretOutput $keylist pgpresult 1
                                  if {$pgpresult(ok) == 1} { 
                                    set i 1
                                    set j 1
                                 } else {
                                  set i 1
                                  set j 0
                              timedmsgpopup "Secring view error" "Wrong smart card configration" 10000
                                 set resultkey 0
                                catch {unset env(SMARTLOC)}
                                catch {unset env(SMARTPIN)}
                                 }
                            } elseif  { [file exists $env(PGPPATH)/secring.enc] } {
                                 timedmsgpopup "Secring view error" "You need SMART CARD Information" 10000 
                                     set i 1
      	                             set j 0
                                 set resultkey 0
                               } else {
                                    timedmsgpopup "Secring view error" "You need pgp ring files in $env(PGPPATH)" 10000 
                                 set resultkey 0
                              }
                         	} else {
                          	set result [Misc_CheckSmart $env(SMARTPIN)  $env(SMARTLOC) ]
                        	}
                              }
                      	   }
                  	}
           	}
            }
     	}
      } else {
     if { [file exists $env(PGPPATH)/secring.pgp] } {
     set tclcmd [ list exec pgp -kv $env(PGPPATH)/secring.pgp ]
     set resultkey [ catch $tclcmd keylist ]
     pgp_InterpretOutput $keylist pgpresult 1
                             if {$pgpresult(ok) == 1} {
                             set resultkey 1
                                 } else {
                              timedmsgpopup "Secring view error" "Wrong smar
t card configration" 10000
                               return 0
                                 }
    } else {
           set resultkey 0
       }
 
    }

    
if { $resultkey == 1} {
        set tclcmd [ list exec pgp +batchmode=on $local_sapenc_file -o $local_enctxt_file]
        #putlogfile "$tclcmd \n"
        set result [ catch $tclcmd output ]
         #putlogfile "$output"
         pgp_InterpretOutput $output pgpresult 1
         #putlogfile "OK=$pgpresult(ok) summary: $pgpresult(summary)"
         	if {$pgpresult(ok) == 1} {
    		set recv_encstatus "success"
                regsub -all {\"} $pgpresult(msg) {} mess
    		set recv_encmessage $mess
    set recv_encmessage [concat "\n Message Decryption: Success\n " "\n Key Information: \n Key Length: " $pgpresult(siglen) "\n Key Creation Date:" $pgpresult(date) "\n Key ID:" $pgpresult(keyid)]
    		set recv_enc_asym_keyid $pgpresult(keyid)
    		} else {
# set result [pgpExecw [list $local_sapenc_file -o $local_enctxt_file] output]
                set test [regexp -nocase {user id:(.+)} $output {} userw]
                if {$test == 1} {
                set key [lindex $userw 0]
                set interactive 0
    		set result [pgpExec [list $local_sapenc_file \
		        -o $local_enctxt_file] output $key $irand $interactive]
               } else {
               set recv_encstatus "failed"
               set recv_enc_asym_keyid "nonenone"
               set pgpresult(msg) [pgp_ShortenOutput $pgpresult(msg) $pgpresult(summary) "none" "none" "none" "none" "none"] 
                regsub -all {\"} $pgpresult(msg) {} mess
    		set recv_encmessage $mess
	       #timedmsgpopup "Decr: $pgpresult(msg)"  "$recv_encstatus" 10000
               return 1
               }
          }
        

    # The error information must be conveyed to the user - more work
    # required....Need a mechanism to identify the session announcement to
    # the user.
    pgp_InterpretOutput $output pgpresult $key
    #putlogfile "OK=$pgpresult(ok) summary: $pgpresult(summary)"

    if {$pgpresult(ok) == 1} {
        set recv_enc_asym_keyid $pgpresult(keyid)
        set recv_encstatus "success"

    set recv_encmessage [concat ". \n Message Decryption: Success\n User:" $key ". \n key information:\n Key ID:" $pgpresult(keyid) ".\n Key Length: " $pgpresult(siglen) "Bits \n Key Creation Date:" $pgpresult(date) ]
    #set recv_encmessage [concat "Message were Successfully Decrepted for" $key ]
    } else {
     set result [pgpExec [list $local_sapenc_file \
                        -o $local_enctxt_file] output  $key $irand 0]
            pgp_InterpretOutput $output pgpresult $key
            if {$pgpresult(ok) == 1} {
            #putlogfile "keyid:$pgpresult(keyid)"
    set recv_encmessage [concat ". \n Message Decryption: Success\n User:" $key ". \n key information:\n  Key ID:" $pgpresult(keyid) ".\n Key Length: " $pgpresult(siglen) "Bits \n Key Creation Date:" $pgpresult(date) ]
    #set recv_encmessage [concat "Message were Successfully Decrepted for" $key ]
    
            set recv_encstatus "success"
            set recv_enc_asym_keyid $pgpresult(keyid)
           } else {
            set recv_encstatus "failed"
            set recv_enc_asym_keyid "nonenone"
            set recv_encmessage $pgpresult(msg)
          }
 
     }
  } else {
    set recv_encstatus "failed"
    set recv_enc_asym_keyid "nonenone"
    set recv_encmessage "Decryption failed"
    }
    #timedmsgpopup "Decryption= $pgpresult(msg)"  "$recv_encstatus" 10000
 
    return 1
}

# ---------------------------------------------------------------------
# AUTH end 
# ---------------------------------------------------------------------


proc pgp_InterpretOutput { in outvar key} {
    global env
 
    # This function is supposed to take the output given by the other
    # pgp exec procedures and writes different information to the
    # given array.  It is probably best to put all the code that
    # change from PGP version to version in a single place.  This is
    # based on 2.6.2
 
    upvar $outvar pgpresult
 
    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
      set env(PGPPATH) $env(PGPPATH)
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
                return 0
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }
    if {[regexp {(.*)child process exited abnormally} $in {} in] == 1} {
    set in [string trim $in]
    }
   #set pgpresult(long) $in 
    set pgpresult(ok) 1
    if { [ regexp -nocase {key id ([0-9a-f]+)} $in {} pgpresult(keyid)] == 1} {
	#putlogfile " keyid == $pgpresult(keyid)"
     } elseif {  [ regexp -nocase {Key ID ([0-9a-f]+)} $in {}  pgpresult(keyid)] == 1} {
          #putlogfile " keyid == $pgpresult(keyid)"
     } else {
          set pgpresult(keyid) "nonenone"
     }
     if { [regexp {user ("[^"]*")} $in {} pgpresult(userid)] == 1} {
	#putlogfile " USER = $pgpresult(userid) "
     } else {
            if { $key != 1 } {
	    set pgpresult(userid) $key
            } else {
	    set pgpresult(userid) "none"
            }
     }
    if { $pgpresult(userid) != "none" } {
        set tclcmdkey [ list exec pgp -kv  +batchmode=on]
        set tclcmdkey [concat $tclcmdkey $pgpresult(userid)]
        #putlogfile "$tclcmdkey \n"
        set resultkey [ catch $tclcmdkey output1 ]
        set keyinfo  [split $output1 "\n"]
       set i  0
	foreach line $keyinfo {
        if { [regexp {^(pub|sec) +([0-9]+)/([0-9A-F]+) +([0-9]+)/([0-9]+)/([0-9]+) +(.*)$} $line pgpresult(line) sigid pgpresult(siglen) pgpresult(keyid) year month day pgpresult(userid)] == 1} {
                set pgpresult(date) [concat $year $month $day]
		#putlogfile "$pgpresult(date) $pgpresult(siglen) $pgpresult(keyid) $pgpresult(userid)"
     }
    incr i
    }
    } else {
       set pgpresult(date) "none"
       set pgpresult(siglen) "none"
       set pgpresult(sigdate) "none"
     }
    if { [regexp {.*Signature made (.*) GMT .*} $in {} pgpresult(sigdate)] == 1 }  {
	#putlogfile " $pgpresult(sigdate)"
	}
    if [regexp {This.*do not have the secret key.*file.} $in \
            pgpresult(msg)] {
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
 
    # DecryptExpect sometimes notifies the user that the
    # file is not encrypted.
 
    if [regexp {Note: File may not have been encrypted} $in] {
        set pgpresult(msg) \
            "Note: File may not have been encrypted.\n\n$pgpresult(msg)"
    }
 
 
#     if $pgp(shortmsgs) {
        #set pgpresult(msg) [pgp_ShortenOutput $pgpresult(msg) \
                                #$pgpresult(summary)]
    #}
}
 
proc pgp_ShortenOutput { pgpresult summary idkey user siglen date sigdate} {
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
       BadContent {return "\n Doesnot Match Content ."}
       UnknownError {return "PGP Error while processing message:\n$pgpresult"}
       SecringMissing {return "PGP Secretering is missing Please enter your smart card detail to decrypt secring"}
       Other {return $pgpresult}
    }
}
proc pgpExec { arglist outvar key  irand  interactive  } {
    upvar $outvar output
    global  env
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
 
    # clean up the output
   # regsub -all "\[\x0d\x07]" $output "" output
    #regsub "^.*\nEnter pass phrase:" $output "" output
    #regsub "\nPlaintext filename:.*" $output "" output
    #regsub "^.*Just a moment\\.\\.+" $output "" output
    #regsub "^.*Public key is required \[^\n]*\n" $output "" output
    #set output [string trim $output]
 
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
proc pgp_GetPass { key } {
    global  pgpPass
    global sspass
    global ppass
 
    set keyname [lindex $key 0]
    if [info exists sspass] {
         if {$sspass == 0} {
              if [info exists pgpPass($keyname)] {
               return $pgpPass($keyname)
                }
    		set passtimeout 60
        		while 1 {
        		if [catch {Misc_GetPass "Enter PGP password" "password for $key "} passw ] {
            		return {}
        		} elseif {[pgpExec_CheckPassword $passw $key]} {
                		set pgpPass($keyname) $passw
                		#after [expr $passtimeout * 60 * 1000] \
                        	#	[list pgp_ClearPassword $key]
            		return $passw
        		}
    			}
 
       	} else {
       	set pgpPass($keyname) $ppass
         return $pgpPass($keyname)
       	}
   } else {
    if [info exists pgpPass($keyname)] {
        return $pgpPass($keyname)
    }
     
    set passtimeout 60
	while 1 {
        if [catch {Misc_GetPass "Enter PGP password" "password for $key "} passw] {
            return {}
        } elseif {[pgpExec_CheckPassword $passw $key]} {
                set pgpPass($keyname) $passw
                #after [expr $passtimeout * 60 * 1000] \
                #        [list pgp_ClearPassword $key]
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
 
    # pgp 4.0 command doesn't like the +keepbinary=off option
    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
      set env(PGPPATH) $env(PGPPATH)
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
                return 0
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }
    set tclcmd [concat \
            [list exec pgp +armorlines=0 +batchmode=on +pager=cat] \
            $arglist]
    #putlogfile "password= $passw"
 
    if {$passw == {}} {
        catch { unset env(PGPPASSFD) }
    } else {
        lappend tclcmd << $passw
        set env(PGPPASSFD) 0
    }
    #putlogfile " $tclcmd "
    set result [catch $tclcmd output]
    #putlogfile "result $result "
    #putlogfile "output $output "
    regsub -all "\x07" $output "" output
    #putlogfile "$output"
 
    catch { unset env(PGPPASSFD) }
 
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

proc Misc_GetPass { title label } {
    global getpass ppass spass sspass

    catch {destroy $w}
    set w [toplevel .getpass -borderwidth 10]
    wm title .getpass  $title

    checkbutton $w.b1 -text "Same Pass" -variable spass\
        -highlightthickness 0 -justify l \
        -relief flat -onvalue yes -offvalue no \
        -command "toggle_pass"
    #tixAddBalloon $w.b1 Button [tt "Select \"Same PASS\"  If you are using the same passphrase for all your secret Keys in the secrekey ring.  "]
     pack $w.b1 -side top -anchor nw

     label $w.lab -text  $label
     pack $w.lab -side top  -anchor w

     #password $w.entry -width 30 -relief sunken -borderwidth 1 \
        -variable ppass
     password $w.entry -width 30  -relief sunken -borderwidth 1 -variable ppass \
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
     catch {destroy $w}
    set w [toplevel .gettext -borderwidth 10]
     wm title .gettext  $title
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
    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
      set env(PGPPATH) $env(PGPPATH)
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
                return 0
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }
     catch {destroy $w}
    set w [toplevel .getans -borderwidth 10]
     wm title .getans  $title
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
proc pgp_smart { title label but} {
    global getsmartans env
    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
      set env(PGPPATH) $env(PGPPATH)
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
                return 0
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }
     catch {destroy $w}
    set w [toplevel .getsmartans -borderwidth 10]
     wm title .getsmartans  $title
     label $w.lab -text  $label
     pack $w.lab -side top -fill x -expand true
     frame $w.but
     pack $w.but -side top -fill x -expand true
     button $w.but.yes -text $but -command {set getsmartans(yes) 1 }
     button $w.but.no -text NO -command { set getsmartans(yes) 0} 
      pack $w.but.yes -side left -fill x -expand true
      pack $w.but.no -side left -fill x -expand true
      foreach f [list $w.but.yes $w.but.no] {
        bindtags $f [list .getsmartans [winfo class $f] $f all]
          }
        bind .getsmartans <Alt-o> "focus $w.but.yes ; break"
        bind .getsmartans <Alt-c> "focus $w.but.no ; break"
        bind .getsmartans <Alt-Key>  break
        bind .getsmartans <Return> { set getsmartans(yes) 1}
        bind .getsmartans <Control-c> { set getsmartans(yes) 0}
       grab $w
       tkwait variable getsmartans(yes)
       grab release $w
       destroy $w
       if { $getsmartans(yes) == 1} {
        return 1
       } else {
         return 0 
       }
}
proc Help_asym {help} {
    global sdr
    set sdrversion 2.5
    set label "Key Generation"
    set local_help_file "[glob -nocomplain [resource sdrHome]]/$help.txt"

    if [Help_Toplevel .pgphelp "Key Generation Help" pgpHelp] {
        Help1_Label .pgphelp.but label {left fill} -text $label
        Help1_AddBut .pgphelp.but setup "Make PGP Key" [list pgp_Setup]
        Help1_AddBut .pgphelp.but setup1 "Make X509 Key" [list x509_Setup]
        Help1_AddBut .pgphelp.but setup2 "Make Des Key" [list Des_Setup]
        set help "

For Asymmetric encryption and authentication we use Pretty Good Privacy
(PGP) and Public Key Cryptographic System (PKCS7) and for symetric
encryption DES.

Pretty Good Privacy (tm) (PGP), from Network Associates, is a high
security cryptographic software application for MSDOS, Unix, VAX/VMS, and
other computers.  PGP allows people to exchange files or messages with
privacy, authentication, and convenience. PGP is based on public key
cryptography. PGP combines the convenience of the Rivest-Shamir-Adleman
(RSA) public key cryptosystem with the speed of symmetric cryptography.
It uses message digests for digital signatures, data compression before
encryption, good ergonomic design, and sophisticated key management.
PGP uses \"message digests\" to form signatures.  A message digest is a
128-bit cryptographically strong one-way hash function of the message. 
It is somewhat analogous to a \"checksum\" or CRC error checking code, in
that it compactly \"represents\" the message and is used to detect
changes in the message.  Unlike a CRC, however, it is computationally
infeasible for an attacker to devise a substitute message that would
produce an identical message digest.  The message digest gets encrypted
by the private key to form a signature.  Documents are signed by
prefixing them with signature certificates, which contain the key ID of
the key that was used to sign it, a private-key-signed message digest
of the document, and a timestamp of when the signature was made.  The
receiver to look up the sender's public key to check the signature uses
the key ID.  The receiver's software automatically looks up the
sender's public key and user ID in the receiver's public key ring. The
key ID of the public key used to encrypt them prefixes encrypted
files.  The receiver uses this key ID message prefix to look up the
private key needed to decrypt the message.  The receiver's software
automatically looks up the necessary private decryption key in the
receiver's private key ring. 

Public Key Cryptographic System (PKCS7): There are many security
toolkits. Our implementation of SDR v1.5 uses Secude for generating
X509 keys and encryption and authentication. The Secude development kit
is a library that offers well-known and established symmetric and
asymmetric cryptography for popular hardware and operating system
platforms. The development kit consists of a set of functions which
allows the incorporation of security in practically any application (e.g.
client/server, e-mail, office applications) and documentation in
Hypertext Markup Language (HTML) which describes in detail the C
programming interface. There are also various commands collected in a
security command shell to ensure an immediate deployment of security. 

Before you generate keys you need to get an e-mail system which has the
capability of sending information securely; for example Exmh can send
encrypted and authenticated text body part using PGP. Eudora can send PGP
and S-MIME authenticated and encrypted messages. Next you need to
establish a group membership, possibly with an e-mail list. Section 3.4.1
of \"USER GUIDE\" shows the step required to generate DES, X509 and PGP
keys and use your chosen mail system to send it to the group members.
Section 3.4.2 of \"USER GUIDE\" will show you how to store keys recieved
via E-mail to be used by SDR v2.5. "

   
        Help1_Text .pgphelp $help
    }
}
proc Help1_AddBut {par but txt cmd {where {right padx 1}} } {
    # Create a Packed button.  Return the button pathname
    set cmd2 [list button $par.$but -text $txt -command $cmd]
    if [catch $cmd2 t] {
        catch {puts stderr "Help1_AddBut (warning) $t"}
        eval $cmd2 {-font fixed}
    }
    pack append $par $par.$but $where
    return $par.$but
}
proc Help_Toplevel { path name {class Dialog} {dismiss yes}} {
    global exwin
    if [catch {wm state $path} state] {
        set t [Help1_Toplevel $path $name $class]
        if ![info exists exwin(toplevels)] {
            set exwin(toplevels) [option get . exwinPaths {}]
        }
        set ix [lsearch $exwin(toplevels) $t]
        if {$ix < 0} {
            lappend exwin(toplevels) $t
        }
        if {$dismiss == "yes"} {
            set f [Help1_Frame $t but Menubar {top fill}]
            Help1_AddBut $f quit "Dismiss" [list Help1_Dismiss $path]
        }
        return 1
    } else {
        if {$state != "normal"} {
            catch {
                wm geometry $path $exwin(geometry,$path)
                #putlogfile "Help_Toplevel $path $exwin(geometry,$path)"
            }
            wm deiconify $path
        } else {
            catch {raise $path}
        }
        return 0
    }
}
proc Help1_Label { frame {name label} {where {left fill}} args} {
    set cmd [list label $frame.$name ]
    if [catch [concat $cmd $args] t] {
        #putlogfile "Help1_Label (warning) $t"
        eval $cmd $args {-font fixed}
    }
    pack append $frame $frame.$name $where
    return $frame.$name
}
proc Help1_Frame {par child {class Sdr} {where {top expand fill}} args } {
 
    if {$par == "."} {
        set self .$child
    } else {
        set self $par.$child
    }
    eval {frame $self -class $class} $args
    pack append $par $self $where
    return $self
}
proc Help1_Dismiss { path {geo ok} } {
    global exwin
    case $geo {
        "ok" {
            set exwin(geometry,$path) [wm geometry $path]
        }
        "nosize" {
            set exwin(geometry,$path) [string trimleft [wm geometry $path] 0
123456789x]
        }
        default {
            catch {unset exwin(geometry,$path)}
        }
    }
    if [info exists exwin(geometry,$path)] {
        # Some window managers return geometry like
        # 80x24+-1152+10
        regsub -all {\+-} $exwin(geometry,$path) + exwin(geometry,$path)
    }
    #Sdr_Focus
    wm withdraw $path
    update idletasks    ;# Helps window dismiss
}
proc Sdr_Focus {} {
    global exwin
    focus $exwin(mtext)
}




proc Help1_Toplevel { path name {class Dialog} {x {}} {y {}} } {
    set self [toplevel $path -class $class]
    set usergeo [option get $path position Position]
    if {$usergeo != {}} {
        if [catch {wm geometry $self $usergeo} err] {
            putlogfile "Help_Toplevel $self $usergeo => $err"
        }
    } else {
        if {($x != {}) && ($y != {})} {
            putlogfile "Event position $self +$x+$y"
            wm geometry $self +$x+$y
        }
    }
    wm title $self $name
    wm group $self .
    return $self
}


proc Help1_Text {frame help} {
    # Create the text widget used to display messages
    set local_help_file "[glob -nocomplain [resource sdrHome]]/$help.txt"
    global exwin
        set side right
    set t [text $frame.lb -setgrid true -width 40 -height 15  \
                -yscroll "$frame.sb set" -relief \
                flat -wrap none \
              -selectforeground [resource activeForeground] \
              -highlightthickness 0  ]
               scrollbar $frame.sb -command "$frame.lb yview" \
                -background [resource scrollbarForeground] \
                -troughcolor [resource scrollbarBackground] \
                -borderwidth 1 -relief flat \
                -highlightthickness 0
        pack $frame.lb -side left -fill both -expand true
        pack $frame.sb -side right -fill y
        $t insert insert $help
       # if [catch {open $local_help_file r} in] {
       #     $t insert insert "Cannot find file pgp.txt to display"
       #     $t configure -state disabled
       # } else {
       #     $t insert insert [read $in]
       # }
}


proc pgp_Setup {  } {
    global pgp env
 
    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
      set env(PGPPATH) $env(PGPPATH)
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
                return 0
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }
    set PGPPATH $env(PGPPATH)
    set pgp(pgppath) $env(PGPPATH)
 
    # make the key pair and self sign it
   # exec xterm -title "PGP Setup" -e sh -c {
   #     cd ${PGPPATH}
   #     rm -f pubring.bak
   #     pgp -kg
   #     rm -f pubring.bak
   #     pgp +verbose=0 +force=on -ks "" -u ""
   # } >& /dev/console
    exec xterm -title "PGP Setup" -e sh -c {
        cd ${PGPPATH}
        rm -f pubring.bak
        pgp -kg
        rm -f pubring.bak
        pgp +verbose=0 +force=on -ks "" -u ""
    }
 
    #if {![file exists "$env(PGPPATH)/pubring.bak"]} {
        #return
    #}
 
        set pgp(secring) $pgp(pgppath)/secring.pgp
        set pgp(privatekeys) [pgpExec_KeyList "" $pgp(secring)]
        #putlogfile "$pgp(privatekeys)"
 
    # send the key to the keyservers
    set pgpfile [pgpExec_GetKeys [lindex [lindex $pgp(privatekeys) 0] 0] ]
    if  [info exists env(MAILAGENT] {
    set mailagent $env(MAILAGENT)
    } else {
    set mailagent [Misc_Gettext "MAILAGENT" "Please enter mail agent"]
    }
    
    if { $mailagent != 0 } {
    set tclcmd [ list exec $mailagent ]

    set result [ catch $tclcmd output ]
    file delete $pgpfile
   }
}
proc pgpExec_KeyList { pattern keyring } {
 
    set pattern [string trimleft $pattern "<>|2"]
    pgpExec_Batch [list -kv $pattern $keyring] keylist {}
 
    # drop the revoked keys
    regsub -all "\n(pub|sec) \[^\n]+\\*\\*\\* KEY REVOKED \\*\\*\\*(\n\[\t ]
\[^\n]+)+" $keylist "" keylist
 
    if { ![regexp {.*(pub|sec) +[0-9]+(/| +)([0-9A-F]+) +[0-9]+/ ?[0-9]+/ ?[
0-9]+ +(.*)} $keylist]} {
        return {}
    } else {
        set keylist [split $keylist "\n"]
        set keys {}
        set key {}
        foreach line $keylist {
            if [regexp {^ *(pub|sec) +[0-9]+(/| +)([0-9A-F]+) +[0-9]+/ ?[0-9
]+/[0-9]+ +(.*)$} $line {} {} {} keyid userid] {
                #set key [list "0x$keyid" [string trim $userid]]
                set key [list [string trim $userid]]
                lappend keys $key
            }
        }
        return $keys
    }
}
proc pgpExec_GetKeys { key } {
    global  env
    set pgpfile  "[glob -nocomplain [resource sdrHome]]/pgpkeyfile"
    set pgpdir "[glob -nocomplain ~]/.pgp"
    if [info exists env(PGPPATH)] {
      set env(PGPPATH) $env(PGPPATH)
    } else { 
          if { [file isdirectory $pgpdir ] == 0} {
            if { [ enter_pgp_path] == 0 } {
                return 0
             }
           } else {
            set env(PGPPATH) $pgpdir
           }
    }
    set tmpfile  "[glob -nocomplain [resource sdrHome]]/tmpfile"
            set p [pgp_GetPass $key]
            if {[string length $p] == 0} {
                return 0
            }
           set fileid [open $pgpfile w]
            puts $fileid [concat "password: " $p]
            
            close $fileid
	set tclcmd [ list exec pgp -akx +armorlines=0 +batchmode=on $key $tmpfile  $env(PGPPATH)/secring.pgp]
            set result [ catch $tclcmd output ]
        if {![file exists $tmpfile] && [file exists "$tmpfile.asc"]} {
            pgp_Rename "$tmpfile.asc" $tmpfile
        }

            set tmpid [open $tmpfile r]
            set content [read $tmpid]
            close $tmpid
             file delete $tmpfile
            set fileid [open $pgpfile a]
            puts $fileid  $content
             close $fileid
        set tclcmd [ list exec pgp -akx +armorlines=0 +batchmode=on $key $tmpfile  $env(PGPPATH)/pubring.pgp]
            set result [ catch $tclcmd output ]
        if {![file exists $tmpfile] && [file exists "$tmpfile.asc"]} {
            pgp_Rename "$tmpfile.asc" $tmpfile
        }
            set tmpid [open $tmpfile r]
            set content [read $tmpid]
            close $tmpid
             file delete $tmpfile
            set fileid [open $pgpfile a]
            puts $fileid $content
            close $fileid
return $pgpfile
}
proc Des_Setup {  } {
    global  env deskey
    set result [creat_des_key]
    #putlogfile "$result"
    if { $result == 1 } {
    set desfile  "[glob -nocomplain [resource sdrHome]]/deskeyfile"
    set i 0
    while { $i == 0 } {
    if {[string length $deskey(pass)]<8} {
        bell
        timedmsgpopup "Encryption keys must be at least 8 characters" "TRY again" 3000
        Des_Setup
    } else {
    if {[string compare $deskey(pass) $deskey(pass1)] !=0} {
        timedmsgpopup "You have not entered the same key twice" "TRY again" 3000
         Des_Setup
    } else {
        set i 1
     }
    }
   }
    set fileid [open $desfile w]
            puts $fileid [concat "DES Encryption Key: " $deskey(pass)]
            close $fileid
     set fileid [open $desfile a]
            puts $fileid [concat "DES Encryption Group: " $deskey(name)]
            close $fileid

    if  [info exists env(MAILAGENT] {
    set mailagent $env(MAILAGENT)
    } else {
    set mailagent [Misc_Gettext "MAILAGENT" "Please enter mail agent"]
    }
    
    set tclcmd [ list exec $mailagent ]

    set result [ catch $tclcmd output ]
    file delete $desfile
  }
}
proc creat_des_key {} {
    global  env desinfo deskey
    global desname despass despass1
    catch {destroy $w}
    set w [toplevel .desinfo -borderwidth 2]
    wm title .desinfo "Sdr: Des Information to send to group"
    frame $w.f -borderwidth 5 -relief groove
    pack $w.f -side top
    message $w.f.l -aspect 500  -text "Please enter name of encryption group and key"
    pack $w.f.l -side top
    frame $w.f.f0
    pack $w.f.f0 -side top -fill x -expand true
    label $w.f.f0.l -text "Des Encryption group"
    pack $w.f.f0.l -side left -anchor e -fill x -expand true
    entry $w.f.f0.e -width 40 -relief sunken -borderwidth 1 \
        -bg [option get . entryBackground Sdr] \
         -highlightthickness 0   -textvariable desname
    pack $w.f.f0.e -side left
 
    frame $w.f.f1
    pack $w.f.f1 -side top -fill x -expand true
    label $w.f.f1.l -text "Encryption Key at least 8 character"
    pack $w.f.f1.l -side left -anchor e -fill x -expand true
    #entry ..f.f1.e -width 40 -relief sunken -borderwidth 1 \
#       -bg [option get . entryBackground Sdr] \
#        -highlightthickness 0
    password $w.f.f1.e -width 30 -relief sunken -borderwidth 1 \
        -variable despass -background [option get . entryBackground Sdr]
    pack $w.f.f1.e -side left
    frame $w.f.f2
    pack $w.f.f2 -side top -fill x -expand true
    label $w.f.f2.l -text "Encryption Key (again)"
    pack $w.f.f2.l -side left -anchor e -fill x -expand true
    password $w.f.f2.e -width 30 -relief sunken -borderwidth 1 \
        -variable despass1 -background [option get . entryBackground Sdr]
    pack $w.f.f2.e -side left
 
    frame $w.f.f3
    pack $w.f.f3 -side top -fill x -expand true
 
    button $w.f.f3.ok -text OK -command {set desinfo(ok) 1 }
    pack $w.f.f3.ok -side left -fill x -expand true
    button $w.f.f3.cancel -text Cancel \
            -command {set desinfo(ok) 0 }
    pack $w.f.f3.cancel -side left -fill x -expand true
    grab $w
       tkwait variable desinfo(ok)
       #grab release $w
       destroy .desinfo
       if { $desinfo(ok) == 1} {
        set deskey(name) $desname
        set deskey(pass) $despass
        set deskey(pass1) $despass1
       destroy .desinfo
          return 1
       } else {
        destroy .desinfo
        return 0
       }
}

 
proc enter_pgp_path {} {
    global  env pgpinfo yourkey yourpin

    catch {destroy $w}
    set w [toplevel .pgpinfo -borderwidth 2] 
    wm title .pgpinfo "Sdr: PGP  Configure Information"

    frame $w.f -borderwidth 5 -relief groove
    pack  $w.f -side top

    message $w.f.l -aspect 500  -text "Please configure sdr with your PGP PATH "
    pack    $w.f.l -side top

    frame $w.f.f0 
    pack  $w.f.f0 -side top -fill x -expand true

    label $w.f.f0.l -text "PGP Key Ring Location"
    pack  $w.f.f0.l -side left -anchor e -fill x -expand true

    entry $w.f.f0.e -width 30 -relief sunken -borderwidth 1 \
	-bg [option get . entryBackground Sdr] \
	-highlightthickness 0   -textvariable yourkey
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
