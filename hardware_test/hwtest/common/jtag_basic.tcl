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



proc list_jtag {} {
    global jtag_master_list
    global selected_jtag

    if {![info exists selected_jtag]} {set selected_jtag 0}

    set jtag_master_list [get_service_paths master]
    set n 0

    puts "Available JTAG Masters:"

    foreach {path} $jtag_master_list {
        puts "$n: $path"
        incr n
    }

    puts ""
    puts "Type set_jtag # to select a master"
    puts "Type list_jtag to display this list again"
    puts "Currently selected master is $selected_jtag:"
    puts [lindex $jtag_master_list $selected_jtag]
}

proc set_jtag {n} {
    global selected_jtag
    global jtag_master_list
    close_port
    set selected_jtag $n
    puts "Currently selected master is $selected_jtag:"
    puts [lindex $jtag_master_list $selected_jtag]
    open_port
}

proc open_port {} {
    variable master_claim_path
    variable jtag_master_list
    variable selected_jtag

    set port_id [lindex $jtag_master_list $selected_jtag]
    set master_claim_path [claim_service master $port_id mylib]
}

proc close_port {} {
    variable master_claim_path
    close_service master $master_claim_path
}

# Used to change JTAG masters using a matching string
# Example: switch_jtag "*10A*USB-1*"
proc switch_jtag { match_string } {
    set path_num [find_jtag $match_string]

    if {$path_num != -1} {
        set_jtag $path_num
    }

    return $path_num
}

proc find_jtag { match_string } {
    global jtag_master_list

    set index 0
    foreach path $jtag_master_list {
        set mtch [string match $match_string $path]
        if {$mtch} { return $index }
        incr index
    }
    return -1
}
#______________________________________________________________________________
# write : 32-bit data with 24-bit addresses
#______________________________________________________________________________

proc reg_write {base args} {
    variable master_claim_path

    set arg_list [regexp -all -inline {\S+} $args]
    set num_args [llength $arg_list]

    if {$num_args == 1} {
        set offset 0
        set wdata [lindex $arg_list 0]
    } elseif {$num_args == 2} {
        set offset [lindex $arg_list 0]
        set wdata  [lindex $arg_list 1]
    } else {
        puts "reg_write: rong number of arguments"
        return -1
    }

    set word_address [ expr $base + $offset ]
    set byte_address [ expr $word_address * 4 ]
    master_write_32 $master_claim_path $byte_address $wdata
    return 0
}

#______________________________________________________________________________
# read : 32-bit data with 24-bit addresses
#______________________________________________________________________________

 proc reg_read {base {offset 0}} {
    variable master_claim_path

    set word_address [ expr $base + $offset ]
    set byte_address [ expr $word_address * 4 ]
    set rdata [master_read_32 $master_claim_path $byte_address 1]
    return $rdata
}


proc widenum {upper32 lower32} {
    set multi [expr {pow(2,32)}];
    set up_conv [expr {$upper32 * $multi}];
    set temp [expr {$up_conv + $lower32}];
    return [expr {entier($temp)}];
}

proc stats_read {base loffset} {
    set hoffset [ expr $loffset + 1 ]

    set low_data [ reg_read $base $loffset ]
    set hi_data  [ reg_read $base $hoffset ]
    set data [ expr { ($hi_data << 32) + $low_data } ]
    return $data
}

list_jtag
open_port
