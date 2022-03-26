CXX = g++-9
LD = g++-9

CXXFLAGS = -Wall -ansi -Wextra -std=c++11 -O3 -g -fPIC -m64 -march=native -mavx

ifdef DSC_BUF_SIZE
CXXFLAGS += -D DSC_BUF_SIZE=$(DSC_BUF_SIZE)
endif

ifdef PKT_BUF_SIZE
CXXFLAGS += -D PKT_BUF_SIZE=$(PKT_BUF_SIZE)
endif

ifdef BATCH_SIZE
CXXFLAGS += -D BATCH_SIZE=$(BATCH_SIZE)
endif

LDFLAGS = -g -O3 -m64 -march=native

SRCS = socket.cpp pcie.cpp api/linux/intel_fpga_pcie_api_linux.cpp
OBJS = $(subst .cpp,.o,$(SRCS))
LIB_STATIC = libnorman.a
LIB_SHARED = libnorman.so

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
