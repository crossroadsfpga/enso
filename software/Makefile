CXX = g++
LD = g++
CXXFLAGS = -Wall -ansi -Wextra -std=c++11 -O3 \
	-I fd/api/linux
LDFLAGS = -Lfd -lfd -pthread -O3

SRCS = app.cpp
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
