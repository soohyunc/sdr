struct addr_list {
  struct in_addr addr;
#ifdef HAVE_IPv6
  struct in6_addr addr6;
#endif
  unsigned long endtime;
  struct addr_list *next;
  struct addr_list *prev;
};
