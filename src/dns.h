struct dnshdr {
  unsigned int id:16;
  unsigned int qr:1;
  unsigned int opcode:4;
  unsigned int aa:1;
  unsigned int tc:1;
  unsigned int rd:1;
  unsigned int ra:1;
  unsigned int z:3;
  unsigned int rcode:4;
  unsigned int qdcount:16;
  unsigned int ancount:16;
  unsigned int nscount:16;
  unsigned int arcount:16;
};
