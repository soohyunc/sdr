#ifndef MM_DEBUG_H
#define MM_DEBUG_H


/* Debugging levels */
#define SIP              0x00001
#define REG              0x00002

/* Debugging macros */
#ifdef MDEBUG_FLAG
extern int mdebug;
#define MDEBUG(level, arg)         if (mdebug & level) printf/**/arg

#else
#define MDEBUG(level, arg)

#endif /* MDEBUG_FLAG */

#endif /* MM_DEBUG_H */
