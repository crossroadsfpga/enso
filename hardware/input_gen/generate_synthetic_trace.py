#! /usr/bin/env python3.8

import binascii
import ipaddress
import math
import os
import sys

from itertools import cycle

from tqdm import tqdm
from scapy.all import IP, TCP, Ether, Raw, bytes_encode, PcapWriter, DLT_EN10MB


# Bypassing scapy's awfully slow wrpcap, have to use raw packets as input
# To get a raw packet from a scapy packet use `bytes_encode(pkt)`.
def wrpcap(pcap_name, raw_packets):
    with PcapWriter(pcap_name, linktype=DLT_EN10MB) as pkt_wr:
        for raw_pkt in raw_packets:
            if not pkt_wr.header_present:
                pkt_wr._write_header(raw_pkt)
            pkt_wr._write_packet(raw_pkt)


def generate_pcap(nb_pkts, out_pcap, pkt_size, nb_src, nb_dest):
    sample_pkts = []
    ipv4_len = pkt_size - 14 - 4
    counter_size = math.ceil(math.log2(nb_pkts))
    for i in range(nb_dest):
        dst_ip = ipaddress.ip_address('192.168.0.0') + i
        src_offset = int(i/(nb_dest/nb_src))
        src_ip = ipaddress.ip_address('192.168.0.0') + src_offset
        pkt = (
            Ether() /
            IP(dst=str(dst_ip), src=str(src_ip), len=ipv4_len) /
            TCP(dport=80, sport=8080, flags='S')
        )

        missing_bytes = pkt_size - len(pkt) - 4  # no CRC
        payload = binascii.unhexlify('00' * missing_bytes)
        pkt = pkt/Raw(load=payload)
        pkt = bytes_encode(pkt)
        sample_pkts.append(pkt)

    def pkt_gen():
        for _, pkt in zip(tqdm(range(nb_pkts)), cycle(sample_pkts)):
            yield pkt

    wrpcap(out_pcap, pkt_gen())


def main():
    if len(sys.argv) != 6:
        print('Usage:', sys.argv[0],
              'nb_pkts pkt_size nb_src nb_dest output_pcap')
        sys.exit(1)

    nb_pkts = int(sys.argv[1])
    pkt_size = int(sys.argv[2])
    nb_src = int(sys.argv[3])
    nb_dest = int(sys.argv[4])
    out_pcap = sys.argv[5]

    try:
        os.remove(out_pcap)
    except OSError:
        pass

    generate_pcap(nb_pkts, out_pcap, pkt_size, nb_src, nb_dest)


if __name__ == "__main__":
    main()
