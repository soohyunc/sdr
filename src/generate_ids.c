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
#include "sdr.h"
#include "generate_ids.h"
#include "prototypes.h"

int generate_port(char *media)
{
  int base=49152;
  int mask=0x3fff;
  if(media!=NULL)
    {
      if(strcmp("audio",media)==0)
        {
          base=16384;
          mask=0x3ffe;
        }
      else if(strcmp("whiteboard",media)==0)
        {
          base=32768;
        }
      else if(strcmp("video", media)==0)
        {
          mask=0x3ffe;
        }
    }
  return((lbl_random()&mask)+base);
}


static struct addr_list *first_addr=NULL;
static struct addr_list *last_addr=NULL;

int store_address(struct in_addr *addr, unsigned long endtime)
{
  struct addr_list *new_address, *test;
  test=first_addr;

  while (test!=NULL) {
    if (addr->s_addr == test->addr.s_addr) {
        if (endtime == test->endtime) return 0;
        delete_address(test);
        break;
    }
    test=test->next;
  }

  new_address=(struct addr_list *)malloc(sizeof(struct addr_list));
  new_address->addr.s_addr= addr->s_addr;
  new_address->next=NULL;
  new_address->endtime=endtime;
  if(first_addr==NULL)
    {
      first_addr=new_address;
      last_addr=new_address;
      new_address->prev=NULL;
    }
  else
    {
      new_address->prev=last_addr;
      last_addr->next=new_address;
      last_addr=new_address;
    }
  return 0;
}

int delete_address(struct addr_list *test)
{
#ifdef DEBUG
  printf("Address %s no longer in use\n", test->addr);
#endif
  if (test->prev) {
    test->prev->next = test->next;
   } else {
     first_addr = test->next;
   }
   if (test->next) {
     test->next->prev = test->prev;
   } else {
     last_addr = test->prev;
   }
  free(test);
  return 0;
}

int check_address(struct in_addr *addr)
{
  struct addr_list *test, *tmp;
  struct timeval tv;
  test=first_addr;
  gettimeofday(&tv, NULL);
  while(test!=NULL)
    {
      if((test->endtime!=0)&&(test->endtime<tv.tv_sec))
	{
	  tmp=test->next;
	  delete_address(test);
	  test=tmp;
	}
      else
	{
	  if(addr->s_addr==test->addr.s_addr)
	    return FALSE;
	  test=test->next;
	}
    }
  return TRUE;
}

struct in_addr generate_address(struct in_addr *baseaddr, int netmask)
{
  unsigned int i;
  struct in_addr newaddr;
  struct in_addr mask;

  mask.s_addr = htonl(~((1 << (32 - netmask)) - 1));
  if (baseaddr==NULL) {
    newaddr.s_addr = htonl(0xe0028000);	/* 224.2.128.0 */
    mask.s_addr = htonl(0xffff8000);	/* 255.255.128.0 */
  } else {
    newaddr = *baseaddr;
  }
  while(1)
    {
      i=lbl_random();
      newaddr.s_addr &= mask.s_addr;
      newaddr.s_addr |= (i & ~mask.s_addr);
      if (check_address(&newaddr)==TRUE)
	return(newaddr);
    }
}
