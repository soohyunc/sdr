#sdr.tcl 
#Copyright University College London 1995
#see ui_fns.c for information on usage and redistribution of this file
#and for a DISCLAIMER OF ALL WARRANTIES.


proc start_all {aid} {
  global ldata
  set success 1
  for {set i 0} {$i < $ldata($aid,medianum)} {incr i} {
      set success [expr [start_media "$aid" $i "start"]&&$success]
  }
#  if {$success} {
#      timedmsgpopup [tt "Please wait..."] [tt "the conference tools are starting"] 3000
#  }
  set ldata($aid,is_popped) -1;
  popdown $aid
}


proc start_media {aid mnum mode} {
  global ldata
#  puts "aid: $aid"
#  puts "mnum: $mnum"
  set ldata($aid,started) 1
  set media $ldata($aid,$mnum,media)

  if {$mode=="start"} {
      if {[is_known_media $media]!=-1} {
          return [start_media_tool $aid $mnum $ldata($aid,$mnum,proto) $ldata($aid,$mnum,fmt) [split $ldata($aid,$mnum,vars) "\n"]]
      } else {
	  msgpopup "Media $media unknown" "The session you tried to join contains a media \"$media\" that I do not know about.  To join this session you need the \"$media\" sdr plug-in module and a media tool capable of joining this session.  \n\nSee \"Help\" for more details of plug-in modules."
	  return 0
      }
  } elseif {$mode=="record"} {
      return [record_$media]
  } else {
      puts "unknown mode to start_media: $mode"
      return 0
  }
}


#get_channel taken from sd.tcl by Van Jacobson 
set ipc_chan 0
proc get_channel { confid } {
    global ipc_tab ipc_chan
    if { [info exists ipc_tab($confid)] } {
	return $ipc_tab($confid)
    }
    incr ipc_chan
    if { $ipc_chan > 300 } {
	set ipc_chan 1
    }
    set ipc_tab($confid) $ipc_chan
    return $ipc_chan
}
