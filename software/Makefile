CXX = g++
LD = g++
CXXFLAGS = -Wall -ansi -Wextra -O2 -std=c++11 \
	-I fd/api/linux
LDFLAGS = -O2 -Lfd -lfd -pthread

SRCS = short.cpp
OBJS = $(subst .cpp,.o,$(SRCS))
EXEC = app

# switch to use static or dynamic library
# LIB = fd/libfd.a
LIB = fd/libfd.so

all: $(EXEC) .depend

.cpp.o:
	$(CXX) $(CXXFLAGS) -c $< -o $@

.depend: $(SRCS)
	$(RM) ./.depend
	$(CXX) $(CXXFLAGS) -MM $^ >> ./.depend

-include .depend

fd/libfd.a:
	+$(MAKE) all-static -C fd

fd/libfd.so:
	+$(MAKE) -C fd

$(EXEC): $(LIB) $(OBJS)
	$(LD) $(OBJS) $(LDFLAGS) -o $(EXEC)

clean:
	$(RM) $(EXEC) $(OBJS) .depend
	+$(MAKE) clean -C fd
