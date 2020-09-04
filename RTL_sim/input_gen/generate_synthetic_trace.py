#! /usr/bin/env python3

import sys

from scapy.all import IP, TCP, UDP, wrpcap, Ether, Raw


def generate_pcap(nb_pkts, out_pcap, pig=False):
    pkt = Ether()/IP(dst='192.168.1.1')/TCP(dport=80, flags='S')
    if pig:
        data = 'Pigs can also fly!'
        pkt = pkt/Raw(load=data)
    pkts = []

    for _ in range(nb_pkts):
        pkts.append(pkt.copy())

    wrpcap(out_pcap, pkts)


def main():
    argv = sys.argv[:]
    pig = False
    if '--pig' in argv:
        pig = True
        argv.remove('--pig')

    if len(argv) != 3:
        print('Usage:', sys.argv[0], 'nb_pkts output_pcap [--pig]')
        sys.exit(1)

    nb_pkts = int(argv[1])
    out_pcap = argv[2]

    generate_pcap(nb_pkts, out_pcap, pig=pig)


if __name__ == "__main__":
    main()
