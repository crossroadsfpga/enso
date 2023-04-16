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


# =====================================================
# 	Top level register map: Base Addresses
# =====================================================
source [file join [file dirname [info script]] "../sval_top/reg_map_inc.tcl"]

# ==================================================================
# 	PHY Registers
# ==================================================================
#
set ADDR_PHY_REVID    0x00
set ADDR_PHY_SCRTCH   0x01
set ADDR_PHY_IPNAME2  0x02
set ADDR_PHY_IPNAME1  0x03
set ADDR_PHY_IPNAME0  0x04

# config bits, Alvin added 0x12
set ADDR_PHY_PMACFG   0x10
set ADDR_PHY_WORDLCK  0x12
set ADDR_PHY_PMALOOP  0x13
set ADDR_PHY_PHYFSEL  0x14
set ADDR_PHY_PHYFLAG  0x15

# status flags, alvin added x28 and x29, removed x20
set ADDR_PHY_FREQLOCK 0x21
set ADDR_PHY_CLKMACOK 0x22
set ADDR_PHY_FRMERROR 0x23
set ADDR_PHY_CLRFRMER 0x24
set ADDR_PHY_SFTRESET 0x25
set ADDR_PHY_FALIGNED 0x26
set ADDR_PHY_ERINJRST 0x27
set ADDR_PHY_AMLOCK   0x28
set ADDR_PHY_LNDSKWED 0x29
# Pcs_vlane info
set ADDR_PHY_PCSVLAN0 0x30
set ADDR_PHY_PCSVLAN1 0x31
set ADDR_PHY_PCSVLAN2 0x32
set ADDR_PHY_PCSVLAN3 0x33

# clock frequencies, alvin modified x43 and x44
set ADDR_PHY_RFCLKHZ  0x40
set ADDR_PHY_RXCLKHZ  0x41
set ADDR_PHY_TXCLKHZ  0x42
set ADDR_PHY_TXRSKHZ  0x43
set ADDR_PHY_RXRSKHZ  0x44

# reconfig controller
set ADDR_PHY_RECOADDR 0x50
set ADDR_PHY_RECORDWR 0x51
set ADDR_PHY_RECOWDAT 0x52
set ADDR_PHY_RECORDAT 0x53

# ___________________________________________________________________________
#
#
proc chkphy_revid {} {
    global BASE_RXPHY
    global ADDR_PHY_REVID
    puts "RX PHY Register Access: RevID\n"
    reg_read   $BASE_RXPHY $ADDR_PHY_REVID
}

proc setphy_lpon {} {
    global BASE_RXPHY
    global ADDR_PHY_PMALOOP
    # puts "RX PHY Register Access: Setting Serial PMA Loopback\n"
    reg_write   $BASE_RXPHY $ADDR_PHY_PMALOOP 0xffff
    reg_read    $BASE_RXPHY $ADDR_PHY_PMALOOP
}

proc settmp_rst_on {} {
    global BASE_RXPHY
    global ADDR_PHY_ERINJRST
    # puts "RX PHY Register Access: Setting Rst=1 on Top level RXSOP RXEOP TXSOP TXEOP CNTERS \n"
    reg_write   $BASE_RXPHY $ADDR_PHY_ERINJRST 0x0003
    reg_read    $BASE_RXPHY $ADDR_PHY_ERINJRST
}

proc settmp_rst_off {} {
    global BASE_RXPHY
    global ADDR_PHY_ERINJRST
    # puts "RX PHY Register Access: Setting Rst=0 on Top level RXSOP RXEOP TXSOP TXEOP CNTERS \n"
    reg_write   $BASE_RXPHY $ADDR_PHY_ERINJRST 0x0000
    reg_read    $BASE_RXPHY $ADDR_PHY_ERINJRST
}

proc rxsft_rst_on {} {
    global BASE_RXPHY
    global ADDR_PHY_PMACFG
    # puts "RX PHY Register Access: Enable Soft Reset on the Rx \n"
    reg_write   $BASE_RXPHY $ADDR_PHY_PMACFG 0x0004
    reg_read    $BASE_RXPHY $ADDR_PHY_PMACFG
}

proc rxsft_rst_off {} {
    global BASE_RXPHY
    global ADDR_PHY_PMACFG
    # puts "RX PHY Register Access: Disable Soft Reset on the Rx \n"
    reg_write   $BASE_RXPHY $ADDR_PHY_PMACFG 0x0000
    reg_read    $BASE_RXPHY $ADDR_PHY_PMACFG
}


proc txsft_rst_on {} {
    global BASE_RXPHY
    global ADDR_PHY_PMACFG
    # puts "TX PHY Register Access: Enable Soft Reset on the Tx \n"
    reg_write   $BASE_RXPHY $ADDR_PHY_PMACFG 0x0002
    set pmacfg_b2 [ reg_read    $BASE_RXPHY $ADDR_PHY_PMACFG ]
    return $pmacfg_b2
}

proc txsft_rst_off {} {
    global BASE_RXPHY
    global ADDR_PHY_PMACFG
    # puts "TX PHY Register Access: Disable Soft Reset on the Tx \n"
    reg_write   $BASE_RXPHY $ADDR_PHY_PMACFG 0x0000
    set pmacfg_b2 [ reg_read    $BASE_RXPHY $ADDR_PHY_PMACFG ]
    return $pmacfg_b2
}


proc eiosys_rst_on {} {
    global BASE_RXPHY
    global ADDR_PHY_PMACFG
    # puts "EIO SYS Register Access: Enable Eio Sys Reset on the Xcvr and CSR \n"
    reg_write   $BASE_RXPHY $ADDR_PHY_PMACFG 0x0001
    reg_read    $BASE_RXPHY $ADDR_PHY_PMACFG
}

proc eiosys_rst_off {} {
    global BASE_RXPHY
    global ADDR_PHY_PMACFG
    # puts "EIO SYS Register Access: Disable Eio Sys Reset on the Xcvr and CSR \n"
    reg_write   $BASE_RXPHY $ADDR_PHY_PMACFG 0x0000
    reg_read    $BASE_RXPHY $ADDR_PHY_PMACFG
}


proc setphy_lpoff {} {
    global BASE_RXPHY
    global ADDR_PHY_PMALOOP
    # puts "RX PHY Register Access: Setting Serial PMA Loopback\n"
    reg_write  $BASE_RXPHY $ADDR_PHY_PMALOOP 0x0
    reg_read   $BASE_RXPHY $ADDR_PHY_PMALOOP
}

proc chkphy_clk_speeds {} {
    global BASE_RXPHY
    global ADDR_PHY_RFCLKHZ
    global ADDR_PHY_TXCLKHZ
    global ADDR_PHY_RXCLKHZ
    global ADDR_PHY_TXRSKHZ
    global ADDR_PHY_RXRSKHZ

    puts " RX PHY Register Access: Checking Clock Frequencies (KHz) \n"
    set refclk [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_RFCLKHZ ]]
    set txclk  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_TXCLKHZ ]]
    set rxclk  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_RXCLKHZ ]]
    set txrsclk  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_TXRSKHZ ]]
    set rxrsclk  [ expr [ reg_read $BASE_RXPHY $ADDR_PHY_RXRSKHZ ]]

    puts "	REFCLK 		:$refclk (KHZ) "
    puts "	TXCLK 		:$txclk  (KHZ) "
    puts "	RXCLK 		:$rxclk  (KHZ) "
    puts "	TXRSCLK 	:$txrsclk  (KHZ) "
    puts "	RXRSCLK 	:$rxrsclk  (KHZ) "
}

proc setphy_clear_frame_error {} {
    global BASE_RXPHY
    global ADDR_PHY_CLRFRMER
    reg_write  $BASE_RXPHY $ADDR_PHY_CLRFRMER 0x01
    reg_write  $BASE_RXPHY $ADDR_PHY_CLRFRMER 0x00
}

proc chkphy_frame_error {} {
    global 	BASE_RXPHY
    global 	ADDR_PHY_FRMERROR
    set rxfrm_err [ reg_read   $BASE_RXPHY $ADDR_PHY_FRMERROR ]
    setphy_clear_frame_error
    return $rxfrm_err
}

proc read_phy_frame_error {} {
    global 	BASE_RXPHY
    global 	ADDR_PHY_FRMERROR
    set rxfrm_err [ reg_read   $BASE_RXPHY $ADDR_PHY_FRMERROR ]
    return $rxfrm_err
}

proc chkphy_io_status {} {
    global BASE_RXPHY
    global ADDR_PHY_FREQLOCK
    global ADDR_PHY_CLKMACOK
    global ADDR_PHY_FRMERROR
    global ADDR_PHY_CLRFRMER
    global ADDR_PHY_SFTRESET
    global ADDR_PHY_FALIGNED
    global ADDR_PHY_AMLOCK
    global ADDR_PHY_LNDSKWED

    puts " RX PHY Status Polling \n"
    puts " Rx Frequency Lock Status     [ reg_read   $BASE_RXPHY $ADDR_PHY_FREQLOCK ] \n"
    puts " Mac Clock in OK Condition?   [ reg_read   $BASE_RXPHY $ADDR_PHY_CLKMACOK ] \n"
    puts " Rx Frame Error               [ chkphy_frame_error                        ] \n"
    puts " Rx PHY Fully Aligned?        [ reg_read   $BASE_RXPHY $ADDR_PHY_FALIGNED ] \n"
    puts " Rx AM LOCK Condition?        [ reg_read   $BASE_RXPHY $ADDR_PHY_AMLOCK   ] \n"
    puts " Rx Lanes Deskewed Condition? [ reg_read   $BASE_RXPHY $ADDR_PHY_LNDSKWED ] \n"
}

# ______________________________________________________________________________
#
#
proc chkphy_status {} {
    chkphy_clk_speeds
    chkphy_io_status
}

proc loop_on {} {setphy_lpon}
proc loop_off {} {setphy_lpoff}

proc tmpcntrst_on {} {settmp_rst_on}
proc tmpcntrst_off {} {settmp_rst_off}
# ___________________________________________________________________________
#

proc phy_locked {} {
    global BASE_RXPHY
    global ADDR_PHY_FALIGNED
    set locked [ reg_read $BASE_RXPHY $ADDR_PHY_FALIGNED ]
    return $locked
}

proc wait_for_phy_lock { { timeout 2 } } {
    set num_tries [ expr {$timeout * 10}]
    for {set i 0} {$i < $num_tries} {incr i} {
        set locked [phy_locked]
           puts " wait for phy lock=$num_tries, locked=$locked\n"
        if {$locked == 1} {return 0}
        after 100
    }
    return -1
}

proc wait_for_phy_unlock { { timeout 2 } } {
    set num_tries [ expr {$timeout * 10}]
    for {set i 0} {$i < $num_tries} {incr i} {
        set locked [phy_locked]
        if {$locked == 0} {return 0}
        after 100
    }
    return -1
}

proc cycle_loopback {count} {
    loop_off
    wait_for_unlock

    for {set i 1} {$i <= $count} {incr i} {
        puts "Loopback cycle count = $i"

        loop_on
        set res [ wait_for_lock ]
        if {$res != 0} {return -1}

        loop_off
        set res [ wait_for_unlock ]
        if {$res != 0} {return -1}
    }
    return 0
}

proc cycle_reset {count} {
    loop_on
    wait_for_lock

    for {set i 1} {$i <= $count} {incr i} {
        puts "Reset cycle = $i"
        reg_write 0x326 1
        reg_write 0x326 0
        set res [ wait_for_lock ]
        if {$res != 0} {return -1}
    }
    return 0
}

proc recovery_test {count} {
    set res [ cycle_loopback $count ]
    if {$res != 0} {
        puts "Failed loopback test"
        return -1;
    }

    set res [ cycle_reset $count ]
    if {$res != 0} {
        puts "Failed reset test"
        return -1;
    }

    puts "Recovery test passed"
    return 0
}
