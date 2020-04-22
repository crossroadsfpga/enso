// #include <daq.h>

#include <cstdlib>
#include <csignal>
#include <iostream>

#include "fd/pcie.h"
#include "fd/api/intel_fpga_pcie_api.hpp"

static volatile int keep_running = 1;

void int_handler(int signal __attribute__((unused)))
{
    keep_running = 0;
}

void process_packet(block_s* block __attribute__((unused)))
{
    // do something with the packet
}

int main()
{
    intel_fpga_pcie_dev *dev;
    uint16_t bdf = 0;
    int bar = -1;
    int result;

    try {
        dev = new intel_fpga_pcie_dev(bdf, bar);
    } catch (const std::exception &ex) {
        std::cerr << "Invalid BDF or BAR!\n";
        exit(1);
    }
    std::cout << std::hex << std::showbase;
    std::cout << "Opened a handle to BAR " << dev->get_bar();
    std::cout << " of a device with BDF " << dev->get_dev() << std::endl;

    result = dev->use_cmd(true);
    if (result == 0) {
        std::cerr << "Could not switch to CMD use mode!\n";
        exit(1);
    }

    dma_run(dev, process_packet, &keep_running);

    result = dev->use_cmd(false);
    if (result == 0) {
        std::cerr << "Could not switch to CMD use mode!\n";
        exit(1);
    }

    return 0;
}
