/*
 * Copyright (c) 1995 University College London
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
#ifdef SYSV
void bzero(str, len)
     char *str;
     int len;
{
  int i;
  for(i=0;i<len;i++)
    str[i]='\0';
}

void bcopy(s1, s2, len)
     char *s1, *s2;
     int len;
{
  int i;
  for(i=0;i<len;i++)
    s2[i]=s1[i];
}

int bcmp(s1, s2, len)
     char *s1, *s2;
     int len;
{
  int i;
  int total=1;
  for(i=0;i<len;i++)
    {
      total&=(s1[i]==s2[i]);
    }
  return total;
}
#endif

#ifdef NEEDSTRERROR

#include <errno.h>

char * strerror(i)
	int i;
{
  extern char *sys_errlist[];
  extern int sys_nerr;

  static char msg[100];
  if (i < sys_nerr)
	return sys_errlist[i];
  sprintf(msg, "Error %d", i);
  return msg;
}
#endif
