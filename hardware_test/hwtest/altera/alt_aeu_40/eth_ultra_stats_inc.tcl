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


## ===================================================== 
##     Top level register map: Base Addresses
## ===================================================== 
source [file join [file dirname [info script]] "../sval_top/reg_map_inc.tcl"]

## ================================================================== 
##     Ethernet registers Tx Stats Counters
## ================================================================== 
##
set  REG_FRAGMENTS_LO       0x00
set  REG_FRAGMENTS_HI       0x01
set  REG_JABBERS_LO         0x02
set  REG_JABBERS_HI         0x03
set  REG_CRCERR_LO          0x04
set  REG_CRCERR_SIZEOK_HI   0x05
set  REG_CRCERR_SIZEOK_LO   0x06
set  REG_CRCERR_HI          0x07
set  REG_MCAST_DATA_ERR_LO  0x08
set  REG_MCAST_DATA_ERR_HI  0x09
set  REG_BCAST_DATA_ERR_LO  0x0A
set  REG_BCAST_DATA_ERR_HI  0x0B
set  REG_UCAST_DATA_ERR_LO  0x0C
set  REG_UCAST_DATA_ERR_HI  0x0D
set  REG_MCAST_CTRL_ERR_LO  0x0E
set  REG_MCAST_CTRL_ERR_HI  0x0F
set  REG_BCAST_CTRL_ERR_LO  0x10
set  REG_BCAST_CTRL_ERR_HI  0x11
set  REG_UCAST_CTRL_ERR_LO  0x12
set  REG_UCAST_CTRL_ERR_HI  0x13
set  REG_PAUSE_ERR_LO       0x14
set  REG_PAUSE_ERR_HI       0x15
set  REG_64B_LO             0x16
set  REG_64B_HI             0x17
set  REG_65to127B_LO        0x18
set  REG_65to127B_HI        0x19
set  REG_128to255B_LO       0x1A
set  REG_128to255B_HI       0x1B
set  REG_256to511B_LO       0x1C
set  REG_256to511B_HI       0x1D
set  REG_512to1023B_LO      0x1E
set  REG_512to1023B_HI      0x1F
set  REG_1024to1518B_LO     0x20
set  REG_1024to1518B_HI     0x21
set  REG_1519toMAXB_LO      0x22
set  REG_1519toMAXB_HI      0x23
set  REG_OVERSIZE_LO        0x24
set  REG_OVERSIZE_HI        0x25
set  REG_MCAST_DATA_OK_LO   0x26
set  REG_MCAST_DATA_OK_HI   0x27
set  REG_BCAST_DATA_OK_LO   0x28
set  REG_BCAST_DATA_OK_HI   0x29
set  REG_UCAST_DATA_OK_LO   0x2A
set  REG_UCAST_DATA_OK_HI   0x2B
set  REG_MCAST_CTRL_OK_LO   0x2C
set  REG_MCAST_CTRL_OK_HI   0x2D
set  REG_BCAST_CTRL_OK_LO   0x2E
set  REG_BCAST_CTRL_OK_HI   0x2F
set  REG_UCAST_CTRL_OK_LO   0x30
set  REG_UCAST_CTRL_OK_HI   0x31
 set  REG_PAUSE_LO          0x32
 set  REG_PAUSE_HI          0x33
 set  REG_RNT_LO            0x34
 set  REG_RNT_HI            0x35
 set  REG_ST_LO             0x36
 set  REG_ST_HI             0x37
 set  REG_DB_LO             0x38
 set  REG_DB_HI             0x39
 set  REG_EBLK_HI           0x3A
 set  REG_EBLK_LO           0x3B
 set  REG_FST_LO            0x3C
 set  REG_FST_HI            0x3D
 set  REG_F_LONG_HI         0x3E
 set  REG_F_LONG_LO         0x3F
 set  REG_STAT_REVID        0x40
 set  REG_STAT_SCRATCH      0x41
 set  REG_STAT_NAME_0       0x42
 set  REG_STAT_NAME_1       0x43
 set  REG_STAT_NAME_2       0x44
 set  REG_STAT_CFG          0x45
 set  REG_STAT_STATUS       0x46

proc pause_stats {reg_base} {
    global REG_STAT_CFG
    reg_write $reg_base $REG_STAT_CFG 0x4
}

proc unpause_stats {reg_base} {
    global REG_STAT_CFG
    reg_write $reg_base $REG_STAT_CFG 0x0
}

proc clear_stats {reg_base} {
    global REG_STAT_CFG
    reg_write $reg_base $REG_STAT_CFG 0x1
    reg_write $reg_base $REG_STAT_CFG 0x0
}

proc clear_rx_stats {} {
    global BASE_RXSTATS
    clear_stats $BASE_RXSTATS
}

proc clear_tx_stats {} {
    global BASE_TXSTATS
    clear_stats $BASE_TXSTATS
}

proc clear_all_stats {} {
    clear_rx_stats
    clear_tx_stats
}

 # ___________________________________________________________________________________
 #
proc check_stats {reg_base t} {
    global BASE_STATS
    global REG_FRAGMENTS_LO
    global REG_FRAGMENTS_HI
    global REG_JABBERS_LO
    global REG_JABBERS_HI
    global REG_CRCERR_LO
    global REG_CRCERR_SIZEOK_HI
    global REG_CRCERR_SIZEOK_LO
    global REG_CRCERR_HI
    global REG_MCAST_DATA_ERR_LO
    global REG_MCAST_DATA_ERR_HI
    global REG_BCAST_DATA_ERR_LO
    global REG_BCAST_DATA_ERR_HI
    global REG_UCAST_DATA_ERR_LO
    global REG_UCAST_DATA_ERR_HI
    global REG_MCAST_CTRL_ERR_LO
    global REG_MCAST_CTRL_ERR_HI
    global REG_BCAST_CTRL_ERR_LO
    global REG_BCAST_CTRL_ERR_HI
    global REG_UCAST_CTRL_ERR_LO
    global REG_UCAST_CTRL_ERR_HI
    global REG_PAUSE_ERR_HI
    global REG_PAUSE_ERR_LO
    global REG_64B_LO
    global REG_64B_HI
    global REG_65to127B_LO
    global REG_65to127B_HI
    global REG_128to255B_LO
    global REG_128to255B_HI
    global REG_256to511B_LO
    global REG_256to511B_HI
    global REG_512to1023B_LO
    global REG_512to1023B_HI
    global REG_1024to1518B_LO
    global REG_1024to1518B_HI
    global REG_1519toMAXB_LO
    global REG_1519toMAXB_HI
    global REG_OVERSIZE_LO
    global REG_OVERSIZE_HI
    global REG_MCAST_DATA_OK_LO
    global REG_MCAST_DATA_OK_HI
    global REG_BCAST_DATA_OK_LO
    global REG_BCAST_DATA_OK_HI
    global REG_UCAST_DATA_OK_LO
    global REG_UCAST_DATA_OK_HI
    global REG_MCAST_CTRL_OK_LO
    global REG_MCAST_CTRL_OK_HI
    global REG_BCAST_CTRL_OK_LO
    global REG_BCAST_CTRL_OK_HI
    global REG_UCAST_CTRL_OK_LO
    global REG_UCAST_CTRL_OK_HI
    global REG_PAUSE_LO
    global REG_PAUSE_HI
    global REG_RNT_LO
    global REG_RNT_HI
    global REG_ST_LO
    global REG_ST_HI
    global REG_DB_LO
    global REG_DB_HI
    global REG_EBLK_HI
    global REG_EBLK_LO
    global REG_FST_LO
    global REG_FST_HI
    global REG_F_LONG_HI
    global REG_F_LONG_LO
    global REG_STAT_CFG
    global REG_STAT_STATUS

    set BASE_STATS $reg_base
    #for CLI output only
    #for table widths
    set w_des 30
    set w_val 30
    pause_stats $reg_base
    puts " =========================================================================================="
    puts "                        STATISTICS FOR BASE $BASE_STATS ($t)                               "
    puts " =========================================================================================="
    puts "Fragmented Frames                : [expr [stats_read $BASE_STATS     $REG_FRAGMENTS_LO        ]] "
    puts "Jabbered Frames                  : [expr [stats_read $BASE_STATS     $REG_JABBERS_LO          ]] "
    puts "Any Size with FCS Err Frame      : [expr [stats_read $BASE_STATS     $REG_CRCERR_LO           ]] "
    puts "Right Size with FCS Err Fra      : [expr [stats_read $BASE_STATS     $REG_CRCERR_SIZEOK_LO    ]] "
    puts "Multicast data  Err Frames       : [expr [stats_read $BASE_STATS     $REG_MCAST_DATA_ERR_LO   ]] "
    puts "Broadcast data Err  Frames       : [expr [stats_read $BASE_STATS     $REG_BCAST_DATA_ERR_LO   ]] "
    puts "Unicast data Err  Frames         : [expr [stats_read $BASE_STATS     $REG_UCAST_DATA_ERR_LO   ]] "
    puts "Multicast control  Err Frame     : [expr [stats_read $BASE_STATS     $REG_MCAST_CTRL_ERR_LO   ]] "
    puts "Broadcast control Err  Frame     : [expr [stats_read $BASE_STATS     $REG_BCAST_CTRL_ERR_LO   ]] "
    puts "Unicast control Err  Frames      : [expr [stats_read $BASE_STATS     $REG_UCAST_CTRL_ERR_LO   ]] "
    puts "Pause control Err  Frames        : [expr [stats_read $BASE_STATS     $REG_PAUSE_ERR_LO        ]] "


    puts "64 Byte Frames                   : [expr [stats_read $BASE_STATS     $REG_64B_LO              ]] "
    puts "65 - 127 Byte Frames             : [expr [stats_read $BASE_STATS     $REG_65to127B_LO         ]] "
    puts "128 - 255 Byte Frames            : [expr [stats_read $BASE_STATS     $REG_128to255B_LO        ]] "
    puts "256 - 511 Byte Frames            : [expr [stats_read $BASE_STATS     $REG_256to511B_LO        ]] "
    puts "512 - 1023 Byte Frames           : [expr [stats_read $BASE_STATS     $REG_512to1023B_LO       ]] "
    puts "1024 - 1518 Byte Frames          : [expr [stats_read $BASE_STATS     $REG_1024to1518B_LO      ]] "
    puts "1519 - MAX Byte Frames           : [expr [stats_read $BASE_STATS     $REG_1519toMAXB_LO       ]] "
    puts "> MAX Byte Frames                : [expr [stats_read $BASE_STATS     $REG_OVERSIZE_LO         ]] "
    puts "$t Frame Starts                  : [expr [stats_read $BASE_STATS     $REG_ST_LO               ]] "
    puts "Multicast data  OK  Frame        : [expr [stats_read $BASE_STATS     $REG_MCAST_DATA_OK_LO    ]] "
    puts "Broadcast data OK   Frame        : [expr [stats_read $BASE_STATS     $REG_BCAST_DATA_OK_LO    ]] "
    puts "Unicast data OK   Frames         : [expr [stats_read $BASE_STATS     $REG_UCAST_DATA_OK_LO    ]] "
    puts "Multicast Control Frames         : [expr [stats_read $BASE_STATS     $REG_MCAST_CTRL_OK_LO    ]] "
    puts "Broadcast Control Frames         : [expr [stats_read $BASE_STATS     $REG_BCAST_CTRL_OK_LO    ]] "
    puts "Unicast Control Frames           : [expr [stats_read $BASE_STATS     $REG_UCAST_CTRL_OK_LO    ]] "
    puts "Pause Control Frames             : [expr [stats_read $BASE_STATS     $REG_PAUSE_LO            ]] "
    unpause_stats $reg_base
}

proc diff_count { info_offset } {
    global BASE_TXSTATS
    global BASE_RXSTATS

    set tx_value [expr [stats_read $BASE_TXSTATS $info_offset]]
    set rx_value [expr [stats_read $BASE_RXSTATS $info_offset]]

    return [expr {$tx_value - $rx_value}]
}

proc check_packet_errors {} {
    global BASE_RXSTATS
    global REG_FRAGMENTS_LO
    global REG_JABBERS_LO
    global REG_CRCERR_LO
    global REG_CRCERR_SIZEOK_LO
    global REG_MCAST_DATA_ERR_LO
    global REG_BCAST_DATA_ERR_LO
    global REG_UCAST_DATA_ERR_LO
    global REG_MCAST_CTRL_ERR_LO
    global REG_BCAST_CTRL_ERR_LO
    global REG_UCAST_CTRL_ERR_LO
    global REG_PAUSE_ERR_LO

    set BASE_STATS $BASE_RXSTATS

    set frag_count      [expr [stats_read $BASE_STATS     $REG_FRAGMENTS_LO         ]]
    set jab_count       [expr [stats_read $BASE_STATS     $REG_JABBERS_LO           ]]
    set crcerr_count    [expr [stats_read $BASE_STATS     $REG_CRCERR_LO            ]]
    set crcerr2_count   [expr [stats_read $BASE_STATS     $REG_CRCERR_SIZEOK_LO     ]]
    set mcastderr_count [expr [stats_read $BASE_STATS     $REG_MCAST_DATA_ERR_LO    ]]
    set bcastderr_count [expr [stats_read $BASE_STATS     $REG_BCAST_DATA_ERR_LO    ]]
    set ucastderr_count [expr [stats_read $BASE_STATS     $REG_UCAST_DATA_ERR_LO    ]]
    set mcastcerr_count [expr [stats_read $BASE_STATS     $REG_MCAST_CTRL_ERR_LO    ]]
    set bcastcerr_count [expr [stats_read $BASE_STATS     $REG_BCAST_CTRL_ERR_LO    ]]
    set ucastcerr_count [expr [stats_read $BASE_STATS     $REG_UCAST_CTRL_ERR_LO    ]]
    set pauseerr_count  [expr [stats_read $BASE_STATS     $REG_PAUSE_ERR_LO         ]]

    set total [expr { $frag_count + $jab_count + $crcerr_count + $crcerr2_count \
        + $mcastderr_count + $bcastderr_count + $ucastderr_count \
        + $mcastcerr_count + $bcastcerr_count + $ucastcerr_count \
        + $pauseerr_count }]

    if {$total != 0} {
        puts "Error: Frame errors reported."
    }
    return $total
}

proc get_rx_count {} {
    global BASE_RXSTATS
    global REG_ST_LO
    set rx_value [expr [stats_read $BASE_RXSTATS $REG_ST_LO]]
    return $rx_value
}

proc get_tx_count {} {
    global BASE_TXSTATS
    global REG_ST_LO
    set tx_value [expr [stats_read $BASE_TXSTATS $REG_ST_LO]]
    return $tx_value
}

proc get_mac_rx_count_bin { size } {
    global BASE_RXSTATS
    set counter_reg [get_mac_count_register $size]
    set count [expr [stats_read $BASE_RXSTATS $counter_reg]]
    return $count
}

proc get_mac_tx_count_bin { size } {
    global BASE_TXSTATS
    set counter_reg [get_mac_count_register $size]
    set count [expr [stats_read $BASE_TXSTATS $counter_reg]]
    return $count
}

proc get_mac_count_register { size } {
    global REG_64B_LO
    global REG_65to127B_LO
    global REG_128to255B_LO
    global REG_256to511B_LO
    global REG_512to1023B_LO
    global REG_1024to1518B_LO
    global REG_1519toMAXB_LO
    global REG_OVERSIZE_LO

    if {$size <= 64} {
        return $REG_64B_LO
    } elseif {$size <= 127} {
        return $REG_65to127B_LO
    } elseif {$size <= 255} {
        return $REG_128to255B_LO
    } elseif {$size <= 511} {
        return $REG_256to511B_LO
    } elseif {$size <= 1023} {
        return $REG_512to1023B_LO
    } elseif {$size <= 1518} {
        return $REG_1024to1518B_LO
    } elseif {$size <= 9600} {
        return $REG_1519toMAXB_LO
    } else {
        return $REG_OVERSIZE_LO
    }
}

proc verify_rxtx_counts {} {
    global REG_64B_LO
    global REG_65to127B_LO
    global REG_128to255B_LO
    global REG_256to511B_LO
    global REG_512to1023B_LO
    global REG_1024to1518B_LO
    global REG_1519toMAXB_LO
    global REG_OVERSIZE_LO
    global REG_ST_LO
    global REG_MCAST_DATA_OK_LO
    global REG_BCAST_DATA_OK_LO
    global REG_UCAST_DATA_OK_LO
    global REG_MCAST_CTRL_OK_LO
    global REG_BCAST_CTRL_OK_LO
    global REG_UCAST_CTRL_OK_LO
    global REG_PAUSE_LO

    set 64b_count [diff_count $REG_64B_LO]
    set 50b_count [diff_count $REG_65to127B_LO]
    set 128b_count [diff_count $REG_128to255B_LO]
    set 256b_count [diff_count $REG_256to511B_LO]
    set 512b_count [diff_count $REG_512to1023B_LO]
    set 1024b_count [diff_count $REG_1024to1518B_LO]
    set 1519_count [diff_count $REG_1519toMAXB_LO]
    set oversize_count [diff_count $REG_OVERSIZE_LO]
    set starts_count [diff_count $REG_ST_LO]
    set mcastd_count [diff_count $REG_MCAST_DATA_OK_LO]
    set bcastd_count [diff_count $REG_BCAST_DATA_OK_LO]
    set ucastd_count [diff_count $REG_UCAST_DATA_OK_LO]
    set mcastc_count [diff_count $REG_MCAST_CTRL_OK_LO]
    set bcastc_count [diff_count $REG_BCAST_CTRL_OK_LO]
    set ucastc_count [diff_count $REG_UCAST_CTRL_OK_LO]
    set pause_count [diff_count $REG_PAUSE_LO]

    set total [expr {$64b_count + $50b_count + $128b_count \
        + $256b_count + $512b_count + $1024b_count + $1519_count \
        + $oversize_count + $starts_count + $mcastd_count \
        + $bcastd_count + $ucastd_count + $mcastc_count \
        + $bcastc_count + $ucastc_count + $pause_count} ]

    if {$total != 0} {
        puts "Error: RX and TX packet counts do not match."
        return -1
    } else {
        return 0
    }
}


 # ___________________________________________________________________________________
 #
proc check_stats_log {reg_base} {
    global log
    global BASE_STATS
    global REG_FRAGMENTS_LO
    global REG_FRAGMENTS_HI
    global REG_JABBERS_LO
    global REG_JABBERS_HI
    global REG_CRCERR_LO
    global REG_CRCERR_SIZEOK_HI
    global REG_CRCERR_SIZEOK_LO
    global REG_CRCERR_HI
    global REG_MCAST_DATA_ERR_LO
    global REG_MCAST_DATA_ERR_HI
    global REG_BCAST_DATA_ERR_LO
    global REG_BCAST_DATA_ERR_HI
    global REG_UCAST_DATA_ERR_LO
    global REG_UCAST_DATA_ERR_HI
    global REG_MCAST_CTRL_ERR_LO
    global REG_MCAST_CTRL_ERR_HI
    global REG_BCAST_CTRL_ERR_LO
    global REG_BCAST_CTRL_ERR_HI
    global REG_UCAST_CTRL_ERR_LO
    global REG_UCAST_CTRL_ERR_HI
    global REG_PAUSE_ERR_HI
    global REG_PAUSE_ERR_LO
    global REG_64B_LO
    global REG_64B_HI
    global REG_65to127B_LO
    global REG_65to127B_HI
    global REG_128to255B_LO
    global REG_128to255B_HI
    global REG_256to511B_LO
    global REG_256to511B_HI
    global REG_512to1023B_LO
    global REG_512to1023B_HI
    global REG_1024to1518B_LO
    global REG_1024to1518B_HI
    global REG_1519toMAXB_LO
    global REG_1519toMAXB_HI
    global REG_OVERSIZE_LO
    global REG_OVERSIZE_HI
    global REG_MCAST_DATA_OK_LO
    global REG_MCAST_DATA_OK_HI
    global REG_BCAST_DATA_OK_LO
    global REG_BCAST_DATA_OK_HI
    global REG_UCAST_DATA_OK_LO
    global REG_UCAST_DATA_OK_HI
    global REG_MCAST_CTRL_OK_LO
    global REG_MCAST_CTRL_OK_HI
    global REG_BCAST_CTRL_OK_LO
    global REG_BCAST_CTRL_OK_HI
    global REG_UCAST_CTRL_OK_LO
    global REG_UCAST_CTRL_OK_HI
    global REG_PAUSE_LO
    global REG_PAUSE_HI
    global REG_RNT_LO
    global REG_RNT_HI
    global REG_ST_LO
    global REG_ST_HI
    global REG_DB_LO
    global REG_DB_HI
    global REG_EBLK_HI
    global REG_EBLK_LO
    global REG_FST_LO
    global REG_FST_HI
    global REG_F_LONG_HI
    global REG_F_LONG_LO
    global REG_STAT_CFG
    global REG_STAT_STATUS

    set BASE_STATS $reg_base
    #for CLI output only
    #for table widths
    set w_des 30
    set w_val 30
    pause_stats $reg_base
    set msg_hdr_tborder_cli             "==================================================================="
    set msg_hdr_title_cli               "              STATISTICS FOR BASE $BASE_STATS                      "
    set msg_hdr_lborder_cli             "==================================================================="
    set msg_Tx_Title_cli                    [format "| %-*s | %-*s |" $w_des "--DESCRIPTION--" $w_val "--VALUE--"]
    set msg_Tx_Frame_Starts_cli             [format "| %-*s | %-*d |" $w_des "Tx Frame Starts" $w_val                   [expr [stats_read $BASE_STATS     $REG_ST_LO                ]]]
    set msg_Fragmented_Frames_cli           [format "| %-*s | %-*d |" $w_des "Fragmented Frames" $w_val                 [expr [stats_read $BASE_STATS     $REG_FRAGMENTS_LO         ]]]
    set msg_Jabbered_Frames_cli             [format "| %-*s | %-*d |" $w_des "Jabbered Frames" $w_val                   [expr [stats_read $BASE_STATS     $REG_JABBERS_LO           ]]]
    set msg_Any_Size_with_FCS_Err_cli       [format "| %-*s | %-*d |" $w_des "Any Size with FCS Err Frames" $w_val      [expr [stats_read $BASE_STATS     $REG_CRCERR_LO            ]]]
    set msg_Right_Size_with_FCS_Err_cli     [format "| %-*s | %-*d |" $w_des "Right Size with FCS Err Frames" $w_val    [expr [stats_read $BASE_STATS     $REG_CRCERR_SIZEOK_LO     ]]]
    set msg_Multicast_data_Err_Frames_cli   [format "| %-*s | %-*d |" $w_des "Multicast data  Err Frames" $w_val        [expr [stats_read $BASE_STATS     $REG_MCAST_DATA_ERR_LO    ]]]
    set msg_Broadcast_data_Err_Frames_cli   [format "| %-*s | %-*d |" $w_des "Broadcast data Err  Frames" $w_val        [expr [stats_read $BASE_STATS     $REG_BCAST_DATA_ERR_LO    ]]]
    set msg_Unicast_data_Err_Frames_cli     [format "| %-*s | %-*d |" $w_des "Unicast data Err  Frames" $w_val          [expr [stats_read $BASE_STATS     $REG_UCAST_DATA_ERR_LO    ]]]
    set msg_Multicast_ctrl_Err_Frames_cli   [format "| %-*s | %-*d |" $w_des "Multicast control  Err Frames" $w_val     [expr [stats_read $BASE_STATS     $REG_MCAST_CTRL_ERR_LO    ]]]
    set msg_Broadcast_ctrl_Err_Frames_cli   [format "| %-*s | %-*d |" $w_des "Broadcast control Err  Frames" $w_val     [expr [stats_read $BASE_STATS     $REG_BCAST_CTRL_ERR_LO    ]]]
    set msg_Unicast_control_Err_Frames_cli  [format "| %-*s | %-*d |" $w_des "Unicast control Err  Frames" $w_val       [expr [stats_read $BASE_STATS     $REG_UCAST_CTRL_ERR_LO    ]]]
    set msg_Pause_control_Err_Frames_cli    [format "| %-*s | %-*d |" $w_des "Pause control Err  Frames" $w_val         [expr [stats_read $BASE_STATS     $REG_PAUSE_ERR_LO         ]]]


    set msg_64_Byte_Frames_cli              [format "| %-*s | %-*d |" $w_des "64 Byte Frames" $w_val                [expr [stats_read $BASE_STATS     $REG_64B_LO           ]]]
    set msg_65_127_Byte_Frames_cli          [format "| %-*s | %-*d |" $w_des "65 - 127 Byte Frames" $w_val          [expr [stats_read $BASE_STATS     $REG_65to127B_LO      ]]]
    set msg_128_255_Byte_Frames_cli         [format "| %-*s | %-*d |" $w_des "128 - 255 Byte Frames" $w_val         [expr [stats_read $BASE_STATS     $REG_128to255B_LO     ]]]
    set msg_256_511_Byte_Frames_cli         [format "| %-*s | %-*d |" $w_des "256 - 511 Byte Frames" $w_val         [expr [stats_read $BASE_STATS     $REG_256to511B_LO     ]]]
    set msg_512_1023_Byte_Frames_cli        [format "| %-*s | %-*d |" $w_des "512 - 1023 Byte Frames" $w_val        [expr [stats_read $BASE_STATS     $REG_512to1023B_LO    ]]]
    set msg_1024_1518_Byte_Frames_cli       [format "| %-*s | %-*d |" $w_des "1024 - 1518 Byte Frames" $w_val       [expr [stats_read $BASE_STATS     $REG_1024to1518B_LO   ]]]
    set msg_1519_MAX_Byte_Frames_cli        [format "| %-*s | %-*d |" $w_des "1519 - MAX Byte Frames" $w_val        [expr [stats_read $BASE_STATS     $REG_1519toMAXB_LO    ]]]
    set msg_More_than_MAX_Byte_Frames_cli   [format "| %-*s | %-*d |" $w_des "> MAX Byte Frames" $w_val             [expr [stats_read $BASE_STATS     $REG_OVERSIZE_LO      ]]]
    set msg_Multicast_data_OK_Frames_cli    [format "| %-*s | %-*d |" $w_des "Multicast data  OK  Frames" $w_val    [expr [stats_read $BASE_STATS     $REG_MCAST_DATA_OK_LO ]]]
    set msg_Broadcast_data_OK_Frames_cli    [format "| %-*s | %-*d |" $w_des "Broadcast data OK   Frames" $w_val    [expr [stats_read $BASE_STATS     $REG_BCAST_DATA_OK_LO ]]]
    set msg_Unicast_data_OK_Frames_cli      [format "| %-*s | %-*d |" $w_des "Unicast data OK   Frames" $w_val      [expr [stats_read $BASE_STATS     $REG_UCAST_DATA_OK_LO ]]]
    set msg_Multicast_Control_Frames_cli    [format "| %-*s | %-*d |" $w_des "Multicast Control Frames" $w_val      [expr [stats_read $BASE_STATS     $REG_MCAST_CTRL_OK_LO ]]]
    set msg_Broadcast_Control_Frames_cli    [format "| %-*s | %-*d |" $w_des "Broadcast Control Frames" $w_val      [expr [stats_read $BASE_STATS     $REG_BCAST_CTRL_OK_LO ]]]
    set msg_Unicast_Control_Frames_cli      [format "| %-*s | %-*d |" $w_des "Unicast Control Frames" $w_val        [expr [stats_read $BASE_STATS     $REG_UCAST_CTRL_OK_LO ]]]
    set msg_Pause_Control_Frames_cli        [format "| %-*s | %-*d |" $w_des "Pause Control Frames" $w_val          [expr [stats_read $BASE_STATS     $REG_PAUSE_LO         ]]]

    #for log
    set msg_hdr_title_log             "*TX STATISTICS*"
    set msg_Tx_Title_log             "--DESCRIPTION--, --VALUE--"

    set msg_Tx_Frame_Starts_log             "Tx Frame Starts"                   [expr [reg_read $BASE_STATS     $REG_ST_LO              ]]]
    set msg_Fragmented_Frames_log           "Fragmented Frames"                 [expr [reg_read $BASE_STATS     $REG_FRAGMENTS_LO       ]]]
    set msg_Jabbered_Frames_log             "Jabbered Frames"                   [expr [reg_read $BASE_STATS     $REG_JABBERS_LO         ]]]
    set msg_Any_Size_with_FCS_Err_log       "Any Size with FCS Err Frames"      [expr [reg_read $BASE_STATS     $REG_CRCERR_LO          ]]]
    set msg_Right_Size_with_FCS_Err_log     "Right Size with FCS Err Frames"    [expr [reg_read $BASE_STATS     $REG_CRCERR_SIZEOK_LO   ]]]
    set msg_Multicast_data_Err_Frames_log   "Multicast data  Err Frames"        [expr [reg_read $BASE_STATS     $REG_MCAST_DATA_ERR_LO  ]]]
    set msg_Broadcast_data_Err_Frames_log   "Broadcast data Err  Frames"        [expr [reg_read $BASE_STATS     $REG_BCAST_DATA_ERR_LO  ]]]
    set msg_Unicast_data_Err_Frames_log     "Unicast data Err  Frames"          [expr [reg_read $BASE_STATS     $REG_UCAST_DATA_ERR_LO  ]]]
    set msg_Multicast_ctrl_Err_Frames_log   "Multicast control  Err Frames"     [expr [reg_read $BASE_STATS     $REG_MCAST_CTRL_ERR_LO  ]]]
    set msg_Broadcast_ctrl_Err_Frames_log   "Broadcast control Err  Frames"     [expr [reg_read $BASE_STATS     $REG_BCAST_CTRL_ERR_LO  ]]]
    set msg_Unicast_control_Err_Frames_log  "Unicast control Err  Frames"       [expr [reg_read $BASE_STATS     $REG_UCAST_CTRL_ERR_LO  ]]]
    set msg_Pause_control_Err_Frames_log    "Pause control Err  Frames"         [expr [reg_read $BASE_STATS     $REG_PAUSE_ERR_LO       ]]]

    set msg_64_Byte_Frames_log              "64 Byte Frames"                [expr [reg_read $BASE_STATS     $REG_64B_LO             ]]]
    set msg_65_127_Byte_Frames_log          "65 - 127 Byte Frames"          [expr [reg_read $BASE_STATS     $REG_65to127B_LO        ]]]
    set msg_128_255_Byte_Frames_log         "128 - 255 Byte Frames"         [expr [reg_read $BASE_STATS     $REG_128to255B_LO       ]]]
    set msg_256_511_Byte_Frames_log         "256 - 511 Byte Frames"         [expr [reg_read $BASE_STATS     $REG_256to511B_LO       ]]]
    set msg_512_1023_Byte_Frames_log        "512 - 1023 Byte Frames"        [expr [reg_read $BASE_STATS     $REG_512to1023B_LO      ]]]
    set msg_1024_1518_Byte_Frames_log       "1024 - 1518 Byte Frames"       [expr [reg_read $BASE_STATS     $REG_1024to1518B_LO     ]]]
    set msg_1519_MAX_Byte_Frames_log        "1519 - MAX Byte Frames"        [expr [reg_read $BASE_STATS     $REG_1519toMAXB_LO      ]]]
    set msg_More_than_MAX_Byte_Frames_log   "> MAX Byte Frames"             [expr [reg_read $BASE_STATS     $REG_OVERSIZE_LO        ]]]
    set msg_Multicast_data_OK_Frames_log    "Multicast data  OK  Frames"    [expr [reg_read $BASE_STATS     $REG_MCAST_DATA_OK_LO   ]]]
    set msg_Broadcast_data_OK_Frames_log    "Broadcast data OK   Frames"    [expr [reg_read $BASE_STATS     $REG_BCAST_DATA_OK_LO   ]]]
    set msg_Unicast_data_OK_Frames_log      "Unicast data OK   Frames"      [expr [reg_read $BASE_STATS     $REG_UCAST_DATA_OK_LO   ]]]
    set msg_Multicast_Control_Frames_log    "Multicast Control Frames"      [expr [reg_read $BASE_STATS     $REG_MCAST_CTRL_OK_LO   ]]]
    set msg_Broadcast_Control_Frames_log    "Broadcast Control Frames"      [expr [reg_read $BASE_STATS     $REG_BCAST_CTRL_OK_LO   ]]]
    set msg_Unicast_Control_Frames_log      "Unicast Control Frames"        [expr [reg_read $BASE_STATS     $REG_UCAST_CTRL_OK_LO   ]]]
    set msg_Pause_Control_Frames_log        "Pause Control Frames"          [expr [reg_read $BASE_STATS     $REG_PAUSE_LO           ]]]

     # ______________________________________________________________________________________________________________________________
     #
    if {$log == "both"} {puts "$msg_hdr_tborder_cli\r"} elseif {$log == "log"} {} else {puts "$msg_hdr_tborder_cli\r"}
    if {$log == "both"} {putl "$msg_hdr_title_log"; puts "$msg_hdr_title_cli\r"} elseif {$log == "log"} {putl "$msg_hdr_title_log"} else {puts "$msg_hdr_title_cli\r"}
    if {$log == "both"} {puts "$msg_hdr_lborder_cli\r"} elseif {$log == "log"} {} else {puts "$msg_hdr_lborder_cli\r"}
    if {$log == "both"} {putl "$msg_Tx_Title_log"; puts "$msg_Tx_Title_cli\r"} elseif {$log == "log"} {putl "$msg_Tx_Title_log"} else {puts "$msg_Tx_Title_cli\r"}
    
    if {$log == "both"} {putl "$msg_Tx_Frame_Starts_log"; puts "$msg_Tx_Frame_Starts_cli\r"} elseif {$log == "log"} {putl "$msg_Tx_Frame_Starts_log"} else {puts "$msg_Tx_Frame_Starts_cli\r"}
    if {$log == "both"} {putl "$msg_8_byte_data_blocks_log"; puts "$msg_8_byte_data_blocks_cli\r"} elseif {$log == "log"} {putl "$msg_8_byte_data_blocks_log"} else {puts "$msg_8_byte_data_blocks_cli\r"}

    
    if {$log == "both"} {putl "$msg_64_Byte_Frames_log"; puts "$msg_64_Byte_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_64_Byte_Frames_log"} else {puts "$msg_64_Byte_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_65_127_Byte_Frames_log"; puts "$msg_65_127_Byte_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_65_127_Byte_Frames_log"} else {puts "$msg_65_127_Byte_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_128_255_Byte_Frames_log"; puts "$msg_128_255_Byte_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_128_255_Byte_Frames_log"} else {puts "$msg_128_255_Byte_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_256_511_Byte_Frames_log"; puts "$msg_256_511_Byte_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_256_511_Byte_Frames_log"} else {puts "$msg_256_511_Byte_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_512_1023_Byte_Frames_log"; puts "$msg_512_1023_Byte_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_512_1023_Byte_Frames_log"} else {puts "$msg_512_1023_Byte_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_1024_1518_Byte_Frames_log"; puts "$msg_1024_1518_Byte_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_1024_1518_Byte_Frames_log"} else {puts "$msg_1024_1518_Byte_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_1519_MAX_Byte_Frames_log"; puts "$msg_1519_MAX_Byte_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_1519_MAX_Byte_Frames_log"} else {puts "$msg_1519_MAX_Byte_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_More_than_MAX_Byte_Frames_log"; puts "$msg_More_than_MAX_Byte_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_More_than_MAX_Byte_Frames_log"} else {puts "$msg_More_than_MAX_Byte_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Multicast_data_Err_Frames_log"; puts "$msg_Multicast_data_Err_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Multicast_data_Err_Frames_log"} else {puts "$msg_Multicast_data_Err_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Multicast_data_OK_Frames_log"; puts "$msg_Multicast_data_OK_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Multicast_data_OK_Frames_log"} else {puts "$msg_Multicast_data_OK_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Broadcast_data_Err_Frames_log"; puts "$msg_Broadcast_data_Err_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Broadcast_data_Err_Frames_log"} else {puts "$msg_Broadcast_data_Err_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Broadcast_data_OK_Frames_log"; puts "$msg_Broadcast_data_OK_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Broadcast_data_OK_Frames_log"} else {puts "$msg_Broadcast_data_OK_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Unicast_data_Err_Frames_log"; puts "$msg_Unicast_data_Err_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Unicast_data_Err_Frames_log"} else {puts "$msg_Unicast_data_Err_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Unicast_data_OK_Frames_log"; puts "$msg_Unicast_data_OK_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Unicast_data_OK_Frames_log"} else {puts "$msg_Unicast_data_OK_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Multicast_Control_Frames_log"; puts "$msg_Multicast_Control_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Multicast_Control_Frames_log"} else {puts "$msg_Multicast_Control_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Broadcast_Control_Frames_log"; puts "$msg_Broadcast_Control_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Broadcast_Control_Frames_log"} else {puts "$msg_Broadcast_Control_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Unicast_Control_Frames_log"; puts "$msg_Unicast_Control_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Unicast_Control_Frames_log"} else {puts "$msg_Unicast_Control_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Pause_Control_Frames_log"; puts "$msg_Pause_Control_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Pause_Control_Frames_log"} else {puts "$msg_Pause_Control_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Fragmented_Frames_log"; puts "$msg_Fragmented_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Fragmented_Frames_log"} else {puts "$msg_Fragmented_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Jabbered_Frames_log"; puts "$msg_Jabbered_Frames_cli\r"} elseif {$log == "log"} {putl "$msg_Jabbered_Frames_log"} else {puts "$msg_Jabbered_Frames_cli\r"}
    if {$log == "both"} {putl "$msg_Right_Size_with_FCS_Err_log\r"; puts "$msg_Right_Size_with_FCS_Err_cli\n"} elseif {$log == "log"} {putl "$msg_Right_Size_with_FCS_Err_log\r"} else {puts "$msg_Right_Size_with_FCS_Err_cli\n"} 
    unpause_stats $reg_base
}

proc CHK_TXSTATS {} {
    global BASE_TXSTATS
    check_stats $BASE_TXSTATS Tx
}

proc CHK_RXSTATS {} {
    global BASE_RXSTATS
    check_stats $BASE_RXSTATS Rx
}

proc chkmac_stats {} {
    CHK_RXSTATS
    CHK_TXSTATS
}

 # ___________________________________________________________________________________
 # For internal debug purpose -- start 


proc check_stats_internal {reg_base t} {
    global BASE_STATS
    global REG_FRAGMENTS_LO
    global REG_FRAGMENTS_HI
    global REG_JABBERS_LO
    global REG_JABBERS_HI
    global REG_CRCERR_LO
    global REG_CRCERR_SIZEOK_HI
    global REG_CRCERR_SIZEOK_LO
    global REG_CRCERR_HI
    global REG_MCAST_DATA_ERR_LO
    global REG_MCAST_DATA_ERR_HI
    global REG_BCAST_DATA_ERR_LO
    global REG_BCAST_DATA_ERR_HI
    global REG_UCAST_DATA_ERR_LO
    global REG_UCAST_DATA_ERR_HI
    global REG_MCAST_CTRL_ERR_LO
    global REG_MCAST_CTRL_ERR_HI
    global REG_BCAST_CTRL_ERR_LO
    global REG_BCAST_CTRL_ERR_HI
    global REG_UCAST_CTRL_ERR_LO
    global REG_UCAST_CTRL_ERR_HI
    global REG_PAUSE_ERR_HI
    global REG_PAUSE_ERR_LO
    global REG_64B_LO
    global REG_64B_HI
    global REG_65to127B_LO
    global REG_65to127B_HI
    global REG_128to255B_LO
    global REG_128to255B_HI
    global REG_256to511B_LO
    global REG_256to511B_HI
    global REG_512to1023B_LO
    global REG_512to1023B_HI
    global REG_1024to1518B_LO
    global REG_1024to1518B_HI
    global REG_1519toMAXB_LO
    global REG_1519toMAXB_HI
    global REG_OVERSIZE_LO
    global REG_OVERSIZE_HI
    global REG_MCAST_DATA_OK_LO
    global REG_MCAST_DATA_OK_HI
    global REG_BCAST_DATA_OK_LO
    global REG_BCAST_DATA_OK_HI
    global REG_UCAST_DATA_OK_LO
    global REG_UCAST_DATA_OK_HI
    global REG_MCAST_CTRL_OK_LO
    global REG_MCAST_CTRL_OK_HI
    global REG_BCAST_CTRL_OK_LO
    global REG_BCAST_CTRL_OK_HI
    global REG_UCAST_CTRL_OK_LO
    global REG_UCAST_CTRL_OK_HI
    global REG_PAUSE_LO
    global REG_PAUSE_HI
    global REG_RNT_LO
    global REG_RNT_HI
    global REG_ST_LO
    global REG_ST_HI
    global REG_DB_LO
    global REG_DB_HI
    global REG_EBLK_HI
    global REG_EBLK_LO
    global REG_FST_LO
    global REG_FST_HI
    global REG_F_LONG_HI
    global REG_F_LONG_LO
    global REG_STAT_CFG
    global REG_STAT_STATUS

    set BASE_STATS $reg_base
    #for CLI output only
    #for table widths
    set w_des 30
    set w_val 30
    pause_stats $reg_base
    puts " =========================================================================================="
    puts "                        STATISTICS FOR BASE $BASE_STATS ($t)                               "
    puts " =========================================================================================="
    puts "Fragmented Frames                : [expr [stats_read $BASE_STATS     $REG_FRAGMENTS_LO        ]] "
    puts "Jabbered Frames                  : [expr [stats_read $BASE_STATS     $REG_JABBERS_LO          ]] "
    puts "Any Size with FCS Err Frame      : [expr [stats_read $BASE_STATS     $REG_CRCERR_LO           ]] "
    puts "Right Size with FCS Err Fra      : [expr [stats_read $BASE_STATS     $REG_CRCERR_SIZEOK_LO    ]] "
    puts "Multicast data  Err Frames       : [expr [stats_read $BASE_STATS     $REG_MCAST_DATA_ERR_LO   ]] "
    puts "Broadcast data Err  Frames       : [expr [stats_read $BASE_STATS     $REG_BCAST_DATA_ERR_LO   ]] "
    puts "Unicast data Err  Frames         : [expr [stats_read $BASE_STATS     $REG_UCAST_DATA_ERR_LO   ]] "
    puts "Multicast control  Err Frame     : [expr [stats_read $BASE_STATS     $REG_MCAST_CTRL_ERR_LO   ]] "
    puts "Broadcast control Err  Frame     : [expr [stats_read $BASE_STATS     $REG_BCAST_CTRL_ERR_LO   ]] "
    puts "Unicast control Err  Frames      : [expr [stats_read $BASE_STATS     $REG_UCAST_CTRL_ERR_LO   ]] "
    puts "Pause control Err  Frames        : [expr [stats_read $BASE_STATS     $REG_PAUSE_ERR_LO        ]] "
    puts "Fragmented Frames -NO CRC        : [expr [stats_read $BASE_STATS     $REG_RNT_LO        ]] "
    puts "Invalid SOP Err  Frames          : [expr [stats_read $BASE_STATS     $REG_ST_LO        ]] "
    puts "Invalid EOP Err  Frames          : [expr [stats_read $BASE_STATS     $REG_DB_LO        ]] "


    puts "64 Byte Frames                   : [expr [stats_read $BASE_STATS     $REG_64B_LO              ]] "
    puts "65 - 127 Byte Frames             : [expr [stats_read $BASE_STATS     $REG_65to127B_LO         ]] "
    puts "128 - 255 Byte Frames            : [expr [stats_read $BASE_STATS     $REG_128to255B_LO        ]] "
    puts "256 - 511 Byte Frames            : [expr [stats_read $BASE_STATS     $REG_256to511B_LO        ]] "
    puts "512 - 1023 Byte Frames           : [expr [stats_read $BASE_STATS     $REG_512to1023B_LO       ]] "
    puts "1024 - 1518 Byte Frames          : [expr [stats_read $BASE_STATS     $REG_1024to1518B_LO      ]] "
    puts "1519 - MAX Byte Frames           : [expr [stats_read $BASE_STATS     $REG_1519toMAXB_LO       ]] "
    puts "> MAX Byte Frames                : [expr [stats_read $BASE_STATS     $REG_OVERSIZE_LO         ]] "
    puts "$t Frame Starts                  : [expr [stats_read $BASE_STATS     $REG_ST_LO               ]] "
    puts "Multicast data  OK  Frame        : [expr [stats_read $BASE_STATS     $REG_MCAST_DATA_OK_LO    ]] "
    puts "Broadcast data OK   Frame        : [expr [stats_read $BASE_STATS     $REG_BCAST_DATA_OK_LO    ]] "
    puts "Unicast data OK   Frames         : [expr [stats_read $BASE_STATS     $REG_UCAST_DATA_OK_LO    ]] "
    puts "Multicast Control Frames         : [expr [stats_read $BASE_STATS     $REG_MCAST_CTRL_OK_LO    ]] "
    puts "Broadcast Control Frames         : [expr [stats_read $BASE_STATS     $REG_BCAST_CTRL_OK_LO    ]] "
    puts "Unicast Control Frames           : [expr [stats_read $BASE_STATS     $REG_UCAST_CTRL_OK_LO    ]] "
    puts "Pause Control Frames             : [expr [stats_read $BASE_STATS     $REG_PAUSE_LO            ]] "
    unpause_stats $reg_base
}

proc CHK_TXSTATS_INTERNAL {} {
    global BASE_TXSTATS
    check_stats_internal $BASE_TXSTATS Tx
}

proc CHK_RXSTATS_INTERNAL {} {
    global BASE_RXSTATS
    check_stats_internal $BASE_RXSTATS Rx
}

proc chkmac_stats_internal {} {
    CHK_RXSTATS_INTERNAL
    CHK_TXSTATS_INTERNAL
}

 # ___________________________________________________________________________________
 # For internal debug purpose -- end 

