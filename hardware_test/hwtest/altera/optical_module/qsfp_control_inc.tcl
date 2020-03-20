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
#    word address to byte address translations should
#    happen inside the basic.tcl defining write & read
# ______________________________________________________

source [file join [file dirname [info script]] "../sval_top/reg_map_inc.tcl"]

set REG_MODNAME             0x00
set REG_SCRATCH             0x01
set REG_QSFP_ENABLE         0x02
set REG_QSFP_STATUS         0x03

set REG_I2C_WRITE_DATA      0x20
set REG_I2C_READ_DATA_STATS 0x21
set REG_QSFP_I2C_ADDR       0x22
set REG_I2C_READ_WRITE      0x23

set QSFP_SLAVE_ADDR         0x50

# =====================================================
#     test utilities
# =====================================================

# PLL Functions

proc restore_pll_default {} {
    freeze_pll_dco
    recall_default_pll_settings
    unfreeze_pll_dco
    pll_assert_new_freq
}

proc increase_rfreq { n } {
    set rfreq [get_pll_rfreq_val]
    puts $rfreq
    set rfreq [expr {$rfreq + $n}]
    #puts $rfreq
    freeze_pll_dco
    set_pll_rfreq_val $rfreq
    unfreeze_pll_dco
    pll_assert_new_freq
    puts [get_pll_rfreq_val]
}

proc pll_assert_new_freq {} {
    pll_set_bit 135 6
}

proc recall_default_pll_settings {} {
    pll_set_bit 135 0
}

proc freeze_pll_dco {} {
    pll_set_bit 137 4
}

proc unfreeze_pll_dco {} {
    pll_clear_bit 137 4
}

proc pll_set_bit { addr bit } {
    set data [pll_i2c_read $addr]
    set data [expr {$data | (1 << $bit)}]
    pll_i2c_write $addr $data
}

proc pll_clear_bit { addr bit } {
    set data [pll_i2c_read $addr]
    set data [expr {$data & ( ~(1 << $bit))}]
    pll_i2c_write $addr $data
}

proc get_pll_freq {} {
    set fxtal   114.20033446717018; # Calculated
    set n1      [get_pll_n1]
    set hsdiv   [get_pll_hsdiv]
    set rfreq   [get_pll_rfreq]
    set freq    [expr {${fxtal}*${rfreq}/(${hsdiv}*${n1})}]
    return $freq
}

proc calc_fxtal { fout } {
    set n1      [get_pll_n1]
    set hsdiv   [get_pll_hsdiv]
    set rfreq   [get_pll_rfreq]
    set fxtal [expr {${fout}*${hsdiv}*${n1}/${rfreq}}]
    return $fxtal
}

proc get_pll_rfreq {} {
    set num [get_pll_rfreq_val]
    set den [expr {pow(2, 28)}]
    set freq [expr { 1.0*${num}/${den} }]
    return $freq
}

proc get_pll_rfreq_val {} {
    set b4 [pll_i2c_read 8]
    set b4 [expr {$b4 & 0b111111}]
    set b3 [pll_i2c_read 9]
    set b2 [pll_i2c_read 10]
    set b1 [pll_i2c_read 11]
    set b0 [pll_i2c_read 12]

    set rfreq $b0
    set rfreq [expr {$rfreq + ($b1 << 8)}]
    set rfreq [expr {$rfreq + ($b2 << 16)}]
    set rfreq [expr {$rfreq + ($b3 << 24)}]
    set rfreq [expr {$rfreq + ($b4 << 32)}]

    return $rfreq
}

proc set_pll_rfreq_val { val } {
    set b0 [get_byte $val 0]
    set b1 [get_byte $val 1]
    set b2 [get_byte $val 2]
    set b3 [get_byte $val 3]
    set b4 [get_byte $val 4]
    set b4 [expr {$b4 & 0b111111}]

    set b4temp [pll_i2c_read 8]
    set b4temp [expr {$b4temp & 0b11000000}]
    set b4 [expr {$b4temp | $b4}]

    pll_i2c_write 12 $b0
    pll_i2c_write 11 $b1
    pll_i2c_write 10 $b2
    pll_i2c_write 9  $b3
    pll_i2c_write 8  $b4
}



proc get_pll_n1 {} {
    set n1_high [pll_i2c_read 7]
    set n1_high [expr {($n1_high & 0b11111)}]
    set n1_low  [pll_i2c_read 8]
    set n1_low  [expr {($n1_low >> 6) & 0b11}]
    set n1 [expr {($n1_high << 2) + ($n1_low)}]
    set n1 [expr {$n1 + 1}]
    return $n1
}

proc get_pll_hsdiv {} {
    set hsdiv_addr 7
    set data [pll_i2c_read $hsdiv_addr]
    set val [expr {($data >> 5) & 0b111}]

    switch $val {
        0 { set hsdiv 4 }
        1 { set hsdiv 5 }
        2 { set hsdiv 6 }
        3 { set hsdiv 7 }
        5 { set hsdiv 9 }
        7 { set hsdiv 11 }
        default { set hsdiv 0 }
    }

    return $hsdiv
}

proc pll_i2c_read { addr } {
    set slave_addr [get_y3_pll_addr]
    set data [read_i2c $slave_addr $addr]
    return $data
}

proc pll_i2c_write { addr data } {
    set slave_addr [get_y3_pll_addr]
    blocking_i2c_write $slave_addr $addr $data
}

proc get_y3_pll_addr {} { return 0x66 }

# QSFP functions
proc qsfp_on {} {
    global REG_QSFP_ENABLE
    qsfp_write $REG_QSFP_ENABLE 1
}

proc qsfp_off {} {
    global REG_QSFP_ENABLE
    qsfp_write $REG_QSFP_ENABLE 0
}

proc print_id {} {
    global REG_MODNAME
    set data [qsfp_read $REG_MODNAME]
    set str  [integer2string $data]
    puts $str
    return $str
}

proc read_qsfp_scratch {} {
    global REG_SCRATCH
    set data [qsfp_read $REG_SCRATCH]
    return $data
}

proc write_qsfp_scratch { data } {
    global REG_SCRATCH
    qsfp_write $REG_SCRATCH $data
}
proc qsfp_read { addr } {
    global BASE_PMDC
    set data [reg_read $BASE_PMDC $addr]
    return $data
}

proc qsfp_write { addr data } {
    global BASE_PMDC
    reg_write $BASE_PMDC $addr $data
}

proc qsfp_inserted {} {
    set bitnum 1
    set data [get_qsfp_status]
    set val [get_data_bit $data $bitnum]
    return $bitnum
}

proc get_qsfp_alarm {} {
    set bitnum 6
    set data [get_qsfp_status]
    set val [get_data_bit $data $bitnum]
    return $val
}

proc qsfp_inserted {} {
    set bitnum 1
    set data [get_qsfp_status]
    set val [get_data_bit $data $bitnum]
    return $bitnum
}

proc get_qsfp_reset {} {
    set bitnum 0
    set data [get_qsfp_status]
    set val [get_data_bit $data $bitnum]
    return $bitnum
}

proc get_qsfp_status {} {
    global REG_QSFP_STATUS
    set data [qsfp_read $REG_QSFP_STATUS]
    return $data
}

# Returns true if the qsfp module is enabled
proc get_qsfp_enabled {} {
    global REG_QSFP_ENABLE
    set data [qsfp_read $REG_QSFP_ENABLE]
    return $data
}

############## I2C functions #################

# Returns the 7 bit slave addresses of a devices
# responding on the i2c bus
proc print_valid_i2c_slave_addresses {} {
    for {set i 0} {$i < 128} {incr i} {
        set valid [test_i2c_slave_ack $i]
        if {$valid} {
            set i_hex [format 0x%02X $i]
            puts $i_hex
        }
    }
}

# Performs and i2c read
proc read_i2c { slave_addr mem_addr } {
    set_i2c_slave_addr $slave_addr
    set_i2c_mem_addr $mem_addr
    start_i2c_read
    set res [wait_i2c_ready]

    if {$res == -1} {
        #Wait timed out
        return 0
    } else {
        set data [i2c_read_data]
        return $data
    }
}

# Performs a test read of a given slave address
# at mem address 0. Returns 1 if a devices
# acknowledges the read.
# Quick way to verify slave address
proc test_i2c_slave_ack { slave_addr } {
    set_i2c_slave_addr $slave_addr
    set_i2c_mem_addr 0
    start_i2c_read
    wait_i2c_ready
    set ack_fail [i2c_ack_failure]
    if {$ack_fail} {
        return 0
    } else {
        return 1
    }
}

# A blocking version of the write_i2c function.
# Returns when the write is complete.
proc blocking_i2c_write { slave_addr mem_addr data } {
    write_i2c $slave_addr $mem_addr $data
    set res [wait_i2c_ready]
    return $res
}

# Performs an i2c write.
proc write_i2c { slave_addr mem_addr data } {
    set_i2c_slave_addr $slave_addr
    set_i2c_mem_addr $mem_addr
    set_i2c_write_data $data
    start_i2c_write
}

# A blocking spin lock function which
# returns after the i2c controller
# de-asserts its busy signal.
# Returns -1 if wait times out
proc wait_i2c_ready {} {
    for {set i 0} {$i < 100} {incr i} {
        set busy [i2c_busy]
        if {$busy == 0} {
            return 0
        }
        after 10
    }
    # Timed out
    return -1
}

# Pulses the i2c read bit to initiate
# a read cycle
proc start_i2c_read {} {
    global REG_I2C_READ_WRITE
    qsfp_write $REG_I2C_READ_WRITE 1
    qsfp_write $REG_I2C_READ_WRITE 0
}

# Pulses the i2c write bit to initiate
# a write cycle
proc start_i2c_write {} {
    global REG_I2C_READ_WRITE
    qsfp_write $REG_I2C_READ_WRITE 2
    qsfp_write $REG_I2C_READ_WRITE 0
}

# Sets the i2c slave address
proc set_i2c_slave_addr { addr } {
    set i2c_addr [get_i2c_addr]
    set i2c_addr [expr {$i2c_addr & 0x00FF}]
    set slave_addr [expr {$addr & 0x7F}]
    set shifted_slave_addr [expr {$slave_addr << 9}]
    set new_addr [expr {$shifted_slave_addr | $i2c_addr}]
    set_i2c_addr $new_addr
}

# Sets the i2c target memmory address
proc set_i2c_mem_addr { addr } {
    set i2c_addr [get_i2c_addr]
    set i2c_addr [expr {$i2c_addr & 0xFF00}]
    set mem_addr [expr {$addr & 0xFF}]
    set new_addr [expr {$i2c_addr | $mem_addr}]
    set_i2c_addr $new_addr
}

# Returns the i2c address register
proc get_i2c_addr {} {
    global REG_QSFP_I2C_ADDR
    set addr [qsfp_read $REG_QSFP_I2C_ADDR]
    return $addr
}

# Sets the i2c address register which contains
# the i2c slave address and target mem address
proc set_i2c_addr { addr } {
    global REG_QSFP_I2C_ADDR
    qsfp_write $REG_QSFP_I2C_ADDR $addr
}

# Indicates that the i2c module is in the
# middle of a read or write cycle.
proc i2c_busy {} {
    set reg_data [get_i2c_data_stats]
    set busy [get_data_bit $reg_data 31]
    return $busy
}

# Returns the ack failure indicator bit
# High indicates that the last read was
# not acknowledged
proc i2c_ack_failure {} {
    set reg_data [get_i2c_data_stats]
    set fail [get_data_bit $reg_data 30]
    return $fail
}

# Returns the data stored in the register that
# the i2c controller writes to after it's finished
# reading
proc i2c_read_data {} {
    set reg_data [get_i2c_data_stats]
    set data [expr {$reg_data & 0xFF}]
    return $data
}

# Reads the register from the i2c module containing
# the read data and read status
proc get_i2c_data_stats {} {
    global REG_I2C_READ_DATA_STATS
    set data [qsfp_read $REG_I2C_READ_DATA_STATS]
    return $data
}

# Writes to a register that the i2c controller
# uses for the write data
proc set_i2c_write_data { data } {
    global REG_I2C_WRITE_DATA
    qsfp_write $REG_I2C_WRITE_DATA $data
}

############## Misc functions #################

# Converts the first four bytes of an integer
# to ascii characters
proc integer2string { num } {
    set str ""

    for {set i 0} {$i < 4} {incr i} {
        set shift_bits [expr {$i * 8}]
        set shift_num  [expr {$num >> $shift_bits}]
        set mask_num   [expr {$shift_num & 0xFF}]
        set c [format %c $mask_num]
        set str "${c}${str}"
    }
    return $str
}

# Returns the specified bit number of a file
proc get_data_bit { data bit_num } {
    set mask_data [expr {$data >> $bit_num}]
    set bit [expr {$mask_data & 1}]
    return $bit
}

# Returns the byte number out of a multibyte value
proc get_byte { data byte_num } {
    set shift_bits [expr {$byte_num * 8}]
    set byte [expr {$data >> $shift_bits}]
    set byte [expr {$byte & 0xFF}]
    return $byte
}
