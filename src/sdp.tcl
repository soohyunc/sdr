#set invite_ctr 0
proc parse_sdp {msg} {
    global ldata
    debug "*******************************"
    set lines [split $msg "\n"]
    foreach line $lines {
	set tag [lindex [split $line "="] 0]
	set value [join [lrange [split $line "="] 1 end] "="]
	switch $tag {
	    v { if {$value!="0"} {debug "new announcement";return 0} }
	    o {
		set str [lindex $value 0][lindex $value 1][lindex $value 5]
		set aid [get_aid $str]

		set ldata($aid,creator) [lindex $value 0]
		set ldata($aid,modtime) [lindex $value 2]
		set ldata($aid,createtime) [lindex $value 1]
		set ldata($aid,createaddr) [lindex $value 5]
		set ldata($aid,phonelist) ""
		set ldata($aid,emaillist) ""
		set ldata($aid,vars) ""
		set ldata($aid,no_of_times) -1
		set ldata($aid,uri) 0
		set ldata($aid,multicast) 0
		set ldata($aid,key) ""
		if {![info exists ldata($aid,trust)]} {
		    set ldata($aid,trust) "sip"
		}
		if {![info exists ldata($aid,sap_addr)]} {
		    #which SAP address and port did this come from? - none!
		    set ldata($aid,sap_addr) ""
		    set ldata($aid,sap_port) ""
		}
		if {![info exists ldata($aid,started)]} {
		    #have the media tools been started? - no
		    set ldata($aid,started) 0
		}
		if {![info exists ldata($aid,list)]} {
		    #which display list is it on - none yet
		    set ldata($aid,list) ""
		}
		set mn -1

		if {![info exists ldata($aid,heardfrom)]} {
		    #only set these if we didn't already know about it
		    set ldata($aid,source) $ldata($aid,createaddr)
		    set ldata($aid,heardfrom) "session invitation"
		    set ldata($aid,theard) [fixtime [gettime [gettimeofday]]]
		    set ldata($aid,method) invite
		    set ldata($aid,lastheard) [gettimeofday]
		}
	    }
	    s { set ldata($aid,session) $value }
	    i { set ldata($aid,desc) $value }
	    p { 
		if {$ldata($aid,phonelist)==""} {
		    set ldata($aid,phonelist) "{$value}"
		} else {
		    set ldata($aid,phonelist) "$ldata($aid,phonelist) {$value}"
		}
	    }
	    e { 
		if {$ldata($aid,emaillist)==""} {
		    set ldata($aid,emaillist) "{$value}"
		} else {
		    set ldata($aid,emaillist) "$ldata($aid,emaillist) {$value}"
		}
	    }
	    u { set ldata($aid,uri) $value }
	    c {
		debug $value
		if {([lindex $value 0]!="IN")&&([lindex $value 1]!="IP4")} {
		    debug "Unknown address type"
		    return 0;
		}
		set tmp [split [lindex $value 2] "/"]
		if {$mn==-1} {
		    set ldata($aid,multicast) [lindex $tmp 0]
		    set ldata($aid,ttl) [lindex $tmp 1]
		} else {
		    set ldata($aid,$mn,addr) [lindex $tmp 0]
		    set ldata($aid,$mn,ttl) [lindex $tmp 1]
		    if {[llength $tmp] > 2} {
			set ldata($aid,$mn,layers) [lindex $tmp 2]
		    } else {
			set ldata($aid,$mn,layers) 1
		    }
		}
	    }
	    t {
		incr ldata($aid,no_of_times)
		set t $ldata($aid,no_of_times)
		if {$t==0} {
		    set ldata($aid,starttime) [ntp_to_unix [lindex $value 0]]
		    set ldata($aid,endtime) [ntp_to_unix [lindex $value 1]]
		} else {
		    if {[lindex $value 0]<$ldata($aid,starttime)} {
			set ldata($aid,starttime) [ntp_to_unix [lindex $value 0]]
		    }
		    if {[lindex $value 1]>$ldata($aid,endtime)} {
			set ldata($aid,endtime) [ntp_to_unix [lindex $value 1]]
		    }
		}
		set ldata($aid,starttime,$t) [ntp_to_unix [lindex $value 0]]
		set ldata($aid,endtime,$t) [ntp_to_unix [lindex $value 1]]
		set ldata($aid,tfrom,$t) start
		set ldata($aid,tto,$t) end
		set ldata($aid,time$t,no_of_rpts) 0
	    }
	    a {
		if {$mn==-1} {
		    if {$ldata($aid,vars)==""} {
			set ldata($aid,vars) $value
		    } else {
			set ldata($aid,vars) "$ldata($aid,vars)\n$value"
		    }
		    switch [lindex [split $value ":"] 0] {
			tool {
			    set ldata($aid,tool) [lindex [split $value ":"] 1]
			}
			type {
			    set ldata($aid,type) [lindex [split $value ":"] 1]
			}
		    }
		} else {
		    if {$ldata($aid,$mn,vars)==""} {
			set ldata($aid,$mn,vars) $value
		    } else {
			set ldata($aid,$mn,vars) "$ldata($aid,$mn,vars)\n$value"
		    }
		}
	    }
	    m {
		incr mn
		catch {
		    #there may or may not have already been a "c=" field
		    set ldata($aid,$mn,addr) $ldata($aid,multicast)
		    set ldata($aid,$mn,ttl) $ldata($aid,ttl)
		}
		set ldata($aid,$mn,vars) ""
		set ldata($aid,$mn,media) [lindex $value 0]
		set ldata($aid,$mn,port) [lindex $value 1]
		set ldata($aid,$mn,proto) [lindex $value 2]
		set ldata($aid,$mn,fmt) [lrange $value 3 end]
	    }
	}
    }
    set ldata($aid,medianum) [expr $mn+1]
    if {$ldata($aid,starttime)==0} {
	set ldata($aid,tfrom) 0
    } else {
	set ldata($aid,tfrom) [fixtime [gettime \
				    [ntp_to_unix $ldata($aid,starttime)]]]
    }
    if {$ldata($aid,endtime)==0} {
	set ldata($aid,tto) 0
    } else {
	set ldata($aid,tto) [fixtime [gettime \
				  [ntp_to_unix $ldata($aid,endtime)]]]
    }
    if {$ldata($aid,multicast)==0} {
	set ldata($aid,multicast) $ldata($aid,0,addr)
	set ldata($aid,ttl) $ldata($aid,0,ttl)
    }
    incr ldata($aid,no_of_times)
    debug $aid
    debug "[gettimeofday] $ldata($aid,starttime) $ldata($aid,endtime)"
    debug end
    return $aid
}

proc fixtime {gt} {
    set y [lindex $gt 0]
    set m [lindex $gt 1]
    set e [lindex $gt 2]
    set H [lindex $gt 3]
    set M [lindex $gt 4]
    set w [lindex $gt 5]
    set B [lindex $gt 6]
    set a [lindex $gt 7]
    set A [lindex $gt 8]
    set Z [lindex $gt 9]
    return "$e $B $y $H:$M $Z"
}

proc get_aid {str} {
    set aid 0
    set len [expr [string length $str]/4]
    for {set i 0} {$i <= $len} {incr i} {
	set int 0
	for {set j [expr $i*4]} {$j<[expr ($i+1)*4]} {incr j 4} {
	    set a 0;set b 0;set c 0;set d 0
	    scan [string range $str $j [expr $j+3]] "%c%c%c%c" a b c d
	    set int [expr (((((($a*256)+$b)*256)+$c)*256)+$d)]
#	    set int [expr (((((($d*256)+$c)*256)+$b)*256)+$a)]
	    set aid [expr (($aid<<1)|(($aid>>31)&1))^$int]
	}
    }
    set aid [format "%x" $aid]
    return $aid
}
