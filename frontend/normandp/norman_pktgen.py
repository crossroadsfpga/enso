
import math
import tempfile

from collections import defaultdict
from csv import DictReader
from fractions import Fraction

from netexp.helpers import remote_command, watch_command, download_file
from netexp.pktgen import Pktgen

from normandp.consts import FPGA_RATELIMIT_CLOCK, NORMAN_PKTGEN_CMD
from normandp.norman_dataplane import NormanDataplane


class NormanPktgenStats:
    def __init__(self, file_name: str) -> None:

        self.stats = defaultdict(list)
        self.nb_samples = 0
        with open(file_name, newline='') as f:
            csv_reader = DictReader(f)
            for row in csv_reader:
                self.nb_samples += 1
                for k, v in row.items():
                    self.stats[k].append(int(v))

    def get_summary(self, calculate_tx_mean: bool = False):
        if self.nb_samples < 3:
            raise RuntimeError('Not enough samples to calculate summary')

        summary = {}

        # Ignore first and last datapoints for RX.
        rx_goodput = self.stats['rx_goodput_mbps'][1:-1]
        rx_pkt_rate = self.stats['rx_pkt_rate_kpps'][1:-1]

        summary['rx_mean_goodput_mbps'] = sum(rx_goodput) / len(rx_goodput)
        summary['rx_mean_rate_kpps'] = sum(rx_pkt_rate) / len(rx_pkt_rate)

        summary['rx_bytes'] = self.stats['rx_bytes'][-1]
        summary['rx_packets'] = self.stats['rx_packets'][-1]

        if calculate_tx_mean:
            # For TX, we need to ignore all the datapoints after it's done
            # transmitting. For lower rates, it might take a while before
            # pktgen receives all the packets back.
            last_tx_sample = self.stats['tx_goodput_mbps'].find(0) - 1

            if last_tx_sample < 3:
                raise RuntimeError('Not enough samples to calculate TX mean')

            tx_goodput = self.stats['tx_goodput_mbps'][1:last_tx_sample]
            tx_pkt_rate = self.stats['tx_pkt_rate_kpps'][1:last_tx_sample]

            summary['tx_mean_goodput_mbps'] = sum(tx_goodput) / len(tx_goodput)
            summary['tx_mean_rate_kpps'] = sum(tx_pkt_rate) / len(tx_pkt_rate)

        summary['tx_bytes'] = self.stats['tx_bytes'][-1]
        summary['tx_packets'] = self.stats['tx_packets'][-1]

        if 'mean_rtt_ns' in self.stats:
            mean_rtts = self.stats['mean_rtt_ns'][1:-1]
            summary['mean_rtt_ns'] = sum(mean_rtts) / len(mean_rtts)

        return summary


def mean_pkt_size_remote_pcap(ssh_client, pcap_path) -> float:
    capinfos_cmd = remote_command(
        ssh_client, f'capinfos -z {pcap_path}', pty=True
    )
    output = watch_command(capinfos_cmd,
                           keyboard_int=lambda: capinfos_cmd.send('\x03'))
    status = capinfos_cmd.recv_exit_status()
    if status != 0:
        raise RuntimeError('Error processing remote pcap')

    try:
        parsed_output = output.split(' ')[-2]
        mean_pcap_pkt_size = float(parsed_output)
    except (IndexError, ValueError):
        raise RuntimeError(
            f'Error processing remote pcap (capinfos output: "{output}"')

    return mean_pcap_pkt_size


class NormanPktgen(Pktgen):
    """Python wrapper for Norman pktgen.
    """
    def __init__(self, dataplane: NormanDataplane, pcap_path, core_id: int = 0,
                 queues: int = 4, multicore: bool = False, rtt: bool = False,
                 rtt_hist: bool = False, rtt_hist_offset: int = None,
                 rtt_hist_len: int = None, stats_file: str = None,
                 hist_file: str = None) -> None:
        super().__init__()

        self.dataplane = dataplane
        self.dataplane.enable_rr()
        self.dataplane.fallback_queues = queues

        self.pcap_path = pcap_path

        self.core_id = core_id
        self.queues = queues
        self.multicore = multicore
        self.rtt = rtt
        self.rtt_hist = rtt_hist
        self.rtt_hist_offset = rtt_hist_offset
        self.rtt_hist_len = rtt_hist_len

        self.stats_file = stats_file or 'stats.csv'
        self.hist_file = hist_file or 'hist.csv'

        self.pktgen_cmd = None

        self.clean_stats()

    def start(self, throughput: float, nb_pkts: int):
        """Start packet generation.

        Args:
            throughput: Throughput in bits per second.
            nb_pkts: Number of packets to transmit.
        """
        if self.pcap_path is None:
            raise RuntimeError('No pcap was configured')

        eth_overhead = 20 + 4
        bits_per_pkt = (self.mean_pcap_pkt_size + eth_overhead) * 8
        pkts_per_sec = throughput / bits_per_pkt
        flits_per_pkt = math.ceil(self.mean_pcap_pkt_size / 64)

        hardware_rate = pkts_per_sec * flits_per_pkt / FPGA_RATELIMIT_CLOCK

        rate_frac = Fraction(hardware_rate).limit_denominator(1000)

        command = (
            f'sudo {self.dataplane.remote_norman_path}/{NORMAN_PKTGEN_CMD}'
            f' {self.pcap_path} {rate_frac.numerator} {rate_frac.denominator}'
            f' --count {nb_pkts}'
            f' --core {self.core_id}'
            f' --queues {self.queues}'
            f' --save {self.stats_file}'
        )

        if self.multicore:
            command += ' --multicore'

        if self.rtt:
            command += ' --rtt'

        if self.rtt_hist:
            command += f' --rtt-hist {self.hist_file}'

        if self.rtt_hist_offset is not None:
            command += ' --rtt-hist-offset'

        if self.rtt_hist_len is not None:
            command += ' --rtt-hist-len'

        self.pktgen_cmd = remote_command(
            self.dataplane.ssh_client, command
        )

    def wait_transmission_done(self):
        if self.pktgen_cmd is None:
            # Pktgen is not running.
            return

        watch_command(self.pktgen_cmd,
                      keyboard_int=lambda: self.pktgen_cmd.send('\x03'))
        status = self.pktgen_cmd.recv_exit_status()
        if status != 0:
            raise RuntimeError('Error running Norman Pktgen')

        # Retrieve the latest stats.
        with tempfile.TemporaryDirectory() as tmp:
            local_stats = f'{tmp}/stats.csv'
            download_file(self.dataplane.host, self.stats_file, local_stats)
            parsed_stats = NormanPktgenStats(local_stats)
            stats_summary = parsed_stats.get_summary()

        self.mean_rx_goodput = stats_summary.get('rx_mean_goodput_mbps', 0)
        self.mean_tx_goodput = stats_summary.get('tx_mean_goodput_mbps', 0)

        self.mean_rx_rate = stats_summary.get('rx_mean_rate_kpps', 0)
        self.mean_tx_rate = stats_summary.get('tx_mean_rate_kpps', 0)

        self.nb_rx_pkts += stats_summary.get('rx_packets', 0)
        self.nb_tx_pkts += stats_summary.get('tx_packets', 0)

        self.nb_rx_bytes += stats_summary.get('rx_bytes', 0)
        self.nb_tx_bytes += stats_summary.get('tx_bytes', 0)

        self.mean_rtt = stats_summary.get('mean_rtt_ns', 0)

        self.pktgen_cmd = None

    @property
    def pcap_path(self):
        return self._pcap_path

    @pcap_path.setter
    def pcap_path(self, pcap_path):
        self.mean_pcap_pkt_size = mean_pkt_size_remote_pcap(
            self.dataplane.ssh_client, pcap_path)

        self._pcap_path = pcap_path

        try:
            parsed_output = output.split(' ')[-2]
            self.mean_pcap_pkt_size = float(parsed_output)
        except IndexError:
            raise RuntimeError(
                f'Error processing remote pcap (capinfos output: "{output}"')

        self._pcap_path = pcap_path

    def clean_stats(self):
        self.nb_rx_pkts = 0
        self.nb_rx_bytes = 0
        self.mean_rx_goodput = 0
        self.mean_rx_rate = 0
        self.nb_tx_pkts = 0
        self.mean_tx_goodput = 0
        self.mean_tx_rate = 0
        self.nb_tx_bytes = 0
        self.mean_rtt = 0

    def close(self):
        pass
