LIB_DIR = /cs/research/mice/starship/common/sunos/lib
LIBRARY_TCL = $(LIB_DIR)/tcl8.0
LIBRARY_TK = $(LIB_DIR)/tk8.0

all:	../winsdr.tar

include ../src/Makefile.template

SDR_UI_C_FILES = $(SDR_UI_FILES:.o=.c)
SDR_UI_C_FILES_CRYPT = $(SDR_UI_FILES_CRYPT:.o=.c) 

CC = gcc
CFLAGS=$(INCLUDES) -DWIN32 -DCANT_MCAST_BIND -Wall

TCL2C = ./tcl2c -c

makefile.mak: makefile.vc.template
	-rm -f makefile.mak
	echo "OBJS = win32.obj $(OBJS:.o=.obj) $(ENCOBJS:.0=.obj) $(SDR_UI_FILES:.o=.obj) $(SDR_UI_FILES_CRYPT:.o=.obj)" > makefile.mak
	cat makefile.vc.template >> makefile.mak

../winsdr.tar: $(SDR_UI_C_FILES) $(SDR_HELP_FILES) $(SDR_UI_C_FILES_CRYPT) makefile.mak ../src/tcl_modules.h
	-ln -s ../src/*.[ch] ../src/*.xbm  .
	tar cfh ../winsdr.tar makefile.mak *.[ch] *.xbm *.ehtml

clean:
	rm -f ../winsdr.tar *.[ch] *.tcl *.xbm *.ehtml tcl2c makefile.mak

../src/html/changes.ehtml: ../src/CHANGES
	echo "<!-- DO NOT MODIFY THIS FILE -->" > ../src/html/changes.html
	echo "<!-- This file is automatically derived from CHANGES -->" >> ../src/html/changes.html
	cat ../src/CHANGES >> ../src/html/changes.html
 
../src/html/bugs.html:  ../src/BUGS
	echo "<!-- DO NOT MODIFY THIS FILE -->" > ../src/html/bugs.html
	echo "<!-- This file is automatically derived from BUGS -->" >> ../src/html/bugs.html
	cat ../src/BUGS >> ../src/html/bugs.html

$(SDR_HELP_FILES): tcl2c
$(SDR_UI_C_FILES): tcl2c
$(SDR_UI_FILES_CRYPT): tcl2c
