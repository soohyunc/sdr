proc add_address {} {
    global userlist
    catch {destroy .newuser}
    sdr_toplevel .newuser "Add new user"
    frame .newuser.f -relief groove -borderwidth 2
    pack .newuser.f -side top
    set win .newuser.f
    message $win.msg -text "Enter the details of the new user to be added to your address book" -aspect 400
    pack $win.msg -side top
    frame $win.f1 
    pack $win.f1 -side top
    
}
