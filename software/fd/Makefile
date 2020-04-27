CXX = g++
LD = g++
CXXFLAGS = -Wall -ansi -Wextra -std=c++11 -O3 -fPIC
LDFLAGS = -O3

SRCS = fd.cpp pcie.cpp api/linux/intel_fpga_pcie_api_linux.cpp
OBJS = $(subst .cpp,.o,$(SRCS))
LIB_STATIC = libfd.a
LIB_SHARED = libfd.so

all: $(LIB_SHARED) .depend

all-static: $(LIB_STATIC) .depend

.cpp.o:
	$(CXX) $(CXXFLAGS) -c $< -o $@

.depend: $(SRCS)
	$(RM) ./.depend
	$(CXX) $(CXXFLAGS) -MM $^ >> ./.depend

-include .depend

api:
	+$(MAKE) -C api

$(LIB_SHARED): $(OBJS)
	$(CXX) -shared  $(OBJS) -o $@ $(LDFLAGS)

$(LIB_STATIC): $(OBJS)
	$(AR) rcs $(LIB_STATIC) $(OBJS)

clean:
	$(RM) $(OBJS) $(LIB_SHARED) $(LIB_STATIC) .depend
	+$(MAKE) clean -C api
