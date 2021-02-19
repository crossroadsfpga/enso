CXX = g++
LD = g++
CXXFLAGS = -Wall -ansi -Wextra -O0 -std=c++11 \
	-I fd/api/linux
LDFLAGS = -O0 -Lfd -lfd -pthread

SRCS = app.cpp
OBJS = $(subst .cpp,.o,$(SRCS))
EXEC = app

DISPATCH_SRCS = dispatch.cpp
DISPATCH_OBJS = $(subst .cpp,.o,$(DISPATCH_SRCS))
DISPATCH_EXEC = dispatch

# switch to use static or dynamic library
# LIB = fd/libfd.a
LIB = fd/libfd.so

all: $(EXEC) $(DISPATCH_EXEC) .depend

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

clean:
	$(RM) $(EXEC) $(OBJS) $(DISPATCH_OBJS) .depend
	+$(MAKE) clean -C fd
