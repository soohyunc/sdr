/*
 * Copyright (c) 1993 Regents of the University of California.
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
 *	This product includes software developed by the Computer Systems
 *	Engineering Group at Lawrence Berkeley Laboratory.
 * 4. Neither the name of the University nor of the Laboratory may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * LBL random number generator.
 *
 * Written by Steve McCanne & Chris Torek (mccanne@ee.lbl.gov,
 * torek@ee.lbl.gov), November, 1992.
 *
 * This implementation is based on ``Two Fast Implementations of
 * the "Minimal Standard" Random Number Generator", David G. Carta,
 * Communications of the ACM, Jan 1990, Vol 33 No 1.
 */

#include "sdr.h"
#include "sap_crypt.h"

static int randseed = 1;

void
srandom(unsigned int seed)
{
	randseed = seed;
}

#if sparc && !__SUNPRO_C
#ifdef __svr4__
#define RANDOM "random"
#define RANDSEED "randseed"
#else
#define RANDOM "_random"
#define RANDSEED "_randseed"
#endif
asm("\
	.global	" RANDOM "			;\
" RANDOM ":					;\
	sethi	%hi(16807), %o1			;\
	wr	%o1, %lo(16807), %y		;\
	 sethi	%hi(" RANDSEED "), %g1		;\
	 ld	[%g1 + %lo(" RANDSEED ")], %o0	;\
	 andcc	%g0, 0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %o0, %o2			;\
	mulscc  %o2, %g0, %o2			;\
	rd	%y, %o3				;\
	srl	%o2, 16, %o1			;\
	set	0xffff, %o4			;\
	and	%o4, %o2, %o0			;\
	sll	%o0, 15, %o0			;\
	srl	%o3, 17, %o3			;\
	or	%o3, %o0, %o0			;\
	addcc	%o0, %o1, %o0			;\
	bneg	1f				;\
	 sethi	%hi(0x7fffffff), %o1		;\
	retl					;\
	 st	%o0, [%g1 + %lo(" RANDSEED ")]	;\
1:						;\
	or	%o1, %lo(0x7fffffff), %o1	;\
	add	%o0, 1, %o0			;\
	and	%o1, %o0, %o0			;\
	retl					;\
	 st	%o0, [%g1 + %lo(" RANDSEED ")] ");
#else
#ifdef __linux__	/* yeuch :-( */
int
#else
long
#endif
random(void)
{
	register int x = randseed;
	register int hi, lo;
	register long t;

	hi = x / 127773;
	lo = x % 127773;
	t = 16807 * lo - 2836 * hi;
	if (t <= 0)
		t += 0x7fffffff;
	randseed = t;
	return (t);
}
#endif

/* ---------------------------------------------------------------------- */ 
/* secure random number generator from OSISEC source                      */
/* ---------------------------------------------------------------------- */ 

static int seeded = 0;

/* ---------------------------------------------------------------------- */ 
/* sec_randomkey                                                          */
/*                                                                        */
/* ---------------------------------------------------------------------- */ 
int sec_randomkey(char *key, int *seed)
{
        struct {
          long  no[2];
        } temp_key;
 
        sec_seed();
        *seed = temp_key.no[0] = sec_longrand();
        *seed = temp_key.no[1] = sec_longrand();
 
        memcpy(key, &temp_key, 8);
 
        return (OK);
}

/* ---------------------------------------------------------------------- */ 
/* sec_seed                                                               */
/*                                                                        */
/* seed initialiser for sec_longrand()                                    */
/*                                                                        */
/* This routine may be replaced by any initialisation required for        */
/* sec_longrand().                                                        */
/*                                                                        */
/* Returns OK if successful,  NOTOK otherwise.                            */
/* ---------------------------------------------------------------------- */ 
 
int sec_seed()
{
        if (seeded == 0) {
          srand48((unsigned)(time(NULL) + getpid()));
          seeded = 1;     /* don't seed again */
        }
        return OK;
}

/* ---------------------------------------------------------------------- */ 
/* sec_longrand                                                           */
/*                                                                        */
/* primary security-oriented random number routine                        */
/*                                                                        */
/* Should be seeded exactly once by a call to sec_seed()                  */
/*                                                                        */
/* This routine may be replaced by any means of random number             */
/* generation which generates a non-negative long value                   */
/*                                                                        */
/* 0 <= return < 2**31                                                    */
/* ---------------------------------------------------------------------- */ 

long sec_longrand()
{
        return lrand48();
}

