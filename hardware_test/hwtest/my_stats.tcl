set STATS_BASE  0x20000000
set LATENCY_BASE  0x28000000
set TX_TRACKER_BASE  0x30000000
set TOP_REG_BASE  0x22000000
set PCIE_BASE    0x2A000000

# These **must be kept in sync** with the variables with the same name on
# `hardware/src/constants.sv` and `software/norman/pcie.h`.
set MAX_NB_APPS 256
# set MAX_NB_FLOWS 65536
set MAX_NB_FLOWS 8192

set REGS_PER_PKT_QUEUE 4
set REGS_PER_DSC_QUEUE 8

#PCIE reg
set PCIE_CTRL_REG       0

set NB_CTRL_REGS 4
set NB_QUEUE_REGS 16384

set PKT_QUEUE_OFFSET $NB_CTRL_REGS
set DSC_QUEUE_OFFSET [
    expr $PKT_QUEUE_OFFSET + $MAX_NB_FLOWS * $REGS_PER_PKT_QUEUE]

set SCRATCH     0
set REG_CTRL    1

set RX_STATS    2
set RX_MAX_FLIT 3
set RX_CYCLE    4
set RX_FLIT     5
set RX_PKT      6
set RX_BYTE     7
set RX_MAX_PKT     9
set RX_WARMUP_PKT  10
set RX_RECV_PKT  11
set O_RX_RECV_PKT  12
set RX_RECV_NF_PKT  13


set TX_STATS    22
set TX_MAX_FLIT 23
set TX_CYCLE    24
set TX_FLIT     25
set TX_PKT      26
set TX_BYTE     27
set TX_LATENCY  28
set TX_MAX_PKT     29
set TX_WARMUP_PKT  30


#TOP reg
set IN_PKT                    0
set OUT_PKT                   1
set OUT_IN_COMP_PKT           2
set OUT_PARSER_PKT            3
set MAX_PARSER_FIFO           4
set FD_IN_PKT                 5
set FD_OUT_PKT                6
set MAX_FD_OUT_FIFO           7
set IN_DATAMOVER_PKT          8
set IN_EMPTYLIST_PKT          9
set OUT_EMPTYLIST_PKT         10
set PKT_ETH                   11
set PKT_DROP                  12
set PKT_PCIE                  13
set MAX_DM2PCIE_FIFO          14
set MAX_DM2PCIE_META_FIFO     15
set PCIE_PKT                  16
set PCIE_META                 17
set DM_PCIE_PKT               18
set DM_PCIE_META              19
set DM_ETH_PKT                20
set RX_DMA_PKT                21
set RX_PKT_HEAD_UPD           22
set TX_DSC_TAIL_UPD           23
set DMA_REQUEST               24
set RULE_SET                  25
set EVICTION                  26
set MAX_PDUGEN_PKT_FIFO       27
set MAX_PDUGEN_META_FIFO      28
set PCIE_CORE_FULL            29
set RX_DMA_DSC_CNT            30
set RX_DMA_DSC_DROP_CNT       31
set RX_DMA_PKT_FLIT_CNT       32
set RX_DMA_PKT_FLIT_DROP_CNT  33
set CPU_DSC_BUF_FULL          34
set CPU_DSC_BUF_IN            35
set CPU_DSC_BUF_OUT           36
set CPU_PKT_BUF_FULL          37
set CPU_PKT_BUF_IN            38
set CPU_PKT_BUF_OUT           39
set PCIE_ST_ORD_IN            40
set PCIE_ST_ORD_OUT           41
set MAX_PCIE_PKT_FIFO         42
set MAX_PCIE_META_FIFO        43
set PCIE_RX_IGNORED_HEAD      44
set PCIE_TX_Q_FULL_SIGNALS    45
set PCIE_TX_DSC_CNT           46
set PCIE_TX_EMPTY_TAIL_CNT    47
set PCIE_TX_DSC_READ_CNT      48
set PCIE_TX_PKT_READ_CNT      49
set PCIE_TX_BATCH_CNT         50
set PCIE_TX_MAX_INFLIGHT_DSCS 51
set PCIE_TX_MAX_NB_REQ_DSCS   52
set TX_DMA_PKT                53
set PCIE_TOP_FULL_SIGNALS_1   54
set PCIE_TOP_FULL_SIGNALS_2   55

set log 0
#clock period
set cp 2.56
set hist_size 1024

proc set_up {} {
    #set_pkt_size 117
    #load_pkt
    #load_meta
    set_rx_warmup_pkt 1000
    set_tx_warmup_pkt 1000
    set_rx_max_pkt 90000
    set_tx_max_pkt 90000
}

proc get_stats {} {
    rx_stats
    tx_stats
}


proc set_clear {} {
    global STATS_BASE
    global REG_CTRL
    global TX_LATENCY
    global rdata
    global wdata

    #hist states return to write.
    set rdata [reg_read $STATS_BASE $TX_LATENCY]
    set rdata [expr $rdata & 0x0]
    reg_write $STATS_BASE $TX_LATENCY $rdata

    reg_write $STATS_BASE $REG_CTRL 1
    sleep 1

    reg_write $STATS_BASE $REG_CTRL 0
}


############RX#####################
proc set_rx_max_flit {MAX_SIZE} {
    global STATS_BASE
    global RX_MAX_FLIT
    global rdata
    global wdata
    reg_write $STATS_BASE $RX_MAX_FLIT $MAX_SIZE
}

proc set_rx_max_pkt {MAX_SIZE} {
    global STATS_BASE
    global RX_MAX_PKT
    global rdata
    global wdata
    reg_write $STATS_BASE $RX_MAX_PKT $MAX_SIZE
}

proc set_rx_warmup_pkt {MAX_SIZE} {
    global STATS_BASE
    global RX_WARMUP_PKT
    global rdata
    global wdata
    reg_write $STATS_BASE $RX_WARMUP_PKT $MAX_SIZE
}

proc get_rx_max_flit {} {
    global STATS_BASE
    global RX_MAX_FLIT
    #global log
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $RX_MAX_FLIT]
    return $rdata
}

proc check_rx_done {} {
    global STATS_BASE
    global RX_STATS
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $RX_STATS]
    if {$rdata == 1} {
        puts "Done"
    } else {
        puts "Not Done yet"
    }
}

proc get_rx_cycle {} {
    global STATS_BASE
    global RX_CYCLE
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $RX_CYCLE]
    return $rdata
}

proc get_rx_flit {} {
    global STATS_BASE
    global RX_FLIT
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $RX_FLIT]
    return $rdata
}

proc get_rx_pkt {} {
    global STATS_BASE
    global RX_PKT
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $RX_PKT]
    return $rdata
}

proc get_rx_byte {} {
    global STATS_BASE
    global RX_BYTE
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $RX_BYTE]
    return $rdata
}

proc get_rx_recv_pkt {} {
    global STATS_BASE
    global RX_RECV_PKT
    global O_RX_RECV_PKT
    global RX_RECV_NF_PKT
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $RX_RECV_PKT]
    puts "RX_RECV_PKT: $rdata"
    set rdata [reg_read $STATS_BASE $O_RX_RECV_PKT]
    puts "O_RX_RECV_PKT: $rdata"
    set rdata [reg_read $STATS_BASE $RX_RECV_NF_PKT]
    puts "RX_RECV_NF_PKT: $rdata"
}


proc rx_stats {} {
    set fp [open "res.txt" w+]
    global cp
    set a [get_rx_max_flit]
    set a [expr $a]
    puts "RX_MAX_FLITS: $a"
    puts $fp "RX_MAX_FLITS: $a"
    set rx_flit [get_rx_flit]
    set rx_flit [expr $rx_flit]
    puts "RX_FLITS: $rx_flit"
    puts $fp "RX_FLITS: $rx_flit"
    set a [get_rx_pkt]
    set a [expr $a]
    puts "RX_PKT: $a"
    puts $fp "RX_PKT: $a"
    #set byte [get_rx_byte]
    #set byte [expr $byte]
    set byte [expr $rx_flit * 64]
    puts "RX_BYTE: $byte"
    puts $fp "RX_BYTE: $byte"
    set cycle [get_rx_cycle]
    set cycle [expr $cycle]
    puts "RX_CYCLE: $cycle"
    puts $fp "RX_CYCLE: $cycle"
    set xput [expr $byte*8.0/($cycle*$cp)]
    puts "RX XPUT: $xput Gbps"
    puts $fp "RX XPUT: $xput Gbps"
    close $fp
}

############TX#####################

proc set_tx_max_flit {MAX_SIZE} {
    global STATS_BASE
    global TX_MAX_FLIT
    global rdata
    global wdata
    reg_write $STATS_BASE $TX_MAX_FLIT $MAX_SIZE
}

proc set_tx_max_pkt {MAX_SIZE} {
    global STATS_BASE
    global TX_MAX_PKT
    global rdata
    global wdata
    reg_write $STATS_BASE $TX_MAX_PKT $MAX_SIZE
}

proc set_tx_warmup_pkt {MAX_SIZE} {
    global STATS_BASE
    global TX_WARMUP_PKT
    global rdata
    global wdata
    reg_write $STATS_BASE $TX_WARMUP_PKT $MAX_SIZE
}


proc get_tx_max_flit {} {
    global STATS_BASE
    global TX_MAX_FLIT
    #global log
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $TX_MAX_FLIT]
    return $rdata
}

proc check_tx_done {} {
    global STATS_BASE
    global TX_STATS
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $TX_STATS]
    if {$rdata == 1} {
        puts "Done"
    } else {
        puts "Not Done yet"
    }
}

proc get_tx_cycle {} {
    global STATS_BASE
    global TX_CYCLE
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $TX_CYCLE]
    return $rdata
}

proc get_tx_flit {} {
    global STATS_BASE
    global TX_FLIT
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $TX_FLIT]
    return $rdata
}

proc get_tx_pkt {} {
    global STATS_BASE
    global TX_PKT
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $TX_PKT]
    return $rdata
}

proc get_tx_byte {} {
    global STATS_BASE
    global TX_BYTE
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $TX_BYTE]
    return $rdata
}

proc get_tx_latency {} {
    global STATS_BASE
    global TX_LATENCY
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $TX_LATENCY]
    return $rdata
}

proc get_tx_fetch {} {
    global STATS_BASE
    global TX_LATENCY
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $TX_LATENCY]
    set rdata [expr $rdata & 1]
    return $rdata
}

proc set_tx_fetch {} {
    global STATS_BASE
    global TX_LATENCY
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $TX_LATENCY]
    set wdata [expr $rdata | 1]
    reg_write $STATS_BASE $TX_LATENCY $wdata
}


proc get_tx_scale {} {
    global STATS_BASE
    global TX_LATENCY
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $TX_LATENCY]
    set rdata [expr $rdata >> 1]
    return $rdata
}

proc set_tx_scale {tx_scale} {
    global STATS_BASE
    global TX_LATENCY
    global rdata
    global wdata
    set rdata [reg_read $STATS_BASE $TX_LATENCY]
    set fetch [expr $rdata & 1]
    set wdata [expr ($tx_scale << 1) | $fetch]
    reg_write $STATS_BASE $TX_LATENCY $wdata
}

proc tx_stats {} {
    global cp
    set fp [open "res.txt" a+]
    set a [get_tx_max_flit]
    set a [expr $a]
    puts "TX_MAX_FLITS: $a"
    puts $fp "TX_MAX_FLITS: $a"
    set tx_flit [get_tx_flit]
    set tx_flit [expr $tx_flit]
    puts "TX_FLITS: $tx_flit"
    puts $fp "TX_FLITS: $tx_flit"
    set a [get_tx_pkt]
    set a [expr $a]
    puts "TX_PKT: $a"
    puts $fp "TX_PKT: $a"
    #set byte [get_tx_byte]
    #set byte [expr $byte]
    set byte [expr $tx_flit * 64]
    puts "TX_BYTE: $byte"
    puts $fp "TX_BYTE: $byte"
    set cycle [get_tx_cycle]
    set cycle [expr $cycle]
    puts "TX_CYCLE: $cycle"
    puts $fp "TX_CYCLE: $cycle"
    set xput [expr $byte*8.0/($cycle*$cp)]
    puts "TX XPUT: $xput Gbps"
    puts $fp "TX XPUT: $xput Gbps"
    close $fp
}


################## Latency ##################
proc read_hist {} {
    global STATS_BASE
    global LATENCY_BASE
    global rdata
    global wdata
    global hist_size
    global TX_LATENCY

    set rdata [reg_read $STATS_BASE $TX_LATENCY]
    set rdata [expr $rdata | 0x1]
    reg_write $STATS_BASE $TX_LATENCY $rdata

    set fp [open "hist.txt" w+]

    set total 0

    for { set a 0 } { $a < $hist_size } {incr a} {
        set rdata [reg_read $LATENCY_BASE $a]
        set rdata [expr $rdata]
        set total [expr $total + $rdata]
        #puts "$a : $rdata"
        puts $fp "$a : $rdata"
    }
    puts "Total: $total"
    close $fp
}

################## TX_Tracker ##################
proc read_tracker {first_n} {
    global TX_TRACKER_BASE
    global rdata

    for { set a 0 } { $a < $first_n } {incr a} {
        set rdata [reg_read $TX_TRACKER_BASE $a]
        set rdata [expr $rdata]
        puts "$a : $rdata"
    }
}

################## TOP ##################
proc get_top_stats {} {
    global IN_PKT
    global OUT_PKT
    global OUT_IN_COMP_PKT
    global OUT_PARSER_PKT
    global MAX_PARSER_FIFO
    global FD_IN_PKT
    global FD_OUT_PKT
    global MAX_FD_OUT_FIFO
    global IN_DATAMOVER_PKT
    global IN_EMPTYLIST_PKT
    global OUT_EMPTYLIST_PKT
    global PKT_ETH
    global PKT_DROP
    global PKT_PCIE
    global MAX_DM2PCIE_FIFO
    global MAX_DM2PCIE_META_FIFO
    global PCIE_PKT
    global PCIE_META
    global DM_PCIE_PKT
    global DM_PCIE_META
    global DM_ETH_PKT
    global RX_DMA_PKT
    global RX_PKT_HEAD_UPD
    global TX_DSC_TAIL_UPD
    global DMA_REQUEST
    global RULE_SET
    global EVICTION
    global MAX_PDUGEN_PKT_FIFO
    global MAX_PDUGEN_META_FIFO
    global PCIE_CORE_FULL
    global RX_DMA_DSC_CNT
    global RX_DMA_DSC_DROP_CNT
    global RX_DMA_PKT_FLIT_CNT
    global RX_DMA_PKT_FLIT_DROP_CNT
    global CPU_DSC_BUF_FULL
    global CPU_DSC_BUF_IN
    global CPU_DSC_BUF_OUT
    global CPU_PKT_BUF_FULL
    global CPU_PKT_BUF_IN
    global CPU_PKT_BUF_OUT
    global PCIE_ST_ORD_IN
    global PCIE_ST_ORD_OUT
    global MAX_PCIE_PKT_FIFO
    global MAX_PCIE_META_FIFO
    global PCIE_RX_IGNORED_HEAD
    global PCIE_TX_Q_FULL_SIGNALS
    global PCIE_TX_DSC_CNT
    global PCIE_TX_EMPTY_TAIL_CNT
    global PCIE_TX_DSC_READ_CNT
    global PCIE_TX_PKT_READ_CNT
    global PCIE_TX_BATCH_CNT
    global PCIE_TX_MAX_INFLIGHT_DSCS
    global PCIE_TX_MAX_NB_REQ_DSCS
    global TX_DMA_PKT
    global PCIE_TOP_FULL_SIGNALS_1
    global PCIE_TOP_FULL_SIGNALS_2

    set fp [open "top_stats.txt" w+]
    read_top_reg IN_PKT                    $IN_PKT                    $fp
    read_top_reg OUT_PKT                   $OUT_PKT                   $fp
    read_top_reg OUT_IN_COMP_PKT           $OUT_IN_COMP_PKT           $fp
    read_top_reg OUT_PARSER_PKT            $OUT_PARSER_PKT            $fp
    read_top_reg MAX_PARSER_FIFO           $MAX_PARSER_FIFO           $fp
    read_top_reg FD_IN_PKT                 $FD_IN_PKT                 $fp
    read_top_reg FD_OUT_PKT                $FD_OUT_PKT                $fp
    read_top_reg MAX_FD_OUT_FIFO           $MAX_FD_OUT_FIFO           $fp
    read_top_reg IN_DATAMOVER_PKT          $IN_DATAMOVER_PKT          $fp
    read_top_reg IN_EMPTYLIST_PKT          $IN_EMPTYLIST_PKT          $fp
    read_top_reg OUT_EMPTYLIST_PKT         $OUT_EMPTYLIST_PKT         $fp
    read_top_reg PKT_ETH                   $PKT_ETH                   $fp
    read_top_reg PKT_DROP                  $PKT_DROP                  $fp
    read_top_reg PKT_PCIE                  $PKT_PCIE                  $fp
    read_top_reg MAX_DM2PCIE_FIFO          $MAX_DM2PCIE_FIFO          $fp
    read_top_reg MAX_DM2PCIE_META_FIFO     $MAX_DM2PCIE_META_FIFO     $fp
    read_top_reg PCIE_PKT                  $PCIE_PKT                  $fp
    read_top_reg PCIE_META                 $PCIE_META                 $fp
    read_top_reg DM_PCIE_PKT               $DM_PCIE_PKT               $fp
    read_top_reg DM_PCIE_META              $DM_PCIE_META              $fp
    read_top_reg DM_ETH_PKT                $DM_ETH_PKT                $fp
    read_top_reg RX_DMA_PKT                $RX_DMA_PKT                $fp
    read_top_reg RX_PKT_HEAD_UPD           $RX_PKT_HEAD_UPD           $fp
    read_top_reg TX_DSC_TAIL_UPD           $TX_DSC_TAIL_UPD           $fp
    read_top_reg DMA_REQUEST               $DMA_REQUEST               $fp
    read_top_reg RULE_SET                  $RULE_SET                  $fp
    read_top_reg EVICTION                  $EVICTION                  $fp
    read_top_reg MAX_PDUGEN_PKT_FIFO       $MAX_PDUGEN_PKT_FIFO       $fp
    read_top_reg MAX_PDUGEN_META_FIFO      $MAX_PDUGEN_META_FIFO      $fp
    read_top_reg PCIE_CORE_FULL            $PCIE_CORE_FULL            $fp
    read_top_reg RX_DMA_DSC_CNT            $RX_DMA_DSC_CNT            $fp
    read_top_reg RX_DMA_DSC_DROP_CNT       $RX_DMA_DSC_DROP_CNT       $fp
    read_top_reg RX_DMA_PKT_FLIT_CNT       $RX_DMA_PKT_FLIT_CNT       $fp
    read_top_reg RX_DMA_PKT_FLIT_DROP_CNT  $RX_DMA_PKT_FLIT_DROP_CNT  $fp
    read_top_reg CPU_DSC_BUF_FULL          $CPU_DSC_BUF_FULL          $fp
    read_top_reg CPU_DSC_BUF_IN            $CPU_DSC_BUF_IN            $fp
    read_top_reg CPU_DSC_BUF_OUT           $CPU_DSC_BUF_OUT           $fp
    read_top_reg CPU_PKT_BUF_FULL          $CPU_PKT_BUF_FULL          $fp
    read_top_reg CPU_PKT_BUF_IN            $CPU_PKT_BUF_IN            $fp
    read_top_reg CPU_PKT_BUF_OUT           $CPU_PKT_BUF_OUT           $fp
    read_top_reg PCIE_ST_ORD_IN            $PCIE_ST_ORD_IN            $fp
    read_top_reg PCIE_ST_ORD_OUT           $PCIE_ST_ORD_OUT           $fp
    read_top_reg MAX_PCIE_PKT_FIFO         $MAX_PCIE_PKT_FIFO         $fp
    read_top_reg MAX_PCIE_META_FIFO        $MAX_PCIE_META_FIFO        $fp
    read_top_reg PCIE_RX_IGNORED_HEAD      $PCIE_RX_IGNORED_HEAD      $fp
    read_top_reg PCIE_TX_Q_FULL_SIGNALS    $PCIE_TX_Q_FULL_SIGNALS    $fp
    read_top_reg PCIE_TX_DSC_CNT           $PCIE_TX_DSC_CNT           $fp
    read_top_reg PCIE_TX_EMPTY_TAIL_CNT    $PCIE_TX_EMPTY_TAIL_CNT    $fp
    read_top_reg PCIE_TX_DSC_READ_CNT      $PCIE_TX_DSC_READ_CNT      $fp
    read_top_reg PCIE_TX_PKT_READ_CNT      $PCIE_TX_PKT_READ_CNT      $fp
    read_top_reg PCIE_TX_BATCH_CNT         $PCIE_TX_BATCH_CNT         $fp
    read_top_reg PCIE_TX_MAX_INFLIGHT_DSCS $PCIE_TX_MAX_INFLIGHT_DSCS $fp
    read_top_reg PCIE_TX_MAX_NB_REQ_DSCS   $PCIE_TX_MAX_NB_REQ_DSCS   $fp
    read_top_reg PCIE_TOP_FULL_SIGNALS_1   $PCIE_TOP_FULL_SIGNALS_1   $fp
    read_top_reg PCIE_TOP_FULL_SIGNALS_2   $PCIE_TOP_FULL_SIGNALS_2   $fp
    close $fp
}

proc s {} {
    get_top_stats
}

proc read_top_reg {reg_name reg_index fp} {
    global TOP_REG_BASE
    set rdata [reg_read $TOP_REG_BASE $reg_index]
    set decimal [expr $rdata]
    puts "$reg_name: $decimal"
    puts $fp "$reg_name: $decimal"

}

################## sanity_check ##################

proc sanity_check {} {
    global TOP_REG_BASE
    global IN_PKT
    global OUT_IN_COMP_PKT
    global OUT_PARSER_PKT
    global IN_FT_PKT
    global OUT_FT_PKT
    global IN_DATAMOVER_PKT
    global OUT_PKT
    global OUT_DATAMOVER_PKT
    global IN_EMPTYLIST_PKT
    global OUT_EMPTYLIST_PKT
    global PKT_FORWARD
    global PKT_DROP
    global PKT_CHECK
    global PKT_OOO
    global PKT_FORWARD_OOO
    global PKT_DONE

    global FT_REG_BASE
    global FT_FLOW_INSERT
    global FT_FLOW_DEQ
    global FT_LOOKUP_PKT
    global FT_CONC_FLOW
    global FT_CURRENT_FLOW
    global PKT_CNT_FIN
    global PKT_CNT_ACK
    global PKT_INSERT_OOO
    global rdata
    global wdata


    # Test 1
    puts "Check bufferred PKTS in FT"
    set rdata [reg_read $TOP_REG_BASE $IN_FT_PKT]
    set rdata1 [reg_read $TOP_REG_BASE $OUT_FT_PKT]
    set result [expr $rdata - $rdata1]

    set rdata [reg_read $FT_REG_BASE $PKT_INSERT_OOO]
    set rdata1 [reg_read $TOP_REG_BASE $PKT_OOO]
    set result1 [expr $rdata - $rdata1]

    puts "in_ft_pkt - out_ft_pkt = $result"
    puts "pkt_insert_ooo - pkt_ooo = $result1"

    if {$result == $result1} {
        puts "Passed"
    } else {
        puts "Failed"
    }

    ### Test 2
    puts "Check dropped PKTS in datamover"
    set rdata [reg_read $TOP_REG_BASE $IN_DATAMOVER_PKT]
    set rdata1 [reg_read $TOP_REG_BASE $OUT_DATAMOVER_PKT]
    set result [expr $rdata - $rdata1]

    set rdata [reg_read $TOP_REG_BASE $PKT_DROP]
    set result1 [expr $rdata]

    puts "in_datamover_pkt - out_datamover_pkt = $result"
    puts "pkt_drop = $result1"

    if {$result == $result1} {
        puts "Passed"
    } else {
        puts "Failed"
    }

    ### Test 3
    puts "Check Emptylist"
    set rdata [reg_read $TOP_REG_BASE $IN_EMPTYLIST_PKT]
    set rdata1 [reg_read $TOP_REG_BASE $OUT_EMPTYLIST_PKT]
    set result [expr $rdata - $rdata1]

    set rdata [reg_read $FT_REG_BASE $PKT_INSERT_OOO]
    set rdata1 [reg_read $TOP_REG_BASE $PKT_OOO]
    set result1 [expr 1024 - ($rdata - $rdata1)]

    puts "in_empty_pkt - out_empty_pkt = $result"
    puts "1024 - (pkt_insert_ooo - pkt_ooo)= $result1"

    if {$result == $result1} {
        puts "Passed"
    } else {
        puts "Failed"
    }

    ### Test 4
    puts "Check datamover in pkts"
    set rdata [reg_read $TOP_REG_BASE $IN_DATAMOVER_PKT]
    set result [expr $rdata]

    set rdata [reg_read $TOP_REG_BASE $PKT_FORWARD]
    set rdata1 [reg_read $TOP_REG_BASE $PKT_DROP]
    set rdata2 [reg_read $TOP_REG_BASE $PKT_CHECK]
    set rdata3 [reg_read $TOP_REG_BASE $PKT_OOO]
    set result1 [expr $rdata + $rdata1 + $rdata2 + $rdata3]

    puts "in_datamover_pkt = $result"
    puts "pkt_forward + pkt_drop + pkt_check + pkt_ooo = $result1"

    if {$result == $result1} {
        puts "Passed"
    } else {
        puts "Failed"
    }


}

################## PCIE ##################

proc read_pcie_reg {reg_nb} {
    global PCIE_BASE

    set rdata [reg_read $PCIE_BASE $reg_nb]
    puts "$reg_nb : $rdata"
}

proc write_pcie_reg {reg_nb {wdata}} {
    global PCIE_BASE

    reg_write $PCIE_BASE $reg_nb $wdata
}

proc read_pcie {{nb_regs 16}} {
    global PCIE_BASE

    for { set a 0 } { $a < $nb_regs } {incr a} {
        set rdata [reg_read $PCIE_BASE $a]
        puts "$a : $rdata"
    }
}

proc read_pkt_queue {queue_id} {
    global PCIE_BASE
    global REGS_PER_PKT_QUEUE
    global PKT_QUEUE_OFFSET


    for { set a 0 } { $a < $REGS_PER_PKT_QUEUE } {incr a} {
        set rdata [reg_read $PCIE_BASE [
            expr $PKT_QUEUE_OFFSET + $queue_id * $REGS_PER_PKT_QUEUE + $a]]
        puts "$a : $rdata"
    }
}

proc read_dsc_queue {queue_id} {
    global PCIE_BASE
    global REGS_PER_DSC_QUEUE
    global DSC_QUEUE_OFFSET

    for { set a 0 } { $a < $REGS_PER_DSC_QUEUE } {incr a} {
        set rdata [reg_read $PCIE_BASE [
            expr $DSC_QUEUE_OFFSET + $queue_id * $REGS_PER_DSC_QUEUE + $a]]
        puts "$a : $rdata"
    }
}

proc disable_pcie {} {
    global PCIE_BASE
    global PCIE_CTRL_REG

    set rdata [reg_read $PCIE_BASE $PCIE_CTRL_REG]
    set wdata [expr ($rdata | 0x1)]

    reg_write $PCIE_BASE $PCIE_CTRL_REG $wdata

    set_clear
    set_up
}

proc enable_pcie {} {
    global PCIE_BASE
    global PCIE_CTRL_REG

    set rdata [reg_read $PCIE_BASE $PCIE_CTRL_REG]
    set wdata [expr ($rdata & 0xFFFFFFFE)]

    reg_write $PCIE_BASE $PCIE_CTRL_REG $wdata

    set_clear
    set_up
}

proc sw_rst {} {
    global PCIE_BASE
    global PCIE_CTRL_REG
    global NB_CTRL_REGS
    global NB_QUEUE_REGS

    global rdata
    global wdata

    set rdata [reg_read $PCIE_BASE $PCIE_CTRL_REG]
    puts "rdata : $rdata"
    set wdata [expr ( (1 << 27) | $rdata )]

    reg_write $PCIE_BASE $PCIE_CTRL_REG $wdata

    # # clear all queue registers
    # for { set a 0 } { $a < $NB_QUEUE_REGS } {incr a} {
    #     reg_write $PCIE_BASE [expr $a + $NB_CTRL_REGS] 0
    # }


    after 100
    # rewrite old value back
    reg_write $PCIE_BASE $PCIE_CTRL_REG $rdata

    set_clear
    set_up
}

proc set_pkt_buf_size {buf_size} {
    global PCIE_BASE
    global PCIE_CTRL_REG
    global rdata
    global wdata

    set rdata [reg_read $PCIE_BASE $PCIE_CTRL_REG]
    set wdata [expr ( ($buf_size << 1) | ($rdata & 0xF8000001) )]

    reg_write $PCIE_BASE $PCIE_CTRL_REG $wdata

    set_clear
    set_up
}

proc set_dsc_buf_size {buf_size} {
    global PCIE_BASE
    global PCIE_CTRL_REG
    global rdata
    global wdata

    set wr_reg [expr $PCIE_CTRL_REG + 1]

    reg_write $PCIE_BASE $wr_reg $buf_size

    set_clear
    set_up
}

proc set_nb_tx_credits {nb_tx_credits} {
    global PCIE_BASE
    global PCIE_CTRL_REG
    global rdata
    global wdata

    set wr_reg [expr $PCIE_CTRL_REG + 2]
    set rdata [reg_read $PCIE_BASE $wr_reg]
    set wdata [expr (($rdata & 0x80000000) | ($nb_tx_credits & 0x7fffffff))]

    reg_write $PCIE_BASE $wr_reg $nb_tx_credits

    set_clear
    set_up
}

proc set_eth_port {eth_port} {
    global PCIE_BASE
    global PCIE_CTRL_REG
    global rdata
    global wdata

    set wr_reg [expr $PCIE_CTRL_REG + 2]

    set rdata [reg_read $PCIE_BASE $wr_reg]
    set wdata [expr (($rdata & 0x7fffffff) | ($eth_port << 31))]

    reg_write $PCIE_BASE $wr_reg $wdata

    set_clear
    set_up
}

proc set_nb_fallback_queues {nb_fb_queues} {
    global PCIE_BASE
    global PCIE_CTRL_REG
    global rdata
    global wdata

    set wr_reg [expr $PCIE_CTRL_REG + 3]
    set rdata [reg_read $PCIE_BASE $wr_reg]
    set wdata [expr (($rdata & 0xc0000000) | ($nb_fb_queues & 0x3fffffff))]

    reg_write $PCIE_BASE $wr_reg $wdata

    set_clear
    set_up
}

proc set_desc_per_pkt {desc_per_pkt_value} {
    global PCIE_BASE
    global PCIE_CTRL_REG
    global rdata
    global wdata

    set wr_reg [expr $PCIE_CTRL_REG + 3]

    set rdata [reg_read $PCIE_BASE $wr_reg]
    set wdata [expr (($rdata & 0xbfffffff) | ($desc_per_pkt_value << 30))]

    reg_write $PCIE_BASE $wr_reg $wdata

    set_clear
    set_up
}

proc enable_desc_per_pkt {} {
    set_desc_per_pkt 1
}

proc disable_desc_per_pkt {} {
    set_desc_per_pkt 0
}

proc set_rr {rr_value} {
    global PCIE_BASE
    global PCIE_CTRL_REG
    global rdata
    global wdata

    set wr_reg [expr $PCIE_CTRL_REG + 3]

    set rdata [reg_read $PCIE_BASE $wr_reg]
    set wdata [expr (($rdata & 0x7fffffff) | ($rr_value << 31))]

    reg_write $PCIE_BASE $wr_reg $wdata

    set_clear
    set_up
}

proc enable_rr {} {
    set_rr 1
}

proc disable_rr {} {
    set_rr 0
}
