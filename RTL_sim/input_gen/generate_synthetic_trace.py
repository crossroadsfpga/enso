#! /usr/bin/env python3

import sys

from scapy.all import IP, TCP, UDP, wrpcap, Ether


def generate_pcap(nb_pkts, out_pcap):
    pkt = Ether()/IP(dst='192.168.1.1')/TCP(dport=80, flags='S')
    pkts = []

    for _ in range(nb_pkts):
        pkts.append(pkt.copy())

    wrpcap(out_pcap, pkts)


def main():
    if len(sys.argv) != 3:
        print('Usage:', sys.argv[0], '[nb pkts] [output pcap]')
        sys.exit(1)

    nb_pkts = int(sys.argv[1])
    out_pcap = sys.argv[2]

    generate_pcap(nb_pkts, out_pcap)


if __name__ == "__main__":
    main()
