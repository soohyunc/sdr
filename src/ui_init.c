
/* 
 * Modifications Copyright (c) 1995,1996 University College London
 * Copyright (c) 1990-1993 The Regents of the University of California.
 * All rights reserved.
 *
 * Permission is hereby granted, without written agreement and without
 * license or royalty fees, to use, copy, modify, and distribute this
 * software and its documentation for any purpose, provided that the
 * above copyright notice and the following two paragraphs appear in
 * all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 */

#include "sdr.h"
#include "prototypes.h"
#include "tcl_modules.h"

extern int gui;
#define MAXCLINE 256

/*
 * Declarations for various library procedures and variables (don't want
 * to include tkInt.h or tkConfig.h here, because people might copy this
 * file out of the Tk source directory to make their own modified versions).
 */

extern void		exit _ANSI_ARGS_((int status));
/*
 * Global variables used by the main program:
 */

static Tk_Window mainWindow;	/* The main window for the application.  If
				 * NULL then the application no longer
				 * exists. */
Tcl_Interp *interp;	/* Interpreter for this application. */
static Tcl_DString command;	/* Used to assemble lines of terminal input
				 * into Tcl commands. */

/*
 * Command-line options:
 */

static int synchronize = 0;
static char *fileName = NULL;
static char *name = "sdr";
static char *display = NULL;
static char *geometry = NULL;

static Tk_ArgvInfo argTable[] = {
    {"-file", TK_ARGV_STRING, (char *) NULL, (char *) &fileName,
	"File from which to read commands"},
    {"-geometry", TK_ARGV_STRING, (char *) NULL, (char *) &geometry,
	"Initial geometry for window"},
    {"-display", TK_ARGV_STRING, (char *) NULL, (char *) &display,
	"Display to use"},
    {"-name", TK_ARGV_STRING, (char *) NULL, (char *) &name,
	"Name to use for application"},
    {"-sync", TK_ARGV_CONSTANT, (char *) 1, (char *) &synchronize,
	"Use synchronous mode for display server"},
    {(char *) NULL, TK_ARGV_END, (char *) NULL, (char *) NULL,
	(char *) NULL}
};


/*
 *----------------------------------------------------------------------
 *
 * main --
 *
 *	Main program for Wish.
 *
 * Results:
 *	None. This procedure never returns (it exits the process when
 *	it's done
 *
 * Side effects:
 *	This procedure initializes the wish world and then starts
 *	interpreting commands;  almost anything could happen, depending
 *	on the script being interpreted.
 *
 *----------------------------------------------------------------------
 */

int
ui_init(argc, argv)
    int *argc;				/* Number of arguments. */
    char **argv;			/* Array of argument strings. */
{
    char buf[MAXCLINE];
    int i;

    interp = Tcl_CreateInterp();
#ifdef TCL_MEM_DEBUG
    Tcl_InitMemory(interp);
#endif

    /*
     * Parse command-line arguments.
     */

    if (Tk_ParseArgv(interp, (Tk_Window) NULL, argc, argv, argTable, 0)
	    != TCL_OK) {
	fprintf(stderr, "%s\n", interp->result);
	exit(1);
    }

    /*
     * If a display was specified, put it into the DISPLAY
     * environment variable so that it will be available for
     * any sub-processes created by us.
     */

    if (display != NULL) {
	Tcl_SetVar2(interp, "env", "DISPLAY", display, TCL_GLOBAL_ONLY);
    }

    strcpy(buf, "-name sdr");
    for(i=1;i<*argc;i++)
      {
        strncat(buf, " ", MAXCLINE-strlen(buf));
        strncat(buf, argv[i], MAXCLINE-strlen(buf));
      }
    Tcl_SetVar(interp, "argv", buf, TCL_GLOBAL_ONLY);

    if (gui==GUI) {
      if(Tk_Init(interp)!=TCL_OK)
	{
	  fprintf(stderr, "Sdr: %s\n", interp->result);
	  exit(-1);
	}
      mainWindow = Tk_MainWindow(interp);
    }

#ifdef WIN32
    {
	/*
	 * under windows, there's no useful notion of stdout or stderr
	 * so redefine the 'puts' command to put up a dialog box (otherwise
	 * we'll never see any of the intialization errors).
	 */
	extern int WinPutsCmd(ClientData, Tcl_Interp*, int, char **);
	Tcl_CreateCommand(interp, "puts", WinPutsCmd, 0, 0);
    }
#endif

    /*
     * Add a few application-specific commands to the application's
     * interpreter.
     */
    for(i=0;i<MAX_UI_FN;i++)
      Tcl_CreateCommand(interp, ui_fn_name[i], ui_fn[i],
                      (ClientData) mainWindow, 0);
    return 1;

}

int announce_error(int code, char *command)
{
	if (code != TCL_OK) {
		char buf[128];
		strncpy(buf, interp->result, sizeof(buf) - 1);
		fprintf(stderr, "sdr:%s %s\n", command, interp->result);
		Tcl_VarEval(interp, "puts $errorInfo", NULL);
		Tcl_VarEval(interp, "tkerror {", buf, "}", NULL);
	}
	return (code);
}

int ui_create_interface()
{
  int i;
  announce_error(Tcl_VarEval(interp, tcl_libs, 0), "tcl_libs");

  /*
   * Set the geometry of the main window, if requested.
   */
  if (geometry != NULL) {
    announce_error(Tcl_VarEval(interp, "wm geometry . ", geometry, 0), 
		   "setting geometry");
  }

  for(i=0;i<MAX_TCL_MODULE;i++)
    {
      announce_error(Tcl_VarEval(interp, modvar[i], 0), modname[i]);
    }

    return 0;
}
