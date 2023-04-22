#!/bin/sh
#print the raw bytes from pcap, first 10 pkts
#tcpdump -r $1 -c 4096 -xxn > raw_bytes.txt
# tcpdump -r $1 -c 100 -xxn > raw_bytes.txt
tcpdump -r $1 -xxn > raw_bytes.txt

#add an empty line at the end of the raw_bytes such that
#python script would not miss the last pkt
echo >> raw_bytes.txt

OUTPUT_FILE=${2:-"output.pkt"}

#convert the raw_bytes to verilog ROM content
python3 parse_output_100.py raw_bytes.txt $OUTPUT_FILE

#run Modelsim
#./run_vsim.sh
