#! /usr/bin/env python3.8

import binascii
import ipaddress
import math
import sys

from itertools import cycle

from scapy.all import IP, TCP, UDP, wrpcap, Ether, Raw


def generate_pcap(nb_pkts, out_pcap, pkt_size, nb_dest):
    sample_pkts = []
    ipv4_len = pkt_size - 14 - 4
    counter_size = math.ceil(math.log2(nb_pkts))
    for i in range(nb_dest):
        src_ip = ipaddress.ip_address('192.168.0.0') + i
        pkt = (
            Ether() /
            IP(dst='192.168.1.1', src=str(src_ip), len=ipv4_len) /
            TCP(dport=80, sport=8080, flags='S')
        )

        # payload = '0' * missing_bytes
        # pkt = pkt/Raw(load=payload)
        sample_pkts.append(pkt)

    pkts = []
    for i, pkt in zip(range(nb_pkts), cycle(sample_pkts)):
        payload = (i).to_bytes(counter_size, byteorder='big')
        missing_bytes = pkt_size - len(pkt) - counter_size - 4  # no CRC
        payload += binascii.unhexlify('00' * missing_bytes)
        pkt = pkt/Raw(load=payload)

        if i == 0:
            print(len(pkt), pkt)
        pkts.append(pkt)

    wrpcap(out_pcap, pkts)


def main():
    if len(sys.argv) != 5:
        print('Usage:', sys.argv[0], 'nb_pkts pkt_size nb_dest output_pcap')
        sys.exit(1)

    nb_pkts = int(sys.argv[1])
    pkt_size = int(sys.argv[2])
    nb_dest = int(sys.argv[3])
    out_pcap = sys.argv[4]

    if nb_dest > 256:
        print('Can only support up to 256 destinations')

    generate_pcap(nb_pkts, out_pcap, pkt_size, nb_dest)


if __name__ == "__main__":
    main()
