proc show_pkcs7_keys {win} {
    $win.auth.pwd.e configure -state normal
    pkcs7_get_key_list $win
}
 
proc pkcs7_get_key_list { win } {
    global no_of_keys
    global user_id
    global key_id
    global  env yourpse
 
        # Extract the owner of the pse and display it 
        if [info exists env(PSELOC)] {
         set yourpse $env(PSELOC)
         set result 1
    	} else {
	set i 0
         if { [enter_pse_details ] == 0} {
            return 0
         } else {
        set result [Misc_CheckPse $env(PSEPIN) $env(PSELOC)]
		while {$i == 0 } {
        		if { $result == 1} {
  			putlogfile "The pse and pinn check OK"
			set i 1
        		} else {
			catch {unset env(PSELOC)}
			catch {unset env(PSEPIN)}
                        if {[enter_pse_details ] == 0} {
                           return 0
                         } else {
                        set result [Misc_CheckPse $env(PSEPIN)  $env(PSELOC)]
			}
		}
  	   }
    	}
     }
        set ownerl [Get_ownerlist ]
        if {$result == 0} {
        putlogfile "Cannot open pse-file \n"
        } else {
        set ownerl [split $ownerl "<"]
        set i 0
        foreach line $ownerl {
        #set result [regexp { Owner:  (.+)} $line {} userid ]
        #putlogfile "result = $result"
           if [regexp {Owner:  (.+)} \
               $line {} userid ] {
                  set user_id(x509,$i) $userid
                  set key_id(x509,$i) $line
                  set key_id(x509,auth_cur_key_sel) ""
 
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
                          set user_id(x509,auth_cur_key_sel) $user_id(x509,%s)
                          set key_id(x509,auth_cur_key_sel) $key_id(x509,%s)
                            if { [string length $user_id(x509,auth_cur_key_sel)] > 18} {
                                set dotdot "..."
                            } else {
                                set dotdot ""
                            }
 
                            %s.auth.pwd.l configure -text "Enter passphrase\
 for [string range $user_id(x509,auth_cur_key_sel) 0 18]$dotdot" \
                                -font [resource infoFont]
                        } $win $win $i $win $i $i $win]
                  incr i
           }
        }
 
        set no_of_keys $i
        if {$key_id(x509,auth_cur_key_sel) == ""} {
                set user_id(x509,auth_cur_key_sel) $user_id(x509,0)
                set key_id(x509,auth_cur_key_sel) $key_id(x509,0)
        }
 
        # Need to highlight previously used key in list or, if a new
        # session is being created, the first key in the list
        for {set i 0} {$i < $no_of_keys} {incr i} {
          if {$key_id(x509,auth_cur_key_sel)==$key_id(x509,$i)} {
                $win.auth.keys.lb tag configure line$i -background\
                [option get . activeBackground Sdr]
                set user_id(x509,auth_cur_key_sel) $user_id(x509,$i)
          }
 
        }
 
        # Restrict how much we display of the user id of each key
        if { [string length $user_id(x509,auth_cur_key_sel)] > 18} {
             set dotdot "..."
        } else {
             set dotdot ""
        }
 
        $win.auth.pwd.l configure -text "Enter passphrase for\
[string range $user_id(x509,auth_cur_key_sel) 0 18]$dotdot" -font [resource infoFont]
    }
  return
}

proc pkcs7_create_signature {irand} {
    global asympass
    global recv_result
    global cert
    global user_id
    global key_id
    global recv_authmessage
    global yourpse env
    set local_x509key_file "[glob -nocomplain [resource sdrHome]]/$irand.cert"
    set local_x509sig_file "[glob -nocomplain [resource sdrHome]]/$irand.sig"
    set local_x509sigcmp_file "[glob -nocomplain [resource sdrHome]]/$irand.sigcmp"
    set local_x509txt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"
    set local_x509bdy_file "[glob -nocomplain [resource sdrHome]]/$irand.btxt"
        if [info exists env(PSELOC)] {
         set yourpse $env(PSELOC)
    	} else {
	set i 0
         if { [enter_pse_details ] == 0} {
            set recv_result "0"
            return 0
         } else {
        set result [Misc_CheckPse $env(PSEPIN) $env(PSELOC)]
		while {$i == 0 } {
        		if { $result == 1} {
  			putlogfile "The pse and pinn check OK"
			set i 1
        		} else {
			catch {unset env(PSELOC)}
			catch {unset env(PSEPIN)}
                        if {[enter_pse_details ] == 0} {
                           set recv_result "0"
                           return 0
                         } else {
                        set result [Misc_CheckPse $env(PSEPIN)  $env(PSELOC)]
			}
		}
  	   }
    	}
     }
     set newpse [Get_Owner_PSE $user_id(x509,auth_cur_key_sel)] 
    set tclcmd [ list exec secude pkcs7enc SIGNED-DATA -p $newpse -C $cert -i $local_x509txt_file  -o $local_x509sigcmp_file -E $local_x509bdy_file ]


    #putlogfile "$tclcmd \n"
    set result [catch $tclcmd output]
    set tclcmd [ list exec secude sec_zip $local_x509sigcmp_file  $local_x509sig_file ]


    #putlogfile "$tclcmd \n"
    set result [catch $tclcmd output]
    if { $result == 1 } {
    #putlogfile " $output\n"
    #putlogfile "result = $result "
    }
 
    #set tclcmd [ list exec secude psemaint -p $newpse export Cert  $local_x509key_file   ]
    #putlogfile "$tclcmd \n"
    set result [catch $tclcmd output]
    #if {$result == 0} {
    #    putlogfile "Something wrong here...cannot extract key for $user_id(x509,\auth_cur_key_sel) \n"
    #    return 0
    #} else {
    #    putlogfile "$user_id(x509,auth_cur_key_sel) key extracted...\n"
    #}
    set tclcmd [ list exec secude psemaint -p $newpse own]
    set result [ catch $tclcmd ownerlist ]
   set ownerlist [regexp -nocase {PSE Owner:  (.+)} $ownerlist {} ownerl] 
                set mess "The Message were Successfully Signed Using"
    		set recv_authmessage [ concat $mess $ownerl] 
    putlogfile "Adding authentication to session announcement \n"
    set recv_result "1"
    return 1
}

proc pkcs7_cleanup {irand} {
   file delete  "[glob -nocomplain [resource sdrHome]]/$irand.txt"
   file delete "[glob -nocomplain [resource sdrHome]]/$irand.btxt"
   file delete "[glob -nocomplain [resource sdrHome]]/$irand.sig"
   file delete "[glob -nocomplain [resource sdrHome]]/$irand.desig"
   file delete "[glob -nocomplain [resource sdrHome]]/$irand.cert"
   file delete "[glob -nocomplain [resource sdrHome]]/$irand.sigcmp"
   file delete "[glob -nocomplain [resource sdrHome]]/$irand.info"
 
}
proc enc_pkcs7_cleanup {irand} {
   file delete  "[glob -nocomplain [resource sdrHome]]/$irand.txt"
   file delete "[glob -nocomplain [resource sdrHome]]/$irand.sym"
   file delete "[glob -nocomplain [resource sdrHome]]/$irand.cert"
 
}


proc pkcs7_check_authentication {irand} {
    global recv_result
    global env
    global recv_asym_keyid
    global recv_authstatus
    global recv_authmessage
    global yourpse
   set recv_asym_keyid "none"
    set local_x509txt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"
    set local_x509sig_file "[glob -nocomplain [resource sdrHome]]/$irand.sig"
    set local_x509desig_file "[glob -nocomplain [resource sdrHome]]/$irand.desig"
    set local_info_file "[glob -nocomplain [resource sdrHome]]/$irand.info"
    set local_key_file "[glob -nocomplain [resource sdrHome]]/$irand.cert"
	set i 0
        if [info exists env(PSELOC)] {
         set yourpse $env(PSELOC)
    	} else {
	set i 0
         if { [enter_pse_details ] == 0} {
            set recv_result "0"
            return 0
         } else {
        set result [Misc_CheckPse $env(PSEPIN) $env(PSELOC)]
		while {$i == 0 } {
        		if { $result == 1} {
  			putlogfile "The pse and pinn check OK"
			set i 1
        		} else {
			catch {unset env(PSELOC)}
			catch {unset env(PSEPIN)}
                        if {[enter_pse_details ] == 0} {
                           set recv_result "0"
                           return 0
                         } else {
                        set result [Misc_CheckPse $env(PSEPIN)  $env(PSELOC)]
			}
		}
  	   }

         
    	}
     }
    set tclcmd [ list exec secude sec_zip -d $local_x509sig_file $local_x509desig_file ]
    #putlogfile "$tclcmd"
    set result [ catch $tclcmd output ]
    if { $result == 1 } {
    #putlogfile "OUTPUTZIP $output"
    }
    set newpse [Get_PSE $local_x509desig_file $irand]
    set tclcmd [ list exec secude pkcs7dec -p $newpse -i $local_x509desig_file -E $local_x509txt_file ]
    putlogfile "$tclcmd"
    set result [ catch $tclcmd output ]
    if { $result == 1 } {
    putlogfile "OUTPUT $output"
    }
    pkcs7_InterpretOutput $output pkcs7result
   set pkcs7result(msg) [pkcs7_ShortenOutput $pkcs7result(msg) $pkcs7result(summary)] 
   #putlogfile "MSGshort = $pkcs7result(msg) "
    putlogfile "OKshort=$pkcs7result(ok) summary: $pkcs7result(summary)"
    set tclcmd [ list exec secude asn1show $local_x509desig_file]
    set result [ catch $tclcmd certinfo]
    set infofile [open $local_info_file w 0600]
    puts $infofile $certinfo
    close $infofile
     set certinfofile [get_cert_info $local_info_file]
    file delete $local_info_file
    if {$pkcs7result(ok) == 1} {
    set recv_authstatus "trustworthy"
    #regsub -all {\<} $pkcs7result(keyid)  {} test1
    #regsub -all {\>} $test1 {} test2
    #regsub -all {\\} $test2 {} test3
    #regsub -all {\\} $test2 {} test3
     
    set dmess "\. \nPSE location: $newpse \n Signer Information \n"
    set recv_authmessage [concat  " \.\nSuccess\n" $pkcs7result(msg) $dmess $pkcs7result(keyid) $certinfofile]
    set recv_asym_keyid $pkcs7result(keyid) 
    
    #timedmsgpopup " $pkcs7result(msg) from $pkcs7result(keyid) " "  $recv_authstatus" 10000 
    } else {
    set recv_authstatus "failed"
    set dmess "\. \nPSE location: $newpse \n Signer Information \n"
    set recv_authmessage [concat "\.\nFailed\n"  $pkcs7result(msg) $dmess $pkcs7result(keyid) $certinfofile]
    set recv_asym_keyid $pkcs7result(keyid)
    #timedmsgpopup "$pkcs7result(msg) $pkcs7result(keyid) \n" "$recv_authstatus" 10000 
     }
    Addx509-cert-alias $local_x509desig_file  $pkcs7result(dn) 
    #timedmsgpopup "$pkcs7result(msg)"  "$recv_symstatus" 10000
    set recv_result "1"
    return 1
}

proc pkcs7_InterpretOutput { in outvar } {
upvar $outvar pkcs7result
set pkcs7result(ok) 1
    if {[regexp {Certificate of owner (<[^<]*>).*} $in {} user] == 1 } {
          set pkcs7result(keyid) $user
          set pkcs7result(dn) $user
    } elseif {[regexp {Certificate of .* (<[^<]*>).*} $in {} use] == 1 } {
          set pkcs7result(keyid) $use
      } else {
	set pkcs7result(keyid) "none"
     }
    if {[regexp {.*issued by (<[^<]*>).*} $in {} iss] == 1 } {
	  set  pkcs7result(issued) $iss
      } else { 
	  set  pkcs7result(issued) "none"
      }
    if {[regexp {.*serial number: (.*)\(.*} $in {} serial] == 1 } {
	  set pkcs7result(serialno)  $serial
      } else {
         set  pkcs7result(serialno) "none"
     }
     #putlogfile "key-id = $pkcs7result(keyid)"
     if [regexp {.*failed.*} $in pkcs7result(msg)] {
       if [regexp {You are not on the recipients.*} $in pkcs7result(msg)] {
	   set pkcs7result(summary) "SecMissing"
           set pkcs7result(ok) 0
       } elseif [regexp {The verification of the text signature failed.*} $in pkcs7result(msg)] {
	   set pkcs7result(summary) "BadContent"
           set pkcs7result(ok) 0
       } else {
        set pkcs7result(summary) "CertMissing"
        set pkcs7result(ok) 0
	}
     } elseif [regexp {.* n o t  validated .*} $in \
                  pkcs7result(msg)] {
        set pkcs7result(summary) "PublicMissing"
        set pkcs7result(ok) 0
     } elseif [regexp {Can't.*can't check signature integrity.*} $in \
                  pkcs7result(msg)] {
        set pkcs7result(summary) "PublicMissing"
        set pkcs7result(ok) 0
     } elseif [regexp {Can't find recipients .*} $in \
                  pkcs7result(msg)] {
        set pkcs7result(summary) "PublicMissing"
        set pkcs7result(ok) 0
     } elseif [regexp {Can't open PSE.*} $in \
                  pkcs7result(msg)] {
        set pkcs7result(summary) "MissingPSE"
        set pkcs7result(ok) 0
     } elseif [regexp {The PSE is not .*} $in \
                  pkcs7result(msg)] {
        set pkcs7result(summary) "MissingPSE"
        set pkcs7result(ok) 0
     } elseif [regexp {Invalid PIN .*} $in \
                  pkcs7result(msg)] {
        set pkcs7result(summary) "WrongPIN"
        set pkcs7result(ok) 0
     } elseif [regexp {.* segmentation violation .*} $in \
                  pkcs7result(msg)] {
        set pkcs7result(summary) "SegViolation"
        set pkcs7result(ok) 0
     } elseif [regexp {.* segmentation violation} $in \
                  pkcs7result(msg)] {
        set pkcs7result(summary) "SegViolation"
        set pkcs7result(ok) 0
     } elseif [regexp {Object is not in to.*} $in \
                  pkcs7result(msg)] {
        set pkcs7result(summary) "Missing Alias File"
        set pkcs7result(ok) 0
     } elseif [regexp {ERROR} $in pkcs7result(msg)] {
        set pkcs7result(summary) "UnknownError"
 	set pkcs7result(msg) $in
        set pkcs7result(ok) 0
     } elseif [regexp {which was trusted and found in PKList} $in pkcs7result(msg)] {
        set pkcs7result(summary) "GoodSig"
        set pkcs7result(ok) 1
    } else {
        set pkcs7result(summary) "Other"
        set pkcs7result(msg) $in
    }
}
proc pkcs7_ShortenOutput { pkcs7result summary } {
switch $summary {
CertMissing {return "Missing Certificate Path "}
SecMissing {return "Missing Secretkey for Decryption "}
MissingPSE {return "Missing PSE "}
SegViolation {return "segmentation violation "}
MissingAlias {return "Missing Alias File "}
WrongPIN {return "Wrong PIN "}
GoodSig {return " Good Trusted Signature\n "}
BadContent {return " The verification of the text signature failed"}
UnknownError {return " Error while processing message:$pkcs7result"}
Other {return $pkcs7result}
    }
}

proc Misc_GetX509Pass { title label } {
    global getpassx509
    global x509pass
     catch {destroy $w}
    set w [toplevel .getpassx509 -borderwidth 10]
     wm title .getpassx509  $title
     label $w.lab -text  $label
     pack $w.lab -side top  -anchor w
     password $w.entry -width 30 -relief sunken -borderwidth 1 \
        -variable x509pass
     pack $w.entry -side top  -anchor w
     frame $w.but
     pack $w.but -side top -anchor w
     button $w.but.ok -text OK -command {set getpassx509(ok) 1 }\
                                                 -underline 0
     button $w.but.cancel -text Cancel -command { set getpassx509(ok) 0} \
                                                -underline 0
      pack $w.but.ok -side left -fill x -expand true
      pack $w.but.cancel -side right -fill x -expand true
       grab $w
       tkwait variable getpassx509(ok)
       grab release $w
       destroy $w
       if { $getpassx509(ok) == 1} {
         set passpkcs  "[glob -nocomplain [$x509pass]"
          return $passpkcs
       } else {
             return {}
       }
}
proc Misc_GetPseL { title label } {
    global getpinl
    global ppinl
     catch {destroy $w}
    set w [toplevel .getpinl -borderwidth 10]
     wm title .getpinl  $title
     label $w.lab -text  $label
     pack $w.lab -side top  -anchor w
     entry $w.entry -textvariable getpinl(result)
     pack $w.entry -side top  -anchor w
     frame $w.but
     pack $w.but -side top -anchor w
     button $w.but.ok -text OK -command {set getpinl(ok) 1 }\
                                                 -underline 0
     button $w.but.cancel -text Cancel -command { set getpinl(ok) 0} \
                                                -underline 0
      pack $w.but.ok -side left -fill x -expand true
pack $w.but.cancel -side right -fill x -expand true
      foreach f [list $w.entry $w.but.ok $w.but.cancel] {
        bindtags $f [list .getpinl [winfo class $f] $f all]
          }
 
        bind .getpinl <Alt-o> "focus $w.but.ok ; break"
        bind .getpinl <Alt-c> "focus $w.but.cancel ; break"
        bind .getpinl <Alt-Key> break
        bind .getpinl <Return> { set getpinl(ok) 1}
        bind .getpinl <Control-c> { set getpinl(ok) 0}
       focus $w.entry
       grab $w
       tkwait variable getpinl(ok)
       grab release $w
       destroy $w
       if { $getpinl(ok) == 1} {
          #putlogfile "$getpinl(result)"
	return $getpinl(result)
       } else {
             return {}
       }
}

proc Misc_CheckPse {yourpin yourpse} {
global env
	set tmpfile "[glob -nocomplain [resource sdrHome]]/pwdin"
        set outfile "[glob -nocomplain [resource sdrHome]]/pwdout"
        set out [open $tmpfile w 0600]
    	puts $out "salut"
    	close $out
	set env(USERPIN) $yourpin
	set tclcmd [ list exec secude pkcs7enc SIGNED-DATA -p $yourpse -i $tmpfile -o $outfile]
	#putlogfile "$tclcmd"
	set result [ catch $tclcmd output ]
        if { $result == 1 } {
	putlogfile "$output"
         }
        file delete $tmpfile
        file delete $outfile
	pkcs7_InterpretOutput $output pkcs7result
	if {$pkcs7result(ok) == 0} {
	#putlogfile " checkresult = $pkcs7result(ok)"
        #putlogfile "$pkcs7result(summary)"
	return 0
	} else {
        #putlogfile "$pkcs7result(summary)"
	return 1
	}
}

proc Misc_CheckSmart {smartpin smartpse} {
global env
	set tmpfile "[glob -nocomplain [resource sdrHome]]/pwdin"
        set outfile "[glob -nocomplain [resource sdrHome]]/pwdout"
        set out [open $tmpfile w 0600]
    	puts $out "salut"
    	close $out
	set env(USERPIN) $smartpin
	set tclcmd [ list exec secude pkcs7enc SIGNED-DATA -p $smartpse -i $tmpfile -o $outfile]
	#putlogfile "$tclcmd"
	set result [ catch $tclcmd output ]
        if { $result == 1 } {
	putlogfile "$output"
         }
        file delete $tmpfile
        file delete $outfile
	pkcs7_InterpretOutput $output pkcs7result
	if {$pkcs7result(ok) == 0} {
	#putlogfile " checkresult = $pkcs7result(ok)"
        #putlogfile "$pkcs7result(summary)"
	return 0
	} else {
        #putlogfile "$pkcs7result(summary)"
	return 1
	}
}
proc enc_show_x509_keys {win aid} {
    enc_x509_get_key_list $win $aid
}

 
proc enc_x509_get_key_list {win aid} {
    global no_of_keys
    global user_id
    global key_id
    global sig_id
    global ldata
    global env
    #putlogfile "enc_x509_get_key_list"
    set alfile "[glob -nocomplain [resource sdrHome]]/pks-als.txt"

    if { [file exists $alfile]  } {
    putlogfile "file exists"
    } else {
    set certfile "[glob -nocomplain [resource sdrHome]]/owncert"
        # Extract the owner of the pse and display it 
        if [info exists env(PSELOC)] {
         set yourpse $env(PSELOC)
        } else {
        set i 0
         if { [enter_pse_details ] == 0} {
            return 0
         } else {
        set result [Misc_CheckPse $env(PSEPIN) $env(PSELOC)]
                while {$i == 0 } {
                        if { $result == 1} {
                        putlogfile "The pse and pinn check OK"
                        set yourpse $env(PSELOC)
                        set i 1
                        } else {
                        catch {unset env(PSELOC)}
                        catch {unset env(PSEPIN)}
                        if {[enter_pse_details ] == 0} {
                           return 0
                         } else {
                        set result [Misc_CheckPse $env(PSEPIN)  $env(PSELOC) ]
                        set yourpse $env(PSELOC)
                        }
                }
           }
        }
     }
   set test 100
   set userpin $env(USERPIN)
   unset env(USERPIN)  
   set  tclcmd [ list exec secude psemaint -p $env(PSELOC).$test ]
   set result [ catch $tclcmd noofpse]
   set env(USERPIN) $userpin
   if { [regexp {Selected PSE not in MPSEFile\, valid only ([0-9]+) to ([0-9]+)} $noofpse {} start end] == 1 } {
        incr end
    for {set i $start} {$i < $end } {incr i } {
      set tclcmd [ list exec secude psemaint -p $env(PSELOC).$i own]
      set result [ catch $tclcmd ownerlist ]
   set ownerlist [regexp -nocase {PSE Owner:  (.+)} $ownerlist {} owndn($i)]
   set tclcmd [ list exec secude psemaint -p $env(PSELOC).$i  export Cert $certfile
]
   set result [ catch $tclcmd output ]
   set tclcmd [list exec secude psemaint -p $env(PSELOC).$i addpk $certfile]
   set tclcmd [list exec secude psemaint -p $env(PSELOC).$start addpk $certfile]
   set result [ catch $tclcmd output ]
   file delete $certfile
   #set owndn [concat "<" $owndn ">"]
    set out [open  $alfile a 0600]
    puts $out $owndn($i)
    close $out

     }
   } else {
   set tclcmd [ list exec secude psemaint -p $env(PSELOC) own]
   set result [ catch $tclcmd ownerlist ]
   set ownerlist [regexp -nocase {PSE Owner:  (.+)} $ownerlist {} owndn(1)] 
   set tclcmd [ list exec secude psemaint -p $env(PSELOC) export Cert $certfile]
   set result [ catch $tclcmd output ]
   set tclcmd [list exec secude psemaint -p $env(PSELOC) addpk $certfile]
   set result [ catch $tclcmd output ]
   file delete $certfile
   #set owndn [concat "<" $owndn ">"]
    set out [open  $alfile a 0600]
    puts $out $owndn(1)
    close $out
    }
   }
        set out  [open  $alfile r]
        set i 0
	$win.enc.keys.lb delete 0 end
        while { [gets $out line ] >= 0 } {
                  set user_id(x509,$i) $line
                  set key_id(x509,$i) $line
                  set key_id(x509,enc_cur_key_sel) $key_id(x509,0)

                  if { [string length $line] > 26 } {
                        set dotdot "..."
                  } else {
                        set dotdot ""
                  }
		  set keyn [string range $line 0 26]$dotdot
		  #$win.enc.keys.lb delete $i end
		  $win.enc.keys.lb insert $i "$keyn"
                  #putlogfile "i= $i keyn=$keyn"
 
                  incr i
             }
        close $out
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
			set x509key [lindex $selkey 0]
	   	set user_id(x509,enc_cur_key_sel) $user_id(x509,$x509key)
	   	set key_id(x509,enc_cur_key_sel) $key_id(x509,$x509key)
 			if { [string length $user_id(x509,enc_cur_key_sel)] > 18} {
                              set dotdot "..."
                            } else {
                                set dotdot ""
                            }
		    } $win $win $win $win] "
 
  if {([string compare $aid "new"]!=0)&&($ldata($aid,enc_asym_keyid)!="")} {
         for {set i 0} {$i < $no_of_keys} {incr i} {
          if {[string compare $ldata($aid,enc_asym_keyid) $key_id(x509,$i)] == 0} {
                $win.enc.keys.lb  selection set $i
                set user_id(x509,enc_cur_key_sel) $user_id(x509,$i)
		break
          }
 
        	}
	}
  return
}


proc pkcs7_create_encryption {irand} {
   global user_id
    global key_id
    global env
   global yourpse
   global recv_result
   global recv_encmessage
set local_sapenc_file "[glob -nocomplain [resource sdrHome]]/$irand.sym"
    set local_enctxt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"
        if [info exists env(PSELOC)] {
         set yourpse $env(PSELOC)
        } else {
        set i 0
         if { [enter_pse_details ] == 0} {
            set recv_result "0"
            return 0
         } else {
        set result [Misc_CheckPse $env(PSEPIN) $env(PSELOC)]
                while {$i == 0 } {
                        if { $result == 1} {
                        putlogfile "The pse and pinn check OK"
                        set i 1
                        } else {
                        catch {unset env(PSELOC)}
                        catch {unset env(PSEPIN)}
                        if {[enter_pse_details ] == 0} {
                           set recv_result "0"
                           return 0
                         } else {
                        set result [Misc_CheckPse $env(PSEPIN)  $env(PSELOC) ]
                        }
                }
           }
 
 
        }
     }
                set tclcmd [ list exec secude psemaint -p $yourpse own]
                set result [ catch $tclcmd ownerlist ]
       		set ownerlist [regexp -nocase {PSE Owner:  (.+)} $ownerlist {} ownerl] 

set tclcmd [ list exec secude pkcs7enc ENVELOPED-DATA]
set tclcmd [concat $tclcmd  -p $yourpse]
set tclcmd [concat $tclcmd  -r \"$key_id(x509,enc_cur_key_sel)\"]
set tclcmd [concat $tclcmd  -r \"$ownerl\"]
set tclcmd [concat $tclcmd  -i $local_enctxt_file -o $local_sapenc_file]
putlogfile "$tclcmd"

set result [catch $tclcmd output]
        if { $result == 1 } {
	putlogfile "$output"
         }
 set mess [concat "The message was encrypted for both yourself, using your PSE public key, and user " $key_id(x509,enc_cur_key_sel)]
    set  recv_encmessage $mess

 #putlogfile "Adding x509 encryption to session announcement \n"
                           set recv_result "1"
    return 1
}

proc pkcs7_check_encryption {irand} {
    global recv_enc_asym_keyid
    global recv_encstatus
    global recv_encmessage
    global recv_result
    global env
   global yourpse
    set local_sapenc_file "[glob -nocomplain [resource sdrHome]]/$irand.sym"
    set local_enctxt_file "[glob -nocomplain [resource sdrHome]]/$irand.txt"
    set local_cert_file "[glob -nocomplain [resource sdrHome]]/$irand.cert"
        if [info exists env(PSELOC)] {
         set yourpse $env(PSELOC)
        } else {
        set i 0
         if { [enter_pse_details ] == 0} {
            set recv_result "0"
            return 0
         } else {
        set result [Misc_CheckPse $env(PSEPIN) $env(PSELOC)]
                while {$i == 0 } {
                        if { $result == 1} {
                        putlogfile "The pse and pinn check OK"
                        set i 1
                        } else {
                        catch {unset env(PSELOC)}
                        catch {unset env(PSEPIN)}
                        if {[enter_pse_details ] == 0} {
                          set recv_result "0"
                           return 0
                         } else {
                        set result [Misc_CheckPse $env(PSEPIN)  $env(PSELOC) ]
                        }
                }
           }
 
 
        }
     }
      set newpse [Get_PSE $local_sapenc_file $irand]
      #puts "$newpse"
set tclcmd [ list exec secude pkcs7dec ]
set tclcmd [concat $tclcmd  -p $newpse]
set tclcmd [concat $tclcmd  -i  $local_sapenc_file  -o $local_enctxt_file ]
putlogfile "$tclcmd"
set result [catch $tclcmd output]
        #puts "$output"
        if { $result == 1 } {
 	putlogfile "$output"
	}
         pkcs7_InterpretOutput $output pkcs7result
         putlogfile "OK=$pkcs7result(ok) summary: $pkcs7result(summary)"
                if {$pkcs7result(ok) == 1} {
                #putlogfile "keyid:$pkcs7result(keyid)"
                set recv_encstatus "success"
                set recv_enc_asym_keyid $pkcs7result(keyid)
                set tclcmd [ list exec secude psemaint -p $newpse own]
                set result [ catch $tclcmd ownerlist ]
       		set ownerlist [regexp -nocase {PSE Owner:  (.+)} $ownerlist {} ownerl] 
                set tclcmd [ list exec secude psemaint -p $newpse export Cert $local_cert_file]
                set result [ catch $tclcmd certout]
                set tclcmd [ list exec secude asn1show $local_cert_file]
                set result [ catch $tclcmd certinfo]
                set certfile [open $local_cert_file w 0600] 
                 puts $certfile $certinfo
                close $certfile
                set certinfofile [get_cert_info $local_cert_file]
                set decmes ".\n Decryption: Success \n PSE OWNER DN: "
    		set recv_encmessage [ concat $decmes  $ownerl " .\n PSE Location:" $newpse ". \n Recipient Certificate information:\n" $certinfofile] 
               #timedmsgpopup "Decr: $pkcs7result(msg)"  "$recv_encstatus" 10000
                } else {
		set recv_encstatus "failed"
                set recv_encmessage $pkcs7result(msg)
                set recv_enc_asym_keyid "none"
		set pkcs7result(msg) [pkcs7_ShortenOutput $pkcs7result(msg) $pkcs7result(summary)]
               #timedmsgpopup "Decr: $pkcs7result(msg)"  "$recv_encstatus" 10000
               set recv_result "1"
               return 1
               }
}
proc Addx509-cert-alias {file dn } {
global env
    set alfile "[glob -nocomplain [resource sdrHome]]/pks-als.txt"
    if { [file exists $alfile]  } {
    putlogfile "file exists"
    } else {
    set certfile "[glob -nocomplain [resource sdrHome]]/owncert"
    set test 100
   set userpin $env(USERPIN)
    unset env(USERPIN)
   set  tclcmd [ list exec secude psemaint -p $env(PSELOC).$test ]
   set result [ catch $tclcmd noofpse]
   set env(USERPIN) $userpin
   if { [regexp {Selected PSE not in MPSEFile\, valid only ([0-9]+) to ([0-9]+)} $noofpse {} start end] == 1 } {

        incr end
    for {set i $start} {$i < $end } {incr i } {
      set tclcmd [ list exec secude psemaint -p $env(PSELOC).$i own]
      set result [ catch $tclcmd ownerlist ]
   set ownerlist [regexp -nocase {PSE Owner:  (.+)} $ownerlist {} owndn($i)]
   set tclcmd [ list exec secude psemaint -p $env(PSELOC).$i  export Cert $certfile ]
   set result [ catch $tclcmd output ]
   set tclcmd [list exec secude psemaint -p $env(PSELOC).$i addpk $certfile]
    set tclcmd [list exec secude psemaint -p $env(PSELOC).$start addpk $certfile] 
   set result [ catch $tclcmd output ]
   file delete $certfile
   #set owndn [concat "<" $owndn ">"]
    set out [open  $alfile a 0600]
    puts $out $owndn($i)
    close $out
     }
   } else {
   set tclcmd [ list exec secude psemaint -p $env(PSELOC) own]
   set result [ catch $tclcmd ownerlist ]
   set ownerlist [regexp -nocase {PSE Owner:  (.+)} $ownerlist {} owndn(1)]
   set tclcmd [ list exec secude psemaint -p $env(PSELOC)  export Cert $certfile]
   set result [ catch $tclcmd output ]
   set tclcmd [list exec secude psemaint -p $env(PSELOC) addpk $certfile]
   set result [ catch $tclcmd output ]
   file delete $certfile
   #set owndn [concat "<" $owndn ">"]
    set out [open  $alfile a 0600]
    puts $out $owndn(1)
    close $out
    }
  }
              regsub {\<} $dn  {} test1
              regsub {\>} $test1 {} certs
    putlogfile "envUSER  $env(USERPIN)"
    set tclcmd [ list exec secude cifcerts -p $env(PSELOC) -U -u  $file ]
    putlogfile "$tclcmd"
    set result [ catch $tclcmd output ]
    putlogfile "$output"
   if {[regexp {.*Key added to PKList.*} $output testout] == 1} {
    if {[regexp {Found Certificate of (<[^<]*>).*} $output {} user] == 1 } {
    putlogfile "$user"
              regsub {\<} $user  {} test2
              regsub {\>} $test2 {} user1
    putlogfile "$user1"
    set aliasn "$user1"
    set out [open $alfile a]
    putlogfile "$user"
    puts $out $aliasn
    close $out
      } 
	} else {
 # check to see if the Alias file exists
     set i 0
              set out [open $alfile r]
              while { [gets $out line ] > 0 } {
                 if { [ string compare $line $certs ] == 0 } {
                    set i 1
                    break
                  }
                }
                close $out
              set out [open $alfile a]
             if { $i == 0 } {
                 if {[regexp {CN=.*} $dn test] == 1 } {
                  puts $out $certs
                 } else {
                 set tclcmd [ list exec secude psemaint -p $env(PSELOC) ]
                 set tclcmd [concat $tclcmd alias2dname ]
                 set tclcmd [concat $tclcmd \"$certs\"]
                  set result [ catch $tclcmd output ]
                    close $out
                  regexp {.* <(.+)>} $output {} user
                    set out [open $alfile r]
                     while { [gets $out line ] > 0 } {
                 if { [ string compare $line $user ] == 0 } {
                    set i 1
                    break
                  }
                }
                    close $out
                    if { $i == 0 } {
                     set out [open $alfile a]
		    puts $out $user
                    close $out
                      }
                 }
                 
            } 
              close $out
   }
}
proc Addx509cert {yourpse file dn pin} {
global env
    #putlogfile "$pin"
    set env(USERPIN) $pin
    #putlogfile "envUSER  $env(USERPIN)"
    set tclcmd [ list exec secude cifcerts -U -u -p $yourpse  $file ]
    putlogfile "$tclcmd"
    set result [ catch $tclcmd output ]
    regsub {\<} $dn  {} test1
    regsub {\>} $test1 {} aliasdn 
    if {[regexp {<CN=([^,]*)} $dn {} user] == 1 } {
    set aliasn "$user"
    set system "User"
    set alfile "[glob -nocomplain [resource sdrHome]]/alias.txt"
        set out [open $alfile w 0600]
    set tclal "addalias"
    set tclal [ concat $tclal  target\=\"$aliasdn\"]
    set tclal [ concat $tclal  file\=\"$system\" ]
    set tclal [ concat $tclal alias\=\"$aliasn\"]
    #set tclal [ concat $tclal alias\=\"$aliasn\@cs\.ucl\.ac\.uk\"]
    puts $out "$tclal"
    putlogfile "$tclal"
    close $out
    set tclcmd [ list exec secude psemaint -p $yourpse -i $alfile ]
    putlogfile "$tclcmd"
    set result [ catch $tclcmd output ]
    putlogfile "$result"
    #delete file $out
        if { $result == 1 } {
         putlogfile "$output"
	}
    return 0
	} else {
       putlogfile " File already exi"
    return 1
	}
}

proc enter_pse_details {} {
    global  env x509info
    global yourpse yourpin
    catch {destroy $w}
    set w [toplevel .x509info -borderwidth 2] 
    wm title .x509info "Sdr: X509  Configure Information"
    frame $w.f -borderwidth 5 -relief groove
    pack $w.f -side top
    message $w.f.l -aspect 500  -text "Please configure sdr with your PSE name, and Pin (Passphrase).  "
    pack $w.f.l -side top
    frame $w.f.f0 
    pack $w.f.f0 -side top -fill x -expand true
    label $w.f.f0.l -text "PSE Location"
    pack $w.f.f0.l -side left -anchor e -fill x -expand true
    entry $w.f.f0.e -width 30 -relief sunken -borderwidth 1 \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0   -textvariable yourpse
    pack $w.f.f0.e -side left

    frame $w.f.f1 
    pack $w.f.f1 -side top -fill x -expand true
    label $w.f.f1.l -text "PIN for X509"
    pack $w.f.f1.l -side left -anchor e -fill x -expand true
    #entry ..f.f1.e -width 40 -relief sunken -borderwidth 1 \
#	-bg [option get . entryBackground Sdr] \
#	 -highlightthickness 0
    password $w.f.f1.e -width 30 -relief sunken -borderwidth 1 \
        -variable yourpin -background [option get . entryBackground Sdr]
    pack $w.f.f1.e -side left

    frame $w.f.f3 
    pack $w.f.f3 -side top -fill x -expand true

    button $w.f.f3.ok -text OK -command {set x509info(ok) 1 }\
                                                 -underline 0
    pack $w.f.f3.ok -side left -fill x -expand true
    button $w.f.f3.cancel -text Cancel \
	    -command {set x509info(ok) 0 }
    pack $w.f.f3.cancel -side left -fill x -expand true
    grab $w
       tkwait variable x509info(ok)
       #grab release $w
       destroy .x509info
       if { $x509info(ok) == 1} {
	set env(PSELOC) $yourpse
	set env(PSEPIN) $yourpin
        #puts "$env(PSELOC)"
       destroy .x509info
          return 1
       } else {
	destroy .x509info
	return 0
       }
}
proc x509state { } {
	global env
	if [info exists env(X509STATE)] {
   	return 0
	} else {
   	return 1
	}
}

proc enter_key_details {} {
    global  key x509keyinfo
    global keypse keydn keypin keysize keypin1
    catch {destroy $w}
    set w [toplevel .x509keyinfo -borderwidth 2] 
    wm title .x509keyinfo "Sdr: X509  Configure Information"
    frame $w.f -borderwidth 5 -relief groove
    pack $w.f -side top
    message $w.f.l -aspect 500  -text "you need a newname for PSE and PIN  "
    pack $w.f.l -side top
    frame $w.f.f0 
    pack $w.f.f0 -side top -fill x -expand true
    label $w.f.f0.l -text "PSE name"
    pack $w.f.f0.l -side left -anchor e -fill x -expand true
    entry $w.f.f0.e -width 40 -relief sunken -borderwidth 1 \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0   -textvariable keypse
    pack $w.f.f0.e -side left

    frame $w.f.f1 
    pack $w.f.f1 -side top -fill x -expand true
    label $w.f.f1.l -text "PIN for PSE"
    pack $w.f.f1.l -side left -anchor e -fill x -expand true
    #entry ..f.f1.e -width 40 -relief sunken -borderwidth 1 \
#	-bg [option get . entryBackground Sdr] \
#	 -highlightthickness 0
    password $w.f.f1.e -width 30 -relief sunken -borderwidth 1 \
        -variable keypin -background [option get . entryBackground Sdr]
    pack $w.f.f1.e -side left
    frame $w.f.f11 
    pack $w.f.f11 -side top -fill x -expand true
    label $w.f.f11.l -text "PIN for PSE (again)"
    pack $w.f.f11.l -side left -anchor e -fill x -expand true
    #entry ..f.f11.e -width 40 -relief sunken -borderwidth 1 \
#	-bg [option get . entryBackground Sdr] \
#	 -highlightthickness 0
    password $w.f.f11.e -width 30 -relief sunken -borderwidth 1 \
        -variable keypin1 -background [option get . entryBackground Sdr]
    pack $w.f.f11.e -side left

    frame $w.f.f2 
    pack $w.f.f2 -side top -fill x -expand true
    
    label $w.f.f2.l -text "DN name"
    pack $w.f.f2.l -side left -anchor e -fill x -expand true
    entry $w.f.f2.e -width 40 -relief sunken -borderwidth 1 \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0   -textvariable keydn
    pack $w.f.f2.e -side left
    frame $w.f.f3 
    pack $w.f.f3 -side top -fill x -expand true
    
    label $w.f.f3.l -text "key size e.g 512,640,768,....."
    pack $w.f.f3.l -side left -anchor e -fill x -expand true
    entry $w.f.f3.e -width 40 -relief sunken -borderwidth 1 \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0   -textvariable keysize
    pack $w.f.f3.e -side left

    frame $w.f.f4 
    pack $w.f.f4 -side top -fill x -expand true

    button $w.f.f4.ok -text OK -command {set x509keyinfo(ok) 1 }\
                                                 -underline 0
    pack $w.f.f4.ok -side left -fill x -expand true
    button $w.f.f4.cancel -text Cancel \
	    -command {set x509keyinfo(ok) 0 }
    pack $w.f.f4.cancel -side left -fill x -expand true
    grab $w
       tkwait variable x509keyinfo(ok)
       #grab release $w
       destroy .x509keyinfo
       if { $x509keyinfo(ok) == 1} {
	set key(PSELOC) $keypse
	set key(PSEPIN) $keypin
	set key(PSEPIN1) $keypin1
	set key(DN) $keydn
	set key(size) $keysize
       destroy .x509keyinfo
          return 1
       } else {
	destroy .x509keyinfo
	return 0
       }
}
proc x509_Setup {} {
global key env
	if { [enter_key_details ] == 0} {
            timedmsgpopup "no infomation is given " "Key is not generated" 3000
         } else {
         set i 0
          while { $i == 0 } {
           if {[string compare $key(PSEPIN) $key(PSEPIN1)] !=0} {
        timedmsgpopup "You have not entered the same key twice" "TRY again" 3000
         x509_Setup
          } else {
           set i 1
           }
          }

         set env(USERPIN) $key(PSEPIN)
         set psefile  "[glob -nocomplain [resource sdrHome]]/$key(PSELOC)"
         set uupsefile  "[glob -nocomplain [resource sdrHome]]/upsefile"
         set tclcmd [list exec secude psecrt -V -s RSA -k $key(size) ]
         set tclcmd [concat $tclcmd -p $psefile ]
         set tclcmd [concat $tclcmd \"$key(DN)\"    ]
         set result [catch $tclcmd output]
         set keyfile  "[glob -nocomplain [resource sdrHome]]/x509keyfile"
         set tclcmd [ list exec uuencode $psefile $key(PSELOC) ]
         set result [ catch $tclcmd content ]
         #set tmpid [open $upsefile r]
         #   set content [read $tmpid]
         #   close $tmpid
         set fileid [open $keyfile w]
         puts $fileid [concat "password: " $key(PSEPIN)]
         close $fileid
         set fileid [open $keyfile a]
         puts $fileid  $content
             close $fileid
    if  [info exists env(MAILAGENT] {
    set mailagent $env(MAILAGENT)
    } else {
    set mailagent [Misc_Gettext "MAILAGENT" "Please enter mail agent"]
    }
    set tclcmd [ list exec $mailagent ]
 
    set result [ catch $tclcmd output ]
    file delete  $keyfile
         }
}
proc get_cert_info { file } {
global certresult
    set  in  [open $file r]
    set certresult(issuername) "none"
    set certresult(alg) "none"
    foreach inline [split [read $in] \n ] {
    if {[regexp -nocase {IssuerName:               (.*)} $inline {} issuer] == 1 } {
          set certresult(issuername) $issuer
    #} elseif {[regexp -nocase  {SerialNumber:               (.*)\(.*} $inline {} serialno] == 1 } {
    } elseif {[regexp -nocase  {SerialNumber: .*([0-9]+) \(.*} $inline {} serialno] == 1 } {
          set certresult(serialnumber) $serialno
    } elseif {[regexp -nocase {NotBefore: (.*)\(.*} $inline {} notbefore] == 1 } {
          set certresult(before) $notbefore
    } elseif {[regexp -nocase {NotAfter: (.*)\(.*} $inline {} notafter] == 1 } {
          set certresult(after) $notafter
    } elseif {[regexp -nocase {DigestAlgId: (.*)\(.*} $inline {} digst] == 1 } {
          set certresult(alg) $digst
    } else {
           set test "ignore"
    }
 }
  close $in
  return "\.\n IssuerName: $certresult(issuername) \n SerialNumber: $certresult(serialnumber) \n NotBefore: $certresult(before) \n NotAfter: $certresult(after) \n $certresult(alg) "
}

proc enter_smart_pse_details {} {
    global  env smartinfo
    global smartpse smartpin
    catch {destroy $w}
    set w [toplevel .smartinfo -borderwidth 2] 
    wm title .smartinfo "Sdr: SMART CARD  Configure Information"
    frame $w.f -borderwidth 5 -relief groove
    pack $w.f -side top
    message $w.f.l -aspect 500  -text "Please configure sdr with your SMART CARD PSE name, and Pin (Passphrase). "
    pack $w.f.l -side top
    frame $w.f.f0 
    pack $w.f.f0 -side top -fill x -expand true
    label $w.f.f0.l -text "SMART CARD Location"
    pack $w.f.f0.l -side left -anchor e -fill x -expand true
    entry $w.f.f0.e -width 30 -relief sunken -borderwidth 1 \
	-bg [option get . entryBackground Sdr] \
	 -highlightthickness 0   -textvariable smartpse
    pack $w.f.f0.e -side left

    frame $w.f.f1 
    pack $w.f.f1 -side top -fill x -expand true
    label $w.f.f1.l -text "PIN for SMARTCARD"
    pack $w.f.f1.l -side left -anchor e -fill x -expand true
    #entry ..f.f1.e -width 40 -relief sunken -borderwidth 1 \
#	-bg [option get . entryBackground Sdr] \
#	 -highlightthickness 0
    password $w.f.f1.e -width 30 -relief sunken -borderwidth 1 \
        -variable smartpin -background [option get . entryBackground Sdr]
    pack $w.f.f1.e -side left

    frame $w.f.f3 
    pack $w.f.f3 -side top -fill x -expand true

    button $w.f.f3.ok -text OK -command {set smartinfo(ok) 1 }\
                                                 -underline 0
    pack $w.f.f3.ok -side left -fill x -expand true
    button $w.f.f3.cancel -text Cancel \
	    -command {set smartinfo(ok) 0 }
    pack $w.f.f3.cancel -side left -fill x -expand true
    grab $w
       tkwait variable smartinfo(ok)
       #grab release $w
       destroy .smartinfo
       if { $smartinfo(ok) == 1} {
	set env(SMARTLOC) $smartpse
	set env(SMARTPIN) $smartpin
	set env(SMARTUSED) "ys"
        #puts "$env(SMARTLOC)"
       destroy .smartinfo
          return 1
       } else {
	set env(SMARTUSED) "no"
	destroy .smartinfo
	return 0
       }
}

#This process checks the Mpse to fine the right PSE
proc Get_PSE { file irand} {
global certresult env
global recvresult
set pse "none"
set local_info_file "[glob -nocomplain [resource sdrHome]]/$irand.info"
set local_cert_file "[glob -nocomplain [resource sdrHome]]/$irand.cert"
    set tclcmd [ list exec secude asn1show $file]
    set result [ catch $tclcmd recvinfo]
    set recvfile [open $local_info_file w 0600]
    puts $recvfile $recvinfo
    close $recvfile
    set  in  [open $local_info_file r]
    set recvresult(issuername,0) "none"
    set recvresult(issuername,1) "none"
    set recvresult(serialnumber,0) "none"
    set recvresult(serialnumber,1) "none"
    set j 0
    foreach inline [split [read $in] \n ] {
    if {[regexp -nocase {Issuer: .* <(.*)>} $inline {} issuer] == 1 } {
          set recvresult(issuername,$j) $issuer
          #puts "$j $recvresult(issuername,$j)"
    } elseif {[regexp -nocase  {SerialNumber: .*([0-9]+) \(.*} $inline {} serialno] == 1 } {
          set recvresult(serialnumber,$j) $serialno
          #puts "$j $recvresult(serialnumber,$j)"
          incr j
    } else {
           set test "ignore"
    }
 }
  close $in
    file delete $local_info_file
    set test 100
    set userpin $env(USERPIN)
    unset env(USERPIN)
 set  tclcmd [ list exec secude psemaint -p $env(PSELOC).$test ] 
 set result [ catch $tclcmd noofpse]
  set env(USERPIN) $userpin
 if { [regexp {Selected PSE not in MPSEFile\, valid only ([0-9]+) to ([0-9]+)} $noofpse {} start end] == 1 } {
    #puts "end $end"
    incr end 
    #puts "end $end"
    for {set i $start} {$i < $end} {incr i} {
     #puts "i= $i "
     set  tclcmd [ list exec secude psemaint -p $env(PSELOC).$i export Cert $local_cert_file]
     set result [ catch $tclcmd certout]
     set tclcmd [ list exec secude asn1show $local_cert_file]
     set result [ catch $tclcmd certinfo]
    set certfile [open $local_cert_file w 0600]
    puts $certfile $certinfo
    close $certfile
    get_cert_info $local_cert_file
    for {set k 0} {$k < $j} {incr k} {
     #puts "i=$i k=$k $certresult(serialnumber)"
      #puts "i=$i k=$k $certresult(issuername)"
    if { ([string compare $recvresult(serialnumber,$k) $certresult(serialnumber)]==0) && ([string compare $recvresult(issuername,$k) $certresult(issuername)]==0)} {
       set pse $env(PSELOC).$i
       #puts "i=$i k=$k  test done $pse"
        break
       }
     }
     }
  } else {
   set pse $env(PSELOC)
  }
 if { [string compare $pse "none"] == 0} {
     set pse $env(PSELOC) 
    }
return $pse
}

proc Get_ownerlist { } {
global env
set test 100
set userpin $env(USERPIN)
set ownerall "none"
 unset env(USERPIN)
 set  tclcmd [ list exec secude psemaint -p $env(PSELOC).$test ]
 set result [ catch $tclcmd noofpse]
set env(USERPIN) $userpin
	if { [regexp {Selected PSE not in MPSEFile\, valid only ([0-9]+) to ([0-9]+)} $noofpse {} start end] == 1 } {
        incr end
	for {set i $start} {$i < $end} {incr i} {
	set  tclcmd [ list exec secude psemaint -p $env(PSELOC).$i own]
	set result [ catch $tclcmd ownerlist ]
	set ownerlist [regexp -nocase {PSE (.+)} $ownerlist {} ownerl($i)]
	set ownerall [concat "$ownerall<" $ownerl($i)]
	   }
	} else {
        set  tclcmd [ list exec secude psemaint -p $env(PSELOC) own]
        set result [ catch $tclcmd ownerlist ]
        set ownerlist [regexp -nocase {PSE (.+)} $ownerlist {} ownerl(1)]
        set ownerall $ownerl(1)
       }
return $ownerall
}

proc Get_Owner_PSE { dn} {
global  env
set pse "none"
    #puts "$dn"
    set test 100
    set userpin $env(USERPIN)
    unset env(USERPIN)
 set  tclcmd [ list exec secude psemaint -p $env(PSELOC).$test ] 
 set result [ catch $tclcmd noofpse]
  set env(USERPIN) $userpin
 if { [regexp {Selected PSE not in MPSEFile\, valid only ([0-9]+) to ([0-9]+)} $noofpse {} start end] == 1 } {
        incr end
    for {set i $start} {$i < $end } {incr i} {
     set  tclcmd [ list exec secude psemaint -p $env(PSELOC).$i own]
     set result [ catch $tclcmd ownerlist]
     set new [regexp -nocase {PSE Owner:  (.+)} $ownerlist {} newown($i)]
#    puts "$newown($i)"
    if { [string compare $dn $newown($i)] == 0 } {
       set pse $env(PSELOC).$i
#       puts " newpse= $pse"
        break
       }
     }
  } else {
   set pse $env(PSELOC)
  }
 if { [string compare $pse "none"] == 0} {
     set pse $env(PSELOC) 
    }
#puts " PSE returned $pse"
return $pse
}
