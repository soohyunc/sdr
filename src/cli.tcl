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
    puts "Listing of $which sessions:"
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
	    puts "$ix: $ldata($aid,session)"
	}
    }
}

proc cli_map_ix_to_aid {ix} {
    global cli_ixmap
    if {[info exists cli_ixmap($ix)]} {
	set aid $cli_ixmap($ix)
    } else {
	puts "Invalid session number.  Valid session numbers are 1 to [llength [array names cli_ixmap]]."
    }
}

proc cli_describe_session {ix} {
    global ldata 
    set aid [cli_map_ix_to_aid $ix]
    set desc [cli_describe_session_by_aid $aid]
}

proc cli_describe_session_by_aid {aid} {
    global ldata 
    if {$aid==0} return
    set desc ""
    set desc "$desc\n$ldata($aid,session)."
    set desc "$desc\nDescription: [string trimright $ldata($aid,desc) "."]."
    set desc "$desc\nCreated by $ldata($aid,creator) at $ldata($aid,createaddr)."
    if {$ldata($aid,tfrom)!=0} {
	regsub "\n" "[text_times_english $aid]." " " time
	set desc "$desc\n$time"
    } else {
	set desc "$desc\nThis session is not time-bounded."
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
	set desc "$desc\nThe session medium is $medialist."
    } else {
	set desc "$desc\nSession media are $medialist."
    }
    return $desc
}

proc cli_detail_session {ix} {
    global ldata 
    set aid [cli_map_ix_to_aid $ix]
    if {$aid==0} return
    cli_describe_session $ix
    for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
	set media $ldata($aid,$i,media)
	puts "The $media protocol is $ldata($aid,$i,proto), format is [get_fmt_name $ldata($aid,$i,fmt)], address is $ldata($aid,$i,addr) on port $ldata($aid,$i,port) with TTL $ldata($aid,$i,ttl)."
    }
}

proc cli_new_session {aid} {
    global cli_mode cli_prompt cli_explain cli_exec cli_variable
    puts "To abort session creation, enter \"cancel\" at any prompt."
    set cli_mode text
    puts "Enter session name and hit Enter:"
    set cli_variable cli_session
    set cli_exec "cli_new_description $aid"
}

proc cli_new_description {aid} {
    global cli_mode cli_prompt cli_explain cli_exec cli_variable
    set cli_mode text
    puts "Enter session description and hit Enter:"
    set cli_variable cli_desc
    set cli_exec "cli_new_scope $aid"
}

proc cli_new_scope {aid} {
    global cli_mode cli_prompt cli_explain cli_exec cli_variable
    set cli_mode choose
    puts "Possible scopes for the session are:"
    global cli_scopemap
    set cli_variable cli_scopemap
    set cli_prompt "Enter a scope number:"
    set cli_explain scope
}


proc cli_prefs {} {
    puts "Sorry - this feature is not yet implemented."
}


set cli_normal_prompt "SDR command? "
set cli_prompt $cli_normal_prompt

proc cli_prompt {} {
    global cli_prompt
    puts "\n$cli_prompt"
}

proc cli_normal {} {
    global cli_mode cli_prompt cli_normal_prompt
    set cli_mode normal
    set cli_prompt $cli_normal_prompt
}

proc cli_usage {} {
    puts "Type \"help\" for a full command summary.  SDR commands are:"
    puts "scan"
    puts "scan broadcast"
    puts "scan meeting"
    puts "scan test"
    puts "scan unknown"
    puts "scan active"
    puts "scan future"
    puts "show <session number>"
    puts "detail <session number>"
    puts "join <session number>"
    puts "audio <session number>"
    puts "video <session number>"
    puts "whiteboard <session number>"
    puts "create"
    puts "preferences"
}

proc cli_help {} {
    puts "SDR command usage:"
    puts "help"
    puts "   gives this output."
    puts "scan"
    puts "   gives a listing of all sessions."
    puts "scan broadcast"
    puts "   gives a listing of all broadcast type sessions."
    puts "scan meeting"
    puts "   gives a listing of all meeting type sessions."
    puts "scan test"
    puts "   gives a listing of all test type sessions."
    puts "scan unknown"
    puts "   gives a listing of all unknown type sessions."
    puts "scan active"
    puts "   gives a listing of all sessions scheduled to currently be active."
    puts "scan future"
    puts "   gives a listing of all future sessions."
    puts "show <session number>"
    puts "   gives a description of the specified session."
    puts "detail <session number>"
    puts "   gives a more detailed description of the specified session."
    puts "join <session number>"
    puts "   starts all the media tools for the specified session."
    puts "audio <session number>"
    puts "   starts only the audio tool for the specified session."
    puts "video <session number>"
    puts "   starts only the audio tool for the specified session."
    puts "whiteboard <session number>"
    puts "   starts only the whiteboard tool for the specified session."
    puts "create"
    puts "   creates a new session and announces it."
    puts "preferences"
    puts "   sets various preferences for how SDR behaves."
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
	    puts "Error: Session $ix does not have media $media"
	}
    }
}


#XXX this should be merged with start_media in start_tools.tcl
#this is a quick hack that produces the warnings on stdout instead
#of the GUI.
proc cli_start_media {aid mnum mode} {
  global ldata
  set ldata($aid,started) 1
  set media $ldata($aid,$mnum,media)

  if {$mode=="start"} {
      if {[is_known_media $media]!=-1} {
          return [cli_start_media_tool $aid $mnum $ldata($aid,$mnum,proto) $ldata($aid,$mnum,fmt) [split $ldata($aid,$mnum,vars) "\n"]]
      } else {
	  puts "Media $media unknown." 
	  puts "The session you tried to join contains a media \"$media\" that I do not know about.  To join this session you need the \"$media\" sdr plug-in module and a media tool capable of joining this session."
	  return 0
      }
  } elseif {$mode=="record"} {
      return [record_$media]
  } else {
      puts stderr "unknown mode to start_media: $mode"
      return 0
  }
}


#XXX this should be merged with start_media_tool in plugins.tcl
#this is a quick hack that produces the warnings on stdout instead
#of the GUI.
proc cli_start_media_tool {aid mnum proto fmt attrlist} {
    global rules
    global mappings
    global attrflags
    global withattrs
    global tool_state
    global macrovalues
    global ldata

    set media $ldata($aid,$mnum,media)

    foreach macrovalue [array names macrovalues] {
	unset macrovalues($macrovalue)
    }
    
    if {([lsearch $rules "$media.$proto.$fmt"]==-1) && \
        ([wcsearch $rules "$media.$proto"]=="")} {
	puts "The session you tried to join contains a media \"$media\" with protocol \"$proto\" and format \"$fmt\".  I have no plug-in module that defines a $media tool for this.  To join this session you need a plug-in module for this combination of media, protocol and format and a media tool capable of receiving the data."
	return 0
    } else {
	if {[lsearch $rules "$media.$proto.$fmt"]==-1} {
            #there were no exact matches on the format, but a wildcard
            #match was possible (typically an RTP dynamic payload type)
	    set wclist [wcsearch $rules "$media.$proto"]
	    set match 0
#	    puts $wclist
#	    puts "got a wildcard match"
	    foreach wc $wclist {
		set needattr ""
		catch {set needattr $withattrs($media.$proto.*$wc)}
		if {$needattr==""} { continue }
		foreach wa $needattr {
		    set withattr [expand_var $wa $wc $fmt]
		    set tmp $withattr
#		    puts $withattr
		    while {[string first "*(" $tmp]!=-1} {
			set tmp [remove_wc_vars $tmp]
		    }
#		    puts $tmp
		    foreach attr $attrlist {
#			puts "string match >$tmp< >$attr<"
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
#		puts "SUCCESS\nwc:$wc\nwa:$wa"
#		puts "tmp:$tmp"
		foreach attrflag [array names attrflags] {
#		    puts "attrflag:$attrflag"
#		    puts "match: *.$media.$proto.*$wc.$wa"
		    if {[string match "*.$media.$proto.\*$wc.$wa" $attrflag]==1} {
#			puts "flags index: $attrflag"
#			puts "flags: $attrflags($attrflag)"
			set tool [find_tool [lindex [split $attrflag "."] 0]]
			if {$tool==""} { continue }
#			puts "tool: $tool"
			set macrovalues([string trim $wc "()"]) $fmt
			set fmt "*$wc"
			lappend attrlist $wa
			set rule $mappings($media.$proto.*$wc)
			break
		    }
		}
	    } else {
		puts "The session you tried to join contains a media \"$media\" with protocol \"$proto\" and format \"$fmt\".  I have no plug-in module that defines a $media tool for this.  To join this session you need a plug-in module for this combination of media, protocol and format and a media tool capable of receiving the data."
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
#		catch {puts "the tool [lindex $subrule 0] is not installed"}
	    } else {
		set tmp enabled
#		catch {puts "$media.$proto.$fmt.[lindex $subrule 0]"}
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
	    puts "The session you tried to join contains a media \"$media\" for which I can find no suitable tool installed.  Suitable tools that I know about would include:\n$toollist\nNone of these is in your command path."
#	    puts "no tools are installed for $media"
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
    return [apply_startup_rule $aid $mnum $proto $fmt $rule $attrlist]
}

proc cli_select_tool_for_media {aid media proto fmt rulelist attrlist} {
    global cli_toolmap cli_mode cli_exec cli_explain cli_variable cli_prompt
    puts "Select the $media tool to use:"
    set bnum 1
    global startrule
    set startrule($media) [lindex $rulelist 0]
    foreach rule $rulelist {
	set cli_toolmap($bnum) $rule
	puts  "$bnum: [lindex $rule 0]"
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
		cli_new_session new
	    }
	    "preferences" {
		if {[llength $line]!=1} {cli_usage}
		cli_prefs
	    }
	    "quit" {
		puts "Goodbye!"
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
	    puts "OK."
	    cli_normal
	} else {
	    puts "Invalid $cli_explain number.  Valid $cli_explain numbers are 1 to [llength [array names [set cli_variable]]]."
	}
    }
    cli_prompt
}




