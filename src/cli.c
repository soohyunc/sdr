/*Command line interface - see cli.tcl for details*/
#include <stdio.h>
#include <tcl.h>
#include <tk.h>

extern Tcl_Interp *interp;

int init_cli() {
  return 0;
}

int do_cli(clientData, mask)
    ClientData clientData;		/* Not used. */
    int mask;				/* Not used. */
{
  static char cmd[256];
  fgets(cmd, sizeof(cmd), stdin);
  if (Tcl_SetVar(interp, "cli_cmd", cmd, TCL_GLOBAL_ONLY)==NULL)
  {
    Tcl_AddErrorInfo(interp, "\n");
    fprintf(stderr, interp->result);
  }
  if (Tcl_GlobalEval(interp, "cli_parse_command")!=TCL_OK)
  {
    fprintf(stderr, "cli_parse_command failed: %s\n", 
			    interp->result);
  }
  return 0;
}
