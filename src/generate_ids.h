struct addr_list {
  struct in_addr addr;
  unsigned long endtime;
  struct addr_list *next;
  struct addr_list *prev;
};
