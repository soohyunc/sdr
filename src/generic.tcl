#Copyright (c) 1995 University College London
#see ui_fns.c for information on usage and redistribution of this file
#and for a DISCLAIMER OF ALL WARRANTIES.

proc resource {rname} {
    global gui
    if {$gui=="GUI"} {
        return [option get . $rname Sdr]
    } else {
        global resources
        return $resources($rname)
    }
}
 
proc set_resource {rname value} {
    global gui
    if {$gui=="GUI"} {
        option add $rname $value widgetDefault
    } else {
        global resources
	if {[string first "Sdr." $rname]==0} {
	    set rname [string range $rname 4 end]
	} elseif {[string first "*" $rname]==0} {
	    set rname [string range $rname 1 end]
	}
        set resources($rname) $value
    }
}

#sdr logging code for Louise Clark's user interface experiments
set logstr "" 
catch {
    #default to logging if they're a UCL student :-)
    if {[string compare [string range [getusername] 0 3] "zcac"]==0} {
	set log TRUE
    }
}
proc log {str} {
    global log logstr
    catch {
	if {$log=="TRUE"} {
	    set logstr "$logstr$str\n"
	}
    }
}

proc savelog {} {
    global logstr
    catch {
	set filename \
	    "/cs/research/mice/speedy/common/src/mice/sdr/sdrlog/sdrlog"
	set file \
	    [open $filename "a+" 0666 ]
	puts $file $logstr
	close $file
	catch {exec chmod 666 $filename}
    }
}

proc hlfocus {w} {
    bind $w <FocusIn> "$w configure -background [option get . activeBackground Sdr]"
    bind $w <FocusOut> "$w configure -background [option get . background Sdr]"
}

set tixBal(active) 1
set tixBal(popped) 0

proc tixEnableBalloon {} {
    global tixBal
    set tixBal(active) 0
}

proc tixDisableBalloon {} {
    global tixBal
    set tixBal(active) 0
}
proc tixBalloonAuto {} {
    global initWait
    set initWait 400
}
proc tixBalloonManual {} {
    global initWait
    global tixBal
    if {$tixBal(popped) == 1} {
      tixBalPopdown
    }
    set initWait -1
}
proc tixAddBalloon {w class msg {initWait 500}} { 
    global tixBal
    if {$class == "Button" } {
      bind $w <Enter> "+tkButtonEnter $w"
      bind $w <Leave> "+tkButtonLeave $w"
      bind $w <ButtonPress> "+tixBalEnd $w"
    } else {
    if { $class == "Entry" } {
      bind $w <ButtonPress> "+tixBalEnd $w"
      bind $w <ButtonPress> "+focus $w"
    }
    }
#    bind $w <2> "+tixBalPopup $w"
    bind $w <Enter>  +[bind $class <Enter>]
    bind $w <Enter>  "+tixBalStart $w"
    bind $w <Leave>  +[bind $class <Leave>]
    bind $w <Leave>  "+tixBalEnd $w"
    bind $w <Destroy>  +[bind $class <Destroy>]
    bind $w <Destroy> "+catch {unset tixBal($w)}"

    set tixBal($w) $msg
}

proc tixBalStart {w} {
    global tixBal
    global initWait
    global last_widget
    if {$initWait == -1} {
      return
    }
    set last_widget $w
    	after $initWait "careful_popup $w"
}

proc careful_popup {w} {
    global last_widget
    if {$w==$last_widget} {tixBalActivate $w}
}

proc tixBalEnd {w} {
    global tixBal
    global last_widget

    if {$w==$last_widget} {set last_widget foo}
    if {$tixBal(popped) == "1"} {
        tixBalPopdown
    } 
}

proc tixBalMotion {w} {
    global tixBal
    global initWait

    if {$initWait == -1} {
      return
    }
    if {$tixBal(active) == "1" && $tixBal(popped) == 0} {
	incr tixBal(count)
        after $initWait tixBalActivate $w
    }
}

proc tixBalActivate {w} {
    global tixBal
        tixBalPopup $w
}

proc tixBalPopup {widget} {
    global tixBal

    set w .tix_balloon

    catch {
        toplevel $w
	set bg    [tixQueryAppResource balloonBg TixBalloonBg #ffff60]
	set fg    [tixQueryAppResource balloonFg TixBalloonFg black]
	set width [tixQueryAppResource tixBalloonWidth TixBalloonWidth 180]
	wm overrideredirect $w 1
	message $w.msg -bg $bg -fg $fg -width $width
	pack $w.msg -expand yes -fill both
    }

    set x [expr [winfo rootx $widget]+[winfo width  $widget]-8]
    set y [expr [winfo rooty $widget]+[winfo height $widget]-8]
    $w.msg config -text $tixBal($widget)
    wm geometry $w +$x+$y
    wm deiconify $w
    raise $w
    set tixBal(popped) 1
}
    
proc tixBalPopdown {} {
    global tixBal
    set w .tix_balloon

    wm withdraw $w
    set tixBal(popped) 0
}

proc tixQueryAppResource {name class default} {

    set value [resource $name]
    if {$value == ""} {
	return $default
    } else {
	return $value
    }    
}

set_resource *balloonHelp 1

if { [resource balloonHelp] == 0 } {
    tixBalloonManual
    set balloonHelp 0
} else {
    tixBalloonAuto
    set balloonHelp 1
}

proc set_balloon_help {mode} {
 if {$mode==0} {
     tixBalloonManual
 } else {
     tixBalloonAuto
 }
}

proc fixint {i} {
    if {$i == "0"} {return 0}
    return [string trimleft $i 0]
}

proc posn_win_midscreen {w} {
    global sizes wmoffset
    set x 442
    set y 330
    catch {set x $sizes($w.x);set y $sizes($w.y)}
    set sh [winfo screenheight $w]
    set sw [winfo screenwidth $w]
    set xpos [expr (($sw-$x)/2)-$wmoffset(x)]
    set ypos [expr (($sh-$y)/2)-$wmoffset(y)]
    wm geometry $w "+$xpos+$ypos"
    set xn [winfo rootx $w]
    set yn [winfo rooty $w]
    if {$xn>$xpos} {set wmoffset(x) [expr $xn-$xpos]}
    if {$yn>$ypos} {set wmoffset(y) [expr $yn-$ypos]}
}

proc posn_win {w} {
    global sizes wmoffset
    set x 100
    set y 100
    catch {set x $sizes($w.x);set y $sizes($w.y)}
    set geom [wm geometry .]
    set xpos [expr [lindex [split $geom "+x"] 2] + 25]
    set ypos [expr [lindex [split $geom "+x"] 3] + 25]
    set sh [winfo screenheight $w]
    set sw [winfo screenwidth $w]
    if {($xpos+$x+$wmoffset(x))>$sw} {
	set xpos [expr $xpos - (($xpos+$x+$wmoffset(x))-$sw)]
    }
    if {($ypos+$y+$wmoffset(y))>$sh} {
	set ypos [expr $ypos - (($ypos+$y+$wmoffset(y))-$sh)]
    }
    wm geometry $w "+$xpos+$ypos"
    set xn [winfo rootx $w]
    set yn [winfo rooty $w]
    if {$xn>$xpos} {set wmoffset(x) [expr $xn-$xpos]}
    if {$yn>$ypos} {set wmoffset(y) [expr $yn-$ypos]}
}
 
proc posn_win_rel {w main} {
    global sizes wmoffset
    set x 100
    set y 100
    catch {set x $sizes($w.x);set y $sizes($w.y)}
    set geom [wm geometry $main]
    set xpos [expr [lindex [split $geom "+x"] 2] + 25]
    set ypos [expr [lindex [split $geom "+x"] 3] + 25]
    set sh [winfo screenheight $w]
    set sw [winfo screenwidth $w]
    if {($xpos+$x+$wmoffset(x))>$sw} {
	set xpos [expr $xpos - (($xpos+$x+$wmoffset(x))-$sw)]
    }
    if {($ypos+$y+$wmoffset(y))>$sh} {
	set ypos [expr $ypos - (($ypos+$y+$wmoffset(y))-$sh)]
    }
    wm geometry $w "+$xpos+$ypos"
}
set wmoffset(x) 0
set wmoffset(y) 0
set wmoffset(is) 0


proc move_onscreen {w} {
    global sizes
    global wmoffset
    if {[winfo exists $w]==0} { return }
    update
    if {[winfo exists $w]==0} { return }
    set wh [winfo reqheight $w]
    set ww [winfo reqwidth $w]
    set sizes($w.x) $ww
    set sizes($w.y) $wh
    set sh [winfo screenheight $w]
    set sw [winfo screenwidth $w]
    set x [winfo rootx $w]
    set y [winfo rooty $w]
    set flag 0
    if {($x+$ww) > $sw} {
	set x [expr $sw - $ww]
	set flag 1
    }
    if {($y+$wh) > $sh} {
	set y [expr $sh - $wh]
	set flag 1
    }
    if {$flag == 1} {
	wm geometry $w "+[expr $x-$wmoffset(x)]+[expr $y-$wmoffset(y)]"
    }
    if {($wmoffset(is)==0)&&($flag==1)} {
	update
	set nx [winfo rootx $w]
	set ny [winfo rooty $w]
	if {$nx!=$x} {
	    set wmoffset(x) [expr $nx - $x]
	}
	if {$ny!=$y} {
	    set wmoffset(y) [expr $ny - $y]
	}
	wm geometry $w "+[expr $x-$wmoffset(x)]+[expr $y-$wmoffset(y)]"
	set wmoffset(is) 1
    }
}


proc genericpopup {ename explan title} {
    catch {destroy .epopup}
    sdr_toplevel .epopup $title
    posn_win .epopup
    frame .epopup.f -relief groove -borderwidth 2
    label .epopup.f.l -text $ename -font "[option get . headerFont Sdr]"
    message .epopup.f.m -text $explan -font "[option get . mediumFont Sdr]" -aspect 300
    button .epopup.f.dismiss -text Dismiss -command "destroy .epopup"
    pack .epopup.f -side top
    pack .epopup.f.l -side top
    pack .epopup.f.m -side top
    pack .epopup.f.dismiss -side top -fill x -expand true
}

proc errorpopup {ename explan} {
    global gui
    if {$gui=="GUI"} {
	bell
	genericpopup $ename $explan "Sdr: [tt "Error!"]"
    } else {
	puts stderr "$ename $explan"
    }
}
proc msgpopup {ename explan} {
    genericpopup $ename $explan "Sdr"
}
proc timedmsgpopup {ename explan time} {
    genericpopup $ename $explan "Sdr"
    after $time "catch {destroy .epopup}"
}

proc mtk_ImbPost {w {x {}} {y {}}} {
    global tkPriv
    if {([$w.workaround configure -state] == "disabled") || ($w == $tkPriv(postedMb))} {
        return
    }
    set menu [$w.workaround configure -menu]
    if {($menu == "") || ([$menu index last] == "none")} {
        return
    }
    if ![string match $w.* $menu] {
        error "can't post $menu:  it isn't a descendant of $w"
    }
    set cur $tkPriv(postedMb)
    if {$cur != ""} {
        tkMenuUnpost {}
    }
#    set tkPriv(cursor) [$w.workaround configure -cursor]
    set tkPriv(relief) [$w.workaround configure -relief]
 #   $w configure -cursor arrow
    $w configure -relief raised
    set tkPriv(postedMb) $w
    set tkPriv(focus) [focus]
    $menu activate none
 
    # If this looks like an option menubutton then post the menu so
    # that the current entry is on top of the mouse.  Otherwise post
    # the menu just below the menubutton, as for a pull-down.
 
    $menu post [winfo rootx $w] [expr [winfo rooty $w]+[winfo height $w]]
    focus $menu
    tkSaveGrabInfo $w
    grab -global $w
    bind $w <ButtonRelease-1> {mtk_ImbUnpost {} }
    bind $w <ButtonPress-1> {mtk_ImbUnpost {} }
}

proc mtk_ImbUnpost menu {
    global tkPriv
    set mb $tkPriv(postedMb)
 
    # Restore focus right away (otherwise X will take focus away when
    # the menu is unmapped and under some window managers (e.g. olvwm)
    # we'll lose the focus completely).
 
    catch {focus $tkPriv(focus)}
    set tkPriv(focus) ""
 
    # Unpost menu(s) and restore some stuff that's dependent on
    # what was posted.
 
    catch {
        if {$mb != ""} {
            set menu [$mb.workaround configure -menu]
            $menu unpost
            set tkPriv(postedMb) {}
            $mb configure -cursor $tkPriv(cursor)
            $mb configure -relief $tkPriv(relief)
        } elseif {$tkPriv(popup) != ""} {
            $tkPriv(popup) unpost
            set tkPriv(popup) {}
        } elseif {[wm overrideredirect $menu]} {
            # We're in a cascaded sub-menu from a torn-off menu or popup.
            # Unpost all the menus up to the toplevel one (but not
            # including the top-level torn-off one) and deactivate the
            # top-level torn off menu if there is one.
 
            while 1 {
                set parent [winfo parent $menu]
                if {([winfo class $parent] != "Menu")
                        || ![winfo ismapped $parent]} {
                    break
                }
                $parent activate none
                $parent postcascade none
                if {![wm overrideredirect $parent]} {
                    break
                }
                set menu $parent
            }
            $menu unpost
        }
    }
 
    # Release grab, if any, and restore the previous grab, if there
    # was one.
 
    if {$menu != ""} {
        set grab [grab current $menu]
        if {$grab != ""} {
            grab release $grab
        }
    }

    catch {
      if {$tkPriv(oldGrab) != ""} {
        if {$tkPriv(grabStatus) == "global"} {
            grab set -global $tkPriv(oldGrab)
        } else {
            grab set $tkPriv(oldGrab)
        }
        set tkPriv(oldGrab) ""
      }
    }
}

proc iconbutton {args} {
    set name [lindex $args 0]
    global $name
    set [set name](state) normal
    set borderwidth 2
    set relief flat
    set command ""
    set text ""
    set bitmap ""
    set menu ""
    set width ""
    set font ""
    set pad 1
    
    for {set i 1} {$i < [llength $args]} {incr i} {
	case [lindex $args $i] in {	
	    "-borderwidth" {set borderwidth [lindex $args [expr $i+1]];incr i}
	    "-text" {set text [lindex $args [expr $i+1]];incr i}
	    "-bitmap" {set bitmap [lindex $args [expr $i+1]];incr i}
	    "-relief" {set relief [lindex $args [expr $i+1]];incr i}
	    "-command" {set command [lindex $args [expr $i+1]];incr i}
	    "-width" {set width [lindex $args [expr $i+1]];incr i}
	    "-menu" {set menu [lindex $args [expr $i+1]];incr i}
	    "-font" {set font [lindex $args [expr $i+1]];incr i}
	    "-pad" {set pad [lindex $args [expr $i+1]];incr i}
	    "-state" {set [set name](state) [lindex $args [expr $i+1]];incr i}
	    default {puts "Unknown option [lindex $args $i] to iconbutton $name"}
	}
    }
    frame $name -relief flat -borderwidth 0
    frame $name.f -relief $relief -borderwidth $borderwidth
    pack $name.f -side top -fill both
    label $name.f.bm -bitmap $bitmap -borderwidth 0 
    pack $name.f.bm -side left -fill y -ipady 2
    label $name.f.text -text $text -borderwidth 0 -pady $pad
    if {$width!=""} {$name.f.text configure -width $width}
    if {$font!=""} {$name.f.text configure -font $font}
    pack $name.f.text -side left -fill both -expand true -ipady $pad

    bind $name.f.bm <Enter> \
	"highlight_iconbutton $name [option get . activeBackground Sdr]"
    bind $name.f.text <Enter> \
	"highlight_iconbutton $name [option get . activeBackground Sdr]"
    if {$menu==""} {
	bind $name.f.bm <ButtonPress-1> \
	    "$name.f configure -relief sunken;pack_iconbits $name"
	bind $name.f.text <ButtonPress-1> \
	    "$name.f configure -relief sunken;pack_iconbits $name"
	bind $name.f.bm <ButtonRelease-1> \
	    "$name.f configure -relief $relief;pack_iconbits $name;$command"
	bind $name.f.text <ButtonRelease-1> \
	    "$name.f configure -relief $relief;pack_iconbits $name;$command"
	bind $name.f.bm <Leave> \
	    "highlight_iconbutton $name [option get . background Sdr]"
	bind $name.f.text <Leave> \
	    "highlight_iconbutton $name [option get . background Sdr]"
    } else {
	bind $name.f.bm <ButtonPress-1> \
	    "mtk_ImbPost $name"
	bind $name.f.text <ButtonPress-1> \
	    "mtk_ImbPost $name"
	bind $name.f.bm <Leave> \
	    "highlight_iconbutton $name [option get . background Sdr]"
	bind $name.f.text <Leave> \
	    "highlight_iconbutton $name [option get . background Sdr]"
    }
    proc $name.workaround {args} [format {
	global %s
#	puts $args
	case [lindex $args 0] in {
	    {config configure} {
		if {[llength $args]==2} {
		    case [lindex $args 1] in {
			"-relief" {return [%s.f config -relief]}
			"-state" {set st [set %s(state)];return "$st"}
			"-menu" {return "%s"}
		    }
		} else {
		    set ix 1
		    while {$ix < [llength $args]} {
			case [lindex $args $ix] in {
			    "-relief" {
				%s.f configure -relief \
				    [lindex $args [expr $ix + 1]]
			    }
			    "-state" {
				set %s(state) [lindex $args [expr $ix + 1]]
				case [lindex $args [expr $ix + 1]] in {
				    normal {
					%s.f.bm configure -foreground \
					    [option get . foreground Sdr]
					%s.f.text configure -foreground \
					    [option get . foreground Sdr]
				    }
				    disabled {
					%s.f.bm configure -foreground \
					    [option get . disabledForeground Sdr]
					%s.f.text configure -foreground \
					    [option get . disabledForeground Sdr]
				    }
				}
			    }
			}
			incr ix 2
		    }
		}
	    }
	}
    } $name $name $name $menu $name $name $name $name $name $name]
}



proc highlight_iconbutton {name col} {
    global $name
    if {[set [set name](state)]!="disabled"} {
	$name.f.bm configure -background $col
	$name.f.text configure -background $col
    }
}

proc pack_iconbits {name} {
    #shouldn't need this, but there's a bug in the packer...
    pack $name.f.bm -side left
    pack $name.f.text -side left -fill both -expand true
}

proc password {args} {
    if {[llength $args] < 1} { return }
    set win [lindex $args 0]
    set width 10
    set relief sunken
    set borderwidth 2
    set background [option get . background Sdr]
    set font [option get . font Sdr]
    set variable ""
    set command break
    set ix 2
    foreach a [lrange $args 1 end] {
	case $a in {
	    "-width" { set width [lindex $args $ix] }
	    "-relief" { set relief [lindex $args $ix] }
	    "-background" { set background [lindex $args $ix] }
	    "-borderwidth" { set borderwidth [lindex $args $ix] }
	    "-variable" { set variable [lindex $args $ix] }
	    "-font" {set font [lindex $args $ix] }
	    "-command" {set command [lindex $args $ix] }
	}
	incr ix
    }
    entry $win -width $width \
	-background $background \
	-borderwidth $borderwidth \
	-relief $relief \
        -font $font \
        -highlightthickness 0
    global $variable
    set $variable ""
    bind $win <Any-KeyPress> "add_password_char $win $variable %A;break"
    bind $win <Delete> "del_password_char $win $variable;break"
    bind $win <BackSpace> "del_password_char $win $variable;break"
    bind $win <Return> $command
    bind $win <Tab> {focus [tk_focusNext %W];break}
    bind $win <Shift-Tab> {focus [tk_focusPrev %W];break}
    proc $win.workaround {args} [format {
	if {[lindex $args 0]=="set"} {
	    set_password_chars %s %s [lindex $args 1]
	}
    } $win $variable]
}

proc set_password_chars {win var chs} {
    global $var
    set $var $chs
    $win delete 0 end
    for {set i 0} {$i < [string length $chs]} {incr i} {
	$win insert 0 "*"
    }
}

proc add_password_char {win var ch} {
    global $var
    set v [set $var]
    if {[is_printable $ch]} {
	set v "$v$ch"
	$win insert end "*"
	$win icursor end
	set $var $v
    }
}

proc del_password_char {win var} {
    global $var
    set v [set $var]
    set last [expr [string length $v] - 2]
    set v [string range $v 0 $last]
    $win delete 0 1
    set $var $v
}

proc is_printable {ch} {
    if {[string length $ch]==1} {
	scan $ch %c c
	if {$c < 32} {
	    return 0
	}
	return 1
    }
    return 0
}
