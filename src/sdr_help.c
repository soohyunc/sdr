/*
 * Copyright (c) 1995,6 University College London
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by the Computer Science
 *      Department at University College London
 * 4. Neither the name of the University nor of the Department may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE UNIVERSITY AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE UNIVERSITY OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#define NO_OF_HELP 23
int no_of_help=NO_OF_HELP;
const char* const help[NO_OF_HELP]={
 "about",
 "mbone",
 "tools",
 "bugs",
 "changes",
 "sdr",
 "node1", 
 "node2",
 "node3",
 "node4",
 "node5",
 "node6",
 "node7",
 "node8",
 "node9",
 "node10",
 "node11",
 "node12",
 "node13",
 "node14",
 "node15",
 "plugins",
 "plugtut"};

#include "mbone_faq.ehtml"
#include "mbone_tools.ehtml"
#include "bugs.ehtml"
#include "changes.ehtml"
#include "intro.ehtml"
#include "node1.ehtml"
#include "node2.ehtml"
#include "node3.ehtml"
#include "node4.ehtml"
#include "node5.ehtml"
#include "node6.ehtml"
#include "node7.ehtml"
#include "node8.ehtml"
#include "node9.ehtml"
#include "node10.ehtml"
#include "node11.ehtml"
#include "node12.ehtml"
#include "node13.ehtml"
#include "node14.ehtml"
#include "node15.ehtml"
#include "plugins.ehtml"
#include "plugtut.ehtml"

const char* const helpdata[NO_OF_HELP]={
/*about*/
"<html>\n\
<h1>About Sdr</h1>\n\
\n\
Sdr is a session directory tool designed to allow the advertisement\n\
and joining of multicast conferences on the <a\n\
href=help:mbone>Mbone</a>.  It was originally based on sd written by Van Jacobson\n\
at <a href=http://www.lbl.gov/LBL.html>LBNL</a>, but implements a later\n\
version of the session description protocol than sd does.  Sd and sdr are not compatible.\n\
\n\
Help is available on the following topics:\n\
<UL>\n\
<LI><a href=help:mbone>The Multicast Backbone</a>\n\
<LI><a href=help:tools>Multicast Tools</a>\n\
<LI><a href=help:sdr>What Sdr does</a>\n\
<LI><a href=help:node14>About this help system</a>\n\
</UL>\n\
<p>\n\
<a href=help:bugs>bugs</a> and <a href=help:changes>changes</a>\n\
<p>\n\
Sdr was written by <a href=http://buttle.lcs.mit.edu/~mjh/>\n\
Mark Handley</a> at <a href=http://www.cs.ucl.ac.uk/>UCL</a> as part of the <a href=http://www-mice.cs.ucl.ac.uk/mice/mice_home.html>MICE</a> and \n\
<a href=http://www-mice.cs.ucl.ac.uk/merci/>MERCI</a> projects.\n\
Significant additions and modifications have been made by Bill Fenner\n\
at Xerox PARC and by Van Jacobson at <a href=http://www.lbl.gov/LBL.html>LBNL</a>\
</html>",
 mbone_faq,
 mbone_tools,
 bugs,
 changes,
 intro,
 node1, 
 node2,
 node3,
 node4,
 node5,
 node6,
 node7,
 node8,
 node9,
 node10,
 node11,
 node12,
 node13,
 node14,
 node15,
 plugins,
 plugtut
};
