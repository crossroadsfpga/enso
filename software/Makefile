CXX = g++-9
LD = g++-9
CXXFLAGS = -Wall -ansi -Wextra -O2 -g -std=c++11 \
	-I norman/api/linux -m64 -march=native -mavx
LDFLAGS = -O2 -g -Lnorman -lnorman -pthread -m64 -march=native

SRCS = app.cpp
OBJS = $(subst .cpp,.o,$(SRCS))
EXEC = app

DISPATCH_SRCS = dispatch.cpp
DISPATCH_OBJS = $(subst .cpp,.o,$(DISPATCH_SRCS))
DISPATCH_EXEC = dispatch

EVENT_SRCS = app_event.cpp
EVENT_OBJS = $(subst .cpp,.o,$(EVENT_SRCS))
EVENT_EXEC = app_event

PKTGEN_SRCS = pktgen.cpp
PKTGEN_OBJS = $(subst .cpp,.o,$(PKTGEN_SRCS))
PKTGEN_EXEC = pktgen

# switch to use static or dynamic library
LIB = norman/libnorman.a
# LIB = norman/libnorman.so

all: $(EXEC) $(DISPATCH_EXEC) $(EVENT_EXEC) $(PKTGEN_EXEC) .depend

.cpp.o:
	$(CXX) $(CXXFLAGS) -c $< -o $@

.depend: $(SRCS) $(DISPATCH_SRCS)
	$(RM) ./.depend
	$(CXX) $(CXXFLAGS) -MM $^ >> ./.depend

-include .depend

norman/libnorman.a:
	+$(MAKE) all-static -C norman

norman/libnorman.so:
	+$(MAKE) -C norman

$(EXEC): $(LIB) $(OBJS)
	$(LD) $(OBJS) $(LDFLAGS) -o $(EXEC)

$(DISPATCH_EXEC): $(LIB) $(DISPATCH_OBJS)
	$(LD) $(DISPATCH_OBJS) $(LDFLAGS) -o $(DISPATCH_EXEC)

$(EVENT_EXEC): $(LIB) $(EVENT_OBJS)
	$(LD) $(EVENT_OBJS) $(LDFLAGS) -o $(EVENT_EXEC)

$(PKTGEN_EXEC): $(LIB) $(PKTGEN_OBJS)
	$(LD) $(PKTGEN_OBJS) $(LDFLAGS) -lpcap -o $(PKTGEN_EXEC)

clean:
	$(RM) $(EXEC) $(OBJS) $(DISPATCH_OBJS) $(EVENT_OBJS) $(PKTGEN_OBJS) .depend
	+$(MAKE) clean -C norman
