CXX = g++
LD = g++
CXXFLAGS = -Wall -ansi -Wextra -std=c++11 -O2
LDFLAGS = -O2

SRCS = intel_fpga_pcie_api_linux.cpp
OBJS = $(subst .cpp,.o,$(SRCS))

all: $(OBJS) .depend

.cpp.o:
	$(CXX) $(CXXFLAGS) -c $< -o $@

.depend: $(SRCS)
	$(RM) ./.depend
	$(CXX) $(CXXFLAGS) -MM $^ >> ./.depend

-include .depend

clean:
	$(RM) $(OBJS) .depend
