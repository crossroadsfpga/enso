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


set ver 0.1s10c2e

 set ADDR_KR4_BASECTRL    0xb0
 set ADDR_KR4_BASESTAT    0xb1
 set ADDR_KR4_FECCTRL0    0xb2
 set ADDR_KR4_FECCTRL1    0xb5
 set ADDR_KR4_FECCTRL2    0xb8
 set ADDR_KR4_FECCTRL3    0xbb
 set ADDR_KR4_ANCTRL      0xc0
 set ADDR_KR4_ANSTAT      0xc2
 set ADDR_KR4_ANOVRD      0xcc
 set ADDR_KR4_LTCTRL      0xd0
 set ADDR_KR4_LTCTL2      0xd1
 set ADDR_KR4_LTSTAT      0xd2
 set ADDR_KR4_LTBERT      0xd3
 set ADDR_KR4_LTSET0      0xd5
 set ADDR_KR4_LTSET1      0xe2
 set ADDR_KR4_LTSET2      0xe6
 set ADDR_KR4_LTSET3      0xea

proc Get_value_in_variable {uservar} {
    global $uservar
    set userval [set $uservar]
    return $userval
}

proc rst_pcs {} {
    global BASE_RXPHY
    global ADDR_PHY_PMACFG

    reg_write   $BASE_RXPHY $ADDR_PHY_PMACFG 1
    reg_write   $BASE_RXPHY $ADDR_PHY_PMACFG 0
}

proc kr_restart {} {
  global BASE_KR4
  global ADDR_KR4_BASECTRL

  set reg [reg_read   $BASE_KR4 $ADDR_KR4_BASECTRL]
  reg_write $BASE_KR4 $ADDR_KR4_BASECTRL [expr $reg | 0x7]
}

proc an_disable {} {
  global BASE_KR4
  global ADDR_KR4_ANCTRL

  set an_c0 [reg_read    $BASE_KR4 $ADDR_KR4_ANCTRL]
  set an_c0 [expr $an_c0 & 0xFE]
  reg_write   $BASE_KR4 $ADDR_KR4_ANCTRL $an_c0
}

proc an_enable {} {
  global BASE_KR4
  global ADDR_KR4_ANCTRL

  set an_c0 [reg_read    $BASE_KR4 $ADDR_KR4_ANCTRL]
  set an_c0 [expr $an_c0 | 0x1]
  reg_write   $BASE_KR4 $ADDR_KR4_ANCTRL $an_c0
}
proc ignore_nonce_en {} {
  global BASE_KR4
  global ADDR_KR4_ANCTRL
  set an_c0 [reg_read    $BASE_KR4 $ADDR_KR4_ANCTRL]
  set an_c0 [expr $an_c0 | 0x80]
  reg_write   $BASE_KR4 $ADDR_KR4_ANCTRL $an_c0
}
proc ignore_nonce_dis {} {
  global BASE_KR4
  global ADDR_KR4_ANCTRL
  set an_c0 [reg_read    $BASE_KR4 $ADDR_KR4_ANCTRL]
  set an_c0 [expr $an_c0 & 0x7F]
  reg_write   $BASE_KR4 $ADDR_KR4_ANCTRL $an_c0
}

proc kr_defaults {{nomwt 0} {man 0} {ac 0} {dc 0} {vga 0}} {
  global BASE_KR4
  global ADDR_KR4_LTCTRL
  global ADDR_KR4_ANCTRL
  global ADDR_KR4_BASECTRL

  set man [expr $man != 0]
  set nomwt [expr $nomwt != 0]
  set ac [expr ($ac & 0xf) >> 1]
  set dc [expr ($dc & 0x3f) >> 1]
  set vga [expr ($vga & 0x1f) >> 1]
  reg_write   $BASE_KR4 $ADDR_KR4_LTCTRL [expr 0x00000111 | ($man << 19) | ($ac << 20) | {$dc << 23} | {$vga << 28} | ($nomwt << 1)]
#turn off LT-fail-to-AN
  set reg [reg_read   $BASE_KR4 $ADDR_KR4_BASECTRL]
  reg_write $BASE_KR4 $ADDR_KR4_BASECTRL [expr $reg | 0x1000]
#disable nonce check in AN
  set reg [reg_read    $BASE_KR4 $ADDR_KR4_ANCTRL]
  reg_write   $BASE_KR4 $ADDR_KR4_ANCTRL [expr $reg | 0x80]
}

# a10
set ADDR_A10_PST1   0x105
set ADDR_A10_PST1_M 0x7f
set ADDR_A10_PST2   0x106
set ADDR_A10_PST2_M 0x3f
set ADDR_A10_PRE1   0x107
set ADDR_A10_PRE1_M 0x3f
set ADDR_A10_PRE2   0x108
set ADDR_A10_PRE2_M 0x1f
set ADDR_A10_VOD    0x109
set ADDR_A10_VOD_M  0x1f

# burst error insertion
set ADDR_FEC_ERRI   0x0bd
set ADDR_FEC_TRNS_M 0x01
set ADDR_FEC_BRST_M 0x02
#offset and mask for burst_err_len
set ADDR_FEC_BLEN_O 4
set ADDR_FEC_BLEN_M 0xf0

# error marking enable
set ADDR_FEC_EMRK   0x0c2
set ADDR_FEC_EMRK_M 0x20

# fec error counts
set ADDR_FEC_CORR0  0x0dc
set ADDR_FEC_CORR1  0x0dd
set ADDR_FEC_CORR2  0x0de
set ADDR_FEC_CORR3  0x0df

set ADDR_FEC_UCRR0  0x0e0
set ADDR_FEC_UCRR1  0x0e1
set ADDR_FEC_UCRR2  0x0e2
set ADDR_FEC_UCRR3  0x0e3

proc reconfig_read {chan addr} {
    global BASE_S10RECO
    global RECO_CH

    set chanoffs [expr $BASE_S10RECO + ($RECO_CH * $chan)]
    return [reg_read $chanoffs $addr]
}

proc reconfig_write {chan addr val} {
    global BASE_S10RECO
    global RECO_CH

    set chanoffs [expr $BASE_S10RECO + ($RECO_CH * $chan)]
    return [reg_write $chanoffs $addr $val]
}

proc reconfig_rmw {chan addr mask val} {
    set value [reconfig_read $chan $addr]
    set value [expr $value & [expr 0xffffffff & ~$mask]]
    set value [expr $value | $val]
    reconfig_write $chan $addr $value
}

proc a10dprio_read {chan type} {
    global ADDR_A10_$type
    global ADDR_A10_${type}_M

    set reg [reconfig_read $chan [set ADDR_A10_$type]]

    return [expr $reg & [set ADDR_A10_${type}_M]]
}

proc disable_bgcal { {ip_100g 1}} {
    reconfig_write 0 0x542 0
    reconfig_write 1 0x542 0
    if {$ip_100g} {
        reconfig_write 2 0x542 0
        reconfig_write 3 0x542 0
    }
}


proc enable_bgcal { {ip_100g 1}} {
    reconfig_write 0 0x542 1
    reconfig_write 1 0x542 1
    if {$ip_100g} {
        reconfig_write 2 0x542 1
        reconfig_write 3 0x542 1
    }
}

proc fec_err_corr {chan} {
    global BASE_S10RECO
    global RECO_CH
    global ADDR_FEC_CORR0
    global ADDR_FEC_CORR1
    global ADDR_FEC_CORR2
    global ADDR_FEC_CORR3

    set chanoffs [expr $BASE_S10RECO + ($RECO_CH * $chan)]
    set val [reg_read $chanoffs $ADDR_FEC_CORR0]
    set val [expr $val + [reg_read $chanoffs $ADDR_FEC_CORR1] * 0x100]
    set val [expr $val + [reg_read $chanoffs $ADDR_FEC_CORR2] * 0x10000]
    set val [expr $val + [reg_read $chanoffs $ADDR_FEC_CORR3] * 0x1000000]

    return $val
}

proc fec_err_uncorr {chan} {
    global BASE_S10RECO
    global RECO_CH
    global ADDR_FEC_UCRR0
    global ADDR_FEC_UCRR1
    global ADDR_FEC_UCRR2
    global ADDR_FEC_UCRR3

    set chanoffs [expr $BASE_S10RECO + ($RECO_CH * $chan)]
    set val [reg_read $chanoffs $ADDR_FEC_UCRR0]
    set val [expr $val + [reg_read $chanoffs $ADDR_FEC_UCRR1] * 0x100]
    set val [expr $val + [reg_read $chanoffs $ADDR_FEC_UCRR2] * 0x10000]
    set val [expr $val + [reg_read $chanoffs $ADDR_FEC_UCRR3] * 0x1000000]
    return $val
}

proc fec_errs {} {
    puts -nonewline "[fec_err_corr 0] [fec_err_uncorr 0] | "
    puts -nonewline "[fec_err_corr 1] [fec_err_uncorr 1] | "
    puts -nonewline "[fec_err_corr 2] [fec_err_uncorr 2] | "
    puts            "[fec_err_corr 3] [fec_err_uncorr 3]"
}

proc clear_fec_err {chan} {
    global BASE_KR4
    global ADDR_KR4_FECCTRL$chan


    reg_write $BASE_KR4 [set ADDR_KR4_FECCTRL$chan] 0x1000
    reg_write $BASE_KR4 [set ADDR_KR4_FECCTRL$chan] 0x0000
}

proc clear_all_fec_err {} {
    for {set idx 0} {$idx < 4} {incr idx} {
      clear_fec_err $idx
    }
}

#insert FEC burst error, up to length 15
# FEC should correct anything length 11 or lower
proc ins_burst_err {chan len} {
    global BASE_S10RECO
    global RECO_CH
    global ADDR_FEC_ERRI
    global ADDR_FEC_TRNS_M
    global ADDR_FEC_BRST_M
    global ADDR_FEC_BLEN_O
    global ADDR_FEC_BLEN_M
    global BASE_KR4
    global ADDR_KR4_FECCTRL$chan

    set chanoffs [expr $BASE_S10RECO + ($RECO_CH * $chan)]
    set reg [reg_read $chanoffs $ADDR_FEC_ERRI]

    # clear transcode error, set burst error
    set reg [expr ~$ADDR_FEC_TRNS_M & $reg]
    set reg [expr $ADDR_FEC_BRST_M | $reg]

    # set burst error length
    set reg [expr ~$ADDR_FEC_BLEN_M & $reg]
    set reg [expr $reg | (($len << $ADDR_FEC_BLEN_O) & $ADDR_FEC_BLEN_M)]

    reg_write $chanoffs $ADDR_FEC_ERRI $reg

    # trigger error (self clearing)
    reg_write $BASE_KR4 [set ADDR_KR4_FECCTRL$chan] 0x800
}

proc fec_block_lock {chan} {
    global BASE_KR4
    global ADDR_KR4_BASESTAT


    set reg [reg_read $BASE_KR4 $ADDR_KR4_BASESTAT]
    return [expr ($reg & (0x100000 << $chan)) != 0]
}

proc force_fec {{on 1}} {
    global BASE_KR4
    global ADDR_KR4_BASECTRL


    set reg [reg_read $BASE_KR4 $ADDR_KR4_BASECTRL]
    if {$on} {
        set reg [expr $reg | 0x80]
    } else {
        set reg [expr $reg & (~0x80)]
    }

    reg_write $BASE_KR4 $ADDR_KR4_BASECTRL $reg
}

# To trigger ADP -->
# Reset the adp ckt --> rstn= 148[0]=0
# rmw_val [expr $offset + 0x148] 0x01 0x00 ; after 10
# ####Everything is set, now remove reset 148[0]=1 and trigger/toggle adp engine start 14C[0]
# rmw_val [expr $offset + 0x148] 0x01 0x01 ; after 5
# rmw_val [expr $offset + 0x14C] 0x01 0x00 ; after 5
# rmw_val [expr $offset + 0x14C] 0x01 0x01 5
proc trigger_adp {channel} {
  reconfig_rmw $channel 0x148 0x01 0x00
  reconfig_rmw $channel 0x148 0x01 0x00
  reconfig_rmw $channel 0x148 0x01 0x01

  reconfig_rmw $channel 0x148 0x01 0x01
  reconfig_rmw $channel 0x14c 0x01 0x00
  reconfig_rmw $channel 0x14c 0x01 0x00
  reconfig_rmw $channel 0x14c 0x01 0x01
  reconfig_rmw $channel 0x14c 0x01 0x01
}

proc trig_adp_all {} {
    trig_adp 0
    trig_adp 1
    trig_adp 2
    trig_adp 3
}

proc bypass_adp {channel} {
  #enable bypass ctle, vga, dfe
  reconfig_rmw $channel 0x149 0x80 0x80 ; #vga
  reconfig_rmw $channel 0x15c 0x80 0x80 ; #ctle-dc
  reconfig_rmw $channel 0x15f 0x08 0x08 ; #ctle-ac

  reconfig_rmw $channel 0x161 0x60 0x60 ; #dfe/dlev

}

proc bypass_adp_all {} {
    bypass_adp 0
    bypass_adp 1
    bypass_adp 2
    bypass_adp 3
}

#time in milliseconds
proc set_bertime {{t 0.425115}} {
    global BASE_KR4
    global ADDR_KR4_LTBERT
    set t [expr round($t*2.3523) & 0x3ff]
    reg_write $BASE_KR4 $ADDR_KR4_LTBERT [expr $t << 10]
    puts "ber_time_k_frames set to $t"
}

proc chan_stat_csv {chan {usefec 0}} {
    global BASE_KR4
    global ADDR_KR4_LTSTAT
    global ADDR_KR4_LTSET$chan
    global BASE_RXPHY
    global ADDR_PHY_TXPLLOCK
    global ADDR_PHY_FREQLOCK
    global ADDR_PHY_FRMERROR


    puts -nonewline "LANE$chan\t"

    set rdreg [reg_read $BASE_KR4 [set ADDR_KR4_LTSET$chan]]
    set vod [expr $rdreg & 0x0000003f]
    set post [expr ($rdreg & 0x00001f00)>>8]
    set pre [expr ($rdreg & 0x000f0000)>>16]

    set vod_rd [a10dprio_read $chan VOD]
    set vod_rd [expr $vod_rd & 0x1f]
    set post_rd [a10dprio_read $chan PST1]
    if {$post_rd & 0x40} {
        set post_rd [expr $post_rd & 0x3f]
    } else {
        set post_rd [expr -($post_rd & 0x3f)]
    }
    set pre_rd [a10dprio_read $chan PRE1]
    if {$pre_rd & 0x20} {
        set pre_rd [expr $pre_rd & 0x1f]
    } else {
        set pre_rd [expr -($pre_rd & 0x1f)]
    }

    #  Test bus = ADP 171[4:1]=1
    reconfig_rmw $chan 0x171 0x1E 0x16
    reconfig_write $chan 0x17E 0

    if {[reconfig_read $chan 0x161] & 0x20} {
        set dlev "m"
    } else {
        reconfig_rmw $chan 0x149 0x3F 6
        reconfig_write $chan 0x17E 0
        set dlev [expr [ reconfig_read $chan 0x17E ] & 0x3F]
    }
    if {[reconfig_read $chan 0x149] & 0x80} {
        set vga "m [expr (([reconfig_read $chan 0x11f] & 0x1) << 4) | ([reconfig_read $chan 0x11a] & 0x7)]"
    } else {
        reconfig_rmw $chan 0x149 0x3F 5
        reconfig_write $chan 0x17E 0
        set vga [expr [ reconfig_read $chan 0x17E ] & 0x1F]
    }
    if {[reconfig_read $chan 0x15c] & 0x80} {
        set ctle_dc "m [expr ([reconfig_read $chan 0x11e] >> 7) | ([reconfig_read $chan 0x11c] & 0x1f)]"
    } else {
        reconfig_rmw $chan 0x149 0x3F 4
        reconfig_write $chan 0x17E 0
        set ctle_dc [expr [ reconfig_read $chan 0x17E ] & 0x3F]
    }
    if {[reconfig_read $chan 0x15f] & 0x08} {
        set ctle_ac "m [expr [reconfig_read $chan 0x11a] >> 4]"
    } else {
        reconfig_rmw $chan 0x149 0x3F 3
        reconfig_write $chan 0x17E 0
        set ctle_ac [expr [expr [ reconfig_read $chan 0x17E ] >> 3] & 0XF]
    }

    #  Test bus = ADP 171[4:1]=1
    if {[reconfig_read $chan 0x161] & 0x40} {
        set tap1 "m"
        set tap2 "m"
        set tap3 "m"
        set tap4 "m"
        set tap5 "m"
        set tap6 "m"
        set tap7 "m"
    } else {
        reconfig_rmw $chan 0x171 0x1E 0x16
        reconfig_write $chan 0x17e 0
        reconfig_rmw $chan 0x149 0x3F 7
        reconfig_write $chan 0x17E 0
        set tap1 [expr [reconfig_read $chan   0x17E] & 0x7F]
        set tap1 [expr ($tap1 & 0x3F) * (($tap1 & 0x40) ? -1 : 1)]
        reconfig_rmw $chan 0x149 0x3F 8
        reconfig_write $chan 0x17E 0
        set tap2 [expr [reconfig_read $chan   0x17E] & 0x3F]
        set tap2 [expr ($tap2 & 0x1F) * (($tap2 & 0x20) ? -1 : 1)]
        reconfig_rmw $chan 0x149 0x3F 9
        reconfig_write $chan 0x17E 0
        set tap3 [expr [reconfig_read $chan   0x17E] & 0x3F]
        set tap3 [expr ($tap3 & 0x1F) * (($tap3 & 0x20) ? -1 : 1)]
        reconfig_rmw $chan 0x149 0x3F 10
        reconfig_write $chan 0x17E 0
        set tap4 [expr [reconfig_read $chan   0x17E] & 0x1F]
        set tap4 [expr ($tap4 & 0x0F) * (($tap4 & 0x10) ? -1 : 1)]
        reconfig_rmw $chan 0x149 0x3F 11
        reconfig_write $chan 0x17E 0
        set tap5 [expr [reconfig_read $chan   0x17E] & 0x1F]
        set tap5 [expr ($tap5 & 0x0F) * (($tap5 & 0x10) ? -1 : 1)]
        reconfig_rmw $chan 0x149 0x3F 12
        reconfig_write $chan 0x17E 0
        set tap6 [expr [reconfig_read $chan   0x17E] & 0x1F]
        set tap6 [expr ($tap6 & 0x0F) * (($tap6 & 0x10) ? -1 : 1)]
        reconfig_rmw $chan 0x149 0x3F 13
        reconfig_write $chan 0x17E 0
        set tap7 [expr [reconfig_read $chan   0x17E] & 0x1F]
        set tap7 [expr ($tap7 & 0x0F) * (($tap7 & 0x10) ? -1 : 1)]
    }




    set fec_corr [fec_err_corr $chan]
    set fec_uncorr [fec_err_uncorr $chan]

    puts -nonewline "$vod, $post, $pre,   \t$vod_rd, $post_rd, $pre_rd,   \t    $dlev,   $vga,    $ctle_ac,         $ctle_dc, "
    puts -nonewline "   $tap1,    $tap2,    $tap3,    $tap4,    $tap5,    $tap6,    $tap7,"
    if {$usefec} {puts -nonewline " \t$fec_corr, $fec_uncorr, "}

    #set rdreg [reg_read $BASE_RXPHY $ADDR_PHY_TXPLLOCK]
    # TX PLL Not Locked
    #if {!($rdreg & (1 << $chan))} {puts -nonewline "    X"}

    set rdreg [reg_read $BASE_RXPHY $ADDR_PHY_FREQLOCK]
    # RX CDR Not Locked
    if {!($rdreg & (1 << $chan))} {puts -nonewline "    x"}

    set rdreg [reg_read $BASE_RXPHY $ADDR_PHY_FRMERROR]
    # 40G frame error
    if {$rdreg & (1 << $chan)} {puts -nonewline "    e"}

    set rdreg [reg_read $BASE_KR4 $ADDR_KR4_LTSTAT]
    # not trained
    if {!($rdreg & (1 << ($chan * 8)))} {puts -nonewline "    N"}
    # frame lock
    if {$rdreg & (0x2 << ($chan * 8))} {puts -nonewline "    l"}
    # startup
    if {$rdreg & (0x4 << ($chan * 8))} {puts -nonewline "    s"}
    # training fail (timeout)
    if {$rdreg & (0x8 << ($chan * 8))} {puts -nonewline "    F"}

    # FEC not locked
    if {$usefec & ![fec_block_lock $chan]} {puts -nonewline "    L"}

}

proc run_test_meas {t} {
    global CLIENT_BASE
    global REG_TEMP_SENSE
    global BASE_KR4
    global ADDR_KR4_BASECTRL
    global ADDR_KR4_BASESTAT
    global ADDR_KR4_ANSTAT
    global ADDR_KR4_LTCTRL
    global ADDR_KR4_LTCTL2
    global ADDR_KR4_LTSTAT
    global BASE_RXPHY
    global ADDR_PHY_RFCLKHZ
    global ADDR_PHY_CLKMACOK
    global ADDR_PHY_FALIGNED
    global BASE_TXSTATS
    global BASE_RXSTATS
    global REG_ST_LO
    global REG_CRCERR_LO
    global REG_STAT_CFG
    global REG_STAT_STATUS
    global ver


    #set degf [expr [reg_read $CLIENT_BASE $REG_TEMP_SENSE]]
    set degf 72
    set refclk [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_RFCLKHZ ]]

    puts "---------------------------------------"
    puts "KR4 TEST $ver, TIME $t, ????? F, refclk $refclk"

    stop_pkt_gen
    setphy_clear_frame_error
    # clear stats
    clear_all_stats
    clear_all_fec_err

    # todo add error counter/global status readout
    start_pkt_gen
    after $t

    stop_pkt_gen
    after 100

    puts "GLOBAL,reg 0xB0  ,reg 0xB1  ,reg 0xC2  ,reg 0xD0  ,reg 0xD1  ,reg 0xD2  ,\tTX Starts,RX Starts,RX FCS Err,\tFlags"

    set txcnt [expr [stats_read $BASE_TXSTATS $REG_ST_LO]]
    set rxcnt [expr [stats_read $BASE_RXSTATS $REG_ST_LO]]
    set err [expr [stats_read $BASE_RXSTATS $REG_CRCERR_LO]]
    reg_read $BASE_KR4 $ADDR_KR4_ANSTAT
    puts -nonewline "GLOBAL,[reg_read $BASE_KR4 $ADDR_KR4_BASECTRL],[reg_read $BASE_KR4 $ADDR_KR4_BASESTAT],[reg_read $BASE_KR4 $ADDR_KR4_ANSTAT],[reg_read $BASE_KR4 $ADDR_KR4_LTCTRL],[reg_read $BASE_KR4 $ADDR_KR4_LTCTL2],[reg_read $BASE_KR4 $ADDR_KR4_LTSTAT],\t$txcnt,$rxcnt,$err,\t"

    set rdreg [reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED]
    # 40G lanes not deskewed
    if {!($rdreg & 1)} {puts -nonewline "d"}
    # 40G hi BER
    if {$rdreg & 2} {puts -nonewline "H"}

    set rdreg [reg_read $BASE_RXPHY $ADDR_PHY_CLKMACOK]
    # Tx analog not online
    if {!($rdreg & 1)} {puts -nonewline "a"}
    # Tx mac pll not lock
    if {!($rdreg & 2)} {puts -nonewline "P"}
    # Rx mac pll not lock
    if {!($rdreg & 4)} {puts -nonewline "p"}

    set rdreg [reg_read $BASE_KR4 $ADDR_KR4_BASESTAT]
    # link down (not ready)
    if {!($rdreg & 1)} {puts -nonewline "D"}
    #autoneg timeout
    if {$rdreg & 2} {puts -nonewline "A"}
    #link train timeout
    if {$rdreg & 4} {puts -nonewline "T"}


    set rdreg [reg_read $BASE_KR4 $ADDR_KR4_ANSTAT]
    #AN not complete
    if {!($rdreg & 4)} {puts -nonewline "n"}
    #ANSM not idle
    if {!($rdreg & 0x10)} {puts -nonewline "I"}

    set fec_mode [expr ($rdreg & 0x100) != 0]

    set rdreg [reg_read $BASE_RXSTATS $REG_STAT_STATUS]
    # parity error detected somewhere in stats
    if {$rdreg & 1} {puts -nonewline "*"}

    puts ""
    puts -nonewline "LANE#\tvod, post, pre,\tvod_rd, post_rd, pre_rd, DLEV, VGA , CTLE_AC, CTLE_DC, DFE1, DFE2, DFE3, DFE4, DFE5, DFE6, DFE7, "
    if {$fec_mode} { puts -nonewline "\tFEC Corr, FEC Uncorr,"}
    puts " Flags"

    for {set idx 0} {$idx < 4} {incr idx} {
      chan_stat_csv $idx $fec_mode
      puts ""
    }

}
