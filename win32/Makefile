LIB_DIR = /usr/local/lib
LIBRARY_TCL = $(LIB_DIR)/tcl7.6
LIBRARY_TK = $(LIB_DIR)/tk4.2

all:	../winsdr.tar

include ../src/Makefile.template

SDR_UI_C_FILES = $(SDR_UI_FILES:.o=.c)

CC = gcc
CFLAGS=$(INCLUDES) -DWIN32 -DCANT_MCAST_BIND -Wall

TCL2C = ./tcl2c -c

makefile.mak: makefile.vc.template
	-rm -f makefile.mak
	echo "OBJS = win32.obj $(OBJS:.o=.obj) $(SDR_UI_FILES:.o=.obj)" > makefile.mak
	cat makefile.vc.template >> makefile.mak

../winsdr.tar: $(SDR_UI_C_FILES) $(SDR_HELP_FILES) makefile.mak ../src/tcl_modules.h
	-ln -s ../src/*.[ch] ../src/*.xbm  .
	tar cfh ../winsdr.tar makefile.mak *.[ch] *.xbm *.ehtml

clean:
	rm -f ../winsdr.tar *.[ch] *.tcl *.xbm *.ehtml tcl2c makefile.mak

$(SDR_HELP_FILES): tcl2c
$(SDR_UI_C_FILES): tcl2c
