NAME=simple
CFILES= simple.c
MIGCFILES= simpleUser.c 
MIGINCLUDES= simple.h
HFILES= simple_types.h

CFLAGS= -g -O -MD -DMACH -I../../include ${RC_CFLAGS}
OFILES= $(CFILES:.c=.o) $(MIGCFILES:.c=.o)


all:	$(NAME)

$(NAME): $(OFILES)
	cc $(CFLAGS) -o $(NAME) $(OFILES)

.c.o:
	$(CC) $(CFLAGS) -c $*.c
	md -u Makedep -d $*.d

simpleUser.c simple.h: simple.defs 
	mig ${MIGFLAGS} simple.defs

-include Makedep


