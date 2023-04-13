from typing import TextIO, Union, Optional

from netexp.helpers import IntelFpga

from enso.consts import (
    DEFAULT_DSC_BUF_SIZE,
    DEFAULT_ETH_PORT,
    DEFAULT_NB_FALLBACK_QUEUES,
    DEFAULT_NB_TX_CREDITS,
    DEFAULT_PKT_BUF_SIZE,
    SETUP_SW_CMD,
)


LOAD_BITSTREAM_CMD = "scripts/load_bitstream.sh"
RUN_CONSOLE_CMD = "scripts/run_console.sh"


class EnsoNic(IntelFpga):
    """Class to control the Ensō NIC.

    This class can automatically load the bitstream, configure the NIC using
    JTAG and recompile the library according to the specified parameters.

    Attributes:
        fpga_id:
        enso_path:
        host_name:
        load_bitstream:
        ensure_clean:
        setup_sw:
        dsc_buf_size:
        pkt_buf_size:
        tx_credits:
        ethernet_port:
        fallback_queues:
        desc_per_pkt:
        enable_rr:
        skip_config:
        verbose:
        log_file:
    """

    def __init__(
        self,
        fpga_id: str,
        enso_path: str,
        host_name: Optional[str] = None,
        load_bitstream: bool = True,
        ensure_clean: bool = True,
        setup_sw: bool = True,
        sw_reset: bool = False,
        dsc_buf_size: int = DEFAULT_DSC_BUF_SIZE,
        pkt_buf_size: int = DEFAULT_PKT_BUF_SIZE,
        tx_credits: int = DEFAULT_NB_TX_CREDITS,
        ethernet_port: int = DEFAULT_ETH_PORT,
        fallback_queues: int = DEFAULT_NB_FALLBACK_QUEUES,
        desc_per_pkt: bool = False,
        enable_rr: bool = False,
        latency_opt: bool = False,
        skip_config: bool = False,
        verbose: bool = False,
        log_file: Union[bool, TextIO] = False,
    ):
        if load_bitstream and verbose:
            print("Loading bitstream, it might take a couple of seconds.")

        load_bitstream_cmd = f"{enso_path}/{LOAD_BITSTREAM_CMD}"
        run_console_cmd = f"{enso_path}/{RUN_CONSOLE_CMD}"

        super().__init__(
            fpga_id,
            run_console_cmd,
            load_bitstream_cmd,
            host_name=host_name,
            load_bitstream=load_bitstream,
            log_file=log_file,
        )

        self.enso_path = enso_path

        if ensure_clean and load_bitstream:
            output = self.run_jtag_commands("read_pcie")
            lines = [ln for ln in output.split("\n") if " : 0x" in ln]
            for ln in lines:
                reg_value = ln.split(" : ")[1]
                if int(reg_value, 16) != 0:
                    print(reg_value)
                    raise RuntimeError("FPGA registers are not zeroed")

        if sw_reset:
            self.sw_reset()

        if skip_config:
            self._dsc_buf_size = dsc_buf_size
            self._pkt_buf_size = pkt_buf_size
            self._tx_credits = tx_credits
            self._ethernet_port = ethernet_port
            self._fallback_queues = fallback_queues
        else:
            self.dsc_buf_size = dsc_buf_size
            self.pkt_buf_size = pkt_buf_size
            self.tx_credits = tx_credits
            self.ethernet_port = ethernet_port
            self.fallback_queues = fallback_queues

            if desc_per_pkt:
                self.enable_desc_per_pkt()
            else:
                self.disable_desc_per_pkt()

            if enable_rr:
                self.enable_rr()
            else:
                self.disable_rr()

        self.latency_opt = latency_opt

        if setup_sw:
            self.setup_sw()

    def setup_sw(self):
        sw_setup = self.host.run_command(
            f"{self.enso_path}/{SETUP_SW_CMD} {self.dsc_buf_size} "
            f"{self.pkt_buf_size} {self.latency_opt}",
            pty=True,
        )
        sw_setup.watch(
            keyboard_int=lambda: sw_setup.send("\x03"),
            stdout=self.log_file,
            stderr=self.log_file,
        )
        status = sw_setup.recv_exit_status()
        if status != 0:
            raise RuntimeError("Error occurred while setting up software")

    def get_stats(self):
        output = self.run_jtag_commands("s")
        start_index = output.find("IN_PKT: ")
        output = output[start_index:]
        stats = {}
        for row in output.split("\r\n"):
            if row.startswith("% "):
                break

            if ":" not in row:
                continue
            key, value = row.split(": ")
            stats[key] = int(value)
        return stats

    @property
    def dsc_buf_size(self):
        return self._dsc_buf_size

    @dsc_buf_size.setter
    def dsc_buf_size(self, dsc_buf_size):
        self._dsc_buf_size = dsc_buf_size
        self.run_jtag_commands(f"set_dsc_buf_size {dsc_buf_size}")

    @property
    def pkt_buf_size(self):
        return self._pkt_buf_size

    @pkt_buf_size.setter
    def pkt_buf_size(self, pkt_buf_size):
        self._pkt_buf_size = pkt_buf_size
        self.run_jtag_commands(f"set_pkt_buf_size {pkt_buf_size}")

    @property
    def tx_credits(self):
        return self._tx_credits

    @tx_credits.setter
    def tx_credits(self, tx_credits):
        self._tx_credits = tx_credits
        self.run_jtag_commands(f"set_nb_tx_credits {tx_credits}")

    @property
    def ethernet_port(self):
        return self._ethernet_port

    @ethernet_port.setter
    def ethernet_port(self, ethernet_port):
        self._ethernet_port = ethernet_port
        self.run_jtag_commands(f"set_eth_port {ethernet_port}")

    @property
    def fallback_queues(self):
        return self._fallback_queues

    @fallback_queues.setter
    def fallback_queues(self, fallback_queues):
        self._fallback_queues = fallback_queues
        self.run_jtag_commands(f"set_nb_fallback_queues {fallback_queues}")

    def enable_desc_per_pkt(self):
        self.run_jtag_commands("enable_desc_per_pkt")

    def disable_desc_per_pkt(self):
        self.run_jtag_commands("disable_desc_per_pkt")

    def enable_rr(self):
        self.run_jtag_commands("enable_rr")

    def disable_rr(self):
        self.run_jtag_commands("disable_rr")

    def sw_reset(self):
        self.run_jtag_commands("sw_rst")

    def __del__(self):
        return super().__del__()
