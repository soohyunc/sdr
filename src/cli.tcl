#command line interface to Sdr.  mjh@isi.edu, 1998
#
#This is an attempt at a command line interface for sdr.  It is not
#intended to replace the GUI, but rather to aid sdr's use by blind 
#people for whom a GUI is of no use, but a command line interface 
#can be used with a text-to-speech system.  Thanks to Jeremy Hall 
#for the suggestion.


proc cli_say_sessions {which} {
    global cli_ixmap fullnumitems fullix showwhich ldata
    set timespec {all current future}
    foreach el [array names cli_ixmap] {
	unset cli_ixmap($el)
    }
    putlogfile "Listing of $which sessions:"
    set ix 0
    for {set i 0} {$i < $fullnumitems} {incr i} {
	set aid $fullix($i)
	if {[string first $which $timespec]>=0} {
	    set show [listing_criteria $aid $which]
	} else {
	    if {$ldata($aid,type)==$which} {
		set show 1
	    } else {
		set show 0
	    }
	}
	if {$show} {
	    incr ix
	    set cli_ixmap($ix) $aid
	    putlogfile "$ix: $ldata($aid,session)"
	}
    }
}

proc cli_map_ix_to_aid {ix} {
    global cli_ixmap
    if {[info exists cli_ixmap($ix)]} {
	set aid $cli_ixmap($ix)
    } else {
	putlogfile "Invalid session number.  Valid session numbers are 1 to [llength [array names cli_ixmap]]."
    }
}

proc cli_describe_session {ix} {
    global ldata 
    set aid [cli_map_ix_to_aid $ix]
    if {$aid==0} return
    putlogfile "$ldata($aid,session)."
    putlogfile "Description: [string trimright $ldata($aid,desc) "."]."
    putlogfile "Created by $ldata($aid,creator) at $ldata($aid,createaddr)."
    if {$ldata($aid,tfrom)!=0} {
	regsub "\n" "[text_times_english $aid]." " " time
	putlogfile $time
    } else {
	putlogfile "This session is not time-bounded."
    }
    for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
	set media $ldata($aid,$i,media)
	if {$i == 0} {
	    set medialist $media
	} elseif {$i < [expr $ldata($aid,medianum)-1]} {
	    set medialist "$medialist, $media"
	} else {
	    set medialist "$medialist and $media"
	}
    }
    if {$ldata($aid,medianum)==1} {
	putlogfile "The session medium is $medialist."
    } else {
	putlogfile "Session media are $medialist."
    }
}

proc cli_detail_session {ix} {
    global ldata 
    set aid [cli_map_ix_to_aid $ix]
    if {$aid==0} return
    cli_describe_session $ix
    for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
	set media $ldata($aid,$i,media)
	putlogfile "The $media protocol is $ldata($aid,$i,proto), format is [get_fmt_name $ldata($aid,$i,fmt)], address is $ldata($aid,$i,addr) on port $ldata($aid,$i,port) with TTL $ldata($aid,$i,ttl)."
    }
}

proc cli_new_session {aid} {
    global cli_mode cli_prompt cli_explain cli_exec cli_variable
    putlogfile "To abort session creation, enter \"cancel\" at any prompt."
    set cli_mode text
    putlogfile "Enter session name and hit Enter:"
    set cli_variable cli_session
    set cli_exec "cli_new_description $aid"
}

proc cli_new_description {aid} {
    global cli_mode cli_prompt cli_explain cli_exec cli_variable
    set cli_mode text
    putlogfile "Enter session description and hit Enter:"
    set cli_variable cli_desc
    set cli_exec "cli_new_scope $aid"
}

proc cli_new_scope {aid} {
    global cli_mode cli_prompt cli_explain cli_exec cli_variable
    set cli_mode choose
    putlogfile "Possible scopes for the session are:"
    global cli_scopemap
    set cli_variable cli_scopemap
    set cli_prompt "Enter a scope number:"
    set cli_explain scope
}


proc cli_prefs {} {
    putlogfile "Sorry - this feature is not yet implemented."
}


set cli_normal_prompt "SDR command? "
set cli_prompt $cli_normal_prompt

proc cli_prompt {} {
    global cli_prompt
    putlogfile "\n$cli_prompt"
}

proc cli_normal {} {
    global cli_mode cli_prompt cli_normal_prompt
    set cli_mode normal
    set cli_prompt $cli_normal_prompt
}

proc cli_usage {} {
    putlogfile "Type \"help\" for a full command summary.  SDR commands are:"
    putlogfile "scan"
    putlogfile "scan broadcast"
    putlogfile "scan meeting"
    putlogfile "scan test"
    putlogfile "scan unknown"
    putlogfile "scan active"
    putlogfile "scan future"
    putlogfile "show <session number>"
    putlogfile "detail <session number>"
    putlogfile "join <session number>"
    putlogfile "audio <session number>"
    putlogfile "video <session number>"
    putlogfile "whiteboard <session number>"
    putlogfile "create"
    putlogfile "preferences"
}

proc cli_help {} {
    putlogfile "SDR command usage:"
    putlogfile "help"
    putlogfile "   gives this output."
    putlogfile "scan"
    putlogfile "   gives a listing of all sessions."
    putlogfile "scan broadcast"
    putlogfile "   gives a listing of all broadcast type sessions."
    putlogfile "scan meeting"
    putlogfile "   gives a listing of all meeting type sessions."
    putlogfile "scan test"
    putlogfile "   gives a listing of all test type sessions."
    putlogfile "scan unknown"
    putlogfile "   gives a listing of all unknown type sessions."
    putlogfile "scan active"
    putlogfile "   gives a listing of all sessions scheduled to currently be active."
    putlogfile "scan future"
    putlogfile "   gives a listing of all future sessions."
    putlogfile "show <session number>"
    putlogfile "   gives a description of the specified session."
    putlogfile "detail <session number>"
    putlogfile "   gives a more detailed description of the specified session."
    putlogfile "join <session number>"
    putlogfile "   starts all the media tools for the specified session."
    putlogfile "audio <session number>"
    putlogfile "   starts only the audio tool for the specified session."
    putlogfile "video <session number>"
    putlogfile "   starts only the audio tool for the specified session."
    putlogfile "whiteboard <session number>"
    putlogfile "   starts only the whiteboard tool for the specified session."
    putlogfile "create"
    putlogfile "   creates a new session and announces it."
    putlogfile "preferences"
    putlogfile "   sets various preferences for how SDR behaves."
}

proc cli_join_session {media ix} {
    global ldata
    set aid [cli_map_ix_to_aid $ix]
    if {$aid==0} return    
    if {$media=="all"} {
	set success 1
	for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
	    set success [expr [cli_start_media "$aid" $i "start"]&&$success]
	}
    } else {
	set success 0
	set done 0
	for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
	    if {$ldata($aid,$i,media)==$media} {
		set success [cli_start_media "$aid" $i "start"]
		set done 1
		break
	    }
	}
	if {$done==0} {
	    putlogfile "Error: Session $ix does not have media $media"
	}
    }
}


#XXX this should be merged with start_media in start_tools.tcl
#this is a quick hack that produces the warnings on stdout instead
#of the GUI.
proc cli_start_media {aid mnum mode} {
  global sd_sess ldata
  set ldata($aid,started) 1
  set media $ldata($aid,$mnum,media)
  set sd_sess(sess_id) $aid
  set sd_sess(address) $ldata($aid,multicast)
  set sd_sess(ttl)  $ldata($aid,ttl)
  set sd_sess(name) $ldata($aid,session);

  set sd_sess(media) ""
  for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
      set sd_sess(media) "$sd_sess(media) $ldata($aid,$i,media)"
  }
  set sd_sess(creator) $ldata($aid,creator)
  set sd_sess(creator_id) $ldata($aid,source)
  set sd_sess(source_id) $ldata($aid,heardfrom)
  set sd_sess(arrival_time) $ldata($aid,theard)
  set sd_sess(start_time) $ldata($aid,starttime)
  set sd_sess(end_time) $ldata($aid,endtime)
  set sd_sess(attributes) ""

  global sd_$media
  set tmp sd_$media\(attributes\)
  set $tmp $ldata($aid,$mnum,vars)
  set tmp sd_$media\(port\)
  set $tmp $ldata($aid,$mnum,port)
  set tmp sd_$media\(address\)
  set $tmp $ldata($aid,$mnum,addr)
  set tmp sd_$media\(layers\)
  set $tmp $ldata($aid,$mnum,layers)
  set tmp sd_$media\(ttl\)
  set $tmp $ldata($aid,$mnum,ttl)
  set tmp sd_$media\(proto\)
  set $tmp $ldata($aid,$mnum,proto)
  set tmp sd_$media\(fmt\)
  set $tmp $ldata($aid,$mnum,fmt)
  set tmp sd_$media\(proto\)
  set $tmp $ldata($aid,$mnum,proto)
  set sd_priv($media) 1
  if {$mode=="start"} {
      if {[is_known_media $media]!=-1} {
          return [cli_start_media_tool $aid $media $ldata($aid,$mnum,proto) $ldata($aid,$mnum,fmt) [split $ldata($aid,$mnum,vars) "\n"]]
      } else {
	  putlogfile "Media $media unknown." 
	  putlogfile "The session you tried to join contains a media \"$media\" that I do not know about.  To join this session you need the \"$media\" sdr plug-in module and a media tool capable of joining this session."
	  return 0
      }
  } elseif {$mode=="record"} {
      return [record_$media]
  } else {
      putlogfile stderr "unknown mode to start_media: $mode"
      return 0
  }
}


#XXX this should be merged with start_media_tool in plugins.tcl
#this is a quick hack that produces the warnings on stdout instead
#of the GUI.
proc cli_start_media_tool {aid media proto fmt attrlist} {
    global rules
    global mappings
    global attrflags
    global withattrs
    global tool_state
    global macrovalues

    foreach macrovalue [array names macrovalues] {
	unset macrovalues($macrovalue)
    }
    
    if {([lsearch $rules "$media.$proto.$fmt"]==-1) && \
        ([wcsearch $rules "$media.$proto"]=="")} {
	putlogfile "The session you tried to join contains a media \"$media\" with protocol \"$proto\" and format \"$fmt\".  I have no plug-in module that defines a $media tool for this.  To join this session you need a plug-in module for this combination of media, protocol and format and a media tool capable of receiving the data."
	return 0
    } else {
	if {[lsearch $rules "$media.$proto.$fmt"]==-1} {
            #there were no exact matches on the format, but a wildcard
            #match was possible (typically an RTP dynamic payload type)
	    set wclist [wcsearch $rules "$media.$proto"]
	    set match 0
#	    putlogfile $wclist
#	    putlogfile "got a wildcard match"
	    foreach wc $wclist {
		set needattr ""
		catch {set needattr $withattrs($media.$proto.*$wc)}
		if {$needattr==""} { continue }
		foreach wa $needattr {
		    set withattr [expand_var $wa $wc $fmt]
		    set tmp $withattr
#		    putlogfile $withattr
		    while {[string first "*(" $tmp]!=-1} {
			set tmp [remove_wc_vars $tmp]
		    }
#		    putlogfile $tmp
		    foreach attr $attrlist {
#			putlogfile "string match >$tmp< >$attr<"
			if {[string match $tmp $attr]==1} {
			    set match 1
			    break
			}
		    }
		    if {$match==1} { break }
		}
		if {$match==1} { break }
	    }
	    if {$match==1} {
		#at this stage wc holds the name of the wildcard and
		#wa holds the relevant "withattr" line from the plugin
		#now we need to match against the actual attributes..
		#(this is really ugly)
#		putlogfile "SUCCESS\nwc:$wc\nwa:$wa"
#		putlogfile "tmp:$tmp"
		foreach attrflag [array names attrflags] {
#		    putlogfile "attrflag:$attrflag"
#		    putlogfile "match: *.$media.$proto.*$wc.$wa"
		    if {[string match "*.$media.$proto.\*$wc.$wa" $attrflag]==1} {
#			putlogfile "flags index: $attrflag"
#			putlogfile "flags: $attrflags($attrflag)"
			set tool [find_tool [lindex [split $attrflag "."] 0]]
			if {$tool==""} { continue }
#			putlogfile "tool: $tool"
			set macrovalues([string trim $wc "()"]) $fmt
			set fmt "*$wc"
			lappend attrlist $wa
			set rule $mappings($media.$proto.*$wc)
			break
		    }
		}
	    } else {
		putlogfile "The session you tried to join contains a media \"$media\" with protocol \"$proto\" and format \"$fmt\".  I have no plug-in module that defines a $media tool for this.  To join this session you need a plug-in module for this combination of media, protocol and format and a media tool capable of receiving the data."
		return 0
	    }
	} else {
	    #we got a format we know we support
	    set rule $mappings($media.$proto.$fmt)
	}


	set rulelist {}
	foreach subrule $rule {
	    set tool [find_tool [lindex $subrule 0]]
	    if {$tool==""} {
#		catch {putlogfile "the tool [lindex $subrule 0] is not installed"}
	    } else {
		set tmp enabled
#		catch {putlogfile "$media.$proto.$fmt.[lindex $subrule 0]"}
		catch {set tmp $tool_state($media.$proto.$fmt.[lindex $subrule 0])}
		if {$tmp=="enabled"} {
		    lappend rulelist $subrule
		}
	    }
	}
	if {[llength $rulelist]==0} {
	    set toollist {}
	    foreach subrule $rule {
		lappend toollist [lindex $subrule 0]
	    }
	    putlogfile "The session you tried to join contains a media \"$media\" for which I can find no suitable tool installed.  Suitable tools that I know about would include:\n$toollist\nNone of these is in your command path."
#	    putlogfile "no tools are installed for $media"
	    return 0;
	} elseif {[llength $rulelist]>1} {
#	    set toollist {}
#	    set newrules {}
#	    foreach rule [list_reverse $rulelist] {
#		set tool [lindex $rule 0]
#		if {[lsearch -exact $toollist $tool]>=0} {
#		    #we have two rules for the same tool
#		    #skip this rule
#		} else {
#		    lappend newrules $rule
#		}
#		lappend toollist $tool
#	    }
#	    if {[llength $newrules]>1} {
#		select_tool_for_media $aid $media $proto $fmt \
#			$newrules $attrlist
#		return 0
#	    } else {
#		set rule [lindex $newrules 0]
#	    }
            cli_select_tool_for_media $aid $media $proto $fmt \
			$rulelist $attrlist
            return 0
	} else {
	    set rule [lindex $rulelist 0]
	}
    }
    return [apply_startup_rule $aid $media $proto $fmt $rule $attrlist]
}

proc cli_select_tool_for_media {aid media proto fmt rulelist attrlist} {
    global cli_toolmap cli_mode cli_exec cli_explain cli_variable cli_prompt
    putlogfile "Select the $media tool to use:"
    set bnum 1
    global startrule
    set startrule($media) [lindex $rulelist 0]
    foreach rule $rulelist {
	set cli_toolmap($bnum) $rule
	putlogfile  "$bnum: [lindex $rule 0]"
#	    -variable startrule($media) -value $rule -highlightthickness 0
	incr bnum
    }
    set cli_mode starttool
    set cli_exec "apply_startup_rule $aid $media $proto $fmt \"%\" \"$attrlist\""
    set cli_explain "tool"
    set cli_variable cli_toolmap
    set cli_prompt "Please enter the tool number:"
}



set cli_mode normal

proc cli_parse_command {} {
    global cli_cmd 
    global cli_mode cli_exec cli_variable cli_explain cli_prompt
    set line $cli_cmd
    set cmd [lindex $line 0]
    if {$cli_mode=="normal"} {
	switch $cmd {
	    "help" {
		cli_help
	    }
	    "?" {
		cli_usage
	    }
	    "scan" {
		if {[llength $line]>2} {cli_usage}
		if {[llength $line]==1} {
		    cli_say_sessions all
		} else {
		    cli_say_sessions [lindex $line 1]
		}
	    }
	    "show" {
		if {[llength $line]!=2} {cli_usage}
		cli_describe_session [lindex $line 1]
	    }
	    "detail" {
		if {[llength $line]!=2} {cli_usage}
		cli_detail_session [lindex $line 1]
	    }
	    "join" {
		if {[llength $line]!=2} {cli_usage}
		cli_join_session all [lindex $line 1]
	    }
	    "audio" {
		if {[llength $line]!=2} {cli_usage}
		cli_join_session audio [lindex $line 1]
	    }
	    "video" {
		if {[llength $line]!=2} {cli_usage}
		cli_join_session video [lindex $line 1]
	    }
	    "whiteboard" {
		if {[llength $line]!=2} {cli_usage}
		cli_join_session whiteboard [lindex $line 1]
	    }
	    "create" {
		if {[llength $line]!=1} {cli_usage}
		cli_new_session 
	    }
	    "preferences" {
		if {[llength $line]!=1} {cli_usage}
		cli_prefs
	    }
	    "quit" {
		putlogfile "Goodbye!"
		exit 0
	    }
	    default {
		cli_usage 
	    }
	}
    } else {
	global [set cli_variable]
	if {[info exists [set cli_variable]($cli_cmd)]} {
	    set var [set [set cli_variable]($cli_cmd)]
	    regsub "\%" $cli_exec $var cmd
	    eval $cmd
	    putlogfile "OK."
	    cli_normal
	} else {
	    putlogfile "Invalid $cli_explain number.  Valid $cli_explain numbers are 1 to [llength [array names [set cli_variable]]]."
	}
    }
    cli_prompt
}




