proc load_from_cache {} {
    set dirname "[resource sdrHome]/cache"
    if {[file isdirectory $dirname]} {
	foreach file [glob -nocomplain $dirname/*] {
	    if {[file isfile $file] && [file readable $file]} {
		load_cache_entry $file clear
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
		file rm $file
	    }
	}
    }
    set ixnames {}
    catch {set ixnames [array names fullix]}
    foreach i $ixnames {
 	if {[string match *norm $ldata($fullix($i),list)]} {
	    set filename "$dirname/cache/$fullix($i)"
	    write_cache_entry $fullix($i) $filename clear
	} else {
	    #it's an invited session
	}
    }
}

proc write_cache_entry {aid filename security} {
    global ldata rtp_payload

    #if there's no sap_addr specified, this was not an announced session
    #so don't cache it - probably it was a SIP session.
    set sap_addr ""
    catch {set sap_addr $ldata($aid,sap_addr)}
    if {$sap_addr==""} return

    set source [dotted_decimal_to_decimal $ldata($aid,source)]
    set heardfrom [dotted_decimal_to_decimal $ldata($aid,heardfrom)]
    set lastheard $ldata($aid,lastheard)
    set sap_port $ldata($aid,sap_port)
    set trust $ldata($aid,trust)
    set key $ldata($aid,key)
    set adstr "n=$source $heardfrom $lastheard $sap_addr $sap_port $ldata($aid,ttl) $trust\nk=$key\n[make_session $aid]"
    if {$security=="clear"} {
	set file [open $filename w+] 
	puts $file $adstr
        close $file
    } 
}

