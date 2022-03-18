
from netexp.helpers import RemoteIntelFpga, remote_command, watch_command

from norman.consts import DEFAULT_BATCH_SIZE, DEFAULT_DSC_BUF_SIZE, \
    DEFAULT_ETH_PORT, DEFAULT_NB_FALLBACK_QUEUES, DEFAULT_NB_TX_CREDITS, \
    DEFAULT_PKT_BUF_SIZE, SETUP_SW_CMD


class NormanDataplane(RemoteIntelFpga):
    """Class to control the Norman dataplane.

    This class can automatically load the bitstream, configure the dataplane
    using JTAG and recompile the library according to the specified parameters.

    Attributes:
        host:
        fpga_id:
        remote_norman_path:
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
        sw_batch_size:
        verbose:
    """
    def __init__(self, fpga_id: str, host: str, remote_norman_path: str,
                 load_bitstream: bool = True, ensure_clean: bool = True,
                 setup_sw: bool = True, sw_reset: bool = False,
                 dsc_buf_size: int = DEFAULT_DSC_BUF_SIZE,
                 pkt_buf_size: int = DEFAULT_PKT_BUF_SIZE,
                 tx_credits: int = DEFAULT_NB_TX_CREDITS,
                 ethernet_port: int = DEFAULT_ETH_PORT,
                 fallback_queues: int = DEFAULT_NB_FALLBACK_QUEUES,
                 desc_per_pkt: bool = False, enable_rr: bool = False,
                 sw_batch_size: int = DEFAULT_BATCH_SIZE,
                 verbose=False):
        if load_bitstream and verbose:
            print('Loading bitstream, it might take a couple of seconds.')

        super().__init__(host, fpga_id, remote_norman_path, load_bitstream,
                         verbose=verbose)

        self.remote_norman_path = remote_norman_path

        if ensure_clean and load_bitstream:
            output = self.run_jtag_commands('read_pcie')
            lines = [ln for ln in output.split('\n') if ' : 0x' in ln]
            for ln in lines:
                reg_value = ln.split(' : ')[1]
                if int(reg_value, 16) != 0:
                    print(reg_value)
                    raise RuntimeError('FPGA registers are not zeroed')

        if sw_reset:
            self.sw_reset()

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

        self.sw_batch_size = sw_batch_size

        if setup_sw:
            self.setup_sw()

    def setup_sw(self):
        sw_setup = remote_command(
            self.ssh_client,
            f'{self.remote_norman_path}/{SETUP_SW_CMD} {self.dsc_buf_size} '
            f'{self.pkt_buf_size} {self.sw_batch_size}', pty=True
        )
        watch_command(sw_setup, keyboard_int=lambda: sw_setup.send('\x03'),
                      stdout=self.verbose, stderr=self.verbose)
        status = sw_setup.recv_exit_status()
        if status != 0:
            raise RuntimeError('Error occurred while setting up software')

    def get_stats(self):
        output = self.run_jtag_commands('s')
        start_index = output.find('IN_PKT: ')
        output = output[start_index:]
        stats = {}
        for row in output.split('\r\n'):
            if row.startswith('% '):
                break
            key, value = row.split(': ')
            stats[key] = int(value)
        return stats

    @property
    def dsc_buf_size(self):
        return self._dsc_buf_size

    @dsc_buf_size.setter
    def dsc_buf_size(self, dsc_buf_size):
        self._dsc_buf_size = dsc_buf_size
        self.run_jtag_commands(f'set_dsc_buf_size {dsc_buf_size}')

    @property
    def pkt_buf_size(self):
        return self._pkt_buf_size

    @pkt_buf_size.setter
    def pkt_buf_size(self, pkt_buf_size):
        self._pkt_buf_size = pkt_buf_size
        self.run_jtag_commands(f'set_pkt_buf_size {pkt_buf_size}')

    @property
    def tx_credits(self):
        return self._tx_credits

    @tx_credits.setter
    def tx_credits(self, tx_credits):
        self._tx_credits = tx_credits
        self.run_jtag_commands(f'set_nb_tx_credits {tx_credits}')

    @property
    def ethernet_port(self):
        return self._ethernet_port

    @ethernet_port.setter
    def ethernet_port(self, ethernet_port):
        self._ethernet_port = ethernet_port
        self.run_jtag_commands(f'set_eth_port {ethernet_port}')

    @property
    def fallback_queues(self):
        return self._fallback_queues

    @fallback_queues.setter
    def fallback_queues(self, fallback_queues):
        self._fallback_queues = fallback_queues
        self.run_jtag_commands(f'set_nb_fallback_queues {fallback_queues}')

    def enable_desc_per_pkt(self):
        self.run_jtag_commands('enable_desc_per_pkt')

    def disable_desc_per_pkt(self):
        self.run_jtag_commands('disable_desc_per_pkt')

    def enable_rr(self):
        self.run_jtag_commands('enable_rr')

    def disable_rr(self):
        self.run_jtag_commands('disable_rr')

    def sw_reset(self):
        self.run_jtag_commands('sw_rst')

    def __del__(self):
        return super().__del__()
