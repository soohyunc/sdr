set tmp {}
catch {set tmp $applist}
set applist $tmp
set tmp {}
catch {set tmp $rules}
set rules $tmp
set tmp {}
catch {set tmp $medialist}
set medialist $tmp
set tmp {}
catch {set tmp $createrules}
set createrules $tmp

proc parse_plugins {plugindir needtool} {
    global rules mappings createrules
    global fmts fmtnames protos protonames
    set pluginfiles [lsort [glob -nocomplain $plugindir/sdr2.plugin.*]]
    foreach filename $pluginfiles {
#	puts "opening $filename..."
	set file [vopen $filename "r"]
	parse_plugin $file $needtool
	vclose $file
#	puts "...closing $filename"
    }
}


#implement a virtual file so we can push input back onto stdin to do macro
#expansion
proc vopen {filename mode} {
    global ibufs
    set file [open $filename $mode]
    set ibufs($file) ""
    return $file
}

proc vclose {file} {
    global ibufs
    close $file
    unset ibufs($file)
}

proc vgets {file varname} {
    global ibufs
    if {$ibufs($file)!=""} {
	set val [lindex [split $ibufs($file) "\n"] 0]
	set ibufs($file) \
	    [join [lrange [split $ibufs($file) "\n"] 1 end] "\n"]
	uplevel set $varname \"$val\"
	return 0
    } else {
	return [uplevel gets $file $varname]
    }
}

proc vpush {file string} {
    global ibufs
    set ibufs($file) "$string$ibufs($file)"
}

proc parse_plugin {file needtool} {
    global applist
    global mappings
    global rules
    global createrules
    global fmts fmtnames protos protonames
    global attrs attrnames attrvaluenames attrflags noattrflags noattrlist
    global defattrlist withattrs fmtlayers
    global medialist macros macrokeys
    set fmtlist {}
    set stack {}
    set currulectr 0
    set currules {}
    set create yes
    while {[eof $file]==0} {
	if {[vgets $file line]==-1} {
	    break
	}
	set line [string trim $line]

	#ignore comments
	if {[string index $line 0]=="\#"} {
	    continue
	}
	set tag [string trim [lindex [split $line ":"] 0]]
	set value [string trim [join [lrange [split $line ":"] 1 end] ":"]]
	switch $tag {

	    "@define" {
		set varname [string trim $value]
		if {[vgets $file line]==-1} {
		    break
		}
		if {[string trim $line]!="\{"} {
		    puts "parse error in definition of macro $varname"
		    return -1
		}
		set stacked 1
		set macrodef ""
		while {$stacked > 0} {
		    if {[vgets $file line]==-1} {
			puts "end of file in definition of macro $varname"
			return -1
		    }
		    if {[string trim $line]=="\{"} { 
			incr stacked 
		    }
		    if {[string trim $line]=="\}"} { incr stacked -1 }
		    if {$stacked>0} { set macrodef "$macrodef\n$line" }
		}
		set macrodef "$macrodef\n"
#		puts "macro definition of $varname:\n$macrodef"
                set macrodefs($varname) $macrodef
	    }
            "@expand" {
                set varname [string trim $value]
                vpush $file $macrodefs($varname)
		continue
            }
	    media {
		set media [string trim $value]
		add_to_known_media $media
	    }
	    icon {
		add_media_icon $media [string trim $value]
	    }
	    text {
		add_media_text $media $value
	    }
	    cryptflag {
		add_tool_cryptflag $tool [string trim $value]
            }
	    proto {
		set proto [string trim $value]
		set protoname $value
		set tmp {}
		catch {set tmp $attrs($media.$proto)}
		set attrs($media.$proto) $tmp
		set tmp {}
		catch {set tmp $defattrlist($media.$proto)}
		set defattrlist($media.$proto) $tmp
		set tmp {}
		catch {set tmp $noattrlist($tool.$media.$proto)}
		catch {set noattrlist($tool.$media.$proto) $tmp}
	    }
	    protoname {
		set protoname $value
	    }
	    tool {
		set tool [string trim $value]
		if {[lsearch $applist $tool]==-1} {
#		    puts "tool $tool needs approval"
		    set toolloc [find_tool $tool]
		    if {($toolloc=="")&&($needtool=="yes")} {
#			puts "tool $tool is not installed"
			return 0
		    } else {
#			puts "tool $tool is installed as $toolloc"
			set applist "$applist $tool"
		    }
		}
		set tmp {}
		catch {set tmp $noattrlist($tool.$media.$proto)}
		catch {set noattrlist($tool.$media.$proto) $tmp}
	    }
	    layers {
		if {[info exists fmtlayers($media.$proto.$curfmt)]} {
		    if {$fmtlayers($media.$proto.$curfmt)< $value} {
			set fmtlayers($media.$proto.$curfmt) $value
		    }
		} else {
		    set fmtlayers($media.$proto.$curfmt) $value
		}
	    }
	    fmt {
		set curfmt [string trim $value " "]
		if {[info exists fmtlayers($media.$proto.$curfmt)]==0} {
		    set fmtlayers($media.$proto.$curfmt) 1
		}
		set tmpfmts($media.$proto.$curfmt) $value
		set tmpfmtnames($media.$proto.$curfmt) $value
		set tmp {}
		catch {set tmp $attrs($media.$proto.$curfmt)}
		set attrs($media.$proto.$curfmt) $tmp
		set tmp {}
		catch {set tmp $defattrlist($media.$proto.$curfmt)}
		set defattrlist($media.$proto.$curfmt) $tmp
		set noattrlist($tool.$media.$proto.$curfmt) {}
		set last fmt
		incr currulectr
		if {$currulectr==1} {
		    set currules "$media.$proto.$curfmt"
		    set curexec($media.$proto.$curfmt) "$tool"
		} else {
		    set currules "$currules $media.$proto.$curfmt"
		    set curexec($media.$proto.$curfmt) "$tool"
		}
	    }
	    "{" {
		set stack "$last $stack"
	    }
	    "}" {
		set stack [lrange $stack 1 end]
	    }
	    fmtname {
		if {[lindex $stack 0]=="fmt"} {
		    set tmpfmtnames($media.$proto.$curfmt) $value
		} else {
		    catch { puts "parse error: fmtname with no current format" }
		}
	    }
	    flags {
		if {[lindex $stack 0]=="fmt"} {
		    set curexec($media.$proto.$curfmt) \
			"$curexec($media.$proto.$curfmt) $value"
		} elseif {[lindex $stack 0]=="attr"} {
		    if {[lindex $stack 1]=="fmt"} {
			set attrflags($tool.$media.$proto.$curfmt.$curattr) $value
		    } else {
			set attrflags($tool.$media.$proto.$curattr) $value
		    }
		} elseif {[lindex $stack 0]=="noattr"} {
		    if {[lindex $stack 1]=="fmt"} {
			set noattrflags($tool.$media.$proto.$curfmt.$curattr) $value
		    } else {
			set noattrflags($tool.$media.$proto.$curattr) $value
		    }
		} elseif {[lindex $stack 0]=="attrvalue"} {
		    if {[lindex $stack 2]=="fmt"} {
#			puts "$tool.$media.$proto.$curfmt.$curattr:$curattrvalue  -> $value"
			set attrflags($tool.$media.$proto.$curfmt.$curattr:$curattrvalue) $value
		    } else {
			set attrflags($tool.$media.$proto.$curattr:$curattrvalue) $value
		    }
		} else {
		    foreach currule $currules {
			set curexec($currule) "$curexec($currule) $value"
		    }
		}
	    }
	    attr {
		set last attr
		set curattr [string trim $value]
#		puts "curattr: $curattr"
		if {[lindex $stack 0]=="fmt"} {
		    #it's a format attribute
		    lappend attrs($media.$proto.$curfmt) $curattr
		} else {
		    #it's a protocol attribute
		    lappend attrs($media.$proto) $curattr
		}
	    }
	    #specifies a compulsory attribute if a wildcard format is matched
	    withattr {
		set last withattr
		set curattr [lindex [split [string trim $value] ":"] 0]
		if {[lindex $stack 0]=="fmt"} {
		    #it's a format attribute
		    lappend attrs($media.$proto.$curfmt) $curattr
		    lappend withattrs($media.$proto.$curfmt) [string trim $value]
		}
		
	    }
	    #noattr is for when we want to specify an action to perform
	    #when an attribute is *not* present.
	    noattr {
		set last noattr
		set curnoattr [string trim $value]
		if {[lindex $stack 0]=="fmt"} {
		    #it's a format attribute
		    set noattrlist($tool.$media.$proto.$curfmt) \
			"$noattrlist($tool.$media.$proto.$curfmt) $curnoattr"
		} else {
		    #it's a protocol attribute
		    lappend noattrlist($tool.$media.$proto) $curnoattr
		}
	    }
	    #set default attributes/attribute values
	    def {
		if {([string trim $value]=="true")&&\
		    ([lindex $stack 0]=="attr")} {
		    set last defattr
		    if {[lindex $stack 1]=="fmt"} {
			#it's a format attribute
			if {[lsearch -glob $defattrlist($media.$proto.$curfmt) \
			     "$curattr:*"]==-1} {
				 lappend defattrlist($media.$proto.$curfmt) $curattr
			     }
		    } else {
			#it's a protocol attribute
			#not sure this makes sense, but will allow it here
			#and ignore it later...
			if {[lsearch -glob $defattrlist($media.$proto) \
			     "$curattr:*"]==-1} {
				 lappend defattrlist($media.$proto) $curattr
			     }
		    }
		} elseif {([string trim $value " "]=="true")&&\
		    ([lindex $stack 0]=="attrvalue")} {
			if {[lindex $stack 1]=="attr"} {
			    if {[lindex $stack 2]=="fmt"} {
				#it's a format attribute
				set ix [lsearch $defattrlist($media.$proto.$curfmt) \
					$curattr]
				if {$ix==-1} {
				    set ix [lsearch -glob \
					    $defattrlist($media.$proto.$curfmt) \
						"$curattr:*"]
				}
				if {$ix==-1} {
				    lappend defattrlist($media.$proto.$curfmt) \
					$curattr:$curattrvalue
				} else {
				    set defattrlist($media.$proto.$curfmt) \
					[lreplace $defattrlist($media.$proto.$curfmt) \
					 $ix $ix $curattr:$curattrvalue]
				}
			    } else {
				#it's a protocol attribute
				set ix [lsearch $defattrlist($media.$proto) \
					$curattr]
				if {$ix==-1} {
				    set ix [lsearch -glob $defattrlist($media.$proto) \
					    "$curattr:*"]
				}
				if {$ix==-1} {
				    lappend defattrlist($media.$proto) \
					$curattr:$curattrvalue
				} else {
				    set defattrlist($media.$proto) \
					[lreplace $defattrlist($media.$proto) \
					 $ix $ix $curattr:$curattrvalue]
				}
			    }
			}
		    } elseif {[lindex $stack 0]=="inputvalue"} {
			puts "default inputvalue"
		    } else {
			puts "default tag outside of attribute or attribute value"
			return -1;
		    }
	    }
	    hidden {
		if {[lindex $stack 0]=="attr"} {
		} elseif {[lindex $stack 0]=="attrvalue"} {
		} elseif {[lindex $stack 0]=="fmt"} {
#		    puts [array names tmpfmts]
		    set tmpfmts($media.$proto.$curfmt) ""
		}
	    }
	    attrname {
		if {[lindex $stack 0]=="attr"} {
		    set attrnames($curattr) $value
#		    puts "attrname($curattr)=$attrnames($curattr)"
		} else {
		    catch {puts "parse error: attrname with no current attribute"}
		}
	    }
	    inputvalue {
		set last inputvalue
	    }
	    attrvalue {
		set last attrvalue
		regsub -all " " $value "\\ " curattrvalue
		if {[lindex $stack 0]=="attr"} {
		    if {[lindex $stack 1]=="fmt"} {
#			puts $attrs($media.$proto.$curfmt)
			#it's a format attribute
			if {[lindex $attrs($media.$proto.$curfmt) end]\
			    ==$curattr} {
			    set len [llength $attrs($media.$proto.$curfmt)]
                            set attrs($media.$proto.$curfmt) \
				[lrange $attrs($media.$proto.$curfmt) 0 \
				 [expr $len -2]]
			    lappend attrs($media.$proto.$curfmt) \
				     $curattr:$curattrvalue
			} else {
			    lappend attrs($media.$proto.$curfmt) \
				$curattr:$curattrvalue
			}
		    } else {
			#it's a protocol attribute
			if {[lindex $attrs($media.$proto) end]==$curattr} {
			    set len [llength $attrs($media.$proto)]
                            set attrs($media.$proto) \
				[lrange $attrs($media.$proto) 0 \
				 [expr $len -2]]
			    lappend attrs($media.$proto) \
				     $curattr:$curattrvalue
			} else {
			    lappend attrs($media.$proto) \
				$curattr:$curattrvalue
			}
		    }
                } else {
                    catch {puts "parse error: attrvalue with no current attribute\n  $value"}
                }
            }
	    attrvaluename {
		if {[lindex $stack 0]=="attrvalue"} {
		    set attrvaluenames($curattr:$curattrvalue) $value
		} else {
		    catch {puts "parse error: attrvaluename with no current attrvalue\n  $value\n  $stack $curattr:$curattrvalue"}
		}
	    }
	    macro {
		if {([lindex $stack 0]=="attr")||\
 		    ([lindex $stack 0]=="attrvalue")||\
		    ([lindex $stack 0]=="fmt")} {
			set last macro
			set curmacro [string trim $value " "]
		    } else {
			catch {puts "parse error: macro outside of attribute or fmt"}
		    }
	    }
	    value {
		if {[lindex $stack 0]=="macro"} {
		    if {[lindex $stack 2]=="fmt"} {
			#stack is fmt,attr,macro
			set macrokeys($tool.$media.$proto.$curfmt.$curattr) $curmacro
			set macros($tool.$media.$proto.$curfmt.$curattr) $value
		    } elseif {[lindex $stack 2]=="attr"} {
			#stack is fmt,attr,attrvalue,macro
                        set macrokeys($tool.$media.$proto.$curfmt.$curattr) $curmacro
                        set macros($tool.$media.$proto.$curfmt.$curattr) $value
                    } elseif {[lindex $stack 1]=="attr"} {
			#stack is ??,attr,macro
			set macrokeys($tool.$media.$proto.$curattr) $curmacro
			set macros($tool.$media.$proto.$curattr) $value
		    } elseif {[lindex $stack 1]=="fmt"} {
			#stack is fmt,macro
			set macrokeys($tool.$media.$proto.$curfmt) $curmacro
			set macros($tool.$media.$proto.$curfmt) $value
		    }
		} else {
		    catch {puts "parse error: macrovalue outside of macro"}
		}
	    }
	    create {
		if {[string trim $value " "]=="no"} {
		    set create no
		}
	    }
	}
    }
    foreach currule $currules {
	set ruleix [lsearch $rules $currule]
	if {$ruleix==-1} {
	    set rules "$rules $currule"
	    set mappings($currule) [list $curexec($currule)]
	} else {
	    set newtool [lindex $curexec($currule) 0]
	    set done 0
	    set ix 0
	    foreach mapping $mappings([lindex $rules $ruleix]) {
		set oldtool [lindex $mapping 0]
		if {[string compare $oldtool $newtool]==0} {
		    set done 1
                    #replace the old rule with the new one
		    set mappings($currule) [concat \
			    [lrange $mappings($currule) 0 [expr $ix-1]] \
		            [list $curexec($currule)] \
                            [lrange $mappings($currule) [expr $ix+1] end]]
		    break
		} 
		incr ix
	    }
	    if {$done==0} {
		lappend mappings($currule) $curexec($currule)
	    }

	}
	if {([lsearch $createrules $currule]==-1)&&($create=="yes")} {
            set createrules "$createrules $currule"
	    set protos($currule) $proto
	    set fmts($currule) $tmpfmts($currule)
	}
	set protonames($proto) $protoname
	set fmtnames($tmpfmts($currule)) $tmpfmtnames($currule)
    }
    
}

proc add_to_known_media {media} {
    global medialist mediadata
    if {[lsearch $medialist $media]==-1} {
	lappend medialist $media
	set mediadata(icon:$media) unknown
	set mediadata(text:$media) $media
    }
}

proc add_tool_cryptflag {tool cryptflag} {
    global tooldata
    set tooldata(cryptflag:$tool) $cryptflag
}

proc add_media_icon {media icon} {
    global medialist mediadata
    if {$mediadata(icon:$media)=="unknown"} {
	set mediadata(icon:$media) $icon
    } else {
	catch {puts "Warning: icon $mediadata(icon:$media) overridden by icon $icon for media $media"}
	set mediadata(icon:$media) $icon
    }
}

proc add_media_text {media text} {
    global medialist mediadata
    if {$mediadata(text:$media)==$media} {
	set mediadata(text:$media) $text
    } else {
	catch {puts "Warning: text $mediadata(text:$media) overridden by text $text for media $media"}
	set mediadata(text:$media) $text
    }
}

proc find_tool {tool} {
    global env tcl_platform
    if {$tcl_platform(platform) == "windows"} {
	set path [split $env(PATH) ";"]
	set tool $tool.exe
    } else {
	set path [split $env(PATH) ":"]
    }
    foreach dir $path {
	if {[file executable $dir/$tool]==1} {
	    return $dir/$tool
	}
    }
    return ""
}

proc wcsearch {rules base} {
    #wcsearch checks to see if there is any rule which contains a wildcard
    #format which might match if exact matches have failed
    set wclist ""
    foreach rule $rules {
	if {[string first "$base.*" $rule]==0} {
          #success (subject to a suitable attribute telling us what to do)
	  set start [string length "$base.*"]
	  lappend wclist [string range $rule $start end]
	}
    }
    return $wclist
}

proc start_media_tool {aid mnum proto fmt attrlist} {
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
	msgpopup "Unknown protocol or format" "The session you tried to join contains a media \"$media\" with protocol \"$proto\" and format \"$fmt\".  I have no plug-in module that defines a $media tool for this.  To join this session you need a plug-in module for this combination of media, protocol and format and a media tool capable of receiving the data.\n\nSee \"Help\" for more details of plug-in modules"
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
		msgpopup "Unknown protocol or format" "The session you tried to join contains a media \"$media\" with protocol \"$proto\" and format \"$fmt\".  I have no plug-in module that defines a $media tool for this.  To join this session you need a plug-in module for this combination of media, protocol and format and a media tool capable of receiving the data.\n\nSee \"Help\" for more details of plug-in modules"
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
	    msgpopup "No suitable $media tool installed" "The session you tried to join contains a media \"$media\" for which I can find no suitable tool installed.  Suitable tools that I know about would include:\n$toollist\nNone of these is in your command path."
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
            select_tool_for_media $aid $mnum $proto $fmt \
			$rulelist $attrlist
            return 0
	} else {
	    set rule [lindex $rulelist 0]
	}
    }
    return [apply_startup_rule $aid $mnum $proto $fmt $rule $attrlist]
}

proc list_reverse {list} {
    set newlist {}
    foreach el $list {
	set newlist "[list $el] $newlist"
    }
    string trim $newlist
    return $newlist
}

proc apply_startup_rule {aid mnum proto fmt rule attrlist} {
    global tcl_platform
    global macros macrokeys
    global attrflags noattrflags noattrlist macrovalues
    global youremail
    global ldata
    global debug1
    global tooldata encryptionflag

    set media $ldata($aid,$mnum,media)
#    puts apply_startup_rule
#    puts "media: $media"
#    puts "proto: $proto"
#    puts "fmt: $fmt"
#    puts "rule: $rule"
#    puts "attrlist: $attrlist"
    log "starting tool for $media at [getreadabletime]"
    set rule [string trim $rule "\{\}"]
    set tool [lindex $rule 0]

# replaced next line as it adds {} around elements of cmd line. New one doesn't
#   set rule [lrange $rule 1 end]
    set rule [ string range $rule [string wordend $rule 0] end]

    foreach noattr \
	"$noattrlist($tool.$media.$proto) $noattrlist($tool.$media.$proto.$fmt)" {
	    set nat($noattr) 1
    }
    set attrs ""
#    puts $attrlist
    foreach attr $attrlist {
	set tmp ""
	catch {set tmp $attrflags($tool.$media.$proto.$attr)}
	if {$tmp==""} {
	    catch {set tmp $attrflags($tool.$media.$proto.$fmt.$attr)}
	}
	if {$tmp!=""} {
	    catch {unset nat([lindex [split $attr ":"] 0])}
	}
	set attrs "$attrs $tmp"
    }
    set tmp ""
    foreach attr [array names nat] {
	catch {set tmp $noattrflags($tool.$media.$proto.$attr)}
        if {$tmp==""} {
            catch {set tmp $noattrflags($tool.$media.$proto.$fmt.$attr)}
        }
        set attrs "$attrs $tmp"
    }
    set tmp ""
    catch {
	set macrokey $macrokeys($tool.$media.$proto.$fmt)
	set tmp $macros($tool.$media.$proto.$fmt)
    }
    if {$tmp!=""} {
        set macrovalues($macrokey) [expand_macro $tmp ""]
    }

    foreach attr $attrlist {
	set key [lindex [split $attr ":"] 0]
	set tmp ""
	catch {
	    set macrokey $macrokeys($tool.$media.$proto.$key)
	    set tmp $macros($tool.$media.$proto.$key)
	}
	if {$tmp==""} {
	    catch {
		set macrokey $macrokeys($tool.$media.$proto.$fmt.$key)
		set tmp $macros($tool.$media.$proto.$fmt.$key)
	    }
	}
	if {$tmp!=""} {
	    set macrovalues($macrokey) [expand_macro $tmp [lindex [split $attr ":"] 1]]
	}
    }
	
    set ttl $ldata($aid,ttl)
    set sessname \"$ldata($aid,session)\"
    set address $ldata($aid,$mnum,addr)
    set layers $ldata($aid,$mnum,layers)
    set port $ldata($aid,$mnum,port)
    set chan [get_channel $aid]
    set cryptkey \"\"
    catch {set cryptkey \"$ldata($aid,$mnum,mediakey)\"}

    set rule "$tool $attrs $rule"
    if {$debug1} {
	puts "fixing rule: $rule"
    }

    if {([info exists tooldata(cryptflag:$tool)] != 1) && $cryptkey != "\"\""} {
      msgpopup "Encryption Not Supported" "The tool you are using ($tool) does not seem to support encryption. You may be unable to decrypt the $media media stream"
    }

    if {[info exists tooldata(cryptflag:$tool)] && $cryptkey != "\"\""} {
      set encryptionflag $tooldata(cryptflag:$tool)
    } else {
      set encryptionflag ""
    }

    set rule [fix_up_plugin_rule $rule]
    if {$debug1} {
	puts "fixing rule: $rule"
    }
    set rule [fix_up_plugin_rule $rule]
	set pid [run_program $rule]
    if {$pid == -1} {
	# fork failed...
	return 0
    }

    #keep track of the pid so we can see if the tools are still running...
    for {set i 0} {$i<$ldata($aid,medianum)} {incr i} {
	if {$ldata($aid,$i,media)==$media} {
	    set ldata($aid,$i,pid) $pid
	    break
	}
    }
    return 1
}

proc expand_macro {macro value} {
    set ix [string first "\$(VALUE)" $macro]
    if {$ix==-1} {return $macro}
    set first [string range $macro 0 [expr $ix-1]]
    set rest [string range $macro [expr $ix+8] end]
    return "$first$value$rest"
}

proc expand_var {macro variable value} {
    set ix [string first "\$$variable" $macro]
    if {$ix==-1} {return $macro}
    set first [string range $macro 0 [expr $ix-1]]
    set len [string length "\$$variable"]
    set rest [string range $macro [expr $ix+$len] end]
    return "$first$value$rest"
}

proc remove_wc_vars {str} {
    set ix [string first "*(" $str]
    set first [string range $str 0 [expr $ix]]
    set rest [string range $str [expr $ix+2] end]
    set ix [string first ")" $rest]
    set rest [string range $rest [expr $ix+1] end]
    return $first$rest
}

proc fix_up_plugin_rule {rule} {
    global macrovalues
    global encryptionflag
    set vars [split $rule "\$"]
    set newrule [lindex $vars 0]
    foreach var [lrange $vars 1 end] {
	if {[string range $var 0 0]=="("} {
	    set tmp [split [string range $var 1 end] ")"]
	    if {[llength $tmp]==2} {
		set varname [lindex $tmp 0]
		set rest [lindex $tmp 1]
		switch $varname {
		    TTL {
			set newrule "$newrule\$ttl$rest"
		    }
		    LAYERS {
			set newrule "$newrule\$layers$rest"
		    }
		    SESSNAME {
			set newrule "$newrule\$sessname$rest"
		    }
		    ADDRESS {
			set newrule "$newrule\$address$rest"
		    }
		    PORT {
			set newrule "$newrule\$port$rest"
		    }
		    PROTO {
			set newrule "$newrule\$proto$rest"
		    }
		    FMT {
			set newrule "$newrule\$fmt$rest"
		    }
		    CHAN {
			set newrule "$newrule\$chan$rest"
		    }
		    YOUREMAIL {
			set newrule "$newrule\$youremail$rest"
		    }
		    CRYPTKEY {
		    	if { $encryptionflag != "" } {
		    	  set newrule "$newrule $encryptionflag \$cryptkey$rest"
		    	} else {
		    	  set newrule "$newrule$rest"
		    	}
		    }
		    default {
			if {[info exists macrovalues($varname)]} {
			    set newrule \
				"$newrule$macrovalues($varname)$rest"
			} else {
			    set newrule "$newrule$rest"
			}
		    }
		}
	    } else {
		catch {puts "rule parse error"}
		return -1
	    }
	} else {
	    set newrule "$newrule\$$var"
	}
    }
    return $newrule
}

proc select_tool_for_media {aid mnum proto fmt rulelist attrlist} {
    global ldata
    set media $ldata($aid,$mnum,media)
    set win .st$aid$mnum
    catch {destroy $win}
    sdr_toplevel $win "Select a tool"
    frame $win.f -relief groove -borderwidth 2
    pack $win.f -side top
    label $win.f.l -text "More than one $media tool is available"
    pack $win.f.l -side top 
    message $win.f.msg -aspect 300 -text "To join the $media part of this session, you could use one of several tools.  Please select the tool you wish to use."
    pack $win.f.msg -side top -fill x -expand true
    frame $win.f.f 
    pack $win.f.f -side top
    set bnum 0
    global startrule
    set startrule($media) [lindex $rulelist 0]
    foreach rule $rulelist {
	radiobutton $win.f.f.$bnum -text [lindex $rule 0] \
	    -variable startrule($media) -value $rule -highlightthickness 0
	pack $win.f.f.$bnum -side left
	incr bnum
    }
    frame $win.f.f2
    pack $win.f.f2 -side top -fill x -expand true
    button $win.f.f2.start -text "Start tool" \
	-command "apply_startup_rule $aid $mnum $proto $fmt \[set startrule($media)\] \"$attrlist\";destroy $win" -highlightthickness 0
    tixAddBalloon $win.f.f2.start Button [tt "Click here to start up the tool you've selected"]
    pack $win.f.f2.start -side left -fill x -expand true
    button $win.f.f2.cancel -text "Cancel" -command "destroy $win" \
	 -highlightthickness 0
    tixAddBalloon $win.f.f2.cancel Button [tt "Click here to cancel starting up this tool"]
    pack $win.f.f2.cancel -side left -fill x -expand true
}

proc is_creatable {media} {
    global createrules protos
    foreach rule $createrules {
        if {[string first $media $rule]==0} {
	    return 1
        }
    }
    return 0
}

proc get_media_protos {media} {
    global createrules protos
    set protolist {}
    foreach rule $createrules {
	if {[string first $media $rule]==0} {
	    if {[lsearch $protolist $protos($rule)]==-1} {
		lappend protolist $protos($rule)
	    }
	}
    }
    return $protolist
}

proc get_proto_name {proto} {
    global protonames
    set rtn $proto
    catch {set rtn $protonames($proto)}
    return $rtn
}

proc get_media_fmts {media proto} {
    global createrules fmts
    set fmtlist {}
    foreach rule $createrules {
        if {[string first $media.$proto $rule]==0} {
            if {([lsearch $fmtlist $fmts($rule)]==-1)&&($fmts($rule)!="")} {
                lappend fmtlist $fmts($rule)
	    }
	}
    }
    return $fmtlist
}

proc get_fmt_name {fmt} {
    global fmtnames
    set rtn $fmt
    catch {set rtn $fmtnames($fmt)}
    return $rtn
}

proc get_proto_attrs {media proto} {
    global attrs
    return $attrs($media.$proto)
}

proc get_fmt_attrs {media proto fmt} {
    global attrs
    return $attrs($media.$proto.$fmt)
}

proc get_attr_name {attr} {
    global attrnames
    set rtn $attr
    catch {set rtn $attrnames($attr)}
    return $rtn
}

proc get_attrvalue_name {attr value} {
    global attrvaluenames
    set rtn $value
    catch {set rtn $attrvaluenames($attr:$value)}
    return $rtn
}

proc get_max_layers {media proto fmt} {
    global fmtlayers
    return $fmtlayers($media.$proto.$fmt)
}



proc pref_tools {cmd {arg1 {}} {arg2 {}} {arg3 {}}} {
    global prefs tool_state

    switch $cmd {
	copyin		{
			foreach i [array names prefs "tools_*"] {
			    unset prefs($i)
			}
			foreach i [array names tool_state] {
			    set prefs(tools_$i) $tool_state($i)
			}
			}
	copyout		{
			foreach i [array names tool_state] {
			    unset tool_state($i)
			}
			foreach i [array names prefs "tools_*"] {
			    if {[regsub "^tools_(.*)$" $i {\1} tmp]} {
				set tool_state($tmp) $prefs($i)
			    }
			}
			}
	defaults	{
			foreach i [array names prefs "tools_*"] {
			    unset prefs($i)
			}
			}
	create		{
			select_startup_rule $arg1 $arg2 $arg3
			return "Tools"
			}
        balloon         {
	                return "Select the tools that you would like to use when joining a session"
		        }
	save		{
			set lst {}
			catch {set lst [array names tool_state]}
			foreach rule $lst {
			    regsub -all {\)} $rule {\\)} rule
			    puts $arg1 [list set tool_state($rule) disabled]
			}
			}
    }
}

proc select_startup_rule {win width height} {
    global rules mappings font prefs
#    catch {destroy .rules}
#    toplevel .rules
#    wm title .rules "Select Tools to Start"
    
    frame $win -borderwidth 3 -relief raised
    frame $win.setw -borderwidth 0 -height 1 -width $width
    pack $win.setw -side top
#    pack $win -side top

    message $win.msg -aspect 600 -text "The following media formats have more than one tool available to decode them"
    pack $win.msg -side top -fill x
    bind $win.msg <Map> {prefs_help [tt "Click on the tool name to enable or disable it for the particular protocol and format if you don't wish to be prompted."]}    
    bind $win.msg <Unmap> {prefs_help ""}
    set lines 0
    foreach rule $rules {
	if {[llength $mappings($rule)]>1} {
	    incr lines
	}
    }
    set lh 17
    frame $win.f
    pack $win.f -side top
    canvas $win.f.c -width 400 -height 220 \
	    -yscrollcommand "$win.f.sb set" \
	    -scrollregion "0 0 400 [expr ($lines+1)*$lh]"
    pack $win.f.c -side left
    scrollbar $win.f.sb -command "$win.f.c yview"
    pack $win.f.sb -fill y -expand true
    set ix 1
    $win.f.c create text 10 0 -anchor nw -text "Media" -font $font
    $win.f.c create text 60 0 -anchor nw -text "Proto" -font $font
    $win.f.c create text 100 0 -anchor nw -text "Format" -font $font
    $win.f.c create text 150 0 -anchor nw -text "Available Tools" -font $font
    $win.f.c create line 0 15 400 15
    set dislst {}
    catch {set dislst [array names prefs "tools_*"]}
    foreach rule $rules {
	if {[llength $mappings($rule)]>1} {
	    set lst [split $rule "."]
	    set media [lindex $lst 0]
	    set proto [get_proto_name [lindex $lst 1]]
	    set fmt [get_fmt_name [lindex $lst 2]]
	    $win.f.c addtag m.$rule withtag \
		[$win.f.c create text 10 [expr $ix*$lh] -anchor nw\
		 -text $media -font $font]
	    $win.f.c addtag p.$rule withtag \
		[$win.f.c create text 60 [expr $ix*$lh] -anchor nw\
		 -text $proto -font $font]
	    $win.f.c addtag f.$rule withtag \
		[$win.f.c create text 100 [expr $ix*$lh] -anchor nw\
		 -text $fmt -font $font]
	    set mx 150
	    foreach map $mappings($rule) {
		set tool [lindex $map 0]
		$win.f.c addtag b$tool.$rule withtag \
                    [$win.f.c create rectangle [expr $mx-5] [expr ($ix*$lh)-1] \
		     [expr $mx+35] [expr (($ix+1)*$lh)-3 ] -fill white \
			 -outline black]
		$win.f.c addtag $tool.$rule withtag \
		    [$win.f.c create text $mx [expr $ix*$lh] -anchor nw\
                 -text $tool -font $font]
		$win.f.c bind b$tool.$rule <Enter> \
		    "$win.f.c itemconfigure b$tool.$rule -fill black;\
                     $win.f.c itemconfigure $tool.$rule -fill white"
		$win.f.c bind b$tool.$rule <Leave> \
		    "$win.f.c itemconfigure b$tool.$rule -fill white;\
                     $win.f.c itemconfigure $tool.$rule -fill black"
		$win.f.c bind $tool.$rule <Enter> \
		    "$win.f.c itemconfigure b$tool.$rule -fill black;\
                     $win.f.c itemconfigure $tool.$rule -fill white"
		$win.f.c bind $tool.$rule <Leave> \
		    "$win.f.c itemconfigure b$tool.$rule -fill white;\
                     $win.f.c itemconfigure $tool.$rule -fill black"
		$win.f.c bind $tool.$rule <1> \
		    "toggle_tool_state $win.f.c $tool $rule \"$map\" $mx $ix $lh"
		$win.f.c bind b$tool.$rule <1> \
		    "toggle_tool_state $win.f.c $tool $rule \"$map\" $mx $ix $lh"
		if {[lsearch $dislst tools_$rule.$tool]>=0} {
		    unset prefs(tools_$rule.$tool)
		    toggle_tool_state $win.f.c $tool $rule $map $mx $ix $lh
		}
		incr mx 50
	    }
	    incr ix
	}
    }

#    frame $win.f2 -borderwidth 2 -relief groove
#    pack $win.f2 -side top -fill x
#    button $win.f2.save -borderwidth 1 -relief raised -text "Save Preferences"\
#      -command {destroy .rules;save_prefs}
#    pack $win.f2.save -side left -fill x -expand true
#    button $win.f2.ok -borderwidth 1 -relief raised -text "OK"\
#      -command {destroy .rules}
#    pack $win.f2.ok -side left -fill x -expand true
    frame $win.f2 -borderwidth 0 -relief flat -width 1 -height \
	[expr $height - [winfo reqheight $win]]
    pack $win.f2 -side top
}


proc toggle_tool_state {canv tool rule map mx ix lh} {
    global prefs
    set lst {}
    catch {set lst [array names prefs "tools_*"]}
    if {[lsearch $lst tools_$rule.$tool]==-1} {
	#the map is not disabled
	set prefs(tools_$rule.$tool) disabled
	$canv addtag dis1$tool.$rule withtag \
	    [$canv create line [expr $mx-5] [expr ($ix*$lh)-1] \
	     [expr $mx+35] [expr (($ix+1)*$lh)-3 ] -width 2]
	$canv addtag dis2$tool.$rule withtag \
	    [$canv create line [expr $mx+35] [expr ($ix*$lh)-1] \
	     [expr $mx-5] [expr (($ix+1)*$lh)-3 ] -width 2]
	$canv bind dis1$tool.$rule <1> \
	    "toggle_tool_state $canv $tool $rule \"$map\" $mx $ix $lh"
	$canv bind dis2$tool.$rule <1> \
	    "toggle_tool_state $canv $tool $rule \"$map\" $mx $ix $lh"
	$canv bind dis1$tool.$rule <Enter> \
	    "$canv itemconfigure b$tool.$rule -fill black;\
             $canv itemconfigure $tool.$rule -fill white"
	$canv bind dis1$tool.$rule <Leave> \
	    "$canv itemconfigure b$tool.$rule -fill white;\
             $canv itemconfigure $tool.$rule -fill black"
	$canv bind dis2$tool.$rule <Enter> \
	    "$canv itemconfigure b$tool.$rule -fill black;\
             $canv itemconfigure $tool.$rule -fill white"
	$canv bind dis2$tool.$rule <Leave> \
	    "$canv itemconfigure b$tool.$rule -fill white;\
             $canv itemconfigure $tool.$rule -fill black"
    } else {
	$canv delete dis1$tool.$rule
	$canv delete dis2$tool.$rule
	unset prefs(tools_$rule.$tool)
    }
}
