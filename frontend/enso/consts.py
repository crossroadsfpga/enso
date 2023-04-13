DEFAULT_FPGA = "1-12"
DEFAULT_DSC_BUF_SIZE = 16384
DEFAULT_PKT_BUF_SIZE = 32768
DEFAULT_NB_TX_CREDITS = 500
DEFAULT_ETH_PORT = 1  # Can be 0 or 1.
DEFAULT_NB_FALLBACK_QUEUES = 0

# The following paths are relative to the enso path.
SETUP_SW_CMD = "scripts/sw_setup.sh"
ENSOGEN_CMD = "build/software/examples/ensogen"
PCAPS_DIR = "frontend/pcaps/"
PCAP_GEN_CMD = "build/hardware/input_gen/generate_synthetic_trace"

FPGA_RATELIMIT_CLOCK = 200e6  # Hz
