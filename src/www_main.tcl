
set home http://www.cs.ucl.ac.uk
frame .f
pack .f -side top -fill both -expand true
frame .f.f1  -relief groove -borderwidth 2
pack .f.f1 -side top -fill x 
label .f.f1.l -text "UCL WWW v1.5"
pack .f.f1.l -side left 
button .f.f1.b -text "Home" -relief raised -command gohome
pack .f.f1.b -side left 
button .f.f1.q -text "Quit" -relief raised -command {destroy .}
pack .f.f1.q -side left 

