#include "sdr.h"
#include "sap_crypt.h"

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

