#Use same colours as vat
#general
option add *background gray80 widgetDefault
option add *foreground black widgetDefault
option add *activeBackground gray95 widgetDefault
option add *activeForeground black widgetDefault
option add *hotForeground blue widgetDefault
option add *selectBackground gray95 widgetDefault
option add *scrollbarBackground gray50 widgetDefault
option add *scrollbarForeground gray80 widgetDefault
option add *scrollbarActiveForeground gray95 widgetDefault
option add *canvasBackground gray95 widgetDefault
option add *balloonBg gray50 widgetDefault
option add *balloonFg white widgetDefault
#test
option add *disabledBackground gray80 widgetDefault
option add *disabledForeground gray50 widgetDefault
option add *entryBackground lightsteelblue widgetDefault
option add *infoFont \
  -*-helvetica-medium-r-normal--10-* \
  widgetDefault
option add *headerFont \
  -*-helvetica-bold-r-normal--14-* \
  widgetDefault
option add *mediumFont \
  -*-helvetica-medium-r-normal--12-* \
  widgetDefault


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

