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
#include "sdr_server.h"
#include "store_entries.h"
#include "server_prototypes.h"


struct entry_list entries;

void init_entry_list(struct entry_list *elist)
{
  elist->first_entry=NULL;
  elist->no_of_entries=0;
  elist->first_timeout=0;
}

void store_entry(struct session *sess, char *buf, int length,
		 struct entry_list *elist, u_char origin,
		 struct scope *scope)
{
  struct stored_entry *entry, *tmp;
  if((elist->first_entry==NULL)||(elist->first_entry->hash>sess->aid))
    {
      if(elist->first_entry!=NULL) 
	tmp=elist->first_entry;
      else
	tmp=NULL;
      elist->first_entry=malloc(sizeof(struct stored_entry));
      bcopy(buf, elist->first_entry->buf, length);
      elist->first_entry->buf[length]='\0';
      elist->first_entry->length=length;
      elist->first_entry->hash=sess->aid;
      elist->first_entry->sess=sess;
      elist->first_entry->origin=origin;
      elist->first_entry->scope=scope;
      elist->first_entry->next=tmp;
      elist->first_timeout=sess->endtime;
      elist->no_of_entries++;
      return;
    }
  entry=elist->first_entry;
  while(entry->next!=NULL)
    {
      if (entry->hash==sess->aid) break;
      if (entry->next->hash>sess->aid) break;
      entry=entry->next;
    }
  if(entry->hash==sess->aid)
    {
      /*we've seen it before*/
      /*shouldn't have to do this if WSDAP was done properly*/
      bcopy(buf, entry->buf, length);
      entry->buf[length]='\0';
      entry->length=length;
      if((entry->origin==REMOTE)&&(origin==LOCAL_CLIENT))
	entry->origin=LOCAL_CLIENT;
      free_session(entry->sess);
      entry->sess=sess;
      return;
    }
  tmp=entry->next;
  entry->next=malloc(sizeof(struct stored_entry));
  entry=entry->next;
  bcopy(buf, entry->buf, length);
  entry->buf[length]='\0';
  entry->length=length;
  entry->hash=sess->aid;
  entry->sess=sess;
  entry->origin=origin;
  entry->scope=scope;
  if((sess->endtime<elist->first_timeout)&&(elist->first_timeout!=0))
    elist->first_timeout=sess->endtime;
  entry->next=tmp;
  elist->no_of_entries++;
}

void delete_stored_entry(hash_t aid, struct entry_list *elist)
{
  struct stored_entry *entry, *tmp;
  entry=elist->first_entry;
  tmp=NULL;
  while(entry!=NULL)
    {
      if(entry->sess->aid==aid)
	{
	  if(tmp==NULL)
	    elist->first_entry=entry->next;
	  else
	    tmp->next=entry->next;
	  free_session(entry->sess);
	  free(entry);
	  return;
	}
      tmp=entry;
      entry=entry->next;
    }
}

void move_stored_entry(hash_t aid, struct entry_list *oldlist, 
		       struct entry_list *newlist)
{
  struct stored_entry *entry, *tmp;
  entry=oldlist->first_entry;
  tmp=NULL;
  while(entry!=NULL)
    {
      if(entry->sess->aid==aid)
	{
	  if(tmp==NULL)
	    oldlist->first_entry=entry->next;
	  else
	    tmp->next=entry->next;
	  store_entry(entry->sess, entry->buf, entry->length, newlist, entry->origin, entry->scope);
	  free(entry);
	  return;
	}
      tmp=entry;
      entry=entry->next;
    }
}

void timeout_stored_entries(struct entry_list *elist)
{
  struct stored_entry *entry, *tmp;
  struct timeval tv;
#ifndef SYSV
  gettimeofday(&tv, NULL);
#else
  gettimeofday(&tv);
#endif
  if(tv.tv_sec<elist->first_timeout)
    {
      return;
    }
  if(elist->first_entry==NULL) return;
  entry=elist->first_entry;
  tmp=NULL;
  elist->first_timeout=elist->first_entry->sess->endtime;
  while(entry->next!=NULL)
    {
      if(entry->sess->endtime<tv.tv_sec)
	{
	  if(tmp==NULL)
	    elist->first_entry=entry->next;
	  else
	    tmp->next=entry->next;
	  free_session(entry->sess);
	  free(entry);
	  elist->no_of_entries--;
	} else {
	  if (elist->first_timeout>entry->sess->endtime) 
	    elist->first_timeout=entry->sess->endtime;
	}
      tmp=entry;
      entry=entry->next;
    }
}

hash_t *create_hash_list(int *length, struct entry_list *elist)
{
  struct stored_entry *entry;
  hash_t *list;
  int ctr=0;
  list=malloc(elist->no_of_entries*(sizeof(hash_t)));
  if(elist->first_entry==NULL) 
    {
      *length=0;
      return(NULL);
    }
  entry=elist->first_entry;
  while(entry!=NULL)
    {
      list[ctr++]=entry->hash;
      entry=entry->next;
    }
  *length=elist->no_of_entries;
  return(list);
}

void free_hash_list(hash_t *hashlist)
{
  free(hashlist);
}

char *get_stored_entry(hash_t aid, struct entry_list *elist, int *length)
{
  struct stored_entry *entry;
  if(elist->first_entry==NULL)
    {
      *length=0;
      return NULL;
    }
  entry=elist->first_entry;
  while(entry!=NULL)
    {
      if(entry->hash==aid)
	{
	  *length=entry->length;
	  return entry->buf;
	}
      entry=entry->next;
    }
  *length=0;
  return NULL;
}

struct session *get_stored_session(hash_t aid, struct entry_list *elist)
{
  struct stored_entry *entry;
  if(elist->first_entry==NULL)
    {
      return NULL;
    }
  entry=elist->first_entry;
  while(entry!=NULL)
    {
      if(entry->hash==aid)
	{
	  return entry->sess;
	}
      entry=entry->next;
    }
  return NULL;
}

unsigned int get_origin(hash_t aid, struct entry_list *elist)
{
  struct stored_entry *entry;
  if(elist->first_entry==NULL)
    {
      return UNKNOWN;
    }
  entry=elist->first_entry;
  while(entry!=NULL)
    {
      if(entry->hash==aid)
	{
	  return entry->origin;
	}
      entry=entry->next;
    }
  return UNKNOWN;
}

struct scope *get_scope(hash_t aid, struct entry_list *elist)
{
  struct stored_entry *entry;
  if(elist->first_entry==NULL)
    {
      return NULL;
    }
  entry=elist->first_entry;
  while(entry!=NULL)
    {
      if(entry->hash==aid)
	{
	  return entry->scope;
	}
      entry=entry->next;
    }
  return NULL;
}

int have_entry(hash_t aid, struct entry_list *elist)
{
  struct stored_entry *entry;
  if(elist->first_entry==NULL)
    return 0;
  entry=elist->first_entry;
  while(entry!=NULL)
    {
      if(entry->hash==aid)
	return 1;
      entry=entry->next;
    }
  return 0;
}

void sort_hash_list(hash_t *hashlist, int length, int order)
{
  switch(order)
    {
    case ALPHABETIC:
      {
	qsort(hashlist, length, sizeof(hash_t), compare_session_names);
	break;
      }
    case STARTTIME:
      {
	qsort(hashlist, length, sizeof(hash_t), compare_start_times);
	break;
      }
    }
}

int compare_session_names(hash_t *aid1, hash_t *aid2)
{
  char *sname1, *sname2;
  sname1=get_session_name(*aid1);
  sname2=get_session_name(*aid2);
  if((sname1==NULL)||(sname2==NULL)) return 0;
  return(strncasecmp(sname1, sname2, 80));
}

int compare_start_times(hash_t *aid1, hash_t *aid2)
{
  unsigned int stime1, stime2;
  stime1=get_session_starttime(*aid1);
  stime2=get_session_starttime(*aid2);
  if(stime2==0) return -1;
  if(stime1==0) return 1;
  if(stime1>stime2) return 1;
  if(stime1<stime2) return -1;
  return 0;
}

char *get_session_name(hash_t aid)
{
  int length;
  char *entry;
  entry=get_stored_entry(aid, &entries, &length);
  nextline(&entry);
  nextline(&entry);
  if(strncmp(entry, "s=", 2)!=0)
    {
      printf("no session name in %s\n", get_stored_entry(aid, &entries, &length));
      return NULL;
    }
  else
    {
      return(entry+2);
    }
}

unsigned int get_session_starttime(hash_t aid)
{
  struct session *sess;
  sess=get_stored_session(aid, &entries);
  if(sess!=NULL)
    {
      return(sess->starttime);
    }
  else
    return 0;
}
