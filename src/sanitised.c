#include "sdr.h"
#include "prototypes.h"

extern unsigned long hostaddr;
extern int debug1;
extern int doexit;

char *release="exp";

int init_security()
{
  return 0;
}

int aux_load_file(char *buf, char *name, char *flag)
{
  FILE *cache;
  int len;
  cache=fopen(name, "r");
  if (cache==NULL) return TCL_OK;
  len=fread(buf, 1, MAXADSIZE, cache);
  buf[len]='\0';
  fclose(cache);

  return len;

}

int parse_announcement(int enc, char *data, int length, 
		       unsigned long src, unsigned long hfrom,
		       char *addr, int port, int sec)
{
  char recvkey[MAXKEYLEN];
  strcpy(recvkey, "");
  
  /* if someone else is repeating our announcements, be careful
     not to re-announce their modified version ourselves */
  if (src == hfrom || src != hostaddr)
    {
      parse_entry(NULL, data, length, src, hfrom,
		  addr, port,
		  sec, "trusted", recvkey);
    }
  else
    {
      parse_entry(NULL, data, length, src, hfrom,
		  addr, port,
		  sec, "untrusted", recvkey);
    }
  return 0;
}


int build_packet(char *buf, char *adstr, int len, int encrypt)
{
  struct sap_header *bp;
  int len_add=0;

  bp=(struct sap_header *)buf;
  bp->compress=0;
  if (encrypt==0) {
    memcpy(buf+sizeof(struct sap_header), adstr, len);
    if (debug1==TRUE)
      printf("sending %s\n", adstr);
    bp->enc=0;
  } else {
    perror("cannot send encrypted packet with this version\n");
    exit(1);
  }
  bp->src=htonl(hostaddr);
  bp->msgid=0;
  bp->version=1;
  bp->type=0;
  bp->authlen=0;
  return len_add;
}

int store_data_to_announce(struct advert_data *addata, 
			   char * adstr, char *keyname)
{
  addata->data=malloc(addata->length);
  addata->encrypt=0;
  memcpy(addata->data, adstr, addata->length);
  return 0;
}

int ui_createsession(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  int endtime, interval;
  unsigned char ttl;
  int port;
  char aid[80];
  char data[2048];
  struct timeval tv;
  gettimeofday(&tv, NULL);
  endtime=atol(argv[2]);
  ttl=(unsigned char)atoi(argv[5]);
  port=atoi(argv[4]);
  interval=INTERVAL;
  /*need the copy because parse entry splats the data*/
  strncpy(data, argv[1], 2047);
  parse_entry(aid, data, strlen(data), hostaddr, hostaddr, argv[3], port, tv.tv_sec, "trusted", "");
  queue_ad_for_sending(aid, argv[1], interval, endtime, argv[3], port, ttl, argv[6]);
  return TCL_OK;
}
 


int ui_quit()
{
  doexit=TRUE;
  return TCL_OK;
}
