proc load_from_cache {} {
    set dirname "[resource sdrHome]/cache"
    if {[file isdirectory $dirname]} {
	foreach file [glob -nocomplain $dirname/*] {
	    if {[file isfile $file] && [file readable $file]} {
		load_cache_entry $file clear
	    }
	}
     }
    set dirname "[resource sdrHome]/asymmetric"
    if {[file isdirectory $dirname]} {
	foreach file [glob -nocomplain $dirname/*] {
	    if {[file isfile $file] && [file readable $file]} {
		load_cache_entry $file symm
	    }
	}
     }
}

proc load_from_cache_crypt {} {
      set dirname "[resource sdrHome]/encrypt"
          if {[file isdirectory $dirname]} {
          foreach file [glob -nocomplain $dirname/*] {
              if {[file isfile $file] && [file readable $file]} {
                      load_cache_entry $file crypt
                  }
          }
      }
}


proc write_cache {} {
    global ldata fullix
# XXX Just a note here:
# XXX The user interface is probably destroyed by now, if the user clicked
# on quit, so these msgpopups don't do much good.
    set dirname [resource sdrHome]
    if {[file isdirectory $dirname]==0} {
	catch {file mkdir $dirname}
	if {[file isdirectory $dirname]==0} {
	    msgpopup "Error" "Could not create sdr config directory $dirname"
	    return -1
	}
    }
    if {[file isdirectory $dirname/cache]==0} {
	catch {file mkdir $dirname/cache}
	if {[file isdirectory $dirname/cache]==0} {
	    msgpopup "Error" "Could not create sdr cache directory $dirname/cache"
	    return -1
	}
    } else {
	set filelist [glob -nocomplain $dirname/cache/*]
	foreach file $filelist {
	    set tmpaid [file tail $file]
	    set flag 0
	    catch {
		set flag $ldata($tmpaid,session)
	    }
	    if {$flag==0} {
		file delete $file
	    }
	}
    }
    if {[file isdirectory $dirname/encrypt]==0} {
        catch {file mkdir $dirname/encrypt}
        if {[file isdirectory $dirname/encrypt]==0} {
            msgpopup "Error" "Could not create sdr cache directory $dirname/encrypt"
            return -1
        }
    } else {
        set filelist [glob -nocomplain $dirname/encrypt/*]
        foreach file $filelist {
            set tmpaid [file tail $file]
            set flag 0
            catch {
                set flag $ldata($tmpaid,session)
            }
            if {$flag==0} {
                file delete $file
            }
        }
    }
    if {[file isdirectory $dirname/asymmetric]==0} {
        catch {file mkdir $dirname/asymmetric}
        if {[file isdirectory $dirname/asymmetric]==0} {
            msgpopup "Error" "Could not create sdr cache directory $dirname/asymmetric"
            return -1
        }
    } else {
        set filelist [glob -nocomplain $dirname/asymmetric/*]
        foreach file $filelist {
            set tmpaid [file tail $file]
            set flag 0
            catch {
                set flag $ldata($tmpaid,session)
            }
            if {$flag==0} {
                file delete $file
            }
        }
    }

    set ixnames {}
    catch {set ixnames [array names fullix]}
    foreach i $ixnames {
      if {$ldata($fullix($i),trust) != "sip"} {
      		if {$ldata($fullix($i),list) == "norm"} {

           		set filename "$dirname/cache/$fullix($i)"
            		write_cache_entry $fullix($i) $filename clear
      } else {
		if {$ldata($fullix($i),key) != ""} {
              set filename "$dirname/encrypt/$fullix($i)"
              write_cache_entry $fullix($i) $filename crypt
                } else {
		  if   {($ldata($fullix($i),enctype) == "pgp") || ($ldata($fullix($i),enctype) == "x509" ) } {
                 set filename "$dirname/asymmetric/$fullix($i)"
                write_cache_entry $fullix($i) $filename symm
          	} else {

          	# its a SIP Invitation
		}
        }
       }
    } else {
	 # its a SIP Invitation
        }
     }

}
	

proc write_cache_entry {aid filename security} {
    global ldata rtp_payload

#  if there's no sap_addr specified, this was not an announced session
#  so don't cache it - probably it was a SIP session.

    set sap_addr ""
    catch {set sap_addr $ldata($aid,sap_addr)}
    if {$sap_addr==""} return

    set source    [dotted_decimal_to_decimal $ldata($aid,source)]
    set heardfrom [dotted_decimal_to_decimal $ldata($aid,heardfrom)]
    set lastheard $ldata($aid,lastheard)
    set sap_port  $ldata($aid,sap_port)
    set trust     $ldata($aid,trust)
    set key       $ldata($aid,key)
    set auth      $ldata($aid,authtype)
    set enc       $ldata($aid,enctype)

# set k1 (auth ?) - why is it 1 if not asymmetric ?

    if {$ldata($aid,asym_keyid) !=""} {
      set k1  $ldata($aid,asym_keyid) 
    } else {
      set k1 "1"
    }

# set k1 (enc ?) - why is it 1 if not asymmetric ?

    if {$ldata($aid,enc_asym_keyid) !=""} {
      set k2  $ldata($aid,enc_asym_keyid) 
    } else {
      set k2 "2"
    }

    set adstr "n=$source $heardfrom $lastheard $sap_addr $sap_port $ldata($aid,ttl) $trust $auth $enc  $ldata($aid,authstatus) $ldata($aid,encstatus) $k1 $k2 \nk=$key\n[make_session $aid]"

    switch $security {

      clear {
        if {$auth!="none"} {
          append adstr "\nZ=\n"
          putlogfile "write_cache_entry - calling write_authentication"
          write_authentication $filename $adstr [string length $adstr] $aid
        } else {
          set file [open $filename w+]
          puts $file $adstr
          close $file
        }
      }

      symm   {
        append adstr "\nZ=\n"
        putlogfile "write_cache_entry - calling write_encryption"
        write_encryption $filename $adstr [string length $adstr] $aid $auth $enc
      }

      crypt {
        if {$auth!="none" } {
          append adstr "\nZ=\n"
        }
        putlogfile "write_cache_entry - calling write_crypted_file"
        write_crypted_file $filename $adstr [string length $adstr] $aid $auth
      }

     }
}
