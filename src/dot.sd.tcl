#
# tcl 'hooks' invoked when sd takes some action on a session.
#
# sd will invoke:
#     start_session   when the user asks to 'open' (start) a session
#     create_session  just after the user creates a new session
#     heard_session   when announcement for a session is first heard
#     delete_session  when the user or a timeout deletes a session
#
# When any of the above are invoked, the global array sd_sess
# contains all the information about the session to be started:
#   sd_sess(name)
#   sd_sess(description)
#   sd_sess(address)
#   sd_sess(ttl)
#   sd_sess(creator)
#   sd_sess(creator_id)
#   sd_sess(source_id)
#   sd_sess(arrival_time)
#   sd_sess(start_time)
#   sd_sess(end_time)
#   sd_sess(attributes)               (list of session attributes)
#   sd_sess(media)            (list of media names)
#
# For each media name there is an array containing the information
# about that media:
#   sd_$media(port)
#   sd_$media(conf_id)
#   sd_$media(attributes)     (list of media attributes)
#
# Media and session attributes are strings of the form "name" or
# "name:value".
#
# Some global state information is available in array sd_priv:
#   sd_priv(audio)            (= 0 if audio disabled with -a)
#   sd_priv(video)            (= 0 if video disabled with -v)
#   sd_priv(whiteboard)               (= 0 if wb disabled with -w)
 
#set mosaic xmosaic

#proc start_session {} {
#        global sd_sess sd_priv mosaic
#
#        # start up Mosaic if there is a URL in the description.
#        if {[regexp {[a-zA-Z]+://[^ ]+} $sd_sess(description) url]} {
#                exec $mosaic $url &
#        }
#
#        # invoke the appropriate start proc for each of the media
#        # if such a proc exists and that media is enabled.
#        foreach m $sd_sess(media) {
#                if { [llength [info proc start_$m]] && $sd_priv($m) } {
#                        start_$m
#                }
#        }
#}

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

proc start_audio {} {
        global sd_sess sd_audio sd_video
        set audiofmt ""
        set packetfmt "-n"
        set mode "-c"
        foreach a $sd_audio(attributes) {
                case $a {
                        fmt:* { set audiofmt [string range $a 4 end] }
                        vt  { set packetfmt "-v" }
                        lecture  { set mode "-l" }
                }
        }
        set confaddr [format "%s/%s/%s/%s/%s" $sd_sess(address) \
                $sd_audio(port) $sd_audio(conf_id) $audiofmt $sd_sess(ttl)]

        global vat
        if {[lsearch $sd_sess(media) video] >= 0} {
                set chan [get_channel $sd_sess(address)/$sd_video(port)]
                exec $vat -I $chan -C $sd_sess(name) $packetfmt $mode $confaddr &
        } else {
                exec $vat -C $sd_sess(name) $packetfmt $mode $confaddr &
        }
}

proc start_video {} {
      global sd_sess sd_video use_ivs
      set videofmt "nv"
      foreach a $sd_video(attributes) {
              case $a {
                      fmt:* { set videofmt [string range $a 4 end] }
              }
      }
      case $videofmt {
              vic { }
              telesia { set videofmt ivs }
              ivs {
                     if { $use_ivs } {
                         global ivs
                         exec nice $ivs -a -T $sd_sess(ttl) \
                              $sd_sess(address)/$sd_video(port) &
                         return
                     }
              }
              jpg {
                      global imm
                      exec $imm -p $sd_video(port) -I $sd_sess(address) \
			-ttl $sd_sess(ttl) -n $sd_sess(name) &
		      return
              }
              mnm {
                      global mnm
                      exec $mnm -p $sd_video(port) -I $sd_sess(address) \
			-ttl $sd_sess(ttl) -n $sd_sess(name) &
		      return
              }
              default {
                      puts "sd: unknown video format: $videofmt"
                      return
               }
              nv {
                      global nv
                       exec $nv -ttl $sd_sess(ttl) $sd_sess(address) \
                             $sd_video(port) &
                       return
              }
#              ivs {
#                      global ivs
#                      exec $ivs $sd_sess(address)/$sd_video(port) \
#			-t $sd_sess(ttl) -a  &
#              }
        }
        global vic
        if {[lsearch $sd_sess(media) audio] >= 0} {
                set chan [get_channel $sd_sess(address)/$sd_video(port)]
                exec nice $vic -I $chan -A $videofmt -t $sd_sess(ttl) \
                        -C $sd_sess(name) \
                        $sd_sess(address)/$sd_video(port) &
        } else {
                exec nice $vic -A $videofmt -t $sd_sess(ttl) \
                        -C $sd_sess(name) \
                        $sd_sess(address)/$sd_video(port) &
        }
}
 
# set up media option menus for new session window.
set sd_menu(video) "fmt: vic nv ivs jpg mnm"

set use_ivs 1
 
# set up the command names
set imm imm
set mnm mnm
set nv nv
set ivs ivs
set vic vic

proc start_whiteboard {} {
                global sd_sess sd_whiteboard
		set wbfmt "wb"
		foreach a $sd_whiteboard(attributes) {
			case $a {
				fmt:* { set wbfmt [string range $a 4 end] }
			}
		}
		case $wbfmt {
			wb {
				global wb
		                set orient -l
		                set recvonly +r
		                foreach a $sd_whiteboard(attributes) {
		                        case $a {
		                                orient:portrait { set orient -p }
		                                orient:landscape { set orient -l }
		                                orient:seascape { set orient +l }
                		                recvonly { set recvonly -r }
						sendrecv { set recvonly +r }
		                        }
		                }
		                exec $wb -t $sd_sess(ttl) -C wb:$sd_sess(name) $orient \
		                        $recvonly $sd_sess(address)/$sd_whiteboard(port) &
			}
			nt {
				global nt
				exec $nt -t $sd_sess(ttl) $sd_sess(address)/$sd_whiteboard(port) &
			}
		}
}

set sd_menu(whiteboard) "orient: portrait landscape seascape\nrecvonly\nsendrecv\nfmt: wb nt"

set wb wb
set nt nt

set sd_priv(mumble) 1

proc start_mumble {} {
	global sd_sess sd_mumble
	exec xterm -T "mumble:$sd_sess(name)" -e mumble -a . -x . \
		sd-session:$sd_sess(address):$sd_mumble(port):$sd_sess(ttl) &
}

# This is a version of ~/.sd.tcl modified to support webcast data and Mosaic.
# 
# Many thanks to J. Kreibich <jak@cs.uiuc.edu> (author of Mumble, a multicast based
# IRC type tool, at http://www.acm.uiuc.edu/signet/projects/mumble.html) for the
# basis of this script.
#
# NOTE: be sure the path to Mosaic2.6 and webcast are valid for your system!
#

set sd_priv(webcast) 1

proc start_webcast {} {
        global sd_sess sd_webcast
        exec webcast -dest $sd_sess(address) $sd_webcast(port) \
        -t $sd_sess(ttl) -mosaic localhost -cci 1111 &
}
