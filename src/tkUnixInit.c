#include <tcl.h>

int TkPlatformInit(Tcl_Interp *interp)
{
        Tcl_SetVar(interp, "tk_library", ".", TCL_GLOBAL_ONLY);
#ifndef WIN32
	{
		extern void TkCreateXEventSource(void);
		TkCreateXEventSource();
	}
#endif
        return (TCL_OK);
}
