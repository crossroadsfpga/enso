# (C) 2001-2019 Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files from any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Intel Program License Subscription 
# Agreement, Intel FPGA IP License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Intel and sold by 
# Intel or its authorized distributors.  Please refer to the applicable 
# agreement for further details.

#Zhipeng Start
source [file join [file dirname [info script]] "my_stats.tcl"]
source [file join [file dirname [info script]] "pcie.tcl"]
#Zhipeng End

source [file join [file dirname [info script]] "altera/sval_top/main.tcl"]

# Function to run a simple series of tests
proc run_test {} {
    puts "--- Turning off packet generation ----"
    puts "--------------------------------------\n"
    stop_pkt_gen

    puts "--------- Enabling loopback ----------"
    puts "--------------------------------------\n"
    loop_on

    puts "--- Wait for RX clock to settle... ---"
    puts "--------------------------------------\n"
    sleep 2

    puts "-------- Printing PHY status ---------"
    puts "--------------------------------------\n"
    chkphy_status

    puts "---- Clearing MAC stats counters -----"
    puts "--------------------------------------\n"
    clear_all_stats

    puts "--------- Sending packets... ---------"
    puts "--------------------------------------\n"
    start_pkt_gen
    sleep 1
    stop_pkt_gen

    puts "----- Reading MAC stats counters -----"
    puts "--------------------------------------\n"
    chkmac_stats

    puts "---------------- Done ----------------\n"
}

# run 10 times to report hit the 390.62 mhz
proc run_10times  {} {
    global BASE_RXPHY
    global ADDR_PHY_RXCLKHZ
    set k 0
    for {set i 0} {$i < 10} {incr i} {
           loop_off
           tmpcntrst_on
           tmpcntrst_off
           start_pkt_gen
           sleep 1
           stop_pkt_gen

    set rxclk  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_RXCLKHZ ]]
       if {$rxclk == 39062} {
              puts "      RXCLK           :$rxclk  (KHZ) -- LUCKY   "
              incr k
          } else {
              puts "      RXCLK           :$rxclk  (KHZ) "
          }
           sleep 1

        }
    puts "      Lucky hit           : $k  "
    return $rxclk
}

# run 10 times to report hit the 390.62 mhz
proc run_extcnt_err  {} {
    global BASE_RXPHY
    global ADDR_PHY_CNTERRO
    set j 0
    set k 0
    for {set i 0} {$i < 10} {incr i} {
           loop_off
           tmpcntrst_on
           tmpcntrst_off
           start_pkt_gen
           sleep 1
           stop_pkt_gen

    set extcnterr  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_CNTERRO ]]
       if {$extcnterr == 0} {
              puts "      rx_sop=rx_eop=tx_sop=tx_eop and rx_err_cnt==0  "
              incr j
          } else {
              puts "    (rx_err_cntD!=0),(tx_sop_cntD!=rx_sop_cntD),(tx_sop_cntD!=tx_eop_cntD),(rx_sop_cntD!=rx_eop_cntD)==$extcnterr"
              incr k
          }
           sleep 1

        }
    puts "   The number of no error      : $j  "
    puts "   The number of error happen  : $k  "
}

proc run_txsftrst_cnt_err  {} {
    global BASE_RXPHY
    global ADDR_PHY_CNTERRO
    global ADDR_PHY_PMACFG
    global ADDR_PHY_WORDLCK
    global ADDR_PHY_PMALOOP
    global ADDR_PHY_PHYFSEL
    global ADDR_PHY_PHYFLAG
    global ADDR_PHY_FREQLOCK
    global ADDR_PHY_CLKMACOK
    global ADDR_PHY_FRMERROR
    global ADDR_PHY_CLRFRMER
    global ADDR_PHY_SFTRESET
    global ADDR_PHY_FALIGNED
    global ADDR_PHY_ERINJRST
    global ADDR_PHY_AMLOCK
    global ADDR_PHY_LNDSKWED
    global ADDR_PHY_PCSVLAN0
    global ADDR_PHY_PCSVLAN1
    global ADDR_PHY_PCSVLAN2
    global ADDR_PHY_PCSVLAN3

    set j 0
    set k 0
    for {set i 0} {$i < 100} {incr i} {

           #loop_off
           tmpcntrst_on
           tmpcntrst_off
              reg_write    $BASE_RXPHY $ADDR_PHY_CLRFRMER 1
              reg_write    $BASE_RXPHY $ADDR_PHY_CLRFRMER 0
           txsft_rst_on
                set bsit2  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_PMACFG ]]
                puts " 1st tx soft rst reg bit 2 = $bsit2 \n"
           txsft_rst_off
                set bsit2  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_PMACFG ]]
                puts " 2nd tx soft rst reg bit 2 = $bsit2 \n"

           wait_for_phy_lock
           #tmpcntrst_on
           #tmpcntrst_off

           sleep 1
           start_pkt_gen
           sleep 1
           stop_pkt_gen
           sleep 1

    set extcnterr  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_CNTERRO ]]
       if {$extcnterr == 0} {
              puts "      rx_sop=rx_eop=tx_sop=tx_eop and rx_err_cnt==0  "
              set pmacfg  [ reg_read $BASE_RXPHY $ADDR_PHY_PMACFG ]
              set wordlk  [ reg_read    $BASE_RXPHY $ADDR_PHY_WORDLCK ]
              set pmaloop [ reg_read    $BASE_RXPHY $ADDR_PHY_PMALOOP ]
              set phyfsel [ reg_read    $BASE_RXPHY $ADDR_PHY_PHYFSEL ]
              set phyflag [ reg_read    $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
              set freqlock [ reg_read    $BASE_RXPHY $ADDR_PHY_FREQLOCK ]
              set clkmacok  [ reg_read    $BASE_RXPHY $ADDR_PHY_CLKMACOK ] 
              set frmerror  [ reg_read    $BASE_RXPHY $ADDR_PHY_FRMERROR ]
              set clrfrmer  [ reg_read    $BASE_RXPHY $ADDR_PHY_CLRFRMER ]
              set sftreset  [ reg_read    $BASE_RXPHY $ADDR_PHY_SFTRESET ]
              set faligned  [ reg_read    $BASE_RXPHY $ADDR_PHY_FALIGNED ]
              set erinjrst  [ reg_read    $BASE_RXPHY $ADDR_PHY_ERINJRST ]
              set amlock    [ reg_read    $BASE_RXPHY $ADDR_PHY_AMLOCK ]
              set lndskwed  [ reg_read    $BASE_RXPHY $ADDR_PHY_LNDSKWED ]
              set pcsvlan0  [ reg_read    $BASE_RXPHY $ADDR_PHY_PCSVLAN0 ]
              set pcsvlan1  [ reg_read    $BASE_RXPHY $ADDR_PHY_PCSVLAN1 ]
              set pcsvlan2  [ reg_read    $BASE_RXPHY $ADDR_PHY_PCSVLAN2 ]
              set pcsvlan3  [ reg_read    $BASE_RXPHY $ADDR_PHY_PCSVLAN3 ]
              puts " phy_config x10 : $pmacfg "
              puts " word_lock x12 : $wordlk "
              puts " pmaloop x13 : $pmaloop "
              puts " phyfsel x14 : $phyfsel "
              puts " phyflag x15 : $phyflag "
              puts " freqlock x21 : $freqlock "
              puts " clkmacok x22 : $clkmacok "
              puts " frmerror x23 : $frmerror "
              puts " clrfrmer x24 : $clrfrmer "
              puts " sftreset x25 : $sftreset "
              puts " faligned x26 : $faligned "
              puts " erinjrst x27 : $erinjrst "
              puts " amlock x28 : $amlock "
              puts " lndskwed x29 : $lndskwed "
              puts " pcsvlan0 x30 : $pcsvlan0 "
              puts " pcsvlan1 x31 : $pcsvlan1 "
              puts " pcsvlan2 x32 : $pcsvlan2 "
              puts " pcsvlan3 x33 : $pcsvlan3 "
              incr j
          } else {
              set pmacfg  [ reg_read $BASE_RXPHY $ADDR_PHY_PMACFG ]
              set wordlk  [ reg_read    $BASE_RXPHY $ADDR_PHY_WORDLCK ]
              set pmaloop [ reg_read    $BASE_RXPHY $ADDR_PHY_PMALOOP ]
              set phyfsel [ reg_read    $BASE_RXPHY $ADDR_PHY_PHYFSEL ]
              set phyflag [ reg_read    $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
              set freqlock [ reg_read    $BASE_RXPHY $ADDR_PHY_FREQLOCK ]
              set clkmacok  [ reg_read    $BASE_RXPHY $ADDR_PHY_CLKMACOK ] 
              set frmerror  [ reg_read    $BASE_RXPHY $ADDR_PHY_FRMERROR ]
              set clrfrmer  [ reg_read    $BASE_RXPHY $ADDR_PHY_CLRFRMER ]
              set sftreset  [ reg_read    $BASE_RXPHY $ADDR_PHY_SFTRESET ]
              set faligned  [ reg_read    $BASE_RXPHY $ADDR_PHY_FALIGNED ]
              set erinjrst  [ reg_read    $BASE_RXPHY $ADDR_PHY_ERINJRST ]
              set amlock    [ reg_read    $BASE_RXPHY $ADDR_PHY_AMLOCK ]
              set lndskwed  [ reg_read    $BASE_RXPHY $ADDR_PHY_LNDSKWED ]
              set pcsvlan0  [ reg_read    $BASE_RXPHY $ADDR_PHY_PCSVLAN0 ]
              set pcsvlan1  [ reg_read    $BASE_RXPHY $ADDR_PHY_PCSVLAN1 ]
              set pcsvlan2  [ reg_read    $BASE_RXPHY $ADDR_PHY_PCSVLAN2 ]
              set pcsvlan3  [ reg_read    $BASE_RXPHY $ADDR_PHY_PCSVLAN3 ]
              puts " phy_config x10 : $pmacfg "
              puts " word_lock x12 : $wordlk "
              puts " pmaloop x13 : $pmaloop "
              puts " phyfsel x14 : $phyfsel "
              puts " phyflag x15 : $phyflag "
              puts " freqlock x21 : $freqlock "
              puts " clkmacok x22 : $clkmacok "
              puts " frmerror x23 : $frmerror "
              puts " clrfrmer x24 : $clrfrmer "
              puts " sftreset x25 : $sftreset "
              puts " faligned x26 : $faligned "
              puts " erinjrst x27 : $erinjrst "
              puts " amlock x28 : $amlock "
              puts " lndskwed x29 : $lndskwed "
              puts " pcsvlan0 x30 : $pcsvlan0 "
              puts " pcsvlan1 x31 : $pcsvlan1 "
              puts " pcsvlan2 x32 : $pcsvlan2 "
              puts " pcsvlan3 x33 : $pcsvlan3 "

              puts "    (rx_err_cntD!=0),(tx_sop_cntD!=rx_sop_cntD),(tx_sop_cntD!=tx_eop_cntD),(rx_sop_cntD!=rx_eop_cntD)==$extcnterr"
              incr k

              return 0
          }
        }
    puts " Tx Soft reset test on/off, the number of no error      : $j  "
    puts " Tx Soft reset test on/off, the number of error happen  : $k  "
}


proc run_rxsftrst_cnt_err  {} {
    global BASE_RXPHY
    global ADDR_PHY_CNTERRO
    set j 0
    set k 0
    for {set i 0} {$i < 50 } {incr i} {

           loop_on
           tmpcntrst_on
           tmpcntrst_off
           rxsft_rst_on
           rxsft_rst_off
           wait_for_phy_lock
           sleep 1
           start_pkt_gen
           sleep 1
           stop_pkt_gen
           sleep 1

    set extcnterr  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_CNTERRO ]]
       if {$extcnterr == 0} {
              puts "      rx_sop=rx_eop=tx_sop=tx_eop and rx_err_cnt==0  "
              incr j
          } else {
              puts "    (rx_err_cntD!=0),(tx_sop_cntD!=rx_sop_cntD),(tx_sop_cntD!=tx_eop_cntD),(rx_sop_cntD!=rx_eop_cntD)==$extcnterr"
              incr k
          }
        }
    puts " Rx Soft reset test on/off, the number of no error      : $j  "
    puts " Rx Soft reset test on/off, the number of error happen  : $k  "
}

proc run_eiosyssftrst_cnt_err  {} {
    global BASE_RXPHY
    global ADDR_PHY_CNTERRO
    set j 0
    set k 0
    for {set i 0} {$i < 50} {incr i} {

           loop_on
           tmpcntrst_on
           tmpcntrst_off
           eiosys_rst_on
           eiosys_rst_off
           sleep 1
           start_pkt_gen
           sleep 1
           stop_pkt_gen
           sleep 1

    set extcnterr  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_CNTERRO ]]
       if {$extcnterr == 0} {
              puts "      rx_sop=rx_eop=tx_sop=tx_eop and rx_err_cnt==0  "
              incr j
          } else {
              puts "    (rx_err_cntD!=0),(tx_sop_cntD!=rx_sop_cntD),(tx_sop_cntD!=tx_eop_cntD),(rx_sop_cntD!=rx_eop_cntD)==$extcnterr"
              incr k
          }
        }
    puts " EioSys Soft reset test on/off, the number of no error      : $j  "
    puts " EioSys Soft reset test on/off, the number of error happen  : $k  "
}


proc run_internal_serial_loopbk_pcs_am_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_FALIGNED
    set j 0
    set k 0
    for {set i 0} {$i < 3} {incr i} {

           loop_on
           rxsft_rst_on
           rxsft_rst_off
           wait_for_phy_lock

           set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
           set locked [ expr ($locked & 0x01 )]

       if {$locked == 1} {
              puts "  ============================================================"
              puts "  ===== RX PCS get alignment lock  ==========================="
              puts "  ===== run_internal_serial_loopbk_pcs_am_chk TEST PASSED ===="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  RX PCS does not get alignment lock  ========================"
              puts "  ===== run_internal_serial_loopbk_pcs_am_chk TEST FAILED ===="
              puts "  ============================================================"
          }
        }
}


proc run_external_serial_loopbk_pcs_am_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_FALIGNED
    set j 0
    set k 0
    for {set i 0} {$i < 3} {incr i} {

           loop_off
           rxsft_rst_on
           rxsft_rst_off
           wait_for_phy_lock

           set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
           set locked [ expr ($locked & 0x01 )]

       if {$locked == 1} {
              puts "  ============================================================"
              puts "  ===== RX PCS get alignment lock  ==========================="
              puts "  ===== run_internal_serial_loopbk_pcs_am_chk TEST PASSED ===="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  RX PCS does not get alignment lock  ========================"
              puts "  ===== run_internal_serial_loopbk_pcs_am_chk TEST FAILED ===="
              puts "  ============================================================"
          }
        }
}

proc run_internal_serial_loopbk_rxfreq_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_RXCLKHZ
    
    for {set i 0} {$i < 3} {incr i} {

           loop_on
           rxsft_rst_on
           rxsft_rst_off
           sleep 5
           set rxclk  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_RXCLKHZ ]]
           

       if {$rxclk == 39060 | $rxclk == 39061  | $rxclk == 39062  | $rxclk == 39063 |  $rxclk == 39064 } {
              puts "  ============================================================"
              puts "  ===== RX Core Clock Freq Test : $rxclk   ==================="
              puts "  ===== run_internal_serial_loopbk_rxfreq_chk TEST PASSED ===="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  ===== RX Core Clock Freq Test : $rxclk   ==================="
              puts "  ===== run_internal_serial_loopbk_rxfreq_chk TEST FAILED ===="
              puts "  ============================================================"
          }
        }
}


proc run_exnternal_serial_loopbk_rxfreq_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_RXCLKHZ
    
    for {set i 0} {$i < 3} {incr i} {

           loop_off
           rxsft_rst_on
           rxsft_rst_off
           sleep 5
           set rxclk  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_RXCLKHZ ]]
           

       if {$rxclk == 39060 | $rxclk == 39061  | $rxclk == 39062  | $rxclk == 39063 |  $rxclk == 39064 } {
              puts "  ============================================================"
              puts "  ===== RX Core Clock Freq Test : $rxclk   ==================="
              puts "  ===== run_internal_serial_loopbk_rxfreq_chk TEST PASSED ===="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  ===== RX Core Clock Freq Test : $rxclk   ==================="
              puts "  ===== run_internal_serial_loopbk_rxfreq_chk TEST FAILED ===="
              puts "  ============================================================"
          }
        }
}

proc run_internal_serial_loopbk_txfreq_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_TXCLKHZ
    
    for {set i 0} {$i < 3} {incr i} {

           loop_on
           txsft_rst_on
           txsft_rst_off
           sleep 5
           set txclk  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_TXCLKHZ ]]
           

       if {$txclk == 39060 | $txclk == 39061  | $txclk == 39062  | $txclk == 39063 |  $txclk == 39064 } {
              puts "  ============================================================"
              puts "  ===== TX Core Clock Freq Test : $txclk   ==================="
              puts "  ===== run_internal_serial_loopbk_txfreq_chk TEST PASSED ===="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  ===== TX Core Clock Freq Test : $txclk   ==================="
              puts "  ===== run_internal_serial_loopbk_txfreq_chk TEST FAILED ===="
              puts "  ============================================================"
          }
        }
}


proc run_external_serial_loopbk_txfreq_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_TXCLKHZ
    
    for {set i 0} {$i < 3} {incr i} {

           loop_off
           txsft_rst_on
           txsft_rst_off
           sleep 5
           set txclk  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_TXCLKHZ ]]
           

       if {$txclk == 39060 | $txclk == 39061  | $txclk == 39062  | $txclk == 39063 |  $txclk == 39064 } {
              puts "  ============================================================"
              puts "  ===== TX Core Clock Freq Test : $txclk   ==================="
              puts "  ===== run_internal_serial_loopbk_txfreq_chk TEST PASSED ===="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  ===== TX Core Clock Freq Test : $txclk   ==================="
              puts "  ===== run_internal_serial_loopbk_txfreq_chk TEST FAILED ===="
              puts "  ============================================================"
          }
        }
}

proc run_internal_serial_loopbk_reffreq_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_RFCLKHZ
    
    for {set i 0} {$i < 3} {incr i} {

           loop_on
           rxsft_rst_on
           rxsft_rst_off
           sleep 5
           set refclk  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_RFCLKHZ ]]
           

       if {$refclk == 64451 | $refclk == 64452  | $refclk == 64453  | $refclk == 64454 |  $refclk == 64455 } {
              puts "  ============================================================"
              puts "  ===== REFCLK Clock Freq Test : $refclk   ==================="
              puts "  ===== run_internal_serial_loopbk_reffreq_chk TEST PASSED ==="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  ===== REFCLK Core Clock Freq Test : $refclk ================"
              puts "  ===== run_internal_serial_loopbk_reffreq_chk TEST FAILED ==="
              puts "  ============================================================"
          }
        }
}


proc run_external_serial_loopbk_reffreq_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_RFCLKHZ
    
    for {set i 0} {$i < 3} {incr i} {

           loop_off
           rxsft_rst_on
           rxsft_rst_off
           sleep 5
           set refclk  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_RFCLKHZ ]]
           

       if {$refclk == 64451 | $refclk == 64452  | $refclk == 64453  | $refclk == 64454 |  $refclk == 64455 } {
              puts "  ============================================================"
              puts "  ===== REFCLK Clock Freq Test : $refclk   ==================="
              puts "  ===== run_internal_serial_loopbk_reffreq_chk TEST PASSED ==="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  ===== REFCLK Core Clock Freq Test : $refclk ================"
              puts "  ===== run_internal_serial_loopbk_reffreq_chk TEST FAILED ==="
              puts "  ============================================================"
          }
        }
}


proc run_internal_serial_los_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_FALIGNED
    set j 0
    set k 0
    for {set i 0} {$i < 50} {incr i} {
           loop_on
           rxsft_rst_on
           rxsft_rst_off
           loop_off
           wait_for_phy_unlock

           loop_on
           wait_for_phy_lock

           set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
           set locked [ expr ($locked & 0x01 )]
       if {$locked == 1} {
              incr j
       } else {
              incr k
       }
    }
 
       if {$j == 50} {
              puts "  ============================================================"
              puts "  ===== RX LOS Test -- 50 run with $j OK    =================="
              puts "  ===== RX LOS Test -- 50 run with $k Error   ================"
              puts "  ===== run_internal_serial_los_chk TEST PASSED =============="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  ===== RX LOS Test -- 50 run with $j OK    =================="
              puts "  ===== RX LOS Test -- 50 run with $k Error  ================="
              puts "  ===== run_internal_serial_los_chk TEST FAILED =============="
              puts "  ============================================================"
          }

}


proc run_internal_eiosyssftrst_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_FALIGNED
    global ADDR_PHY_CLKMACOK
    global ADDR_PHY_WORDLCK
    global ADDR_PHY_FREQLOCK
    global ADDR_PHY_PHYFSEL
    global ADDR_PHY_PHYFLAG
    set j 0
    set k 0
    for {set i 0} {$i < 50} {incr i} {

           loop_on

           eiosys_rst_on
           sleep 1
           wait_for_phy_unlock

           eiosys_rst_off
           sleep 1
           wait_for_phy_lock

           set pllstat [ reg_read $BASE_RXPHY $ADDR_PHY_CLKMACOK ]
           set wdlock [ reg_read $BASE_RXPHY $ADDR_PHY_WORDLCK ]
           set freqlock [ reg_read $BASE_RXPHY $ADDR_PHY_FREQLOCK ]
#           reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 0
#           set pmatxfull   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
#           reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 1
#           set pmatxempty   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
#           reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 2
#           set pmatxpfull   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
#           reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 3
#           set pmatxpempty  [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
#           reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 4
#           set pmarxfull   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
#           reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 5
#           set pmarxempty   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
#           reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 6
#           set pmarxpfull   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
#           reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 7
#           set pmarxpempty  [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]

           set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
           set locked [ expr ($locked & 0x01 )]

       if {$locked == 1} {
              incr j
              puts "  ===== RXRST GOOD LOCK  $locked  PHY_CLK: $pllstat WORD_LOCK: $wdlock FREQ_LOCK:$freqlock  ============"
#              puts "  ===== RXRST GOOD LOCK  PMA TX FIFO txFull:$pmatxfull txEmpty:$pmatxempty txPartiallyFull:$pmatxpfull txPartialEmpty:$pmatxpempty  ============"
#              puts "  ===== RXRST GOOD LOCK  PMA RX FIFO rxFull:$pmarxfull rxEmpty:$pmarxempty rxPartiallyFull:$pmarxpfull rxPartialEmpty:$pmarxpempty  ============"
       } else {
              incr k
              puts "  ===== RXRST NO LOCK  $locked  PHY_CLK: $pllstat WORD_LOCK: $wdlock FREQ_LOCK:$freqlock ============="
#              puts "  ===== RXRST NO LOCK  PMA TX FIFO txFull:$pmatxfull txEmpty:$pmatxempty txPartiallyFull:$pmatxpfull txPartialEmpty:$pmatxpempty  ============"
#              puts "  ===== RXRST NO LOCK  PMA RX FIFO rxFull:$pmarxfull rxEmpty:$pmarxempty rxPartiallyFull:$pmarxpfull rxPartialEmpty:$pmarxpempty  ============"

#            rxsft_rst_on
#            sleep 1
#            wait_for_phy_unlock
#            rxsft_rst_off
#            sleep 1
#            wait_for_phy_lock
#              reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 4
#              set pllstat [ reg_read $BASE_RXPHY $ADDR_PHY_CLKMACOK ]
#              set wdlock [ reg_read $BASE_RXPHY $ADDR_PHY_WORDLCK ]
#              set freqlock [ reg_read $BASE_RXPHY $ADDR_PHY_FREQLOCK ]
#              set pmarxfull   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
#              reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 2
#              set pmatxpfull   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
#              set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
#              set locked [ expr ($locked & 0x01 )]
#              puts "  ===== RXRST NO LOCK  $locked  PHY_CLK: $pllstat WORD_LOCK: $wdlock FREQ_LOCK:$freqlock PMARXFIFO: $pmarxfull PMATXFIFO: $pmatxpfull ============"
#
#            return -1
       }
    }
 
       if {$j == 50} {
              puts "  ============================================================"
              puts "  =====  SYS RST Test -- 50 run with $j OK    ================"
              puts "  =====  SYS RST Test -- 50 run with $k Error   =============="
              puts "  ===== run_internal_eiosyssftrst_chk TEST PASSED ============"
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  =====  SYS RST Test -- 50 run with $j OK    ================"
              puts "  =====  SYS RST Test -- 50 run with $k Error  ==============="
              puts "  ===== run_internal_eiosyssftrst_chk TEST FAILED ============"
              puts "  ============================================================"
          }

}
## quickway to make fail happen: eiosys_rst_on; after 100; eiosys_rst_off; after 100; reg_read 0x312
##                             : reg_read 0x312
##                             : eiosys_rst_on
##                             : eiosys_rst_off; after 100; reg_read 0x312


proc run_external_eiosyssftrst_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_FALIGNED
    global ADDR_PHY_CLKMACOK
    global ADDR_PHY_WORDLCK
    global ADDR_PHY_FREQLOCK
    global ADDR_PHY_PHYFSEL
    global ADDR_PHY_PHYFLAG
    set j 0
    set k 0
    for {set i 0} {$i < 50} {incr i} {

           loop_off

           eiosys_rst_on
           sleep 1
           wait_for_phy_unlock

           eiosys_rst_off
           sleep 1
           wait_for_phy_lock

              reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 4
           set pllstat [ reg_read $BASE_RXPHY $ADDR_PHY_CLKMACOK ]
           set wdlock [ reg_read $BASE_RXPHY $ADDR_PHY_WORDLCK ]
           set freqlock [ reg_read $BASE_RXPHY $ADDR_PHY_FREQLOCK ]
           set pmaff0   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
           reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 2
           set pmaff1   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
           set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
           set locked [ expr ($locked & 0x01 )]
       if {$locked == 1} {
              incr j
              puts "  ===== RXRST GOOD LOCK  $locked  PHY_CLK: $pllstat WORD_LOCK: $wdlock FREQ_LOCK:$freqlock PMARXFIFO: $pmaff0 PMATXFIFO: $pmaff1 ============"
       } else {
              incr k
              puts "  ===== RXRST GOOD LOCK  $locked  PHY_CLK: $pllstat WORD_LOCK: $wdlock FREQ_LOCK:$freqlock PMARXFIFO: $pmaff0 PMATXFIFO: $pmaff1 ============"

            rxsft_rst_on
            sleep 1
            wait_for_phy_unlock
            rxsft_rst_off
            sleep 1
            wait_for_phy_lock
              reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 4
              set pllstat [ reg_read $BASE_RXPHY $ADDR_PHY_CLKMACOK ]
              set wdlock [ reg_read $BASE_RXPHY $ADDR_PHY_WORDLCK ]
              set freqlock [ reg_read $BASE_RXPHY $ADDR_PHY_FREQLOCK ]
              set pmaff0   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
              reg_write    $BASE_RXPHY $ADDR_PHY_PHYFSEL 2
              set pmaff1   [ reg_read $BASE_RXPHY $ADDR_PHY_PHYFLAG ]
              set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
              set locked [ expr ($locked & 0x01 )]
              puts "  ===== RXRST GOOD LOCK  $locked  PHY_CLK: $pllstat WORD_LOCK: $wdlock FREQ_LOCK:$freqlock PMARXFIFO: $pmaff0 PMATXFIFO: $pmaff1 ============"

       }
    }
 
       if {$j == 50} {
              puts "  =========================================================="
              puts "  =====  SYS RST Test -- 50 run with $j OK    =============="
              puts "  =====  SYS RST Test -- 50 run with $k Error   ============"
              puts "  ===== run_external_eiosyssftrst_chk TEST PASSED =========="
              puts "  =========================================================="
          } else {
              puts "  =========================================================="
              puts "  =====  SYS RST Test -- 50 run with $j OK    =============="
              puts "  =====  SYS RST Test -- 50 run with $k Error  ============="
              puts "  ===== run_external_eiosyssftrst_chk TEST FAILED =========="
              puts "  =========================================================="
          }

}


proc run_internal_txsftrst_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_FALIGNED
    set j 0
    set k 0
    for {set i 0} {$i < 50} {incr i} {

           loop_on

           txsft_rst_on
           sleep 1
           wait_for_phy_unlock

           txsft_rst_off
           wait_for_phy_lock

           set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
           set locked [ expr ($locked & 0x01 )]
       if {$locked == 1} {
              incr j
       } else {
              puts "  ===== RST Test --  PROBLEM HAPPEN $locked============"
              incr k
       }
    }
 
       if {$j == 50} {
              puts "  ============================================================"
              puts "  ===== TX SOFT RST Test -- 50 run with $j OK    =============="
              puts "  ===== TX SOFT RST Test -- 50 run with $k Error   ============"
              puts "  ===== run_txsftrst_chk TEST PASSED ====================="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  ===== TX SOFT RST Test -- 50 run with $j OK    =============="
              puts "  ===== TX SOFT RST Test -- 50 run with $k Error  ============="
              puts "  ===== run_txsftrst_chk TEST FAILED ====================="
              puts "  ============================================================"
          }

}

proc run_external_txsftrst_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_FALIGNED
    set j 0
    set k 0
    for {set i 0} {$i < 50} {incr i} {

           loop_off

           txsft_rst_on
           sleep 1
           wait_for_phy_unlock

           txsft_rst_off
           wait_for_phy_lock

           set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
           set locked [ expr ($locked & 0x01 )]
       if {$locked == 1} {
              incr j
       } else {
              puts "  ===== RST Test --  PROBLEM HAPPEN $locked============"
              incr k
       }
    }
 
       if {$j == 50} {
              puts "  ============================================================"
              puts "  ===== TX SOFT RST Test -- 50 run with $j OK    =============="
              puts "  ===== TX SOFT RST Test -- 50 run with $k Error   ============"
              puts "  ===== run_txsftrst_chk TEST PASSED ====================="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  ===== TX SOFT RST Test -- 50 run with $j OK    =============="
              puts "  ===== TX SOFT RST Test -- 50 run with $k Error  ============="
              puts "  ===== run_txsftrst_chk TEST FAILED ====================="
              puts "  ============================================================"
          }

}


proc run_internal_rxsftrst_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_FALIGNED
    set j 0
    set k 0
    for {set i 0} {$i < 50} {incr i} {

           loop_on

           rxsft_rst_on
           sleep 1
           wait_for_phy_unlock

           rxsft_rst_off
           wait_for_phy_lock

           set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
           set locked [ expr ($locked & 0x01 )]
       if {$locked == 1} {
              incr j
       } else {
              puts "  ===== RST Test --  PROBLEM HAPPEN $locked============"
              incr k
       }
    }
 
       if {$j == 50} {
              puts "  ============================================================"
              puts "  ===== RX SOFT RST Test -- 50 run with $j OK    =============="
              puts "  ===== RX SOFT RST Test -- 50 run with $k Error   ============"
              puts "  ===== run_rxsftrst_chk TEST PASSED ====================="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  ===== RX SOFT RST Test -- 50 run with $j OK    =============="
              puts "  ===== RX SOFT RST Test -- 50 run with $k Error  ============="
              puts "  ===== run_rxsftrst_chk TEST FAILED ====================="
              puts "  ============================================================"
          }

}



proc run_external_rxsftrst_chk  {} {
    global BASE_RXPHY
    global ADDR_PHY_FALIGNED
    set j 0
    set k 0
    for {set i 0} {$i < 50} {incr i} {

           loop_off

           rxsft_rst_on
           sleep 1
           wait_for_phy_unlock

           rxsft_rst_off
           wait_for_phy_lock

           set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
           set locked [ expr ($locked & 0x01 )]
       if {$locked == 1} {
              incr j
       } else {
              puts "  ===== RST Test --  PROBLEM HAPPEN $locked============"
              incr k
       }
    }
 
       if {$j == 50} {
              puts "  ============================================================"
              puts "  ===== RX SOFT RST Test -- 50 run with $j OK    =============="
              puts "  ===== RX SOFT RST Test -- 50 run with $k Error   ============"
              puts "  ===== run_rxsftrst_chk TEST PASSED ====================="
              puts "  ============================================================"
          } else {
              puts "  ============================================================"
              puts "  ===== RX SOFT RST Test -- 50 run with $j OK    =============="
              puts "  ===== RX SOFT RST Test -- 50 run with $k Error  ============="
              puts "  ===== run_rxsftrst_chk TEST FAILED ====================="
              puts "  ============================================================"
          }

}



