/*This module is similar to the crypt module used in RAT, except that
  the padding bit is 0x80 in byte 0, rather than 0x20 in RTP.*/

#include "config_unix.h"
#include "config_win32.h"
#include "crypt.h"
#include "qfDES.h"
#include "md5.h"

/* Global variables accessible inside this module only */
#define TRUE 1
#define FALSE 0
static u_int empty_key = TRUE;
static u_char des_key[8];
u_char crypt_buffer[8192];
u_char* wrkbuf_ = crypt_buffer;
static u_int badpktlen_ = 0;
static u_int badpbit_ = 0;

int Null_Key()
{
	return(empty_key);
}

static int decrypt( const u_char* in, u_char* out, int len)
/***********************************************************************
* DESCRIPTION                                                           *
*                                                                       *
* This function decrypts control and data packets, stripping out the    *
* padding and/or 4 random bytes.                                        *
*                                                                       *
* INPUT PARAMETERS                                                      *
*                                                                       *
*  u_char* in:      the buffer to be decrypted                          *
* int len:          the size of the buffer                              *
*                                                                       *
* OUTPUT PARAMETERS                                                     *
*                                                                       *
* u_char* out: the decrypted information                                *
*                                                                       *
* RETURNS                                                               *
*                                                                       *
* int len: the new buffer size, after padding has been removed.         *
************************************************************************/
{
	int pad;

	/* We are not using the IV */
	u_char initVec[8] = {0,0,0,0,0,0,0,0};
	u_char* inpk = (u_char*)in;

	/* check that packet is an integral number of blocks */
	if ((len & 7) != 0) {
		++badpktlen_;
		return (-1);
	}

	/* Carry out decryption */
	qfDES_CBC_d(des_key, (char *)(inpk), len, initVec);

	memcpy(out, in, len);

	/* Strip off the padding, where necessary */
	if ((out[0] & 0x80) != 0) {
		/* P bit set - trim off padding */
		out[0] = out[0] ^ 0x80;
		pad = out[len - 1];
		if (pad > 7 || pad == 0) {
			++badpbit_;
			return (-1);
		}
		len -= pad;
	}
	return (len);
}


static int install_key( unsigned char* key)
/************************************************************************
* DESCRIPTION                                                           *
*                                                                       *
* This function expands the 56-bit key into 64-bits by inserting parity *
* bits.  The MSB of each byte is used as the parity bit.                *
*                                                                       *
* INPUT PARAMETERS                                                      *
*                                                                       *
*  unsigned char* key: a 56-bit key                                	*
*                                                                       *
* RETURNS                                                               *
*                                                                       *
* This function always returns 0 (Success)                              *
************************************************************************/
{
	int i;
	int j;
	register int k;

	/* DES key */
	/*
	 * Take the first 56-bits of the input key and spread
	 * it across the 64-bit DES key space inserting a bit-space
	 * of garbage (for parity) every 7 bits.  The garbage
	 * will be taken care of below.  The library we're
	 * using expects the key and parity bits in the following
	 * MSB order: K0 K1 ... K6 P0 K8 K9 ... K14 P1 ...
	 */
	des_key[0] = key[0];
	des_key[1] = key[0] << 7 | key[1] >> 1;
	des_key[2] = key[1] << 6 | key[2] >> 2;
	des_key[3] = key[2] << 5 | key[3] >> 3;
	des_key[4] = key[3] << 4 | key[4] >> 4;
	des_key[5] = key[4] << 3 | key[5] >> 5;
	des_key[6] = key[5] << 2 | key[6] >> 6;
	des_key[7] = key[6] << 1;

	/* fill in parity bits to make DES library happy */
	for (i = 0; i < 8; ++i) 
	{
		k = des_key[i] & 0xfe;
		j = k;
		j ^= j >> 4;
		j ^= j >> 2;
		j ^= j >> 1;
		j = (j & 1) ^ 1;
		des_key[i] = k | j;
	}

	return (0);
}

int Set_Key(const char* key)
/************************************************************************
* DESCRIPTION                                                           *
*                                                                       *
* This function creates an MD5 digest of a plain text key to produce a  *
* 56-bit encryption key.  The MD5 digest has (more) uniform entropy     *
* distribution.                                                         *
*                                                                       *
* INPUT PARAMETERS                                                      *
*                                                                       *
*  char* key: the plain text key entered by the operator           	*
*                                                                       *
* RETURNS                                                               *
*                                                                       *
* This function will always return 0 (Success)                          *
************************************************************************/
{
        u_char hash[16];
	int i;
	
	if ( key[0] != 0 )
	{
          MD5_CTX context;
          MD5Init(&context);
          MD5Update(&context, (u_char*)key, strlen(key));
          MD5Final((u_char *)hash, &context);
	  empty_key = FALSE;
          return (install_key(hash));
	}
	else
	{
	  empty_key = TRUE;
	  for (i=0; i<8; i++)
	    des_key[i]=0;
	  return 1;
	}
}

u_char* Encrypt( u_char* in, int* len)
/************************************************************************
* DESCRIPTION                                                           *
*                                                                       *
* This function encrypts data packets.  The data is padded with zeros if*
* the buffer size does not lie on an 8-octet boundary.                  *
*                                                                       *
* INPUT PARAMETERS                                                      *
*                                                                       *
* u_char* in:  the input buffer to be encrypted                   	*
* int* len:          buffer length                                      *
*                                                                       *
* OUTPUT PARAMETERS                                                     *
*                                                                       *
* int* len:  this is to account for padding.                            *
*                                                                       *
* RETURNS                                                               *
*                                                                       *
* A pointer to the encrypted data is returned.                          *
************************************************************************/
{

	/* We are not using the IV */
	 u_char initVec[8] = {0,0,0,0,0,0,0,0};
	int pad;
	u_char* rh = wrkbuf_;
	int i;
	u_char* padding;
 
        memcpy(wrkbuf_, in, *len);
	/*clear the P bit*/
	rh[0]=rh[0]&0x7f;

	/* Pad with zeros to the nearest 8 octet boundary */	
	pad = *len & 7;
        if (pad != 0) 
	{
                /* pad to an block (8 octet) boundary */
                pad = 8 - pad;
                rh[0] = rh[0] | 0x80; /* set P bit */
		padding = (wrkbuf_ + *len);
		for (i=1; i<pad; i++)
		  *(padding++) = 0;
		*(padding++) = (char)pad;
		*len += pad;
        }

	/* Carry out the encryption */
        qfDES_CBC_e(des_key, wrkbuf_, *len, initVec);
	return(wrkbuf_);	
}

int Decrypt( const u_char* in, u_char* out, int len)
/************************************************************************
* DESCRIPTION                                                           *
*                                                                       *
* This function provides the external interface for decrypting data     *
* packets                                                               *
*                                                                       *
* INPUT PARAMETERS                                                      *
*                                                                       *
*  u_char* in: the buffer to be decrypted                               *
* int len:          the size of the buffer                              *
*                                                                       *
* OUTPUT PARAMETERS                                                     *
*                                                                       *
* u_char* out: the decrypted data                                       *
*                                                                       *
* RETURNS                                                               *
*                                                                       *
* int len: the new buffer size, after padding has been removed.         *
************************************************************************/
{
	return (decrypt(in, out, len));
}
