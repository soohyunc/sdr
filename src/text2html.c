/*      sdr written by Mark Handley
	hack to convert plain text to ehtml, modified from...
*/

/*
	Netvideo version 3.2
	Written by Ron Frederick <frederick@parc.xerox.com>

	Simple hack to translate a Tcl/Tk init file into a C string constant
*/

/*
 * Copyright (c) Xerox Corporation 1992. All rights reserved.
 *  
 * License is granted to copy, to use, and to make and to use derivative
 * works for research and evaluation purposes, provided that Xerox is
 * acknowledged in all documentation pertaining to any such copy or derivative
 * work. Xerox grants no other licenses expressed or implied. The Xerox trade
 * name should not be used in any advertising without its written permission.
 *  
 * XEROX CORPORATION MAKES NO REPRESENTATIONS CONCERNING EITHER THE
 * MERCHANTABILITY OF THIS SOFTWARE OR THE SUITABILITY OF THIS SOFTWARE
 * FOR ANY PARTICULAR PURPOSE.  The software is provided "as is" without
 * express or implied warranty of any kind.
 *  
 * These notices must be retained in any copies of any part of this software.
 */

#include <stdio.h>

main()
{
    int c, n;
    FILE* in = stdin;
    FILE* out = stdout;

#ifdef CANDOBIGSTRINGS
    fprintf(out, "\"\\n\\\n");
    while ((c = getc(in)) != EOF) {
	switch (c) {
	case '\n':
	    fprintf(out, "\\n\\\n");
	    break;
	case '\"':
	    fprintf(out, "\\\"");
	    break;
	case '\\':
	    fprintf(out, "\\\\");
	    break;
	default:
	    putc(c, out);
	    break;
	}
    }
    fprintf(out, "\\n\\\n\"\n");
    fclose(out);
#else
    fprintf(out, "{ ");
    for (n = 0; (c = getc(in)) != EOF;)
       fprintf(out, "%u,%c", c, ((++n & 0xf) == 0) ? '\n' : ' ');
    fprintf(out, "\n0 }\n");
#endif
    exit(0);
    /*NOTREACHED*/
}
