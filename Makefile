#
# mdadm - manage Linux "md" devices aka RAID arrays.
#
# Copyright (C) 2001-2002 Neil Brown <neilb@cse.unsw.edu.au>
#
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#    Author: Neil Brown
#    Email: <neilb@cse.unsw.edu.au>
#    Paper: Neil Brown
#           School of Computer Science and Engineering
#           The University of New South Wales
#           Sydney, 2052
#           Australia
#

# define "CXFLAGS" to give extra flags to CC.
# e.g.  make CXFLAGS=-O to optimise
TCC = tcc
UCLIBC_GCC = $(shell for nm in i386-uclibc-linux-gcc i386-uclibc-gcc; do which $$nm > /dev/null && { echo $$nm ; exit; } ; done; echo false No uclibc found )
DIET_GCC = diet gcc
LDLIBS=-lssl

KLIBC=/home/src/klibc/klibc-0.77

KLIBC_GCC = gcc -nostdinc -iwithprefix include -I$(KLIBC)/klibc/include -I$(KLIBC)/linux/include -I$(KLIBC)/klibc/arch/i386/include -I$(KLIBC)/klibc/include/bits32

CC = $(CROSS_COMPILE)gcc
CXFLAGS = -ggdb
CWFLAGS = -Wall -Werror -Wstrict-prototypes

ifdef DEBIAN
CPPFLAGS= -DDEBIAN
else
CPPFLAGS=
endif

SYSCONFDIR = /etc
CONFFILE = $(SYSCONFDIR)/mdadm.conf
MAILCMD =/usr/sbin/sendmail -t
CFLAGS = $(CWFLAGS) $(STATIC) $(CPPFLAGS) -DCONFFILE=\"$(CONFFILE)\" $(CXFLAGS) -DSendmail=\""$(MAILCMD)"\"

# If you want a static binary, you might uncomment these
# LDFLAGS = -static
# STRIP = -s

INSTALL = /usr/bin/install
DESTDIR = 
BINDIR  = /sbin
MANDIR  = /usr/share/man
MAN4DIR = $(MANDIR)/man4
MAN5DIR = $(MANDIR)/man5
MAN8DIR = $(MANDIR)/man8

OBJS =  mdadm.o config.o mdstat.o  ReadMe.o util.o Manage.o Assemble.o Build.o \
	Create.o Detail.o Examine.o Grow.o Monitor.o dlink.o Kill.o Query.o \
	mdopen.o super0.o super1.o bitmap.o restripe.o sysfs.o
SRCS =  mdadm.c config.c mdstat.c  ReadMe.c util.c Manage.c Assemble.c Build.c \
	Create.c Detail.c Examine.c Grow.c Monitor.c dlink.c Kill.c Query.c \
	mdopen.c super0.c super1.c bitmap.c restripe.c sysfs.c

ASSEMBLE_SRCS := mdassemble.c Assemble.c config.c dlink.c util.c super0.c super1.c
ASSEMBLE_FLAGS:= -DMDASSEMBLE
ifdef MDASSEMBLE_AUTO
ASSEMBLE_SRCS += mdopen.c mdstat.c
ASSEMBLE_FLAGS += -DMDASSEMBLE_AUTO
endif

all : mdadm mdadm.man md.man mdadm.conf.man

everything: all mdadm.static mdadm.uclibc swap_super test_stripe  mdassemble mdassemble.uclibc mdassemble.static mdassemble.man
# mdadm.tcc doesn't work..

mdadm : rmconf $(OBJS)
	$(CC) $(LDFLAGS) -o mdadm $(OBJS) $(LDLIBS)

mdadm.static : STATIC=-DSTATIC
mdadm.static : rmconf $(OBJS)
	$(CC) $(LDFLAGS) -DSTATIC -static -o mdadm.static $(OBJS) SHA1.o sha1.o
rmconf:
	rm -f config.o

mdadm.tcc : $(SRCS) mdadm.h
	$(TCC) -o mdadm.tcc $(SRCS)

mdadm.uclibc : $(SRCS) mdadm.h
	$(UCLIBC_GCC) -DUCLIBC -DHAVE_STDINT_H -o mdadm.uclibc $(SRCS) SHA1.c sha1.c

mdadm.klibc : $(SRCS) mdadm.h
	rm -f $(OBJS) 
	gcc -nostdinc -iwithprefix include -I$(KLIBC)/klibc/include -I$(KLIBC)/linux/include -I$(KLIBC)/klibc/arch/i386/include -I$(KLIBC)/klibc/include/bits32 $(CFLAGS) $(SRCS)

test_stripe : restripe.c mdadm.h
	$(CC) $(CXFLAGS) $(LDFLAGS) -o test_stripe -DMAIN restripe.c

mdassemble : $(ASSEMBLE_SRCS) mdadm.h
	rm -f $(OBJS)
	$(DIET_GCC) $(ASSEMBLE_FLAGS) -o mdassemble $(ASSEMBLE_SRCS)  SHA1.c sha1.c

mdassemble.static : $(ASSEMBLE_SRCS) mdadm.h
	rm -f $(OBJS)
	$(CC) $(LDFLAGS) $(ASSEMBLE_FLAGS) -static -DSTATIC -DHAVE_STDINT_H -o mdassemble.static $(ASSEMBLE_SRCS) SHA1.c sha1.c

mdassemble.uclibc : $(ASSEMBLE_SRCS) mdadm.h
	rm -f $(OJS)
	$(UCLIBC_GCC) $(ASSEMBLE_FLAGS) -DSTATIC -DUCLIBC -DHAVE_STDINT_H -static -o mdassemble.uclibc $(ASSEMBLE_SRCS) SHA1.c sha1.c

# This doesn't work
mdassemble.klibc : $(ASSEMBLE_SRCS) mdadm.h
	rm -f $(OBJS)
	$(KLIBC_GCC) $(CFLAGS) $(ASSEMBLE_FLAGS) -o mdassemble $(ASSEMBLE_SRCS)

mdadm.man : mdadm.8
	nroff -man mdadm.8 > mdadm.man

md.man : md.4
	nroff -man md.4 > md.man

mdadm.conf.man : mdadm.conf.5
	nroff -man mdadm.conf.5 > mdadm.conf.man

mdassemble.man : mdassemble.8
	nroff -man mdassemble.8 > mdassemble.man

$(OBJS) : mdadm.h bitmap.h

sha1.o : sha1.c sha1.h md5.h
	$(CC) $(CFLAGS) -DHAVE_STDINT_H -o sha1.o -c sha1.c
SHA1.o : SHA1.c
	$(CC) $(CFLAGS) -DHAVE_STDINT_H -o SHA1.o -c SHA1.c

install : mdadm mdadm.8 md.4 mdadm.conf.5
	$(INSTALL) -D $(STRIP) -m 755 mdadm $(DESTDIR)$(BINDIR)/mdadm
	$(INSTALL) -D -m 644 mdadm.8 $(DESTDIR)$(MAN8DIR)/mdadm.8
	$(INSTALL) -D -m 644 md.4 $(DESTDIR)$(MAN4DIR)/md.4
	$(INSTALL) -D -m 644 mdadm.conf.5 $(DESTDIR)$(MAN5DIR)/mdadm.conf.5

clean : 
	rm -f mdadm $(OBJS) core *.man mdadm.tcc mdadm.uclibc mdadm.static *.orig *.porig *.rej *.alt \
	mdassemble mdassemble.static mdassemble.uclibc mdassemble.klibc swap_super \
	init.cpio.gz mdadm.uclibc.static test_stripe

dist : clean
	./makedist

testdist : everything clean
	./makedist test

TAGS :
	etags *.h *.c
