/*
	Netvideo version 3.2
	Written by Ron Frederick <frederick@parc.xerox.com>

	Simple hack to translate a Tcl/Tk init file into a C string constant
	Extra hacks added by mhandley based on idea from vic
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

main(int argc, char **argv)
{
    int c, n;
    FILE* in = stdin;
    FILE* out = stdout;
    int genstrings = 1;
    const char* prog = argv[0];

    if (argc > 1 && strcmp(argv[1], "-c") == 0) {
	--argc;
	++argv;
	genstrings = 0;
    }
    if (argc < 2) {
	fprintf(stderr, "Usage: %s [-c] stringname\n", prog);
	exit(1);
    }

    if (genstrings) {
	fprintf(out, "const char %s[] = \"\\\n", argv[1]);
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
	fprintf(out, "\";\n");
    } else {
	fprintf(out, "const char %s[] = {\n", argv[1]);
	for (n = 0; (c = getc(in)) != EOF;)
	   fprintf(out, "%u,%c", c, ((++n & 0xf) == 0) ? '\n' : ' ');
	fprintf(out, "0\n};\n");
    }
    fclose(out);
    exit(0);
    /*NOTREACHED*/
}
