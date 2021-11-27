CXX = g++-9
LD = g++-9

SRCS = app.cpp
OBJS = $(subst .cpp,.o,$(SRCS))
EXEC = app

DISPATCH_SRCS = dispatch.cpp
DISPATCH_OBJS = $(subst .cpp,.o,$(DISPATCH_SRCS))
DISPATCH_EXEC = dispatch

EVENT_SRCS = app_event.cpp
EVENT_OBJS = $(subst .cpp,.o,$(EVENT_SRCS))
EVENT_EXEC = app_event

# switch to use static or dynamic library
# LIB = fd/libfd.a
LIB = fd/libfd.so

all: $(EXEC) $(DISPATCH_EXEC) $(EVENT_EXEC) .depend

.cpp.o:
	$(CXX) $(CXXFLAGS) -c $< -o $@

.depend: $(SRCS) $(DISPATCH_SRCS)
	$(RM) ./.depend
	$(CXX) $(CXXFLAGS) -MM $^ >> ./.depend

-include .depend

fd/libfd.a:
	+$(MAKE) all-static -C fd

fd/libfd.so:
	+$(MAKE) -C fd

$(EXEC): $(LIB) $(OBJS)
	$(LD) $(OBJS) $(LDFLAGS) -o $(EXEC)

$(DISPATCH_EXEC): $(LIB) $(DISPATCH_OBJS)
	$(LD) $(DISPATCH_OBJS) $(LDFLAGS) -o $(DISPATCH_EXEC)

$(EVENT_EXEC): $(LIB) $(EVENT_OBJS)
	$(LD) $(EVENT_OBJS) $(LDFLAGS) -o $(EVENT_EXEC)

clean:
	$(RM) $(EXEC) $(OBJS) $(DISPATCH_OBJS) $(EVENT_OBJS) .depend
	+$(MAKE) clean -C fd
