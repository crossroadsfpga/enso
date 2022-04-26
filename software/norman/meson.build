
add_global_arguments(['-mavx'], language: ['c', 'cpp'])

sources = ['socket.cpp', 'pcie.cpp', 'api/linux/intel_fpga_pcie_api_linux.cpp']

norman_lib = library('norman', sources, install: true)
