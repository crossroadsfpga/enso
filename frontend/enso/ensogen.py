import math
from pathlib import Path
import tempfile

from collections import defaultdict
from csv import DictReader
from fractions import Fraction
from typing import Optional, TextIO, Union

from netexp.helpers import download_file
from netexp.pcap import mean_pkt_size_pcap
from netexp.pktgen import Pktgen

from enso.consts import (
    FPGA_RATELIMIT_CLOCK,
    ENSOGEN_CMD,
    PCAP_GEN_CMD,
    PCAPS_DIR,
)
from enso.enso_nic import EnsoNic


ETHERNET_OVERHEAD = 20 + 4  # Includes CRC.


class EnsoGenStats:
    def __init__(self, file_name: str) -> None:
        self.stats = defaultdict(list)
        self.nb_samples = 0
        with open(file_name, newline="") as f:
            csv_reader = DictReader(f)
            for row in csv_reader:
                self.nb_samples += 1
                for k, v in row.items():
                    self.stats[k].append(int(v))

    def get_summary(self, calculate_tx_mean: bool = False):
        if self.nb_samples < 3:
            raise RuntimeError("Not enough samples to calculate summary")

        summary = {}

        rx_goodput = self.stats["rx_goodput_mbps"]
        rx_pkt_rate = self.stats["rx_pkt_rate_kpps"]

        # Ignore first and last datapoints for RX.
        rx_goodput = [g for g in rx_goodput if g != 0][1:-1]
        rx_pkt_rate = [r for r in rx_pkt_rate if r != 0][1:-1]

        if len(rx_goodput) > 0:
            summary["rx_mean_goodput_mbps"] = sum(rx_goodput) / len(rx_goodput)
            summary["rx_mean_rate_kpps"] = sum(rx_pkt_rate) / len(rx_pkt_rate)

        summary["rx_bytes"] = self.stats["rx_bytes"][-1]
        summary["rx_packets"] = self.stats["rx_packets"][-1]

        if calculate_tx_mean:
            tx_goodput = self.stats["tx_goodput_mbps"]
            tx_pkt_rate = self.stats["tx_pkt_rate_kpps"]

            # Ignore first two and last datapoints for TX.
            tx_goodput = [g for g in tx_goodput if g != 0][2:-1]
            tx_pkt_rate = [r for r in tx_pkt_rate if r != 0][2:-1]

            if len(tx_goodput) < 1:
                raise RuntimeError("Not enough samples to calculate TX mean")

            summary["tx_mean_goodput_mbps"] = sum(tx_goodput) / len(tx_goodput)
            summary["tx_mean_rate_kpps"] = sum(tx_pkt_rate) / len(tx_pkt_rate)

        summary["tx_bytes"] = self.stats["tx_bytes"][-1]
        summary["tx_packets"] = self.stats["tx_packets"][-1]

        if "mean_rtt_ns" in self.stats:
            mean_rtts = self.stats["mean_rtt_ns"][1:-1]
            summary["mean_rtt_ns"] = sum(mean_rtts) / len(mean_rtts)

        return summary


class EnsoGen(Pktgen):
    """Python wrapper for the EnsōGen packet generator."""

    def __init__(
        self,
        nic: EnsoNic,
        core_id: int = 0,
        queues: int = 4,
        single_core: bool = False,
        rtt: bool = False,
        rtt_hist: bool = False,
        rtt_hist_offset: Optional[int] = None,
        rtt_hist_len: Optional[int] = None,
        stats_file: Optional[str] = None,
        hist_file: Optional[str] = None,
        stats_delay: Optional[int] = None,
        pcie_addr: Optional[str] = None,
        log_file: Union[bool, TextIO] = False,
        check_tx_rate=False,
    ) -> None:
        super().__init__()

        self.nic = nic
        self.nic.enable_rr()
        self.nic.fallback_queues = queues

        self._pcap_path = None

        self.core_id = core_id
        self.single_core = single_core
        self.rtt = rtt
        self.rtt_hist = rtt_hist
        self.rtt_hist_offset = rtt_hist_offset
        self.rtt_hist_len = rtt_hist_len
        self.stats_delay = stats_delay

        if pcie_addr is not None and pcie_addr.count(":") == 1:
            pcie_addr = f"0000:{pcie_addr}"  # Add domain.
        self.pcie_addr = pcie_addr

        self.stats_file = stats_file or "stats.csv"
        self.hist_file = hist_file or "hist.csv"

        self.log_file = log_file
        self.check_tx_rate = check_tx_rate

        self.pktgen_cmd = None

        self.clean_stats()

    def set_params(self, pkt_size: int, nb_src: int, nb_dst: int) -> None:
        nb_pkts = nb_src * nb_dst

        pcap_name = f"{nb_pkts}_{pkt_size}_{nb_src}_{nb_dst}.pcap"

        remote_dir_path = Path(self.nic.enso_path)
        pcap_dst = remote_dir_path / Path(PCAPS_DIR) / Path(pcap_name)
        pcap_gen_cmd = remote_dir_path / Path(PCAP_GEN_CMD)
        pcap_gen_cmd = (
            f"{pcap_gen_cmd} {nb_pkts} {pkt_size} {nb_src} {nb_dst} {pcap_dst}"
        )

        pcap_gen_cmd = self.nic.host.run_command(
            pcap_gen_cmd, print_command=self.log_file
        )
        pcap_gen_cmd.watch(stdout=self.log_file, stderr=self.log_file)

        status = pcap_gen_cmd.recv_exit_status()
        if status != 0:
            raise RuntimeError("Error generating pcap")

        self.pcap_path = pcap_dst

    def start(self, throughput: float, nb_pkts: int) -> None:
        """Start packet generation.

        Args:
            throughput: Throughput in bits per second.
            nb_pkts: Number of packets to transmit.
        """
        if self.pcap_path is None:
            raise RuntimeError("No pcap was configured")

        bits_per_pkt = (self.mean_pcap_pkt_size + ETHERNET_OVERHEAD) * 8
        pkts_per_sec = throughput / bits_per_pkt
        flits_per_pkt = math.ceil(self.mean_pcap_pkt_size / 64)

        hardware_rate = pkts_per_sec * flits_per_pkt / FPGA_RATELIMIT_CLOCK

        rate_frac = Fraction(hardware_rate).limit_denominator(1000)

        self.current_throughput = throughput
        self.current_goodput = pkts_per_sec * flits_per_pkt * 512
        self.current_pps = pkts_per_sec
        self.expected_tx_duration = nb_pkts / pkts_per_sec

        # Make sure remote stats file does not exist.
        remove_stats_file = self.nic.host.run_command(
            f"rm -f {self.stats_file}",
            print_command=False,
        )
        remove_stats_file.watch(stdout=self.log_file, stderr=self.log_file)
        status = remove_stats_file.recv_exit_status()
        if status != 0:
            raise RuntimeError(
                f"Error removing remote stats file ({self.stats_file})"
            )

        command = (
            f"sudo {self.nic.enso_path}/{ENSOGEN_CMD}"
            f" {self.pcap_path} {rate_frac.numerator} {rate_frac.denominator}"
            f" --count {nb_pkts}"
            f" --core {self.core_id}"
            f" --queues {self.queues}"
            f" --save {self.stats_file}"
        )

        if self.single_core:
            command += " --single-core"

        if self.rtt:
            command += " --rtt"

        if self.rtt_hist:
            command += f" --rtt-hist {self.hist_file}"

        if self.rtt_hist_offset is not None:
            command += f" --rtt-hist-offset {self.rtt_hist_offset}"

        if self.rtt_hist_len is not None:
            command += f" --rtt-hist-len {self.rtt_hist_len}"

        if self.stats_delay is not None:
            command += f" --stats-delay {self.stats_delay}"

        if self.pcie_addr is not None:
            command += f" --pcie-addr {self.pcie_addr}"

        self.pktgen_cmd = self.nic.host.run_command(
            command,
            print_command=self.log_file,
            pty=True,
        )

    def wait_transmission_done(self) -> None:
        pktgen_cmd = self.pktgen_cmd

        if pktgen_cmd is None:
            # Pktgen is not running.
            return

        pktgen_cmd.watch(
            stdout=self.log_file,
            stderr=self.log_file,
            keyboard_int=lambda: pktgen_cmd.send(b"\x03"),
        )
        status = pktgen_cmd.recv_exit_status()
        if status != 0:
            raise RuntimeError("Error running EnsōGen")

        self.update_stats()

        self.pktgen_cmd = None

    def update_stats(self) -> None:
        # Make sure transmission rate matches specification for sufficiently
        # high rates (i.e., >50Gbps).
        calculate_tx_mean = (
            self.check_tx_rate
            and (self.current_throughput > 50e9)
            and (self.expected_tx_duration > 4)
        )

        # Retrieve the latest stats.
        with tempfile.TemporaryDirectory() as tmp:
            local_stats = f"{tmp}/stats.csv"
            download_file(self.nic.host_name, self.stats_file, local_stats,
                          self.log_file)
            parsed_stats = EnsoGenStats(local_stats)

            stats_summary = parsed_stats.get_summary(calculate_tx_mean)

        # Check TX rate.
        if calculate_tx_mean:
            tx_goodput_mbps = stats_summary["tx_mean_goodput_mbps"]
            tx_goodput_gbps = tx_goodput_mbps / 1e3
            expected_goodput_gbps = self.current_goodput / 1e9

            if abs(tx_goodput_gbps - expected_goodput_gbps) > 1.0:
                raise RuntimeError(
                    f"TX goodput ({tx_goodput_gbps} Gbps) does not match "
                    f"specification ({expected_goodput_gbps} Gbps)"
                )

        self.mean_rx_goodput = stats_summary.get("rx_mean_goodput_mbps", 0)
        self.mean_rx_goodput *= 1_000_000
        self.mean_tx_goodput = stats_summary.get("tx_mean_goodput_mbps", 0)
        self.mean_tx_goodput *= 1_000_000

        self.mean_rx_rate = stats_summary.get("rx_mean_rate_kpps", 0) * 1000
        self.mean_tx_rate = stats_summary.get("tx_mean_rate_kpps", 0) * 1000

        self.nb_rx_pkts += stats_summary.get("rx_packets", 0)
        self.nb_tx_pkts += stats_summary.get("tx_packets", 0)

        self.nb_rx_bytes += stats_summary.get("rx_bytes", 0)
        self.nb_tx_bytes += stats_summary.get("tx_bytes", 0)

        self.mean_rtt = stats_summary.get("mean_rtt_ns", 0)

    @property
    def pcap_path(self) -> None:
        return self._pcap_path

    @pcap_path.setter
    def pcap_path(self, pcap_path) -> None:
        self.mean_pcap_pkt_size = mean_pkt_size_pcap(self.nic.host, pcap_path)
        self._pcap_path = pcap_path

    @property
    def queues(self) -> int:
        return self.nic.fallback_queues

    @queues.setter
    def queues(self, queues) -> None:
        self.nic.fallback_queues = queues

    def get_nb_rx_pkts(self) -> int:
        return self.nb_rx_pkts

    def get_nb_tx_pkts(self) -> int:
        return self.nb_tx_pkts

    def get_rx_throughput(self) -> int:
        return self.mean_rx_goodput + self.mean_rx_rate * 24 * 8

    def get_tx_throughput(self) -> int:
        return self.mean_tx_goodput + self.mean_tx_rate * 24 * 8

    def clean_stats(self) -> None:
        self.nb_rx_pkts = 0
        self.nb_rx_bytes = 0
        self.mean_rx_goodput = 0
        self.mean_rx_rate = 0
        self.nb_tx_pkts = 0
        self.mean_tx_goodput = 0
        self.mean_tx_rate = 0
        self.nb_tx_bytes = 0
        self.mean_rtt = 0

    def stop(self) -> None:
        if self.pktgen_cmd is None:
            # Pktgen is not running.
            return

        if self.pktgen_cmd.exit_status_ready():
            # Pktgen has already exited.
            self.pktgen_cmd = None
            return

        self.pktgen_cmd.send(b"\x03")

        self.pktgen_cmd.watch(stdout=self.log_file, stderr=self.log_file)
        status = self.pktgen_cmd.recv_exit_status()
        if status != 0:
            raise RuntimeError("Error stopping EnsōGen")

        self.update_stats()

        self.pktgen_cmd = None

    def close(self) -> None:
        # No need to close here.
        pass
