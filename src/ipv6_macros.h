#ifndef IPV6_MACROS_H
#define IPV6_MACROS_H
#ifdef HAVE_IPv6


#define IPV6_ADDR_LEN sizeof(struct in6_addr)

#define in6_word(a, n)	*((int*)&((a).s6_addr[(n)*sizeof(int)]))
#define in6_wordp(ap, n) *((int*)&((ap)->s6_addr[(n)*sizeof(int)]))


#define IN6_ADDR_ASSIGN(a, w1, w2, w3, w4) { in6_word(a, 0) = (w1) ; \
					     in6_word(a, 1) = (w2) ; \
				     	     in6_word(a, 2) = (w3) ; \
				     	     in6_word(a, 3) = (w4) ; }

#define IN6_pADDR_ASSIGN(ap, w1, w2, w3, w4) { in6_wordp(ap, 0) = (w1); \
					       in6_wordp(ap, 1) = (w2); \
					       in6_wordp(ap, 2) = (w3); \
					       in6_wordp(ap, 3) = (w4); }

#define IN6_ADDR_COPY(dst, src) IN6_ADDR_ASSIGN(dst, \
						in6_word(src, 0), \
						in6_word(src, 1), \
						in6_word(src, 2), \
						in6_word(src, 3))

#define IN6_pADDR_COPY(dstp, srcp) IN6_pADDR_ASSIGN(dstp, \
						in6_wordp(srcp, 0), \
						in6_wordp(srcp, 1), \
						in6_wordp(srcp, 2), \
						in6_wordp(srcp, 3) )

#define IN6_ADDR_EQUAL(a1, a2) ( (in6_word(a1,0) == in6_word(a2,0)) && \
				 (in6_word(a1,1) == in6_word(a2,1)) && \
				 (in6_word(a1,2) == in6_word(a2,2)) && \
				 (in6_word(a1,3) == in6_word(a2,3)))

#define IN6_NETMASK_IT(a, m) \
		{ int i, j; \
		j = i = (m-1) / (sizeof(int) * 8); \
		while(++i < sizeof(struct in6_addr) / sizeof(int) ) \
			in6_word(a, i) = 0x0; \
		i = (m-1) % (sizeof(int) * 8); \
		in6_word(a, j) &= ~((1 << (sizeof(int)*8 - 1 - i)) - 1); } 

#define IS_IN6_MULTICAST(a) ((in6_word(a, 0) & 0xff000000) == 0xff000000 )

/* Scope in Multicast Address */
#define NODE_SCOPE		0x1
#define LINK_SCOPE		0x2
#define SITE_SCOPE		0x5
#define ORGANIZATION_SCOPE	0x8
#define GLOBAL_SCOPE		0xE 


#endif /* HAVE_IPv6 */
#endif /* IPV6_MACROS_H */
