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
#include "ipv6_macros.h"

#define IPV6_ADDR_LEN 16

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

int store_address(struct in_addr *addr, int addr_fam, unsigned long endtime)
//int store_address(char *addr, int addr_fam, unsigned long endtime)
{
  struct addr_list *new_address, *test;
  test=first_addr;

  while (test!=NULL) {
      if (addr_fam == IPv6){
#ifdef HAVE_IPv6
          if (IPV6_ADDR_EQUAL((struct in6_addr *)addr, &(test->addr6))) {
              if (endtime == test->endtime) return 0;
              delete_address(test);
              break;
          } 
#endif
      } else {
          if (addr->s_addr == test->addr.s_addr) {
              if (endtime == test->endtime) return 0;
              delete_address(test);
              break;
          }
      }
      test=test->next;
  }

  new_address=(struct addr_list *)malloc(sizeof(struct addr_list));
  memset(new_address, 0, sizeof(struct addr_list));
  if (addr_fam == IPv6) {
#ifdef HAVE_IPv6
      IN6_ADDR_COPY(new_address->addr6, 
                    (*((struct in6_addr*)addr)));
#endif
  } else {
      new_address->addr.s_addr= addr->s_addr;
  }
  new_address->next=NULL;
  new_address->endtime=endtime;
  
  if (first_addr==NULL) {
      first_addr=new_address;
      last_addr=new_address;
      new_address->prev=NULL;
  } else {
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

int check_address(struct in_addr *addr, int addr_fam)
{
  struct addr_list *test, *tmp;
  struct timeval tv;

  test=first_addr;
  gettimeofday(&tv, NULL);
  while(test!=NULL) {
      if((test->endtime!=0)&&(test->endtime<tv.tv_sec)) {
          tmp=test->next;
          delete_address(test);
          test=tmp;
      } else {
          if (addr_fam == IPv6) {
#ifdef HAVE_IPv6
              if(IPV6_ADDR_EQUAL((struct in6_addr *)addr,
                                &test->addr6)) {
                  return FALSE;
              }
#endif              
          } else {
              if(addr->s_addr==test->addr.s_addr) {
                  return FALSE;
              }
          }
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
      if (check_address(&newaddr, IPv4)==TRUE)
          return(newaddr);
    }
}

#ifdef HAVE_IPv6
struct in6_addr *generate_v6_address(struct in6_addr *baseaddr, int netmask,
                                     struct in6_addr *newaddr)
{
    unsigned long i;
    u_int mask;

    mask = 128;

    // We ignore a passed in scope, we assume that the baseaddr
    // designates a scope. If there is no baseaddr, we assume global scope.

    //printf("in generate addr: scope: %d, netmask: %d\n", scope, netmask);

    if (baseaddr==NULL) {
		inet_pton(AF_INET6, SAPv6_DEFAULT, newaddr);    // ffoe::2:8000
        mask = SAPv6_DEFAULT_MASK;             // 113 bits   
    } else {
        memcpy(newaddr, baseaddr, IPV6_ADDR_LEN);
    }
    /* printf("generate_v6_addr: orig addr:%s\n", inet6_ntoa(newaddr)); */
    while(1) {
        i=lbl_random();

        IN6_NETMASK_IT(*newaddr, mask);

        i = i & ((1 << (128 - netmask)) - 1);

        /* in6_word(newaddr, 3) |= (i);*/
        /* newaddr->s6_words[7] |= (i);*/
		newaddr->s6_addr[14] |= (i>>8);
		newaddr->s6_addr[15] |= (i);

        if (check_address(newaddr, IPv6)==TRUE) {
            return(newaddr);
        }
    }
}
#endif

