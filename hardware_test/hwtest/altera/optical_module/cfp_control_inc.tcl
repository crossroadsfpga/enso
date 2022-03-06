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

 set REG_MODNAME 0x00
 set REG_SCRATCH 0x01
 set REG_OPTXENA 0x02
 set REG_CFPSTTS 0x03
 set REG_CFPCTRL 0x04

 set REG_MDIWRDT 0x10
 set REG_MDIRDDT 0x11
 set REG_MDIADDR 0x12
 set REG_MDICMMD 0x13

 set REG_2WRWRDT 0x20
 set REG_2WRSTTS 0x21
 set REG_2WRADDR 0x22
 set REG_2WRCMMD 0x23

# =====================================================
#     test utilities
# =====================================================

set log 0

proc pmdc_init {LOG} {
    global log
    set log $LOG
}

proc cfp_on {} {
    global BASE_PMDC
    global REG_OPTXENA
    global rdata
    global log
    reg_write $BASE_PMDC $REG_OPTXENA 0x01
    set rdata [reg_read $BASE_PMDC $REG_OPTXENA]

    set msg_hdr_title "____________INFO: CFP Turn ON Confirmation _________________________"
    if {$log == "both"} {putl "$msg_hdr_title"; puts "$msg_hdr_title\r"} elseif {$log == "log"} {putl "$msg_hdr_title"} else {puts "$msg_hdr_title\r"}
    set msg_temp " CFP ENable Control Value (Verified): $rdata "
    if {$log == "both"} {putl "$msg_temp\r"; puts "$msg_temp\n"} elseif {$log == "log"} {putl "$msg_temp\r"} else {puts "$msg_temp\n"}
}
